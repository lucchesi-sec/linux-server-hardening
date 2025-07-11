#!/usr/bin/env python3
"""
Linux Server Hardening Platform - REST API Server
Enterprise-grade API for fleet management and automation
"""

import os
import sys
import logging
import asyncio
import json
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, asdict
from contextlib import asynccontextmanager

import uvicorn
from fastapi import FastAPI, HTTPException, Depends, BackgroundTasks, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
import yaml

# Project imports
sys.path.append(str(Path(__file__).parent.parent))
from core.config_manager import ConfigManager
from core.module_dispatcher import ModuleDispatcher
from compliance.engine import ComplianceEngine

# Logging configuration
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Security
security = HTTPBearer()

# Data models
class HardeningRequest(BaseModel):
    """Request model for hardening operations"""
    modules: List[str] = Field(default=[], description="Modules to execute")
    config: Optional[Dict[str, Any]] = Field(default=None, description="Custom configuration")
    dry_run: bool = Field(default=False, description="Preview mode")
    profile: Optional[str] = Field(default=None, description="Compliance profile")

class ComplianceScanRequest(BaseModel):
    """Request model for compliance scans"""
    framework: str = Field(description="Compliance framework")
    profile: str = Field(default="default", description="Scan profile")
    output_format: str = Field(default="json", description="Report format")

class FleetDeployRequest(BaseModel):
    """Request model for fleet deployment"""
    targets: List[str] = Field(description="Target nodes")
    modules: List[str] = Field(description="Modules to deploy")
    config: Optional[Dict[str, Any]] = Field(default=None)
    async_execution: bool = Field(default=True, description="Asynchronous execution")

class NodeRegistration(BaseModel):
    """Request model for node registration"""
    hostname: str = Field(description="Node hostname")
    ip_address: str = Field(description="Node IP address")
    os_info: Dict[str, str] = Field(description="Operating system information")
    capabilities: List[str] = Field(default=[], description="Node capabilities")

@dataclass
class TaskResult:
    """Task execution result"""
    task_id: str
    status: str  # pending, running, completed, failed
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    result: Optional[Dict[str, Any]] = None
    error: Optional[str] = None

# Application state
class AppState:
    """Application state management"""
    
    def __init__(self):
        self.config_manager = ConfigManager()
        self.module_dispatcher = ModuleDispatcher()
        self.compliance_engine = ComplianceEngine()
        self.active_tasks: Dict[str, TaskResult] = {}
        self.registered_nodes: Dict[str, Dict[str, Any]] = {}
        
    async def initialize(self):
        """Initialize application components"""
        logger.info("Initializing application state...")
        
        # Load default configuration
        await self.config_manager.load_config()
        
        # Initialize compliance engine
        await self.compliance_engine.initialize()
        
        logger.info("Application state initialized")

# Global state instance
app_state = AppState()

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan management"""
    # Startup
    await app_state.initialize()
    yield
    # Shutdown
    logger.info("Shutting down application...")

# FastAPI application
app = FastAPI(
    title="Linux Server Hardening Platform API",
    description="Enterprise security hardening and compliance automation",
    version="1.0.0",
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Authentication dependency
async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Simple token authentication - enhance for production"""
    # TODO: Implement proper JWT/OAuth authentication
    if credentials.credentials != "hardening-api-token":
        raise HTTPException(status_code=401, detail="Invalid authentication credentials")
    return {"user_id": "api_user", "permissions": ["all"]}

# Utility functions
def generate_task_id() -> str:
    """Generate unique task ID"""
    import uuid
    return f"task_{uuid.uuid4().hex[:8]}"

async def execute_hardening_task(task_id: str, request: HardeningRequest):
    """Execute hardening task in background"""
    try:
        task = app_state.active_tasks[task_id]
        task.status = "running"
        task.started_at = datetime.utcnow()
        
        # Execute hardening modules
        result = await app_state.module_dispatcher.execute_modules(
            modules=request.modules,
            config=request.config,
            dry_run=request.dry_run
        )
        
        task.status = "completed"
        task.result = result
        task.completed_at = datetime.utcnow()
        
    except Exception as e:
        task = app_state.active_tasks[task_id]
        task.status = "failed"
        task.error = str(e)
        task.completed_at = datetime.utcnow()
        logger.error(f"Task {task_id} failed: {e}")

