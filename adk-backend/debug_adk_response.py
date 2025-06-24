#!/usr/bin/env python3
"""
Debug script to see what ADK API actually returns
"""

import asyncio
import aiohttp
import json
import uuid

async def debug_adk_response():
    """Test ADK API response format"""
    adk_host = "http://localhost:8001"
    app_name = "data_science_agent"
    user_id = "test_user"
    
    print("🔍 Debugging ADK API response format...")
    
    try:
        # First create a session
        session_id = f"debug_test_{uuid.uuid4().hex[:8]}"
        
        timeout = aiohttp.ClientTimeout(total=30)
        async with aiohttp.ClientSession(timeout=timeout) as session:
            # Create session
            session_url = f"{adk_host}/apps/{app_name}/users/{user_id}/sessions"
            session_data = {"session_id": session_id}
            
            print(f"📡 Creating session: {session_url}")
            async with session.post(session_url, json=session_data) as resp:
                if resp.status == 200:
                    session_result = await resp.json()
                    print(f"✅ Session created: {session_result}")
                else:
                    print(f"❌ Session creation failed: {resp.status}")
                    return
            
            # Send a message
            message_url = f"{adk_host}/apps/{app_name}/users/{user_id}/sessions/{session_id}"
            message_data = {
                "role": "user",
                "content": "Hello! What is 2+2?"
            }
            
            print(f"📤 Sending message: {message_url}")
            print(f"📋 Message data: {json.dumps(message_data, indent=2)}")
            
            async with session.post(message_url, json=message_data) as resp:
                print(f"📊 Response status: {resp.status}")
                print(f"📊 Response headers: {dict(resp.headers)}")
                
                if resp.status == 200:
                    response_data = await resp.json()
                    print(f"📋 Full response structure:")
                    print(json.dumps(response_data, indent=2))
                    
                    # Analyze the response structure
                    if isinstance(response_data, dict):
                        print(f"\n🔍 Response analysis:")
                        print(f"   Top-level keys: {list(response_data.keys())}")
                        
                        for key, value in response_data.items():
                            print(f"   {key}: {type(value)} - {str(value)[:100]}{'...' if len(str(value)) > 100 else ''}")
                        
                        # Check for events specifically
                        if 'events' in response_data:
                            events = response_data['events']
                            print(f"\n🎯 Events found: {len(events)} events")
                            for i, event in enumerate(events):
                                print(f"   Event {i}: {type(event)} - {str(event)[:100]}{'...' if len(str(event)) > 100 else ''}")
                        else:
                            print(f"\n⚠️ No 'events' key found in response")
                            
                else:
                    error_text = await resp.text()
                    print(f"❌ Request failed: {error_text}")
                    
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(debug_adk_response())
