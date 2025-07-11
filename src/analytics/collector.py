#!/usr/bin/env python3
"""
Security Analytics Collector
Real-time security metrics and event collection for threat analysis
"""

import os
import sys
import json
import time
import asyncio
import logging
import hashlib
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Any, Union
from dataclasses import dataclass, asdict
from collections import defaultdict, deque

import psutil
import yaml

# Logging configuration
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@dataclass
class SecurityEvent:
    """Security event data structure"""
    timestamp: str
    event_type: str
    source: str
    severity: str  # critical, high, medium, low, info
    description: str
    details: Dict[str, Any]
    host: str
    user: Optional[str] = None
    process: Optional[str] = None
    network_info: Optional[Dict[str, str]] = None
    file_info: Optional[Dict[str, str]] = None

@dataclass
class SystemMetrics:
    """System performance and security metrics"""
    timestamp: str
    cpu_usage: float
    memory_usage: float
    disk_usage: Dict[str, float]
    network_connections: int
    active_processes: int
    failed_logins: int
    security_alerts: int
    compliance_score: float

@dataclass
class ThreatIndicator:
    """Threat intelligence indicator"""
    indicator_type: str  # ip, domain, hash, url
    value: str
    threat_type: str
    confidence: float
    first_seen: str
    last_seen: str
    count: int
    source: str

