#!/usr/bin/env python3
"""
Comprehensive Ollama + ADK Integration Test Runner
This script starts the Ollama proxy, configures and starts the ADK API server, 
and runs integration tests to verify communication between Ollama and the data science agent.
"""

import os
import sys
import time
import subprocess
import threading
import signal
import asyncio
from pathlib import Path

class OllamaADKIntegrationRunner:
    """Manages the full integration test lifecycle"""
    
    def __init__(self):
        self.backend_dir = Path(__file__).parent
        self.ollama_process = None
        self.adk_process = None
        self.processes = []
        
    def setup_environment(self):
        """Set up environment variables for ADK Ollama integration"""
        print("🔧 Setting up environment for Ollama integration...")
        
        # Load .env file if it exists
        env_file = self.backend_dir / ".env"
        if env_file.exists():
            print(f"📁 Loading environment from {env_file}")
            from dotenv import load_dotenv
            load_dotenv(env_file)
        else:
            print("⚠️ No .env file found. Please create one with your Google API key.")
            print("   See OLLAMA_ADK_SETUP_GUIDE.md for instructions.")
        
        # Configure ADK to use Ollama proxy
        os.environ["LITELLM_PROXY_API_BASE"] = "http://localhost:11434"
        os.environ["ROOT_AGENT_MODEL"] = "gemini-2.0-flash"
        os.environ["LITELLM_API_BASE"] = "http://localhost:11434"
        
        # Configure Ollama proxy for Vertex AI (to match ADK app configuration)
        os.environ["LITELLM_PROVIDER"] = "vertex_ai"
        os.environ["VERTEX_PROJECT_ID"] = os.environ.get("GOOGLE_CLOUD_PROJECT", "agenticds-hackathon-54443")
        os.environ["VERTEX_LOCATION"] = os.environ.get("GOOGLE_CLOUD_LOCATION", "us-central1")
        os.environ["PROXY_HOST"] = "0.0.0.0"
        os.environ["PROXY_PORT"] = "11434"
        
        # Update ROOT_AGENT_MODEL to match Vertex AI model naming
        os.environ["ROOT_AGENT_MODEL"] = "gemini-2.0-flash-001"
        
        # Check for authentication (ADC for Vertex AI)
        try:
            import subprocess
            result = subprocess.run(["gcloud", "auth", "application-default", "print-access-token"], 
                                  capture_output=True, text=True, timeout=10)
            if result.returncode != 0:
                print("❌ Google Cloud Application Default Credentials not configured!")
                print("   Please run: gcloud auth application-default login")
                return False
            print("✅ Google Cloud authentication verified")
        except Exception as e:
            print(f"⚠️ Could not verify Google Cloud authentication: {e}")
            print("   Please ensure: gcloud auth application-default login")
        
        print("✅ Environment configured:")
        print(f"   LITELLM_PROXY_API_BASE: {os.environ.get('LITELLM_PROXY_API_BASE')}")
        print(f"   ROOT_AGENT_MODEL: {os.environ.get('ROOT_AGENT_MODEL')}")
        print(f"   LITELLM_API_BASE: {os.environ.get('LITELLM_API_BASE')}")
        print(f"   LITELLM_PROVIDER: {os.environ.get('LITELLM_PROVIDER')}")
        print(f"   VERTEX_PROJECT_ID: {os.environ.get('VERTEX_PROJECT_ID')}")
        
        return True
        
    def start_ollama_proxy(self):
        """Start the Ollama proxy server"""
        print("🚀 Starting Ollama proxy server...")
        
        try:
            self.ollama_process = subprocess.Popen(
                ["poetry", "run", "python", "ollama_proxy.py"],
                cwd=self.backend_dir,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                preexec_fn=os.setsid if hasattr(os, 'setsid') else None
            )
            self.processes.append(("Ollama Proxy", self.ollama_process))
            
            print("⏳ Waiting for Ollama proxy to start...")
            time.sleep(3)
            
            if self.ollama_process.poll() is not None:
                stdout, stderr = self.ollama_process.communicate()
                print(f"❌ Ollama proxy failed to start:")
                print(f"STDOUT: {stdout}")
                print(f"STDERR: {stderr}")
                return False
                
            print("✅ Ollama proxy started successfully")
            return True
            
        except Exception as e:
            print(f"❌ Failed to start Ollama proxy: {e}")
            return False
    
    def start_adk_server(self):
        """Start the ADK API server"""
        print("🤖 Starting ADK API server...")
        
        try:
            # Set environment for the ADK process
            env = os.environ.copy()
            env.update({
                "LITELLM_PROXY_API_BASE": "http://localhost:11434",
                "ROOT_AGENT_MODEL": "gemini-2.0-flash",
                "LITELLM_API_BASE": "http://localhost:11434"
            })
            
            self.adk_process = subprocess.Popen(
                ["poetry", "run", "adk", "api_server", "--host", "localhost", "--port", "8001"],
                cwd=self.backend_dir,
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                preexec_fn=os.setsid if hasattr(os, 'setsid') else None
            )
            self.processes.append(("ADK API Server", self.adk_process))
            
            print("⏳ Waiting for ADK API server to start...")
            time.sleep(8)  # ADK takes longer to start
            
            if self.adk_process.poll() is not None:
                stdout, stderr = self.adk_process.communicate()
                print(f"❌ ADK API server failed to start:")
                print(f"STDOUT: {stdout}")
                print(f"STDERR: {stderr}")
                return False
                
            print("✅ ADK API server started successfully")
            return True
            
        except Exception as e:
            print(f"❌ Failed to start ADK API server: {e}")
            return False
    
    def wait_for_services(self):
        """Wait for both services to be ready"""
        print("⏳ Waiting for services to be ready...")
        
        import requests
        
        # Check Ollama proxy
        for i in range(30):  # 30 second timeout
            try:
                response = requests.get("http://localhost:11434/health", timeout=2)
                if response.status_code == 200:
                    print("✅ Ollama proxy is ready")
                    break
            except Exception:
                time.sleep(1)
        else:
            print("❌ Ollama proxy not ready after 30 seconds")
            return False
        
        # Check ADK API server
        for i in range(60):  # 60 second timeout (ADK is slower)
            try:
                response = requests.get("http://localhost:8001/list-apps", timeout=2)
                if response.status_code == 200:
                    print("✅ ADK API server is ready")
                    return True
            except Exception:
                time.sleep(1)
        
        print("❌ ADK API server not ready after 60 seconds")
        return False
    
    def run_integration_test(self):
        """Run the integration test"""
        print("🧪 Running integration test...")
        
        try:
            result = subprocess.run(
                ["poetry", "run", "python", "test_ollama_adk_integration.py"],
                cwd=self.backend_dir,
                capture_output=True,
                text=True,
                timeout=300  # 5 minute timeout
            )
            
            print("📋 Integration Test Output:")
            print("=" * 50)
            print(result.stdout)
            
            if result.stderr:
                print("⚠️ Errors/Warnings:")
                print(result.stderr)
            
            if result.returncode == 0:
                print("🎉 Integration test PASSED!")
                return True
            else:
                print("❌ Integration test FAILED!")
                return False
                
        except subprocess.TimeoutExpired:
            print("❌ Integration test timed out after 5 minutes")
            return False
        except Exception as e:
            print(f"❌ Failed to run integration test: {e}")
            return False
    
    def stop_all_services(self):
        """Stop all running services"""
        print("🛑 Stopping all services...")
        
        for name, process in self.processes:
            if process and process.poll() is None:
                try:
                    print(f"   Stopping {name}...")
                    if hasattr(os, 'killpg'):
                        os.killpg(os.getpgid(process.pid), signal.SIGTERM)
                    else:
                        process.terminate()
                    
                    # Wait for graceful shutdown
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        # Force kill if needed
                        if hasattr(os, 'killpg'):
                            os.killpg(os.getpgid(process.pid), signal.SIGKILL)
                        else:
                            process.kill()
                        process.wait()
                        
                except Exception as e:
                    print(f"   ⚠️ Error stopping {name}: {e}")
        
        print("✅ All services stopped")
    
    def run_full_integration_test(self):
        """Run the complete integration test workflow"""
        print("🚀 Ollama + ADK Data Science Agent Integration Test")
        print("=" * 60)
        
        try:
            # Setup
            if not self.setup_environment():
                return False
            
            # Start services
            if not self.start_ollama_proxy():
                return False
                
            if not self.start_adk_server():
                return False
            
            # Wait for readiness
            if not self.wait_for_services():
                return False
            
            # Run tests
            success = self.run_integration_test()
            
            return success
            
        except KeyboardInterrupt:
            print("\n⚠️ Test interrupted by user")
            return False
        except Exception as e:
            print(f"❌ Unexpected error: {e}")
            return False
        finally:
            self.stop_all_services()


def main():
    """Main entry point"""
    runner = OllamaADKIntegrationRunner()
    
    print("Prerequisites Check:")
    print("- Make sure you have a valid Google API key configured")
    print("- Ensure poetry environment is set up (poetry install)")
    print("- Both Ollama proxy and ADK server will be started automatically")
    print()
    
    try:
        success = runner.run_full_integration_test()
        
        if success:
            print("\n🎉 FULL INTEGRATION TEST SUCCESSFUL!")
            print("✅ Ollama models are correctly communicating with the ADK data science agent")
            sys.exit(0)
        else:
            print("\n❌ INTEGRATION TEST FAILED!")
            print("Please check the output above for error details")
            sys.exit(1)
            
    except KeyboardInterrupt:
        print("\n⚠️ Test interrupted by user")
        runner.stop_all_services()
        sys.exit(1)


if __name__ == "__main__":
    # Change to the correct directory
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    main()
