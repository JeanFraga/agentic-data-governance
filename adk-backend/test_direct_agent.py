#!/usr/bin/env python3
"""
Test the data science agent directly to see if it can generate responses
"""

import os
import asyncio
from google.genai import types
from google.adk.sessions import InMemorySessionService
from google.adk.artifacts import InMemoryArtifactService
from google.adk.runners import Runner
from data_science_agent.agent import root_agent

# Set LiteLLM environment
os.environ["LITELLM_API_BASE"] = "http://localhost:11434"
os.environ["LITELLM_API_KEY"] = "dummy"

async def test_direct_agent():
    """Test the agent directly using the Runner"""
    print("🧪 Testing data science agent directly...")
    
    try:
        # Create session and artifact services
        session_service = InMemorySessionService()
        artifact_service = InMemoryArtifactService()
        
        # Create session
        session = await session_service.create_session(
            app_name="test_direct_agent",
            user_id="test_user"
        )
        
        print(f"✅ Session created: {session.id}")
        
        # Create runner with artifact service
        runner = Runner(
            app_name="test_direct_agent",
            agent=root_agent,
            session_service=session_service,
            artifact_service=artifact_service
        )
        
        # Create message
        content = types.Content(
            role="user", 
            parts=[types.Part(text="Hello! What is 2+2? Please give a brief answer.")]
        )
        
        print("📤 Sending message to agent...")
        
        # Run the agent
        events = list(runner.run(
            user_id="test_user",
            session_id=session.id,
            new_message=content
        ))
        
        print(f"✅ Agent processed message - got {len(events)} events")
        
        if events:
            # Look for the last event with content
            for i, event in enumerate(events):
                print(f"Event {i}: {type(event)} - {str(event)[:100]}...")
                if hasattr(event, 'content') and event.content:
                    if hasattr(event.content, 'parts'):
                        for j, part in enumerate(event.content.parts):
                            if hasattr(part, 'text') and part.text:
                                print(f"  Part {j}: {part.text[:200]}...")
            
            # Get final response
            last_event = events[-1]
            if hasattr(last_event, 'content') and last_event.content:
                if hasattr(last_event.content, 'parts'):
                    final_response = "".join([
                        part.text for part in last_event.content.parts 
                        if hasattr(part, 'text') and part.text
                    ])
                    print(f"📥 Final response: {final_response[:300]}...")
                    return True
                    
        print("⚠️ No response content found in events")
        return False
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    asyncio.run(test_direct_agent())