class SecurityAnalyticsCollector:
    """Main analytics collection engine"""
    
    def __init__(self, config_path: Optional[str] = None):
        self.config = self._load_config(config_path)
        self.events_buffer = deque(maxlen=10000)
        self.metrics_buffer = deque(maxlen=1000)
        self.threat_indicators = {}
        self.baseline_metrics = {}
        self.anomaly_thresholds = {}
        self.running = False
        
        # Initialize components
        self.log_parsers = {
            'auth': AuthLogParser(),
            'syslog': SyslogParser(),
            'audit': AuditLogParser(),
            'apache': ApacheLogParser(),
            'nginx': NginxLogParser()
        }
        
        self.metric_collectors = {
            'system': SystemMetricCollector(),
            'network': NetworkMetricCollector(), 
            'security': SecurityMetricCollector(),
            'compliance': ComplianceMetricCollector()
        }
    
    def _load_config(self, config_path: Optional[str]) -> Dict[str, Any]:
        """Load collector configuration"""
        default_config = {
            'collection_interval': 60,
            'log_paths': {
                'auth': '/var/log/auth.log',
                'syslog': '/var/log/syslog',
                'audit': '/var/log/audit/audit.log',
                'apache': '/var/log/apache2/access.log',
                'nginx': '/var/log/nginx/access.log'
            },
            'thresholds': {
                'cpu_high': 80.0,
                'memory_high': 85.0,
                'disk_high': 90.0,
                'failed_login_count': 5,
                'network_connections_high': 1000
            },
            'retention': {
                'events_days': 30,
                'metrics_days': 90
            },
            'export': {
                'prometheus': True,
                'elasticsearch': False,
                'syslog': False
            }
        }
        
        if config_path and Path(config_path).exists():
            try:
                with open(config_path, 'r') as f:
                    config_data = yaml.safe_load(f)
                default_config.update(config_data)
            except Exception as e:
                logger.error(f"Failed to load config: {e}")
        
        return default_config
    
    async def start_collection(self):
        """Start the analytics collection process"""
        logger.info("Starting security analytics collection...")
        self.running = True
        
        # Start collection tasks
        tasks = [
            asyncio.create_task(self._log_collection_loop()),
            asyncio.create_task(self._metric_collection_loop()),
            asyncio.create_task(self._anomaly_detection_loop()),
            asyncio.create_task(self._export_loop())
        ]
        
        try:
            await asyncio.gather(*tasks)
        except Exception as e:
            logger.error(f"Collection error: {e}")
        finally:
            self.running = False
    
    async def _log_collection_loop(self):
        """Main log collection loop"""
        while self.running:
            try:
                for log_type, parser in self.log_parsers.items():
                    log_path = self.config['log_paths'].get(log_type)
                    if log_path and Path(log_path).exists():
                        events = await parser.parse_new_events(log_path)
                        for event in events:
                            self.events_buffer.append(event)
                            await self._process_security_event(event)
                
                await asyncio.sleep(10)  # Check logs every 10 seconds
                
            except Exception as e:
                logger.error(f"Log collection error: {e}")
                await asyncio.sleep(30)
    
    async def _metric_collection_loop(self):
        """System metrics collection loop"""
        while self.running:
            try:
                metrics = {}
                
                for collector_name, collector in self.metric_collectors.items():
                    collector_metrics = await collector.collect_metrics()
                    metrics.update(collector_metrics)
                
                # Create system metrics object
                system_metrics = SystemMetrics(
                    timestamp=datetime.utcnow().isoformat(),
                    cpu_usage=metrics.get('cpu_usage', 0.0),
                    memory_usage=metrics.get('memory_usage', 0.0),
                    disk_usage=metrics.get('disk_usage', {}),
                    network_connections=metrics.get('network_connections', 0),
                    active_processes=metrics.get('active_processes', 0),
                    failed_logins=metrics.get('failed_logins', 0),
                    security_alerts=metrics.get('security_alerts', 0),
                    compliance_score=metrics.get('compliance_score', 0.0)
                )
                
                self.metrics_buffer.append(system_metrics)
                await self._analyze_metrics(system_metrics)
                
                await asyncio.sleep(self.config['collection_interval'])
                
            except Exception as e:
                logger.error(f"Metrics collection error: {e}")
                await asyncio.sleep(60)
    
    async def _anomaly_detection_loop(self):
        """Anomaly detection and alerting loop"""
        while self.running:
            try:
                # Analyze recent metrics for anomalies
                if len(self.metrics_buffer) >= 10:
                    await self._detect_anomalies()
                
                await asyncio.sleep(300)  # Check every 5 minutes
                
            except Exception as e:
                logger.error(f"Anomaly detection error: {e}")
                await asyncio.sleep(300)
    
    async def _export_loop(self):
        """Export metrics to external systems"""
        while self.running:
            try:
                if self.config['export']['prometheus']:
                    await self._export_prometheus_metrics()
                
                if self.config['export']['elasticsearch']:
                    await self._export_elasticsearch_events()
                
                await asyncio.sleep(60)  # Export every minute
                
            except Exception as e:
                logger.error(f"Export error: {e}")
                await asyncio.sleep(120)
    
    async def _process_security_event(self, event: SecurityEvent):
        """Process and analyze security events"""
        # Check for threat indicators
        await self._check_threat_indicators(event)
        
        # Update security metrics
        await self._update_security_metrics(event)
        
        # Generate alerts for high severity events
        if event.severity in ['critical', 'high']:
            await self._generate_alert(event)
    
    async def _check_threat_indicators(self, event: SecurityEvent):
        """Check event against threat intelligence"""
        # Extract potential indicators
        indicators = []
        
        if event.network_info:
            ip = event.network_info.get('source_ip')
            if ip:
                indicators.append(('ip', ip))
        
        if event.file_info:
            file_hash = event.file_info.get('hash')
            if file_hash:
                indicators.append(('hash', file_hash))
        
        # Check against known threats
        for indicator_type, value in indicators:
            threat_key = f"{indicator_type}:{value}"
            if threat_key in self.threat_indicators:
                threat = self.threat_indicators[threat_key]
                threat.count += 1
                threat.last_seen = event.timestamp
                
                # Generate threat alert
                await self._generate_threat_alert(event, threat)
    
    async def _analyze_metrics(self, metrics: SystemMetrics):
        """Analyze system metrics for security implications"""
        thresholds = self.config['thresholds']
        
        # Check resource utilization
        if metrics.cpu_usage > thresholds['cpu_high']:
            await self._generate_resource_alert('cpu', metrics.cpu_usage)
        
        if metrics.memory_usage > thresholds['memory_high']:
            await self._generate_resource_alert('memory', metrics.memory_usage)
        
        # Check disk usage
        for mount, usage in metrics.disk_usage.items():
            if usage > thresholds['disk_high']:
                await self._generate_resource_alert('disk', usage, mount)
        
        # Check network connections
        if metrics.network_connections > thresholds['network_connections_high']:
            await self._generate_resource_alert('network', metrics.network_connections)
    
    async def _detect_anomalies(self):
        """Detect anomalous patterns in metrics"""
        recent_metrics = list(self.metrics_buffer)[-10:]
        
        # Calculate baseline if not established
        if not self.baseline_metrics:
            await self._establish_baseline()
        
        # Detect CPU anomalies
        cpu_values = [m.cpu_usage for m in recent_metrics]
        await self._check_metric_anomaly('cpu_usage', cpu_values)
        
        # Detect memory anomalies
        memory_values = [m.memory_usage for m in recent_metrics]
        await self._check_metric_anomaly('memory_usage', memory_values)
        
        # Detect network anomalies
        network_values = [m.network_connections for m in recent_metrics]
        await self._check_metric_anomaly('network_connections', network_values)
    
    async def _check_metric_anomaly(self, metric_name: str, values: List[float]):
        """Check for anomalies in a specific metric"""
        if metric_name not in self.baseline_metrics:
            return
        
        baseline = self.baseline_metrics[metric_name]
        current_avg = sum(values) / len(values)
        
        # Simple anomaly detection (z-score based)
        z_score = abs(current_avg - baseline['mean']) / baseline['std']
        
        if z_score > 2.0:  # 2 standard deviations
            severity = 'high' if z_score > 3.0 else 'medium'
            await self._generate_anomaly_alert(metric_name, current_avg, baseline, severity)
    
    async def _establish_baseline(self):
        """Establish baseline metrics for anomaly detection"""
        if len(self.metrics_buffer) < 50:
            return
        
        recent_metrics = list(self.metrics_buffer)[-50:]
        
        # Calculate baselines for key metrics
        metrics_data = {
            'cpu_usage': [m.cpu_usage for m in recent_metrics],
            'memory_usage': [m.memory_usage for m in recent_metrics],
            'network_connections': [m.network_connections for m in recent_metrics]
        }
        
        for metric_name, values in metrics_data.items():
            mean = sum(values) / len(values)
            variance = sum((x - mean) ** 2 for x in values) / len(values)
            std = variance ** 0.5
            
            self.baseline_metrics[metric_name] = {
                'mean': mean,
                'std': std,
                'min': min(values),
                'max': max(values)
            }
        
        logger.info("Baseline metrics established")
    
    async def _generate_alert(self, event: SecurityEvent):
        """Generate security alert"""
        alert = {
            'type': 'security_alert',
            'timestamp': datetime.utcnow().isoformat(),
            'event': asdict(event),
            'alert_id': self._generate_alert_id(event)
        }
        
        logger.warning(f"Security Alert: {event.description}")
        
        # Export alert
        await self._export_alert(alert)
    
    async def _generate_threat_alert(self, event: SecurityEvent, threat: ThreatIndicator):
        """Generate threat intelligence alert"""
        alert = {
            'type': 'threat_alert',
            'timestamp': datetime.utcnow().isoformat(),
            'event': asdict(event),
            'threat': asdict(threat),
            'alert_id': self._generate_alert_id(event, 'threat')
        }
        
        logger.error(f"Threat Alert: {threat.threat_type} detected - {threat.value}")
        
        # Export alert
        await self._export_alert(alert)
    
    async def _generate_resource_alert(self, resource_type: str, value: float, mount: str = None):
        """Generate resource utilization alert"""
        description = f"High {resource_type} usage: {value}%"
        if mount:
            description += f" on {mount}"
        
        alert = {
            'type': 'resource_alert',
            'timestamp': datetime.utcnow().isoformat(),
            'resource_type': resource_type,
            'value': value,
            'mount': mount,
            'description': description,
            'alert_id': hashlib.md5(f"{resource_type}_{value}_{int(time.time())}".encode()).hexdigest()[:16]
        }
        
        logger.warning(description)
        
        # Export alert
        await self._export_alert(alert)
    
    async def _generate_anomaly_alert(self, metric_name: str, current_value: float, baseline: Dict, severity: str):
        """Generate anomaly detection alert"""
        alert = {
            'type': 'anomaly_alert',
            'timestamp': datetime.utcnow().isoformat(),
            'metric_name': metric_name,
            'current_value': current_value,
            'baseline': baseline,
            'severity': severity,
            'description': f"Anomaly detected in {metric_name}: {current_value:.2f} (baseline: {baseline['mean']:.2f})",
            'alert_id': hashlib.md5(f"anomaly_{metric_name}_{int(time.time())}".encode()).hexdigest()[:16]
        }
        
        logger.warning(f"Anomaly Alert: {alert['description']}")
        
        # Export alert
        await self._export_alert(alert)
    
    def _generate_alert_id(self, event: SecurityEvent, prefix: str = 'sec') -> str:
        """Generate unique alert ID"""
        data = f"{prefix}_{event.timestamp}_{event.event_type}_{event.source}"
        return hashlib.md5(data.encode()).hexdigest()[:16]
    
    async def _export_alert(self, alert: Dict[str, Any]):
        """Export alert to configured destinations"""
        # Log to file
        alert_log = Path('/var/log/security-alerts.log')
        try:
            with open(alert_log, 'a') as f:
                f.write(json.dumps(alert) + '\n')
        except Exception as e:
            logger.error(f"Failed to write alert to file: {e}")
        
        # Send to syslog if configured
        if self.config['export']['syslog']:
            await self._send_syslog_alert(alert)
    
    async def _export_prometheus_metrics(self):
        """Export metrics in Prometheus format"""
        if not self.metrics_buffer:
            return
        
        latest_metrics = self.metrics_buffer[-1]
        metrics_file = Path('/tmp/security_metrics.prom')
        
        try:
            with open(metrics_file, 'w') as f:
                f.write(f"# HELP security_cpu_usage CPU usage percentage\n")
                f.write(f"# TYPE security_cpu_usage gauge\n")
                f.write(f"security_cpu_usage {latest_metrics.cpu_usage}\n\n")
                
                f.write(f"# HELP security_memory_usage Memory usage percentage\n")
                f.write(f"# TYPE security_memory_usage gauge\n")
                f.write(f"security_memory_usage {latest_metrics.memory_usage}\n\n")
                
                f.write(f"# HELP security_network_connections Active network connections\n")
                f.write(f"# TYPE security_network_connections gauge\n")
                f.write(f"security_network_connections {latest_metrics.network_connections}\n\n")
                
                f.write(f"# HELP security_compliance_score Compliance score percentage\n")
                f.write(f"# TYPE security_compliance_score gauge\n")
                f.write(f"security_compliance_score {latest_metrics.compliance_score}\n\n")
        
        except Exception as e:
            logger.error(f"Failed to export Prometheus metrics: {e}")
    
    async def _update_security_metrics(self, event: SecurityEvent):
        """Update internal security metrics based on events"""
        # This would update counters and metrics based on event types
        pass
    
    def stop_collection(self):
        """Stop the analytics collection"""
        self.running = False
        logger.info("Analytics collection stopped")

