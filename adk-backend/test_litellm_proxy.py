#!/usr/bin/env python3
"""
Test script for LiteLLM Ollama Proxy
This script tests the proxy functionality without requiring the full ADK backend.
"""

import asyncio
import json
import logging
import os
import aiohttp

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

PROXY_URL = "http://localhost:11434"

async def test_health():
    """Test the health endpoint"""
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(f"{PROXY_URL}/health") as response:
                if response.status == 200:
                    health_data = await response.json()
                    logger.info("Health check passed: %s", health_data)
                    return True
                else:
                    logger.error("Health check failed with status: %s", response.status)
                    return False
    except Exception as e:
        logger.error("Health check error: %s", e)
        return False

async def test_models():
    """Test the models endpoint"""
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(f"{PROXY_URL}/api/tags") as response:
                if response.status == 200:
                    models_data = await response.json()
                    logger.info("Available models: %s", [m['name'] for m in models_data.get('models', [])])
                    return True
                else:
                    logger.error("Models endpoint failed with status: %s", response.status)
                    return False
    except Exception as e:
        logger.error("Models endpoint error: %s", e)
        return False

async def test_chat():
    """Test the chat endpoint"""
    try:
        chat_request = {
            "model": "adk-agent:latest",
            "messages": [
                {"role": "user", "content": "Hello! Can you help me with data analysis?"}
            ],
            "stream": False
        }
        
        async with aiohttp.ClientSession() as session:
            async with session.post(
                f"{PROXY_URL}/api/chat",
                json=chat_request,
                headers={"Content-Type": "application/json"}
            ) as response:
                if response.status == 200:
                    chat_data = await response.json()
                    logger.info("Chat response received: %s", chat_data.get('message', {}).get('content', 'No content'))
                    return True
                else:
                    error_text = await response.text()
                    logger.error("Chat endpoint failed with status %s: %s", response.status, error_text)
                    return False
    except Exception as e:
        logger.error("Chat endpoint error: %s", e)
        return False

async def test_streaming_chat():
    """Test the streaming chat endpoint"""
    try:
        chat_request = {
            "model": "adk-agent:latest",
            "messages": [
                {"role": "user", "content": "Tell me about data science in a few sentences."}
            ],
            "stream": True
        }
        
        async with aiohttp.ClientSession() as session:
            async with session.post(
                f"{PROXY_URL}/api/chat",
                json=chat_request,
                headers={"Content-Type": "application/json"}
            ) as response:
                if response.status == 200:
                    logger.info("Streaming chat response:")
                    async for line in response.content:
                        if line:
                            try:
                                chunk_data = json.loads(line.decode())
                                content = chunk_data.get('message', {}).get('content', '')
                                if content:
                                    print(content, end='', flush=True)
                                if chunk_data.get('done'):
                                    print()  # New line at end
                                    break
                            except json.JSONDecodeError:
                                continue
                    return True
                else:
                    error_text = await response.text()
                    logger.error("Streaming chat failed with status %s: %s", response.status, error_text)
                    return False
    except Exception as e:
        logger.error("Streaming chat error: %s", e)
        return False

async def main():
    """Run all tests"""
    logger.info("Starting LiteLLM Ollama Proxy tests...")
    
    # Test health endpoint
    logger.info("1. Testing health endpoint...")
    health_ok = await test_health()
    
    # Test models endpoint
    logger.info("2. Testing models endpoint...")
    models_ok = await test_models()
    
    # Test chat endpoint
    logger.info("3. Testing chat endpoint...")
    chat_ok = await test_chat()
    
    # Test streaming chat endpoint
    logger.info("4. Testing streaming chat endpoint...")
    streaming_ok = await test_streaming_chat()
    
    # Results
    logger.info("Test Results:")
    logger.info("  Health endpoint: %s", "✓ PASS" if health_ok else "✗ FAIL")
    logger.info("  Models endpoint: %s", "✓ PASS" if models_ok else "✗ FAIL")
    logger.info("  Chat endpoint: %s", "✓ PASS" if chat_ok else "✗ FAIL")
    logger.info("  Streaming chat: %s", "✓ PASS" if streaming_ok else "✗ FAIL")
    
    all_passed = health_ok and models_ok and chat_ok and streaming_ok
    logger.info("Overall result: %s", "✓ ALL TESTS PASSED" if all_passed else "✗ SOME TESTS FAILED")
    
    return all_passed

if __name__ == "__main__":
    success = asyncio.run(main())
    exit(0 if success else 1)