# API Routes

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "version": "1.0.0"
    }

@app.get("/api/v1/status")
async def get_system_status(user: dict = Depends(get_current_user)):
    """Get system status and capabilities"""
    return {
        "system": {
            "hostname": os.uname().nodename,
            "os": f"{os.uname().sysname} {os.uname().release}",
            "uptime": "N/A"  # TODO: Implement uptime calculation
        },
        "hardening": {
            "available_modules": app_state.module_dispatcher.get_available_modules(),
            "active_tasks": len([t for t in app_state.active_tasks.values() if t.status == "running"])
        },
        "compliance": {
            "supported_frameworks": app_state.compliance_engine.get_supported_frameworks(),
            "last_scan": "N/A"  # TODO: Get last scan timestamp
        }
    }

@app.post("/api/v1/hardening/apply")
async def apply_hardening(
    request: HardeningRequest,
    background_tasks: BackgroundTasks,
    user: dict = Depends(get_current_user)
):
    """Apply hardening configuration"""
    task_id = generate_task_id()
    
    # Create task
    task = TaskResult(
        task_id=task_id,
        status="pending"
    )
    app_state.active_tasks[task_id] = task
    
    # Execute in background
    background_tasks.add_task(execute_hardening_task, task_id, request)
    
    return {
        "task_id": task_id,
        "status": "pending",
        "message": "Hardening task initiated"
    }

@app.get("/api/v1/hardening/validate")
async def validate_hardening(user: dict = Depends(get_current_user)):
    """Validate current hardening status"""
    try:
        # Run validation engine
        validation_result = await app_state.module_dispatcher.validate_system()
        
        return {
            "status": "success",
            "validation": validation_result,
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        logger.error(f"Validation failed: {e}")
        raise HTTPException(status_code=500, detail=f"Validation failed: {str(e)}")

@app.get("/api/v1/tasks/{task_id}")
async def get_task_status(task_id: str, user: dict = Depends(get_current_user)):
    """Get task execution status"""
    if task_id not in app_state.active_tasks:
        raise HTTPException(status_code=404, detail="Task not found")
    
    task = app_state.active_tasks[task_id]
    return asdict(task)

@app.get("/api/v1/tasks")
async def list_tasks(
    status: Optional[str] = None,
    limit: int = 50,
    user: dict = Depends(get_current_user)
):
    """List active tasks"""
    tasks = list(app_state.active_tasks.values())
    
    # Filter by status if specified
    if status:
        tasks = [t for t in tasks if t.status == status]
    
    # Apply limit
    tasks = tasks[:limit]
    
    return {
        "tasks": [asdict(task) for task in tasks],
        "total": len(tasks)
    }

@app.post("/api/v1/compliance/scan")
async def run_compliance_scan(
    request: ComplianceScanRequest,
    background_tasks: BackgroundTasks,
    user: dict = Depends(get_current_user)
):
    """Run compliance scan"""
    task_id = generate_task_id()
    
    try:
        # Execute compliance scan
        result = await app_state.compliance_engine.run_scan(
            framework=request.framework,
            profile=request.profile,
            output_format=request.output_format
        )
        
        return {
            "task_id": task_id,
            "status": "completed",
            "result": result
        }
    except Exception as e:
        logger.error(f"Compliance scan failed: {e}")
        raise HTTPException(status_code=500, detail=f"Compliance scan failed: {str(e)}")

@app.get("/api/v1/compliance/frameworks")
async def list_compliance_frameworks(user: dict = Depends(get_current_user)):
    """List available compliance frameworks"""
    return {
        "frameworks": app_state.compliance_engine.get_supported_frameworks()
    }

@app.get("/api/v1/compliance/reports")
async def list_compliance_reports(
    framework: Optional[str] = None,
    limit: int = 20,
    user: dict = Depends(get_current_user)
):
    """List compliance reports"""
    try:
        reports = app_state.compliance_engine.list_reports(
            framework=framework,
            limit=limit
        )
        
        return {
            "reports": reports,
            "total": len(reports)
        }
    except Exception as e:
        logger.error(f"Failed to list reports: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to list reports: {str(e)}")

@app.post("/api/v1/fleet/register")
async def register_node(
    request: NodeRegistration,
    user: dict = Depends(get_current_user)
):
    """Register a new node in the fleet"""
    node_id = f"{request.hostname}_{request.ip_address}"
    
    app_state.registered_nodes[node_id] = {
        "id": node_id,
        "hostname": request.hostname,
        "ip_address": request.ip_address,
        "os_info": request.os_info,
        "capabilities": request.capabilities,
        "registered_at": datetime.utcnow().isoformat(),
        "last_seen": datetime.utcnow().isoformat(),
        "status": "active"
    }
    
    return {
        "node_id": node_id,
        "status": "registered",
        "message": f"Node {request.hostname} registered successfully"
    }

@app.get("/api/v1/fleet/nodes")
async def list_fleet_nodes(
    status: Optional[str] = None,
    user: dict = Depends(get_current_user)
):
    """List fleet nodes"""
    nodes = list(app_state.registered_nodes.values())
    
    # Filter by status if specified
    if status:
        nodes = [n for n in nodes if n["status"] == status]
    
    return {
        "nodes": nodes,
        "total": len(nodes)
    }

@app.post("/api/v1/fleet/deploy")
async def deploy_to_fleet(
    request: FleetDeployRequest,
    background_tasks: BackgroundTasks,
    user: dict = Depends(get_current_user)
):
    """Deploy hardening to fleet"""
    task_id = generate_task_id()
    
    # Validate targets
    invalid_targets = [t for t in request.targets if t not in app_state.registered_nodes]
    if invalid_targets:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid targets: {invalid_targets}"
        )
    
    # Create deployment task
    task = TaskResult(
        task_id=task_id,
        status="pending"
    )
    app_state.active_tasks[task_id] = task
    
    # TODO: Implement fleet deployment logic
    
    return {
        "task_id": task_id,
        "status": "pending",
        "targets": request.targets,
        "modules": request.modules,
        "message": "Fleet deployment initiated"
    }

