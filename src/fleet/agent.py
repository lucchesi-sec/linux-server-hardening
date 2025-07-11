#!/usr/bin/env python3
"""
Fleet Management Agent
Lightweight agent for fleet coordination and remote execution
"""

import os
import sys
import json
import time
import asyncio
import logging
import platform
import subprocess
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, asdict

import httpx
import yaml
from cryptography.fernet import Fernet

# Configuration
AGENT_VERSION = "1.0.0"
CONFIG_FILE = "/etc/hardening-agent/config.yaml"
AGENT_LOG = "/var/log/hardening-agent.log"
CERT_FILE = "/etc/hardening-agent/agent.crt"
KEY_FILE = "/etc/hardening-agent/agent.key"

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(AGENT_LOG),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

@dataclass
class AgentConfig:
    """Agent configuration"""
    server_url: str
    node_id: str
    api_token: str
    check_interval: int = 60
    heartbeat_interval: int = 300
    max_retries: int = 3
    encryption_key: Optional[str] = None
    capabilities: List[str] = None
    
    def __post_init__(self):
        if self.capabilities is None:
            self.capabilities = ["hardening", "compliance", "monitoring"]

@dataclass
class SystemInfo:
    """System information"""
    hostname: str
    ip_address: str
    os_name: str
    os_version: str
    kernel_version: str
    architecture: str
    memory_total: int
    cpu_count: int
    disk_usage: Dict[str, Any]
    uptime: float
    last_boot: str

@dataclass
class TaskExecution:
    """Task execution result"""
    task_id: str
    command: str
    status: str  # pending, running, completed, failed
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    exit_code: Optional[int] = None
    stdout: Optional[str] = None
    stderr: Optional[str] = None
    error: Optional[str] = None