# Log Parser Classes
class BaseLogParser:
    """Base class for log parsers"""
    
    def __init__(self):
        self.last_position = 0
        self.last_inode = None
    
    async def parse_new_events(self, log_path: str) -> List[SecurityEvent]:
        """Parse new log entries since last check"""
        try:
            stat = os.stat(log_path)
            
            # Check if file was rotated
            if self.last_inode and stat.st_ino != self.last_inode:
                self.last_position = 0
            
            self.last_inode = stat.st_ino
            
            # Read new content
            with open(log_path, 'r') as f:
                f.seek(self.last_position)
                new_content = f.read()
                self.last_position = f.tell()
            
            # Parse events
            return await self._parse_content(new_content)
        
        except Exception as e:
            logger.error(f"Failed to parse {log_path}: {e}")
            return []
    
    async def _parse_content(self, content: str) -> List[SecurityEvent]:
        """Parse log content - implemented by subclasses"""
        raise NotImplementedError

class AuthLogParser(BaseLogParser):
    """Authentication log parser"""
    
    async def _parse_content(self, content: str) -> List[SecurityEvent]:
        events = []
        
        for line in content.strip().split('\n'):
            if not line:
                continue
            
            # Parse auth log entries
            if 'Failed password' in line:
                event = SecurityEvent(
                    timestamp=datetime.utcnow().isoformat(),
                    event_type='authentication_failure',
                    source='auth_log',
                    severity='medium',
                    description='Failed password authentication',
                    details={'log_line': line},
                    host=os.uname().nodename
                )
                events.append(event)
            
            elif 'Accepted password' in line:
                event = SecurityEvent(
                    timestamp=datetime.utcnow().isoformat(),
                    event_type='authentication_success',
                    source='auth_log',
                    severity='info',
                    description='Successful password authentication',
                    details={'log_line': line},
                    host=os.uname().nodename
                )
                events.append(event)
        
        return events

