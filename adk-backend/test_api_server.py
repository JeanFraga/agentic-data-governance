#!/usr/bin/env python3
"""
Test script for ADK API Server
This script tests the ADK API server functionality using poetry run adk api_server
"""

import os
import sys
import time
import subprocess
import threading
import requests
import json
from pathlib import Path
import signal

class ADKAPIServerTest:
    def __init__(self):
        self.host = "localhost"
        self.port = 8001  # Use different port to avoid conflicts
        self.base_url = f"http://{self.host}:{self.port}"
        self.server_process = None
        self.test_results = []
        
    def start_server(self):
        """Start the ADK API server in background"""
        print(f"🚀 Starting ADK API server on {self.host}:{self.port}")
        
        # Change to adk-backend directory
        backend_dir = Path(__file__).parent
        os.chdir(backend_dir)
        
        # Start server using poetry
        cmd = ["poetry", "run", "adk", "api_server", "--host", self.host, "--port", str(self.port)]
        print(f"Running command: {' '.join(cmd)}")
        
        try:
            self.server_process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                preexec_fn=os.setsid if hasattr(os, 'setsid') else None
            )
            
            # Wait a moment for server to start
            print("⏳ Waiting for server to start...")
            time.sleep(5)
            
            # Check if process is still running
            if self.server_process.poll() is not None:
                stdout, stderr = self.server_process.communicate()
                print(f"❌ Server failed to start:")
                print(f"STDOUT: {stdout}")
                print(f"STDERR: {stderr}")
                return False
                
            print("✅ Server started successfully")
            return True
            
        except Exception as e:
            print(f"❌ Failed to start server: {e}")
            return False
    
    def stop_server(self):
        """Stop the ADK API server"""
        if self.server_process:
            print("🛑 Stopping ADK API server...")
            try:
                # Try graceful shutdown first
                if hasattr(os, 'killpg'):
                    os.killpg(os.getpgid(self.server_process.pid), signal.SIGTERM)
                else:
                    self.server_process.terminate()
                
                # Wait for graceful shutdown
                try:
                    self.server_process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    # Force kill if graceful shutdown fails
                    if hasattr(os, 'killpg'):
                        os.killpg(os.getpgid(self.server_process.pid), signal.SIGKILL)
                    else:
                        self.server_process.kill()
                    self.server_process.wait()
                    
                print("✅ Server stopped")
            except Exception as e:
                print(f"⚠️ Error stopping server: {e}")
    
    def wait_for_server(self, timeout=30):
        """Wait for server to be ready"""
        print(f"⏳ Waiting for server to be ready (timeout: {timeout}s)...")
        start_time = time.time()
        
        # Try multiple endpoints to check if server is ready
        test_endpoints = ["/docs", "/openapi.json", "/list-apps"]
        
        while time.time() - start_time < timeout:
            for endpoint in test_endpoints:
                try:
                    response = requests.get(f"{self.base_url}{endpoint}", timeout=2)
                    if response.status_code in [200, 404]:  # 404 is also ok, means server is responding
                        print(f"✅ Server is ready! (tested {endpoint})")
                        return True
                except requests.exceptions.RequestException:
                    pass
            time.sleep(1)
        
        print("❌ Server failed to become ready within timeout")
        return False
    
    def test_health_endpoint(self):
        """Test the health check endpoint"""
        print("\n🔍 Testing health endpoint...")
        try:
            response = requests.get(f"{self.base_url}/health", timeout=10)
            
            result = {
                "test": "Health Endpoint",
                "status_code": response.status_code,
                "response_time": response.elapsed.total_seconds(),
                "success": response.status_code == 200
            }
            
            if result["success"]:
                print(f"✅ Health check passed (HTTP {response.status_code})")
                print(f"   Response time: {result['response_time']:.3f}s")
                try:
                    data = response.json()
                    print(f"   Response: {json.dumps(data, indent=2)}")
                    result["response_data"] = data
                except:
                    result["response_data"] = response.text
            else:
                print(f"❌ Health check failed (HTTP {response.status_code})")
                
            self.test_results.append(result)
            return result["success"]
            
        except Exception as e:
            print(f"❌ Health check error: {e}")
            self.test_results.append({
                "test": "Health Endpoint",
                "success": False,
                "error": str(e)
            })
            return False
    
    def test_openapi_docs(self):
        """Test OpenAPI documentation endpoint"""
        print("\n🔍 Testing OpenAPI docs...")
        try:
            response = requests.get(f"{self.base_url}/docs", timeout=10)
            
            result = {
                "test": "OpenAPI Docs",
                "status_code": response.status_code,
                "response_time": response.elapsed.total_seconds(),
                "success": response.status_code == 200
            }
            
            if result["success"]:
                print(f"✅ OpenAPI docs accessible (HTTP {response.status_code})")
                print(f"   Response time: {result['response_time']:.3f}s")
                print(f"   Content type: {response.headers.get('content-type', 'unknown')}")
            else:
                print(f"❌ OpenAPI docs failed (HTTP {response.status_code})")
                
            self.test_results.append(result)
            return result["success"]
            
        except Exception as e:
            print(f"❌ OpenAPI docs error: {e}")
            self.test_results.append({
                "test": "OpenAPI Docs",
                "success": False,
                "error": str(e)
            })
            return False
    
    def test_agent_endpoint(self):
        """Test the agent/chat endpoint with a simple query"""
        print("\n🔍 Testing agent endpoint...")
        try:
            # Simple test query
            payload = {
                "message": "Hello, can you help me with data analysis?",
                "session_id": "test-session-123"
            }
            
            response = requests.post(
                f"{self.base_url}/agent/chat",
                json=payload,
                headers={"Content-Type": "application/json"},
                timeout=30
            )
            
            result = {
                "test": "Agent Chat",
                "status_code": response.status_code,
                "response_time": response.elapsed.total_seconds(),
                "success": response.status_code in [200, 201]
            }
            
            if result["success"]:
                print(f"✅ Agent endpoint responded (HTTP {response.status_code})")
                print(f"   Response time: {result['response_time']:.3f}s")
                try:
                    data = response.json()
                    print(f"   Response keys: {list(data.keys()) if isinstance(data, dict) else 'non-dict response'}")
                    result["response_data"] = data
                except:
                    result["response_data"] = response.text[:200] + "..." if len(response.text) > 200 else response.text
            else:
                print(f"❌ Agent endpoint failed (HTTP {response.status_code})")
                print(f"   Response: {response.text[:200]}")
                
            self.test_results.append(result)
            return result["success"]
            
        except Exception as e:
            print(f"❌ Agent endpoint error: {e}")
            self.test_results.append({
                "test": "Agent Chat",
                "success": False,
                "error": str(e)
            })
            return False
    
    def test_run_endpoint(self):
        """Test the /run endpoint with proper payload structure"""
        print("\n🔍 Testing /run endpoint...")
        try:
            # Based on the endpoint discovery, it seems we may need to create a session first
            app_name = "data_science_agent"
            user_id = "test-user-123"
            session_id = "test-session-456"
            
            # Try to create a session first
            print("   Creating session first...")
            session_response = requests.post(
                f"{self.base_url}/apps/{app_name}/users/{user_id}/sessions",
                json={"session_id": session_id},
                headers={"Content-Type": "application/json"},
                timeout=10
            )
            
            if session_response.status_code in [200, 201]:
                print(f"   ✅ Session created (HTTP {session_response.status_code})")
            else:
                print(f"   ⚠️ Session creation failed (HTTP {session_response.status_code})")
                print(f"     Response: {session_response.text[:100]}")
            
            # Now try different payload structures for /run endpoint
            test_payloads = [
                # Try with just role field
                {
                    "appName": app_name,
                    "userId": user_id,
                    "sessionId": session_id,
                    "newMessage": {
                        "role": "user"
                    }
                },
                # Try with empty object  
                {
                    "appName": app_name,
                    "userId": user_id,
                    "sessionId": session_id,
                    "newMessage": {}
                },
                # Try using the session-based endpoint instead
                None  # Special case for session endpoint
            ]
            
            for i, payload in enumerate(test_payloads):
                if payload is None:
                    # Try the session-based endpoint
                    print(f"   Trying session-based endpoint...")
                    
                    session_payload = {
                        "role": "user",
                        "content": "Hello! Can you help me analyze some data?"
                    }
                    
                    response = requests.post(
                        f"{self.base_url}/apps/{app_name}/users/{user_id}/sessions/{session_id}",
                        json=session_payload,
                        headers={"Content-Type": "application/json"},
                        timeout=60
                    )
                    
                    if response.status_code in [200, 201]:
                        print(f"   ✅ Session endpoint succeeded!")
                        
                        result = {
                            "test": "Run Endpoint",
                            "status_code": response.status_code,
                            "response_time": response.elapsed.total_seconds(),
                            "success": True,
                            "endpoint_type": "session-based"
                        }
                        
                        print(f"✅ Session endpoint responded (HTTP {response.status_code})")
                        print(f"   Response time: {result['response_time']:.3f}s")
                        try:
                            data = response.json()
                            print(f"   Response keys: {list(data.keys()) if isinstance(data, dict) else 'non-dict response'}")
                            result["response_data"] = data
                        except:
                            result["response_data"] = response.text[:200] + "..." if len(response.text) > 200 else response.text
                            print(f"   Response (text): {result['response_data']}")
                        
                        self.test_results.append(result)
                        return True
                    else:
                        print(f"   ❌ Session endpoint failed (HTTP {response.status_code})")
                        if response.status_code == 422:
                            try:
                                error_data = response.json()
                                print(f"     Validation error: {error_data}")
                            except:
                                print(f"     Error response: {response.text[:200]}")
                else:
                    print(f"   Trying /run payload variant {i+1}...")
                    
                    response = requests.post(
                        f"{self.base_url}/run",
                        json=payload,
                        headers={"Content-Type": "application/json"},
                        timeout=60
                    )
                    
                    if response.status_code in [200, 201]:
                        print(f"   ✅ Payload variant {i+1} succeeded!")
                        
                        result = {
                            "test": "Run Endpoint",
                            "status_code": response.status_code,
                            "response_time": response.elapsed.total_seconds(),
                            "success": True,
                            "payload_variant": i+1
                        }
                        
                        print(f"✅ /run endpoint responded (HTTP {response.status_code})")
                        print(f"   Response time: {result['response_time']:.3f}s")
                        try:
                            data = response.json()
                            print(f"   Response keys: {list(data.keys()) if isinstance(data, dict) else 'non-dict response'}")
                            result["response_data"] = data
                        except:
                            result["response_data"] = response.text[:200] + "..." if len(response.text) > 200 else response.text
                            print(f"   Response (text): {result['response_data']}")
                        
                        self.test_results.append(result)
                        return True
                    else:
                        print(f"   ❌ Payload variant {i+1} failed (HTTP {response.status_code})")
                        if response.status_code == 422:
                            try:
                                error_data = response.json()
                                print(f"     Validation error: {error_data}")
                            except:
                                print(f"     Error response: {response.text[:200]}")
            
            # If we get here, all variants failed
            result = {
                "test": "Run Endpoint",
                "status_code": response.status_code,
                "response_time": response.elapsed.total_seconds(),
                "success": False,
                "error": f"All payload variants failed. Last error: HTTP {response.status_code}"
            }
            
            print("❌ /run endpoint failed - all payload variants unsuccessful")
            print(f"   Last response: {response.text[:200]}")
                
            self.test_results.append(result)
            return False
            
        except Exception as e:
            print(f"❌ /run endpoint error: {e}")
            self.test_results.append({
                "test": "Run Endpoint",
                "success": False,
                "error": str(e)
            })
            return False
    
    def test_list_apps_endpoint(self):
        """Test the /list-apps endpoint"""
        print("\n🔍 Testing /list-apps endpoint...")
        try:
            response = requests.get(f"{self.base_url}/list-apps", timeout=10)
            
            result = {
                "test": "List Apps Endpoint",
                "status_code": response.status_code,
                "response_time": response.elapsed.total_seconds(),
                "success": response.status_code == 200
            }
            
            if result["success"]:
                print(f"✅ /list-apps endpoint responded (HTTP {response.status_code})")
                print(f"   Response time: {result['response_time']:.3f}s")
                try:
                    data = response.json()
                    if isinstance(data, list):
                        print(f"   Available apps: {len(data)} found")
                        for app in data:
                            print(f"     - {app}")
                    else:
                        print(f"   Response: {data}")
                    result["response_data"] = data
                except:
                    result["response_data"] = response.text
                    print(f"   Response (text): {result['response_data']}")
            else:
                print(f"❌ /list-apps endpoint failed (HTTP {response.status_code})")
                print(f"   Response: {response.text[:200]}")
                
            self.test_results.append(result)
            return result["success"]
            
        except Exception as e:
            print(f"❌ /list-apps endpoint error: {e}")
            self.test_results.append({
                "test": "List Apps Endpoint",
                "success": False,
                "error": str(e)
            })
            return False

    def test_available_endpoints(self):
        """Discover and test available endpoints"""
        print("\n🔍 Discovering available endpoints...")
        try:
            # Try to get OpenAPI spec
            response = requests.get(f"{self.base_url}/openapi.json", timeout=10)
            
            if response.status_code == 200:
                openapi_spec = response.json()
                paths = openapi_spec.get("paths", {})
                print(f"✅ Found {len(paths)} endpoints in OpenAPI spec:")
                for path in sorted(paths.keys()):
                    methods = list(paths[path].keys())
                    print(f"   {path}: {', '.join(methods).upper()}")
                
                result = {
                    "test": "Endpoint Discovery",
                    "success": True,
                    "endpoints": list(paths.keys()),
                    "total_endpoints": len(paths)
                }
            else:
                print("⚠️ Could not retrieve OpenAPI spec, trying manual discovery...")
                result = {
                    "test": "Endpoint Discovery", 
                    "success": False,
                    "error": f"OpenAPI spec unavailable (HTTP {response.status_code})"
                }
            
            self.test_results.append(result)
            return result["success"]
            
        except Exception as e:
            print(f"❌ Endpoint discovery error: {e}")
            self.test_results.append({
                "test": "Endpoint Discovery",
                "success": False,
                "error": str(e)
            })
            return False
    
    def run_all_tests(self):
        """Run all tests"""
        print("🧪 Starting ADK API Server Tests")
        print("=" * 50)
        
        try:
            # Start server
            if not self.start_server():
                print("❌ Failed to start server, aborting tests")
                return False
            
            # Wait for server to be ready
            if not self.wait_for_server():
                print("❌ Server not ready, aborting tests")
                return False
            
            # Run tests
            tests_passed = 0
            total_tests = 0
            
            # Test OpenAPI docs
            total_tests += 1
            if self.test_openapi_docs():
                tests_passed += 1
            
            # Test endpoint discovery
            total_tests += 1
            if self.test_available_endpoints():
                tests_passed += 1
            
            # Test list-apps endpoint
            total_tests += 1
            if self.test_list_apps_endpoint():
                tests_passed += 1
            
            # Test run endpoint
            total_tests += 1
            if self.test_run_endpoint():
                tests_passed += 1
            
            # Print results
            print("\n" + "=" * 50)
            print("🧪 Test Results Summary")
            print("=" * 50)
            print(f"Tests passed: {tests_passed}/{total_tests}")
            
            for result in self.test_results:
                status = "✅ PASS" if result["success"] else "❌ FAIL"
                print(f"{status} {result['test']}")
                if not result["success"] and "error" in result:
                    print(f"     Error: {result['error']}")
            
            success_rate = tests_passed / total_tests if total_tests > 0 else 0
            if success_rate >= 0.75:
                print(f"\n🎉 Overall result: SUCCESS ({success_rate:.1%} pass rate)")
            else:
                print(f"\n❌ Overall result: FAILURE ({success_rate:.1%} pass rate)")
            
            return success_rate >= 0.75
            
        finally:
            # Always stop server
            self.stop_server()

def main():
    """Main test function"""
    print("ADK API Server Test Suite")
    print("=" * 30)
    
    # Check if we're in the right directory
    if not Path("pyproject.toml").exists():
        print("❌ Error: pyproject.toml not found. Please run this from the adk-backend directory.")
        return False
    
    # Check if poetry is available
    try:
        subprocess.run(["poetry", "--version"], check=True, capture_output=True)
        print("✅ Poetry is available")
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("❌ Error: Poetry not found. Please install poetry first.")
        return False
    
    # Run tests
    tester = ADKAPIServerTest()
    return tester.run_all_tests()

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