@app.get("/api/v1/fleet/metrics")
async def get_fleet_metrics(user: dict = Depends(get_current_user)):
    """Get fleet-wide metrics"""
    nodes = list(app_state.registered_nodes.values())
    
    return {
        "total_nodes": len(nodes),
        "active_nodes": len([n for n in nodes if n["status"] == "active"]),
        "os_distribution": {},  # TODO: Calculate OS distribution
        "compliance_status": {},  # TODO: Calculate compliance status
        "last_updated": datetime.utcnow().isoformat()
    }

@app.get("/api/v1/config/profiles")
async def list_configuration_profiles(user: dict = Depends(get_current_user)):
    """List available configuration profiles"""
    try:
        profiles = app_state.config_manager.get_available_profiles()
        return {
            "profiles": profiles
        }
    except Exception as e:
        logger.error(f"Failed to list profiles: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to list profiles: {str(e)}")

@app.get("/api/v1/config/modules")
async def list_available_modules(user: dict = Depends(get_current_user)):
    """List available hardening modules"""
    return {
        "modules": app_state.module_dispatcher.get_available_modules()
    }

# Error handlers
@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    """Handle HTTP exceptions"""
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": exc.detail,
            "status_code": exc.status_code,
            "timestamp": datetime.utcnow().isoformat()
        }
    )

@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    """Handle general exceptions"""
    logger.error(f"Unhandled exception: {exc}")
    return JSONResponse(
        status_code=500,
        content={
            "error": "Internal server error",
            "status_code": 500,
            "timestamp": datetime.utcnow().isoformat()
        }
    )

# Webhook endpoints
@app.post("/api/v1/webhooks/github")
async def github_webhook(request: Request, user: dict = Depends(get_current_user)):
    """Handle GitHub webhooks"""
    payload = await request.json()
    
    # TODO: Implement GitHub webhook processing
    logger.info(f"GitHub webhook received: {payload.get('action', 'unknown')}")
    
    return {"status": "processed"}

@app.post("/api/v1/webhooks/alerts")
async def security_alert_webhook(request: Request, user: dict = Depends(get_current_user)):
    """Handle security alert webhooks"""
    payload = await request.json()
    
    # TODO: Implement alert processing
    logger.info(f"Security alert received: {payload}")
    
    return {"status": "processed"}

# Development server
if __name__ == "__main__":
    uvicorn.run(
        "server:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )