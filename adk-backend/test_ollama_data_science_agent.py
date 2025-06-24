#!/usr/bin/env python3
"""
Test Ollama Model Communication with Data Science Agent
Tests the integration between Ollama local models and the Google ADK data science agent.
"""

import os
import sys
import asyncio
import time
import json
from typing import Dict, Any, Optional

# Add the current directory to the Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    import aiohttp
    from google.adk.agents import LlmAgent
    from google.adk.models.lite_llm import LiteLlm
    from google.adk.sessions import InMemorySessionService
    from google.adk.runners import Runner
    from google.genai import types
    
    # Import our callback handlers
    from adk_callback_handlers import OllamaCallbackHandler, create_callback_handler
    
    print("✅ All imports successful")
except ImportError as e:
    print(f"❌ Import error: {e}")
    print("Please ensure all dependencies are installed with 'poetry install'")
    sys.exit(1)


class OllamaDataScienceAgentTester:
    """Comprehensive tester for Ollama + Data Science Agent integration"""
    
    def __init__(self, ollama_host: str = "http://localhost:11434"):
        self.ollama_host = ollama_host
        self.test_results = []
        self.session_service = InMemorySessionService()
        
    async def run_all_tests(self) -> Dict[str, Any]:
        """Run comprehensive test suite"""
        print("🧪 Starting Ollama Data Science Agent Tests")
        print("=" * 60)
        
        # Test 1: Ollama Service Health
        print("\n1️⃣ Testing Ollama Service Health...")
        health_result = await self.test_ollama_health()
        self.test_results.append({"test": "ollama_health", "result": health_result})
        
        if not health_result["success"]:
            print("❌ Ollama service not available. Please ensure Ollama is running.")
            return self._compile_results()
        
        # Test 2: Available Models
        print("\n2️⃣ Testing Available Models...")
        models_result = await self.test_available_models()
        self.test_results.append({"test": "available_models", "result": models_result})
        
        # Test 3: Basic Agent Creation
        print("\n3️⃣ Testing Agent Creation...")
        agent_result = await self.test_agent_creation()
        self.test_results.append({"test": "agent_creation", "result": agent_result})
        
        # Test 4: Simple Query
        print("\n4️⃣ Testing Simple Query...")
        simple_query_result = await self.test_simple_query()
        self.test_results.append({"test": "simple_query", "result": simple_query_result})
        
        # Test 5: Data Science Query
        print("\n5️⃣ Testing Data Science Query...")
        data_science_result = await self.test_data_science_query()
        self.test_results.append({"test": "data_science_query", "result": data_science_result})
        
        # Test 6: Callback Handler
        print("\n6️⃣ Testing Callback Handler...")
        callback_result = await self.test_callback_handler()
        self.test_results.append({"test": "callback_handler", "result": callback_result})
        
        # Test 7: Performance Test
        print("\n7️⃣ Testing Performance...")
        performance_result = await self.test_performance()
        self.test_results.append({"test": "performance", "result": performance_result})
        
        return self._compile_results()
    
    async def test_ollama_health(self) -> Dict[str, Any]:
        """Test if Ollama service is responding"""
        try:
            timeout = aiohttp.ClientTimeout(total=10)
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.get(f"{self.ollama_host}/health") as resp:
                    if resp.status == 200:
                        health_data = await resp.json()
                        print(f"✅ Ollama proxy healthy (provider: {health_data.get('provider', 'unknown')})")
                        return {
                            "success": True,
                            "provider": health_data.get('provider'),
                            "default_model": health_data.get('default_model'),
                            "host": self.ollama_host
                        }
                    else:
                        print(f"❌ Ollama proxy returned status {resp.status}")
                        return {"success": False, "error": f"HTTP {resp.status}"}
        except Exception as e:
            print(f"❌ Ollama health check failed: {e}")
            return {"success": False, "error": str(e)}
    
    async def test_available_models(self) -> Dict[str, Any]:
        """Test available Ollama models"""
        try:
            timeout = aiohttp.ClientTimeout(total=10)
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.get(f"{self.ollama_host}/api/tags") as resp:
                    if resp.status == 200:
                        models_data = await resp.json()
                        models = models_data.get("models", [])
                        model_names = [model.get("name", "unknown") for model in models]
                        
                        print(f"✅ Found {len(models)} models: {', '.join(model_names[:3])}{'...' if len(models) > 3 else ''}")
                        
                        # Check for common data science models
                        data_science_models = [name for name in model_names if any(
                            ds_model in name.lower() 
                            for ds_model in ["llama", "mistral", "codellama", "deepseek", "qwen"]
                        )]
                        
                        return {
                            "success": True,
                            "total_models": len(models),
                            "model_names": model_names,
                            "data_science_models": data_science_models,
                            "recommended_model": data_science_models[0] if data_science_models else model_names[0] if model_names else None
                        }
                    else:
                        print(f"❌ Failed to get models: HTTP {resp.status}")
                        return {"success": False, "error": f"HTTP {resp.status}"}
        except Exception as e:
            print(f"❌ Model listing failed: {e}")
            return {"success": False, "error": str(e)}
    
    async def test_agent_creation(self) -> Dict[str, Any]:
        """Test creating a data science agent with Ollama model"""
        try:
            # Get available models first
            models_result = await self.test_available_models()
            if not models_result["success"] or not models_result.get("model_names"):
                return {"success": False, "error": "No models available"}
            
            # Use the first available model
            model_name = models_result["model_names"][0]
            
            # Create the agent (models are accessed directly by name through proxy)
            agent = LlmAgent(
                name="ollama_data_science_agent",
                model=LiteLlm(
                    model=model_name,  # Use model name directly with our proxy
                    api_base=self.ollama_host
                ),
                instruction="""You are a data science assistant powered by Ollama.
                Help users with data analysis, statistics, machine learning, and programming tasks.
                Provide clear, accurate, and helpful responses.""",
                description="Data science assistant using local Ollama model"
            )
            
            print(f"✅ Agent created successfully with model: {model_name}")
            return {
                "success": True,
                "agent_name": agent.name,
                "model_name": model_name,
                "agent_type": type(agent).__name__
            }
            
        except Exception as e:
            print(f"❌ Agent creation failed: {e}")
            return {"success": False, "error": str(e)}
    
    async def test_simple_query(self) -> Dict[str, Any]:
        """Test a simple query to the data science agent"""
        try:
            # Get available models
            models_result = await self.test_available_models()
            if not models_result["success"]:
                return {"success": False, "error": "No models available"}
            
            model_name = models_result["model_names"][0]
            
            # Create agent
            agent = LlmAgent(
                name="test_agent",
                model=LiteLlm(
                    model=model_name,  # Use model name directly with our proxy
                    api_base=self.ollama_host
                ),
                instruction="You are a helpful assistant. Keep responses concise and clear.",
                description="Test agent for simple queries"
            )
            
            # Create session and runner
            session = await self.session_service.create_session(app_name="ollama_test", user_id="test_user")
            runner = Runner(app_name="ollama_test", agent=agent, session_service=self.session_service)
            
            # Test query
            test_query = "What is 2 + 2? Please give a brief answer."
            
            print(f"📤 Sending query: '{test_query}'")
            start_time = time.time()
            
            # Run the query
            content = types.Content(role="user", parts=[types.Part(text=test_query)])
            events = list(runner.run(
                user_id="test_user",
                session_id=session.id,
                new_message=content
            ))
            
            response_time = time.time() - start_time
            
            if events and events[-1].content:
                last_event = events[-1]
                response_text = "".join([part.text for part in last_event.content.parts if part.text])
                print(f"📥 Response received in {response_time:.2f}s: {response_text[:100]}...")
                
                return {
                    "success": True,
                    "query": test_query,
                    "response": response_text,
                    "response_time": response_time,
                    "model_name": model_name
                }
            else:
                print("❌ No response received")
                return {"success": False, "error": "No response received"}
                
        except Exception as e:
            print(f"❌ Simple query test failed: {e}")
            return {"success": False, "error": str(e)}
    
    async def test_data_science_query(self) -> Dict[str, Any]:
        """Test a data science specific query"""
        try:
            # Get available models
            models_result = await self.test_available_models()
            if not models_result["success"]:
                return {"success": False, "error": "No models available"}
            
            model_name = models_result["model_names"][0]
            
            # Create data science agent
            agent = LlmAgent(
                name="data_science_agent",
                model=LiteLlm(
                    model=model_name,  # Use model name directly with our proxy
                    api_base=self.ollama_host
                ),
                instruction="""You are an expert data scientist and analyst.
                Help with statistical analysis, data preprocessing, machine learning, and data visualization.
                Provide practical, actionable advice with code examples when appropriate.""",
                description="Data science expert agent"
            )
            
            # Create session and runner
            session = await self.session_service.create_session(app_name="ollama_test", user_id="test_user")
            runner = Runner(app_name="ollama_test", agent=agent, session_service=self.session_service)
            
            # Data science query
            data_science_query = """
            I have a dataset with 1000 customer records including age, income, and purchase history.
            What are the key steps I should take to perform customer segmentation analysis?
            Please provide a brief overview of the approach.
            """
            
            print(f"📤 Sending data science query...")
            start_time = time.time()
            
            # Run the query
            content = types.Content(role="user", parts=[types.Part(text=data_science_query)])
            events = list(runner.run(
                user_id="data_scientist",
                session_id=session.id,
                new_message=content
            ))
            
            response_time = time.time() - start_time
            
            if events and events[-1].content:
                last_event = events[-1]
                response_text = "".join([part.text for part in last_event.content.parts if part.text])
                print(f"📥 Data science response received in {response_time:.2f}s")
                print(f"Response length: {len(response_text)} characters")
                
                # Check if response contains data science terms
                ds_keywords = ["segment", "cluster", "analysis", "data", "machine learning", "algorithm"]
                keyword_matches = [kw for kw in ds_keywords if kw.lower() in response_text.lower()]
                
                return {
                    "success": True,
                    "query": data_science_query.strip(),
                    "response": response_text,
                    "response_time": response_time,
                    "response_length": len(response_text),
                    "keyword_matches": keyword_matches,
                    "model_name": model_name
                }
            else:
                print("❌ No response received for data science query")
                return {"success": False, "error": "No response received"}
                
        except Exception as e:
            print(f"❌ Data science query test failed: {e}")
            return {"success": False, "error": str(e)}
    
    async def test_callback_handler(self) -> Dict[str, Any]:
        """Test the Ollama callback handler functionality"""
        try:
            # Create callback handler
            callback_handler = OllamaCallbackHandler(
                ollama_host=self.ollama_host,
                enable_local_optimizations=True
            )
            
            # Get available models
            models_result = await self.test_available_models()
            if not models_result["success"]:
                return {"success": False, "error": "No models available"}
            
            model_name = models_result["model_names"][0]
            
            # Create agent with callback handler
            agent = LlmAgent(
                name="callback_test_agent",
                model=LiteLlm(
                    model=model_name,  # Use model name directly with our proxy
                    api_base=self.ollama_host
                ),
                instruction="You are a test assistant with callback handlers.",
                description="Agent for testing callback functionality",
                before_model_callback=callback_handler.before_model_callback,
                after_model_callback=callback_handler.after_model_callback
            )
            
            # Create session and runner
            session = await self.session_service.create_session(app_name="ollama_test", user_id="test_user")
            runner = Runner(app_name="ollama_test", agent=agent, session_service=self.session_service)
            
            # Test query with callbacks
            test_query = "Hello, please introduce yourself briefly."
            
            print(f"📤 Testing with callbacks...")
            start_time = time.time()
            
            content = types.Content(role="user", parts=[types.Part(text=test_query)])
            events = list(runner.run(
                user_id="callback_test_user",
                session_id=session.id,
                new_message=content
            ))
            
            response_time = time.time() - start_time
            
            if events and events[-1].content:
                last_event = events[-1]
                response_text = "".join([part.text for part in last_event.content.parts if part.text])
                
                # Check if callback attribution was added
                has_attribution = "Local Ollama Model" in response_text
                
                print(f"✅ Callback test completed in {response_time:.2f}s")
                print(f"Attribution added: {has_attribution}")
                
                return {
                    "success": True,
                    "response_time": response_time,
                    "has_attribution": has_attribution,
                    "cache_size": len(callback_handler.model_cache),
                    "model_name": model_name
                }
            else:
                print("❌ No response received in callback test")
                return {"success": False, "error": "No response received"}
                
        except Exception as e:
            print(f"❌ Callback handler test failed: {e}")
            return {"success": False, "error": str(e)}
    
    async def test_performance(self) -> Dict[str, Any]:
        """Test performance with multiple queries"""
        try:
            # Get available models
            models_result = await self.test_available_models()
            if not models_result["success"]:
                return {"success": False, "error": "No models available"}
            
            model_name = models_result["model_names"][0]
            
            # Create agent
            agent = LlmAgent(
                name="performance_test_agent",
                model=LiteLlm(
                    model=model_name,  # Use model name directly with our proxy
                    api_base=self.ollama_host
                ),
                instruction="You are a helpful assistant. Keep responses brief.",
                description="Agent for performance testing"
            )
            
            # Create session and runner
            session = await self.session_service.create_session(app_name="ollama_test", user_id="test_user")
            runner = Runner(app_name="ollama_test", agent=agent, session_service=self.session_service)
            
            # Multiple test queries
            queries = [
                "What is Python?",
                "Explain machine learning briefly.",
                "What is data science?",
                "How do you calculate mean?",
                "What is statistics?"
            ]
            
            response_times = []
            successful_queries = 0
            
            print(f"📤 Running {len(queries)} performance test queries...")
            
            for i, query in enumerate(queries):
                try:
                    start_time = time.time()
                    
                    content = types.Content(role="user", parts=[types.Part(text=query)])
                    events = list(runner.run(
                        user_id="perf_test_user",
                        session_id=session.id,
                        new_message=content
                    ))
                    
                    response_time = time.time() - start_time
                    response_times.append(response_time)
                    
                    if events and events[-1].content:
                        successful_queries += 1
                        print(f"  Query {i+1}: {response_time:.2f}s ✅")
                    else:
                        print(f"  Query {i+1}: No response ❌")
                        
                except Exception as e:
                    print(f"  Query {i+1}: Error - {e} ❌")
            
            if response_times:
                avg_time = sum(response_times) / len(response_times)
                min_time = min(response_times)
                max_time = max(response_times)
                
                print(f"📊 Performance Results:")
                print(f"  Successful queries: {successful_queries}/{len(queries)}")
                print(f"  Average response time: {avg_time:.2f}s")
                print(f"  Min response time: {min_time:.2f}s")
                print(f"  Max response time: {max_time:.2f}s")
                
                return {
                    "success": True,
                    "total_queries": len(queries),
                    "successful_queries": successful_queries,
                    "avg_response_time": avg_time,
                    "min_response_time": min_time,
                    "max_response_time": max_time,
                    "response_times": response_times,
                    "model_name": model_name
                }
            else:
                return {"success": False, "error": "No successful queries"}
                
        except Exception as e:
            print(f"❌ Performance test failed: {e}")
            return {"success": False, "error": str(e)}
    
    def _compile_results(self) -> Dict[str, Any]:
        """Compile all test results"""
        total_tests = len(self.test_results)
        successful_tests = sum(1 for test in self.test_results if test["result"].get("success", False))
        
        return {
            "summary": {
                "total_tests": total_tests,
                "successful_tests": successful_tests,
                "success_rate": (successful_tests / total_tests) * 100 if total_tests > 0 else 0,
                "overall_success": successful_tests == total_tests
            },
            "test_results": self.test_results,
            "timestamp": time.time()
        }