class SyslogParser(BaseLogParser):
    """System log parser"""
    
    async def _parse_content(self, content: str) -> List[SecurityEvent]:
        events = []
        
        for line in content.strip().split('\n'):
            if not line:
                continue
            
            # Parse syslog entries for security events
            if any(keyword in line.lower() for keyword in ['error', 'warning', 'critical', 'alert']):
                severity = 'high' if any(kw in line.lower() for kw in ['critical', 'alert']) else 'medium'
                
                event = SecurityEvent(
                    timestamp=datetime.utcnow().isoformat(),
                    event_type='system_event',
                    source='syslog',
                    severity=severity,
                    description='System log event',
                    details={'log_line': line},
                    host=os.uname().nodename
                )
                events.append(event)
        
        return events

class AuditLogParser(BaseLogParser):
    """Audit log parser"""
    
    async def _parse_content(self, content: str) -> List[SecurityEvent]:
        events = []
        
        for line in content.strip().split('\n'):
            if not line or not line.startswith('type='):
                continue
            
            # Parse audit records
            if 'type=SYSCALL' in line:
                event = SecurityEvent(
                    timestamp=datetime.utcnow().isoformat(),
                    event_type='system_call',
                    source='audit_log',
                    severity='info',
                    description='System call audit event',
                    details={'log_line': line},
                    host=os.uname().nodename
                )
                events.append(event)
        
        return events

