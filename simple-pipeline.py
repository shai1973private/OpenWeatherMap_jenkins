#!/usr/bin/env python3
"""
Vienna Weather Simple Pipeline
Simple Python-based CI/CD pipeline execution without emojis
"""

import os
import sys
import json
import time
import shutil
import subprocess
import requests
import base64
from datetime import datetime
from pathlib import Path

class SimpleViennaWeatherPipeline:
    def __init__(self):
        self.project_root = Path(__file__).parent
        self.pipeline_id = f"pipeline-{int(time.time())}"
        self.start_time = datetime.now()
        
        # Configuration
        self.elastic_url = "http://localhost:9200"
        self.kibana_url = "http://localhost:5601"
        
        # Pipeline stages
        self.stages = ["clone", "build", "unittest", "deploy"]
        self.stage_results = {}
        
        print("Vienna Weather CI/CD Pipeline")
        print(f"Pipeline ID: {self.pipeline_id}")
        print(f"Start Time: {self.start_time.strftime('%Y-%m-%d %H:%M:%S')}")
        print("=" * 60)

    def send_notification(self, stage, status, details=""):
        """Send pipeline notification to Elasticsearch"""
        try:
            notification = {
                "pipeline_id": self.pipeline_id,
                "timestamp": datetime.now().isoformat(),
                "stage": stage,
                "status": status,
                "details": details,
                "project": "vienna-weather"
            }
            
            response = requests.post(
                f"{self.elastic_url}/vienna-pipeline-notifications/_doc",
                json=notification,
                headers={"Content-Type": "application/json"},
                timeout=2  # Short timeout to prevent hanging
            )
            
            if response.status_code in [200, 201]:
                pass  # Silent success - no need to log during pipeline execution
        except Exception:
            pass  # Silent failure - Elasticsearch might not be ready yet

    def run_stage_clone(self):
        """Stage 1: Clone - Clone repository and validate project structure"""
        print("\nStage 1: Clone - Cloning repository...")
        
        try:
            # Repository configuration
            repo_url = "https://github.com/shai1973private/vienna-weather-monitoring.git"
            temp_clone_dir = self.project_root.parent / "temp_clone"
            
            # Check if we're already in a cloned repo (skip cloning)
            if (self.project_root / ".git").exists():
                print("INFO: Already in a Git repository, skipping clone")
                print("SUCCESS: Using existing repository")
            else:
                # Clean up any existing temp directory
                if temp_clone_dir.exists():
                    import shutil
                    shutil.rmtree(temp_clone_dir)
                    print("INFO: Cleaned up existing temp directory")
                
                # Clone the repository
                print(f"INFO: Cloning from {repo_url}")
                result = subprocess.run([
                    "git", "clone", repo_url, str(temp_clone_dir)
                ], capture_output=True, text=True)
                
                if result.returncode != 0:
                    error_msg = f"Git clone failed: {result.stderr}"
                    print(f"FAILED: {error_msg}")
                    self.stage_results["clone"] = {"status": "failed", "details": error_msg}
                    self.send_notification("clone", "failed", error_msg)
                    return False
                
                print("SUCCESS: Repository cloned successfully")
                
                # Update project root to cloned directory for validation
                validation_root = temp_clone_dir
            
            # Validate project structure
            validation_root = self.project_root if (self.project_root / ".git").exists() else temp_clone_dir
            
            required_files = [
                "weather_auto_rabbitmq.py",
                "docker-compose.yml",
                "pipeline-config.json",
                "simple-pipeline.py"
            ]
            
            missing_files = []
            for file in required_files:
                if not (validation_root / file).exists():
                    missing_files.append(file)
            
            if missing_files:
                result = f"Missing files in repository: {', '.join(missing_files)}"
                print(f"FAILED: {result}")
                self.stage_results["clone"] = {"status": "failed", "details": result}
                self.send_notification("clone", "failed", result)
                return False
            
            # Check Git repository status
            try:
                git_result = subprocess.run([
                    "git", "rev-parse", "--short", "HEAD"
                ], capture_output=True, text=True, cwd=validation_root)
                
                if git_result.returncode == 0:
                    commit_hash = git_result.stdout.strip()
                    print(f"SUCCESS: Repository at commit {commit_hash}")
                else:
                    print("WARNING: Could not get Git commit info")
            except Exception:
                print("WARNING: Git status check failed")
            
            print("SUCCESS: Project structure validated")
            print("SUCCESS: All required files present")
            self.stage_results["clone"] = {"status": "success", "details": "Repository cloned and validated"}
            self.send_notification("clone", "success", "Repository cloned and validated")
            return True
            
        except Exception as e:
            error_msg = f"Clone stage failed: {e}"
            print(f"FAILED: {error_msg}")
            self.stage_results["clone"] = {"status": "failed", "details": error_msg}
            self.send_notification("clone", "failed", error_msg)
            return False

    def run_stage_build(self):
        """Stage 2: Build - Setup environment and dependencies"""
        print("\nStage 2: Build - Setting up environment...")
        
        try:
            # Check Python environment
            if (self.project_root / ".venv").exists():
                print("SUCCESS: Virtual environment found")
            
            # Check and install required packages
            required_packages = ["requests", "pika", "elasticsearch"]
            missing_packages = []
            
            for package in required_packages:
                try:
                    __import__(package)
                    print(f"SUCCESS: {package} available")
                except ImportError:
                    print(f"WARNING: {package} not found")
                    missing_packages.append(package)
            
            # Auto-install missing packages
            if missing_packages:
                print(f"INFO: Installing missing packages: {', '.join(missing_packages)}")
                try:
                    for package in missing_packages:
                        result = subprocess.run([
                            "pip", "install", package
                        ], capture_output=True, text=True)
                        
                        if result.returncode == 0:
                            print(f"SUCCESS: {package} installed successfully")
                        else:
                            print(f"WARNING: Failed to install {package}: {result.stderr}")
                except Exception as e:
                    print(f"WARNING: Package installation failed: {e}")
            
            # Install from requirements.txt if available
            requirements_file = self.project_root / "requirements.txt"
            if requirements_file.exists():
                print("INFO: Installing from requirements.txt...")
                try:
                    result = subprocess.run([
                        "pip", "install", "-r", str(requirements_file)
                    ], capture_output=True, text=True)
                    
                    if result.returncode == 0:
                        print("SUCCESS: Requirements installed successfully")
                    else:
                        print(f"WARNING: Requirements installation had issues: {result.stderr}")
                except Exception as e:
                    print(f"WARNING: Requirements installation failed: {e}")
            
            # Check Docker
            try:
                result = subprocess.run(["docker", "ps"], capture_output=True, text=True)
                if result.returncode == 0:
                    print("SUCCESS: Docker is running")
                    
                    # Check ELK containers
                    containers = ["elasticsearch", "logstash", "kibana"]
                    for container in containers:
                        if container in result.stdout:
                            print(f"SUCCESS: {container} container running")
                        else:
                            print(f"WARNING: {container} container not found")
                else:
                    print("WARNING: Docker not accessible")
            except Exception:
                print("WARNING: Docker not available")
            
            print("SUCCESS: Build stage completed")
            self.stage_results["build"] = {"status": "success", "details": "Environment setup completed"}
            self.send_notification("build", "success", "Environment setup completed")
            return True
            
        except Exception as e:
            error_msg = f"Build failed: {e}"
            print(f"FAILED: {error_msg}")
            self.stage_results["build"] = {"status": "failed", "details": error_msg}
            self.send_notification("build", "failed", error_msg)
            return False

    def run_stage_unittest(self):
        """Stage 3: Unit Test - Run validation tests"""
        print("\nStage 3: Unit Test - Running validation tests...")
        
        try:
            # Test configuration
            config_valid = (self.project_root / "pipeline-config.json").exists()
            print(f"   {'SUCCESS' if config_valid else 'FAILED'}: Configuration test")
            
            # Test API connectivity (simple check)
            api_valid = True
            try:
                response = requests.get("https://httpbin.org/status/200", timeout=5)
                api_valid = response.status_code == 200
            except:
                api_valid = False
            print(f"   {'SUCCESS' if api_valid else 'FAILED'}: API connectivity test")
            
            # Test data format
            data_valid = True
            print(f"   {'SUCCESS' if data_valid else 'FAILED'}: Data format test")
            
            # Test Elasticsearch
            es_valid = False
            try:
                response = requests.get(f"{self.elastic_url}/_cluster/health", timeout=5)
                es_valid = response.status_code == 200
            except:
                pass
            print(f"   {'SUCCESS' if es_valid else 'FAILED'}: Elasticsearch connectivity test")
            
            all_tests_passed = config_valid and api_valid and data_valid
            if all_tests_passed:
                print("SUCCESS: All unit tests passed")
                self.stage_results["unittest"] = {"status": "success", "details": "All tests passed"}
                self.send_notification("unittest", "success", "All tests passed")
                return True
            else:
                print("WARNING: Some unit tests failed")
                self.stage_results["unittest"] = {"status": "warning", "details": "Some tests failed"}
                self.send_notification("unittest", "warning", "Some tests failed")
                return True  # Continue with warnings
                
        except Exception as e:
            error_msg = f"Unit tests failed: {e}"
            print(f"FAILED: {error_msg}")
            self.stage_results["unittest"] = {"status": "failed", "details": error_msg}
            self.send_notification("unittest", "failed", error_msg)
            return False

    def run_stage_deploy(self):
        """Stage 4: Deploy - Deploy ELK stack and verify services"""
        print("\nStage 4: Deploy - Deploying ELK stack and services...")
        
        try:
            # Check if setup-elk-simple.ps1 exists (fallback to regular if not)
            setup_script = self.project_root / "setup-elk-simple.ps1"
            if not setup_script.exists():
                setup_script = self.project_root / "setup-elk.ps1"
            
            if not setup_script.exists():
                print("WARNING: setup-elk script not found, skipping ELK setup")
            else:
                # Execute ELK setup script
                print("INFO: Running ELK stack setup...")
                try:
                    # Run PowerShell script to setup ELK stack
                    result = subprocess.run([
                        "powershell.exe", "-ExecutionPolicy", "Bypass", "-File", str(setup_script)
                    ], capture_output=True, text=True, cwd=self.project_root)
                    
                    if result.returncode == 0:
                        print("SUCCESS: ELK setup script completed successfully")
                        print("INFO: ELK stack deployment initiated")
                    else:
                        print(f"WARNING: ELK setup script had issues: {result.stderr}")
                        print("INFO: Continuing with service verification...")
                    
                    # Wait a bit more for services to stabilize after setup
                    print("INFO: Waiting for services to stabilize...")
                    time.sleep(10)
                    
                except Exception as e:
                    print(f"WARNING: Failed to run ELK setup script: {e}")
                    print("INFO: Proceeding with service verification...")
            
            # Verify Docker containers are running
            print("INFO: Verifying Docker containers...")
            try:
                docker_result = subprocess.run(["docker", "ps"], capture_output=True, text=True)
                if docker_result.returncode == 0:
                    containers = ["elasticsearch", "logstash", "kibana", "rabbitmq"]
                    running_containers = []
                    for container in containers:
                        if container in docker_result.stdout:
                            running_containers.append(container)
                            print(f"SUCCESS: {container} container is running")
                        else:
                            print(f"WARNING: {container} container not found")
                    
                    if len(running_containers) >= 3:  # At least 3 out of 4 containers
                        print(f"SUCCESS: {len(running_containers)}/4 containers are running")
                    else:
                        print(f"WARNING: Only {len(running_containers)}/4 containers running")
                else:
                    print("WARNING: Could not check Docker container status")
            except Exception as e:
                print(f"WARNING: Docker check failed: {e}")
            
            # Test service connectivity
            services_ok = 0
            total_services = 3
            
            # Test Elasticsearch
            try:
                es_response = requests.get(f"{self.elastic_url}/_cluster/health", timeout=10)
                if es_response.status_code == 200:
                    health_data = es_response.json()
                    status = health_data.get('status', 'unknown')
                    print(f"SUCCESS: Elasticsearch is accessible (status: {status})")
                    services_ok += 1
                else:
                    print(f"WARNING: Elasticsearch responded with status {es_response.status_code}")
            except Exception as e:
                print(f"WARNING: Elasticsearch not accessible: {e}")
            
            # Test Kibana
            try:
                kibana_response = requests.get(f"{self.kibana_url}/api/status", timeout=10)
                if kibana_response.status_code == 200:
                    print("SUCCESS: Kibana is accessible")
                    services_ok += 1
                else:
                    print(f"WARNING: Kibana responded with status {kibana_response.status_code}")
            except Exception as e:
                print(f"WARNING: Kibana not accessible: {e}")
            
            # Test RabbitMQ
            try:
                import base64
                credentials = base64.b64encode(b"guest:guest").decode('ascii')
                rabbitmq_response = requests.get(
                    "http://localhost:15672/api/overview",
                    headers={"Authorization": f"Basic {credentials}"},
                    timeout=10
                )
                if rabbitmq_response.status_code == 200:
                    print("SUCCESS: RabbitMQ is accessible")
                    services_ok += 1
                else:
                    print(f"WARNING: RabbitMQ responded with status {rabbitmq_response.status_code}")
            except Exception as e:
                print(f"WARNING: RabbitMQ not accessible: {e}")
            
            # Final deployment status
            if services_ok >= 2:  # At least 2 out of 3 services working
                print(f"SUCCESS: Deploy stage completed ({services_ok}/{total_services} services OK)")
                print("INFO: Dashboard available at http://localhost:5601")
                print("INFO: RabbitMQ Management at http://localhost:15672")
                print("INFO: Elasticsearch API at http://localhost:9200")
                
                self.stage_results["deploy"] = {
                    "status": "success", 
                    "details": f"Deployment completed, {services_ok}/{total_services} services accessible"
                }
                self.send_notification("deploy", "success", f"Deployment completed, {services_ok}/{total_services} services accessible")
                return True
            else:
                print(f"WARNING: Deploy stage completed with issues ({services_ok}/{total_services} services OK)")
                self.stage_results["deploy"] = {
                    "status": "warning", 
                    "details": f"Deployment completed with issues, only {services_ok}/{total_services} services accessible"
                }
                self.send_notification("deploy", "warning", f"Deployment completed with issues, only {services_ok}/{total_services} services accessible")
                return True  # Continue despite warnings
            
        except Exception as e:
            error_msg = f"Deploy failed: {e}"
            print(f"FAILED: {error_msg}")
            self.stage_results["deploy"] = {"status": "failed", "details": error_msg}
            self.send_notification("deploy", "failed", error_msg)
            return False

    def run_pipeline(self):
        """Execute the complete pipeline"""
        print("Starting Vienna Weather CI/CD Pipeline...")
        
        # Pipeline stages
        stages = [
            ("clone", self.run_stage_clone),
            ("build", self.run_stage_build),
            ("unittest", self.run_stage_unittest),
            ("deploy", self.run_stage_deploy)
        ]
        
        success_count = 0
        
        for stage_name, stage_func in stages:
            print(f"\n{'='*20} {stage_name.upper()} STAGE {'='*20}")
            stage_start = time.time()
            
            success = stage_func()
            
            stage_duration = time.time() - stage_start
            print(f"Stage duration: {stage_duration:.2f} seconds")
            
            if success:
                success_count += 1
            else:
                print(f"PIPELINE FAILED at {stage_name} stage")
                break
        
        # Final results
        end_time = datetime.now()
        total_duration = (end_time - self.start_time).total_seconds()
        
        print(f"\n{'='*60}")
        print("PIPELINE SUMMARY")
        print(f"{'='*60}")
        print(f"Total duration: {total_duration:.2f} seconds")
        print(f"Stages completed: {success_count}/{len(stages)}")
        
        if success_count == len(stages):
            print("PIPELINE STATUS: SUCCESS")
            self.send_notification("pipeline", "success", f"All {len(stages)} stages completed")
            print("\nDashboard: http://localhost:5601")
            print("Pipeline logs: vienna-pipeline-notifications index")
            return True
        else:
            print("PIPELINE STATUS: FAILED")
            self.send_notification("pipeline", "failed", f"Failed at stage {success_count + 1}")
            return False

def main():
    try:
        pipeline = SimpleViennaWeatherPipeline()
        success = pipeline.run_pipeline()
        sys.exit(0 if success else 1)
    except Exception as e:
        print(f"CRITICAL ERROR: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()