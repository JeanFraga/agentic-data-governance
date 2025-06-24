#!/usr/bin/env python3
"""
FastAPI service to expose ADK agent through OpenAI-compatible API
"""

import os
import asyncio
import logging
from typing import List, Dict, Any, Optional
from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
import uvicorn
from google.genai import types
from google.adk.sessions import InMemorySessionService
from google.adk.artifacts import InMemoryArtifactService
from google.adk.runners import Runner
from data_science_agent.agent import root_agent

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="ADK Agent API",
    description="OpenAI-compatible API for Google ADK Data Science Agent",
    version="1.0.0"
)

# Global services
session_service = InMemorySessionService()
artifact_service = InMemoryArtifactService()

# Request/Response Models
class ChatMessage(BaseModel):
    role: str
    content: str

class ChatCompletionRequest(BaseModel):
    model: str
    messages: List[ChatMessage]
    stream: Optional[bool] = False
    temperature: Optional[float] = 0.7
    max_tokens: Optional[int] = None

class ChatCompletionResponse(BaseModel):
    id: str
    object: str = "chat.completion"
    created: int
    model: str
    choices: List[Dict[str, Any]]
    usage: Dict[str, int] = {"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0}

class ModelInfo(BaseModel):
    id: str
    object: str = "model"
    created: int
    owned_by: str = "adk"

@app.get("/")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "adk-agent-api", "agent": "data_science_agent"}

@app.get("/v1/models")
async def list_models():
    """List available models (OpenAI-compatible)"""
    import time
    return {
        "object": "list",
        "data": [
            ModelInfo(
                id="adk-data-science-agent",
                created=int(time.time()),
                owned_by="adk"
            ).dict()
        ]
    }

@app.post("/v1/chat/completions")
async def create_chat_completion(request: ChatCompletionRequest):
    """Create a chat completion using the ADK agent (OpenAI-compatible)"""
    try:
        logger.info(f"Received chat completion request for model: {request.model}")
        
        # Extract the user message (last message in the conversation)
        if not request.messages:
            raise HTTPException(status_code=400, detail="No messages provided")
        
        user_message = None
        for msg in reversed(request.messages):
            if msg.role == "user":
                user_message = msg.content
                break
        
        if not user_message:
            raise HTTPException(status_code=400, detail="No user message found")
        
        # Create session
        session = await session_service.create_session(
            app_name="adk_agent_api",
            user_id="api_user"
        )
        
        logger.info(f"Created session: {session.id}")
        
        # Create runner
        runner = Runner(
            app_name="adk_agent_api",
            agent=root_agent,
            session_service=session_service,
            artifact_service=artifact_service
        )
        
        # Create content for the agent
        content = types.Content(
            role="user", 
            parts=[types.Part(text=user_message)]
        )
        
        logger.info(f"Processing message: {user_message[:100]}...")
        
        # Run the agent
        events = list(runner.run(
            user_id="api_user",
            session_id=session.id,
            new_message=content
        ))
        
        logger.info(f"Agent generated {len(events)} events")
        
        # Extract response from events
        response_text = ""
        if events:
            last_event = events[-1]
            if hasattr(last_event, 'content') and last_event.content:
                if hasattr(last_event.content, 'parts'):
                    response_text = "".join([
                        part.text for part in last_event.content.parts 
                        if hasattr(part, 'text') and part.text
                    ])
        
        if not response_text:
            response_text = "I apologize, but I was unable to generate a response. Please try again."
        
        logger.info(f"Generated response: {response_text[:100]}...")
        
        # Format as OpenAI-compatible response
        import time
        import uuid
        
        response = ChatCompletionResponse(
            id=f"chatcmpl-{uuid.uuid4().hex[:8]}",
            created=int(time.time()),
            model=request.model,
            choices=[{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": response_text
                },
                "finish_reason": "stop"
            }]
        )
        
        return response.dict()
        
    except Exception as e:
        logger.error(f"Error processing chat completion: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@app.post("/run_agent")
async def run_agent_direct(request: Dict[str, Any]):
    """Direct agent execution endpoint (for custom integrations)"""
    try:
        user_message = request.get("message", "")
        if not user_message:
            raise HTTPException(status_code=400, detail="No message provided")
        
        # Create session
        session = await session_service.create_session(
            app_name="adk_agent_direct",
            user_id="direct_user"
        )
        
        # Create runner
        runner = Runner(
            app_name="adk_agent_direct",
            agent=root_agent,
            session_service=session_service,
            artifact_service=artifact_service
        )
        
        # Create content for the agent
        content = types.Content(
            role="user", 
            parts=[types.Part(text=user_message)]
        )
        
        # Run the agent
        events = list(runner.run(
            user_id="direct_user",
            session_id=session.id,
            new_message=content
        ))
        
        # Extract response from events
        response_text = ""
        if events:
            last_event = events[-1]
            if hasattr(last_event, 'content') and last_event.content:
                if hasattr(last_event.content, 'parts'):
                    response_text = "".join([
                        part.text for part in last_event.content.parts 
                        if hasattr(part, 'text') and part.text
                    ])
        
        return {
            "response": response_text,
            "session_id": session.id,
            "events_count": len(events)
        }
        
    except Exception as e:
        logger.error(f"Error in direct agent execution: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

if __name__ == "__main__":
    port = int(os.getenv("FASTAPI_PORT", "8000"))
    host = os.getenv("FASTAPI_HOST", "0.0.0.0")
    
    logger.info(f"Starting ADK Agent API server on {host}:{port}")
    uvicorn.run(app, host=host, port=port)