class ApacheLogParser(BaseLogParser):
    """Apache access log parser"""
    
    async def _parse_content(self, content: str) -> List[SecurityEvent]:
        events = []
        
        for line in content.strip().split('\n'):
            if not line:
                continue
            
            # Parse Apache access logs for security events
            if any(status in line for status in [' 403 ', ' 404 ', ' 500 ']):
                severity = 'medium' if ' 403 ' in line else 'low'
                
                event = SecurityEvent(
                    timestamp=datetime.utcnow().isoformat(),
                    event_type='web_access',
                    source='apache_log',
                    severity=severity,
                    description='Web access event',
                    details={'log_line': line},
                    host=os.uname().nodename
                )
                events.append(event)
        
        return events

class NginxLogParser(BaseLogParser):
    """Nginx access log parser"""
    
    async def _parse_content(self, content: str) -> List[SecurityEvent]:
        events = []
        
        for line in content.strip().split('\n'):
            if not line:
                continue
            
            # Parse Nginx access logs for security events
            if any(status in line for status in [' 403 ', ' 404 ', ' 500 ']):
                severity = 'medium' if ' 403 ' in line else 'low'
                
                event = SecurityEvent(
                    timestamp=datetime.utcnow().isoformat(),
                    event_type='web_access',
                    source='nginx_log',
                    severity=severity,
                    description='Web access event',
                    details={'log_line': line},
                    host=os.uname().nodename
                )
                events.append(event)
        
        return events

# Metric Collector Classes
class SystemMetricCollector:
    """System performance metrics collector"""
    
    async def collect_metrics(self) -> Dict[str, Any]:
        try:
            cpu_usage = psutil.cpu_percent(interval=1)
            memory = psutil.virtual_memory()
            
            disk_usage = {}
            for partition in psutil.disk_partitions():
                try:
                    usage = psutil.disk_usage(partition.mountpoint)
                    disk_usage[partition.mountpoint] = (usage.used / usage.total) * 100
                except:
                    continue
            
            return {
                'cpu_usage': cpu_usage,
                'memory_usage': memory.percent,
                'disk_usage': disk_usage,
                'active_processes': len(psutil.pids())
            }
        except Exception as e:
            logger.error(f"System metrics collection failed: {e}")
            return {}

class NetworkMetricCollector:
    """Network metrics collector"""
    
    async def collect_metrics(self) -> Dict[str, Any]:
        try:
            connections = psutil.net_connections()
            return {
                'network_connections': len(connections)
            }
        except Exception as e:
            logger.error(f"Network metrics collection failed: {e}")
            return {}

class SecurityMetricCollector:
    """Security-specific metrics collector"""
    
    async def collect_metrics(self) -> Dict[str, Any]:
        # Placeholder for security metrics
        return {
            'failed_logins': 0,
            'security_alerts': 0
        }

class ComplianceMetricCollector:
    """Compliance metrics collector"""
    
    async def collect_metrics(self) -> Dict[str, Any]:
        # Placeholder for compliance metrics
        return {
            'compliance_score': 85.0
        }

# CLI Interface
async def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Security Analytics Collector")
    parser.add_argument(
        "--config",
        help="Configuration file path"
    )
    parser.add_argument(
        "--daemon",
        action="store_true",
        help="Run as daemon"
    )
    
    args = parser.parse_args()
    
    # Create collector
    collector = SecurityAnalyticsCollector(args.config)
    
    try:
        await collector.start_collection()
    except KeyboardInterrupt:
        logger.info("Collector stopped by user")
    finally:
        collector.stop_collection()

if __name__ == "__main__":
    asyncio.run(main())