async def main():
    """Main test function"""
    print("🚀 Ollama Data Science Agent Integration Test")
    print("=" * 60)
    
    # Check if Ollama host is specified
    ollama_host = os.environ.get("OLLAMA_HOST", "http://localhost:11434")
    print(f"🔗 Testing Ollama at: {ollama_host}")
    
    # Create tester
    tester = OllamaDataScienceAgentTester(ollama_host=ollama_host)
    
    try:
        # Run all tests
        results = await tester.run_all_tests()
        
        # Print final results
        print("\n" + "=" * 60)
        print("📋 FINAL TEST RESULTS")
        print("=" * 60)
        
        summary = results["summary"]
        print(f"Total Tests: {summary['total_tests']}")
        print(f"Successful: {summary['successful_tests']}")
        print(f"Success Rate: {summary['success_rate']:.1f}%")
        
        if summary["overall_success"]:
            print("\n🎉 ALL TESTS PASSED! Ollama is correctly communicating with the data science agent.")
        else:
            print(f"\n⚠️  {summary['total_tests'] - summary['successful_tests']} tests failed. Check the results above.")
        
        # Save results to file
        results_file = "ollama_test_results.json"
        with open(results_file, "w") as f:
            json.dump(results, f, indent=2, default=str)
        print(f"\n💾 Detailed results saved to: {results_file}")
        
        return results
        
    except KeyboardInterrupt:
        print("\n\n⏹️  Tests interrupted by user")
        return {"error": "interrupted"}
    except Exception as e:
        print(f"\n\n❌ Test suite failed: {e}")
        return {"error": str(e)}


if __name__ == "__main__":
    # Run the tests
    results = asyncio.run(main())
    
    # Exit with appropriate code
    if results.get("summary", {}).get("overall_success", False):
        print("\n✅ Test suite completed successfully!")
        sys.exit(0)
    else:
        print("\n❌ Test suite failed!")
        sys.exit(1)