class FleetAgent:
    """Fleet management agent"""
    
    def __init__(self, config_path: str = CONFIG_FILE):
        self.config_path = config_path
        self.config = self._load_config()
        self.client = None
        self.encryption = None
        self.running = False
        self.active_tasks: Dict[str, TaskExecution] = {}
        
        # Initialize encryption if key provided
        if self.config.encryption_key:
            self.encryption = Fernet(self.config.encryption_key.encode())
    
    def _load_config(self) -> AgentConfig:
        """Load agent configuration"""
        try:
            with open(self.config_path, 'r') as f:
                config_data = yaml.safe_load(f)
            
            return AgentConfig(**config_data)
        except Exception as e:
            logger.error(f"Failed to load configuration: {e}")
            # Return minimal config for testing
            return AgentConfig(
                server_url="http://localhost:8000",
                node_id=platform.node(),
                api_token="hardening-api-token"
            )
    
    def _get_system_info(self) -> SystemInfo:
        """Collect system information"""
        try:
            import psutil
            
            # Get network interface IP
            hostname = platform.node()
            ip_address = "127.0.0.1"  # Default fallback
            
            try:
                # Try to get primary network interface IP
                import socket
                s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                s.connect(("8.8.8.8", 80))
                ip_address = s.getsockname()[0]
                s.close()
            except:
                pass
            
            # Get disk usage for root partition
            disk_usage = {}
            try:
                usage = psutil.disk_usage('/')
                disk_usage = {
                    "total": usage.total,
                    "used": usage.used,
                    "free": usage.free,
                    "percent": (usage.used / usage.total) * 100
                }
            except:
                disk_usage = {"error": "Unable to get disk usage"}
            
            # Get boot time
            boot_time = datetime.fromtimestamp(psutil.boot_time())
            uptime = time.time() - psutil.boot_time()
            
            return SystemInfo(
                hostname=hostname,
                ip_address=ip_address,
                os_name=platform.system(),
                os_version=platform.release(),
                kernel_version=platform.version(),
                architecture=platform.machine(),
                memory_total=psutil.virtual_memory().total,
                cpu_count=psutil.cpu_count(),
                disk_usage=disk_usage,
                uptime=uptime,
                last_boot=boot_time.isoformat()
            )
        except ImportError:
            logger.warning("psutil not available, using basic system info")
            return SystemInfo(
                hostname=platform.node(),
                ip_address="127.0.0.1",
                os_name=platform.system(),
                os_version=platform.release(),
                kernel_version=platform.version(),
                architecture=platform.machine(),
                memory_total=0,
                cpu_count=0,
                disk_usage={},
                uptime=0,
                last_boot=datetime.now().isoformat()
            )
    
    async def _make_request(self, method: str, endpoint: str, **kwargs) -> Optional[Dict]:
        """Make HTTP request to management server"""
        if not self.client:
            return None
        
        url = f"{self.config.server_url}{endpoint}"
        headers = {"Authorization": f"Bearer {self.config.api_token}"}
        
        try:
            response = await self.client.request(
                method=method,
                url=url,
                headers=headers,
                timeout=30.0,
                **kwargs
            )
            
            if response.status_code == 200:
                return response.json()
            else:
                logger.error(f"Request failed: {response.status_code} - {response.text}")
                return None
                
        except Exception as e:
            logger.error(f"Request error: {e}")
            return None
    
    async def register_node(self) -> bool:
        """Register node with management server"""
        system_info = self._get_system_info()
        
        registration_data = {
            "hostname": system_info.hostname,
            "ip_address": system_info.ip_address,
            "os_info": {
                "name": system_info.os_name,
                "version": system_info.os_version,
                "kernel": system_info.kernel_version,
                "architecture": system_info.architecture
            },
            "capabilities": self.config.capabilities
        }
        
        response = await self._make_request(
            "POST",
            "/api/v1/fleet/register",
            json=registration_data
        )
        
        if response:
            logger.info(f"Node registered successfully: {response.get('node_id')}")
            return True
        else:
            logger.error("Failed to register node")
            return False
    
    async def send_heartbeat(self) -> bool:
        """Send heartbeat to management server"""
        system_info = self._get_system_info()
        
        heartbeat_data = {
            "node_id": self.config.node_id,
            "timestamp": datetime.utcnow().isoformat(),
            "status": "active",
            "system_info": asdict(system_info),
            "active_tasks": len([t for t in self.active_tasks.values() if t.status == "running"]),
            "agent_version": AGENT_VERSION
        }
        
        response = await self._make_request(
            "POST",
            "/api/v1/fleet/heartbeat",
            json=heartbeat_data
        )
        
        return response is not None
    
    async def check_for_tasks(self) -> List[Dict]:
        """Check for pending tasks"""
        response = await self._make_request(
            "GET",
            f"/api/v1/fleet/tasks?node_id={self.config.node_id}&status=pending"
        )
        
        if response:
            return response.get("tasks", [])
        return []
    
    async def execute_task(self, task: Dict) -> TaskExecution:
        """Execute a task"""
        task_id = task["id"]
        command = task["command"]
        
        logger.info(f"Executing task {task_id}: {command}")
        
        execution = TaskExecution(
            task_id=task_id,
            command=command,
            status="running",
            started_at=datetime.utcnow()
        )
        
        self.active_tasks[task_id] = execution
        
        try:
            # Execute command
            process = await asyncio.create_subprocess_shell(
                command,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await process.communicate()
            
            execution.status = "completed" if process.returncode == 0 else "failed"
            execution.exit_code = process.returncode
            execution.stdout = stdout.decode() if stdout else None
            execution.stderr = stderr.decode() if stderr else None
            execution.completed_at = datetime.utcnow()
            
        except Exception as e:
            execution.status = "failed"
            execution.error = str(e)
            execution.completed_at = datetime.utcnow()
            logger.error(f"Task execution failed: {e}")
        
        return execution
    
    async def report_task_result(self, execution: TaskExecution) -> bool:
        """Report task execution result"""
        result_data = asdict(execution)
        
        # Convert datetime objects to ISO format
        if execution.started_at:
            result_data["started_at"] = execution.started_at.isoformat()
        if execution.completed_at:
            result_data["completed_at"] = execution.completed_at.isoformat()
        
        response = await self._make_request(
            "POST",
            f"/api/v1/fleet/tasks/{execution.task_id}/result",
            json=result_data
        )
        
        return response is not None
    
    async def process_hardening_command(self, command: str) -> Dict[str, Any]:
        """Process hardening-specific commands"""
        logger.info(f"Processing hardening command: {command}")
        
        # Parse command
        parts = command.split()
        if not parts or parts[0] != "harden":
            return {"error": "Invalid hardening command"}
        
        # Build command path
        script_path = Path(__file__).parent.parent.parent / "harden.sh"
        if not script_path.exists():
            return {"error": "Hardening script not found"}
        
        # Execute hardening command
        full_command = f"sudo {script_path} {' '.join(parts[1:])}"
        
        try:
            process = await asyncio.create_subprocess_shell(
                full_command,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await process.communicate()
            
            return {
                "exit_code": process.returncode,
                "stdout": stdout.decode() if stdout else "",
                "stderr": stderr.decode() if stderr else "",
                "success": process.returncode == 0
            }
            
        except Exception as e:
            return {"error": str(e), "success": False}
    
    async def cleanup_old_tasks(self):
        """Clean up old completed tasks"""
        cutoff_time = datetime.utcnow() - timedelta(hours=24)
        
        to_remove = []
        for task_id, execution in self.active_tasks.items():
            if (execution.status in ["completed", "failed"] and 
                execution.completed_at and 
                execution.completed_at < cutoff_time):
                to_remove.append(task_id)
        
        for task_id in to_remove:
            del self.active_tasks[task_id]
        
        if to_remove:
            logger.info(f"Cleaned up {len(to_remove)} old tasks")
    
    async def run(self):
        """Main agent loop"""
        logger.info(f"Starting Fleet Agent v{AGENT_VERSION}")
        
        # Initialize HTTP client
        self.client = httpx.AsyncClient()
        self.running = True
        
        try:
            # Register with management server
            if not await self.register_node():
                logger.error("Failed to register node, continuing anyway...")
            
            last_heartbeat = 0
            last_cleanup = 0
            
            while self.running:
                current_time = time.time()
                
                # Send heartbeat
                if current_time - last_heartbeat >= self.config.heartbeat_interval:
                    await self.send_heartbeat()
                    last_heartbeat = current_time
                
                # Check for new tasks
                tasks = await self.check_for_tasks()
                
                for task in tasks:
                    # Execute task in background
                    asyncio.create_task(self._handle_task(task))
                
                # Cleanup old tasks
                if current_time - last_cleanup >= 3600:  # Every hour
                    await self.cleanup_old_tasks()
                    last_cleanup = current_time
                
                # Wait before next check
                await asyncio.sleep(self.config.check_interval)
                
        except KeyboardInterrupt:
            logger.info("Agent stopped by user")
        except Exception as e:
            logger.error(f"Agent error: {e}")
        finally:
            self.running = False
            if self.client:
                await self.client.aclose()
    
    async def _handle_task(self, task: Dict):
        """Handle individual task execution"""
        try:
            execution = await self.execute_task(task)
            await self.report_task_result(execution)
        except Exception as e:
            logger.error(f"Task handling error: {e}")
    
    def stop(self):
        """Stop the agent"""
        self.running = False

# Command line interface
async def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Fleet Management Agent")
    parser.add_argument(
        "--config",
        default=CONFIG_FILE,
        help="Configuration file path"
    )
    parser.add_argument(
        "--daemon",
        action="store_true",
        help="Run as daemon"
    )
    parser.add_argument(
        "--test",
        action="store_true",
        help="Test configuration and exit"
    )
    
    args = parser.parse_args()
    
    # Create agent
    agent = FleetAgent(args.config)
    
    if args.test:
        # Test configuration
        system_info = agent._get_system_info()
        print("Configuration Test:")
        print(f"  Config loaded: ✓")
        print(f"  Server URL: {agent.config.server_url}")
        print(f"  Node ID: {agent.config.node_id}")
        print(f"  System Info: {system_info.hostname} ({system_info.os_name})")
        return
    
    if args.daemon:
        # TODO: Implement proper daemon mode
        logger.info("Daemon mode not yet implemented, running in foreground")
    
    # Run agent
    await agent.run()

if __name__ == "__main__":
    asyncio.run(main())