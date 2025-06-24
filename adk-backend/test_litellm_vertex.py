#!/usr/bin/env python3
"""
Test LiteLLM with Vertex AI directly to debug authentication
"""

import os
import asyncio
import litellm

# Set up Vertex AI environment
os.environ["VERTEX_PROJECT"] = "agenticds-hackathon-54443"
os.environ["VERTEX_LOCATION"] = "us-central1"
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = os.path.expanduser("~/.config/gcloud/application_default_credentials.json")

async def test_vertex_ai():
    try:
        print("🧪 Testing LiteLLM with Vertex AI...")
        print(f"Project: {os.environ.get('VERTEX_PROJECT')}")
        print(f"Location: {os.environ.get('VERTEX_LOCATION')}")
        print(f"Credentials: {os.environ.get('GOOGLE_APPLICATION_CREDENTIALS')}")
        
        # Test with Vertex AI model
        response = await litellm.acompletion(
            model="vertex_ai/gemini-2.0-flash-001",
            messages=[{"role": "user", "content": "Hello! What is 2+2?"}],
            timeout=30
        )
        
        print("✅ Success! Response:")
        print(response.choices[0].message.content)
        
    except Exception as e:
        print(f"❌ Error: {e}")
        print(f"Error type: {type(e)}")

if __name__ == "__main__":
    asyncio.run(test_vertex_ai())
