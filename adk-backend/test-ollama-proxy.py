#!/usr/bin/env python3
"""
Test script for the Ollama ADK Proxy
This script tests the proxy endpoints to ensure they're working correctly.
"""

import requests
import json
import time
import sys

def test_health():
    """Test the health endpoint"""
    try:
        response = requests.get("http://localhost:11434/health", timeout=5)
        if response.status_code == 200:
            print("✅ Health check passed")
            return True
        else:
            print(f"❌ Health check failed: {response.status_code}")
            return False
    except requests.RequestException as e:
        print(f"❌ Health check failed: {e}")
        return False

def test_models():
    """Test the models endpoint"""
    try:
        response = requests.get("http://localhost:11434/api/tags", timeout=5)
        if response.status_code == 200:
            data = response.json()
            models = data.get("models", [])
            print(f"✅ Models endpoint working, found {len(models)} models")
            for model in models:
                print(f"   - {model.get('name', 'Unknown')}")
            return True
        else:
            print(f"❌ Models endpoint failed: {response.status_code}")
            return False
    except requests.RequestException as e:
        print(f"❌ Models endpoint failed: {e}")
        return False

def test_chat():
    """Test the chat endpoint"""
    chat_request = {
        "model": "adk-agent:latest",
        "messages": [
            {"role": "user", "content": "Hello, can you help me with data analysis?"}
        ],
        "stream": False
    }
    
    try:
        response = requests.post(
            "http://localhost:11434/api/chat",
            json=chat_request,
            timeout=30
        )
        
        if response.status_code == 200:
            data = response.json()
            message = data.get("message", {})
            content = message.get("content", "")
            print("✅ Chat endpoint working")
            print(f"   Response: {content[:100]}{'...' if len(content) > 100 else ''}")
            return True
        else:
            print(f"❌ Chat endpoint failed: {response.status_code}")
            print(f"   Response: {response.text}")
            return False
    except requests.RequestException as e:
        print(f"❌ Chat endpoint failed: {e}")
        return False

def test_adk_backend():
    """Test if ADK backend is accessible"""
    try:
        response = requests.get("http://localhost:8000", timeout=5)
        if response.status_code in [200, 404]:  # 404 is ok, means service is running
            print("✅ ADK Backend is accessible")
            return True
        else:
            print(f"❌ ADK Backend not accessible: {response.status_code}")
            return False
    except requests.RequestException as e:
        print(f"❌ ADK Backend not accessible: {e}")
        return False

def main():
    print("🧪 Testing Ollama ADK Proxy...")
    print("=" * 50)
    
    all_tests_passed = True
    
    # Test ADK Backend first
    print("\n1. Testing ADK Backend connectivity...")
    if not test_adk_backend():
        all_tests_passed = False
        print("⚠️  ADK Backend is not running. Start it first with:")
        print("   docker-compose up adk-backend -d")
    
    # Test Proxy endpoints
    print("\n2. Testing Ollama Proxy health...")
    if not test_health():
        all_tests_passed = False
        print("⚠️  Ollama Proxy is not running. Start it with:")
        print("   docker-compose -f docker-compose.openwebui.yml up ollama-proxy -d")
        return
    
    print("\n3. Testing models endpoint...")
    if not test_models():
        all_tests_passed = False
    
    print("\n4. Testing chat endpoint...")
    if not test_chat():
        all_tests_passed = False
    
    print("\n" + "=" * 50)
    
    if all_tests_passed:
        print("🎉 All tests passed! The Ollama ADK Proxy is working correctly.")
        print("\nYou can now:")
        print("• Access OpenWebUI at http://localhost:3000")
        print("• Use the adk-agent:latest model for conversations")
    else:
        print("❌ Some tests failed. Check the logs and configuration.")
        print("\nTo check logs:")
        print("docker-compose -f docker-compose.openwebui.yml logs ollama-proxy")
        sys.exit(1)

if __name__ == "__main__":
    main()
