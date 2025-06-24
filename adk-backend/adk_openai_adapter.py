#!/usr/bin/env python3
"""
OpenAI-compatible API adapter for Google ADK API Server
This adapter makes the ADK API server compatible with LiteLLM by providing OpenAI-style endpoints
"""

import os
import asyncio
import logging
import time
import uuid
from typing import List, Dict, Any, Optional
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uvicorn
import aiohttp

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="ADK OpenAI Adapter",
    description="OpenAI-compatible API adapter for Google ADK",
    version="1.0.0"
)

# Configuration
ADK_API_BASE = os.getenv("ADK_API_BASE", "http://localhost:8001")
ADK_APP_NAME = os.getenv("ADK_APP_NAME", "data_science_agent")
ADK_USER_ID = os.getenv("ADK_USER_ID", "openai_user")

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
async def root():
    """Root endpoint"""
    return {"message": "ADK OpenAI Adapter", "status": "healthy"}

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "adk-openai-adapter"}

@app.get("/v1/models")
async def list_models():
    """List available models (OpenAI-compatible)"""
    return {
        "object": "list",
        "data": [
            ModelInfo(
                id="adk-data-science-agent",
                created=int(time.time()),
                owned_by="adk"
            ).dict(),
            ModelInfo(
                id="data-science-agent", 
                created=int(time.time()),
                owned_by="adk"
            ).dict()
        ]
    }

@app.post("/v1/chat/completions")
async def create_chat_completion(request: ChatCompletionRequest):
    """Create a chat completion using the ADK API server (OpenAI-compatible)"""
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
        
        logger.info(f"Processing message: {user_message[:100]}...")
        
        # Step 1: Create a session with ADK API server
        session_id = f"openai_session_{uuid.uuid4().hex[:8]}"
        
        async with aiohttp.ClientSession() as session:
            # Create session
            session_url = f"{ADK_API_BASE}/apps/{ADK_APP_NAME}/users/{ADK_USER_ID}/sessions"
            session_data = {"session_id": session_id}
            
            logger.info(f"Creating ADK session: {session_url}")
            async with session.post(session_url, json=session_data) as resp:
                if resp.status != 200:
                    logger.error(f"Failed to create session: {resp.status}")
                    raise HTTPException(status_code=500, detail="Failed to create ADK session")
                
                session_result = await resp.json()
                actual_session_id = session_result.get("id", session_id)
                logger.info(f"ADK session created: {actual_session_id}")
            
            # Step 2: Send message to ADK API server
            message_url = f"{ADK_API_BASE}/apps/{ADK_APP_NAME}/users/{ADK_USER_ID}/sessions/{actual_session_id}"
            message_data = {
                "role": "user",
                "content": user_message
            }
            
            logger.info(f"Sending message to ADK: {message_url}")
            async with session.post(message_url, json=message_data, timeout=aiohttp.ClientTimeout(total=120)) as resp:
                if resp.status != 200:
                    logger.error(f"ADK API request failed: {resp.status}")
                    error_text = await resp.text()
                    raise HTTPException(status_code=500, detail=f"ADK API error: {error_text}")
                
                response_data = await resp.json()
                logger.info(f"ADK response received: {response_data}")
        
        # Step 3: Extract response from ADK API response
        response_text = ""
        events = response_data.get('events', [])
        
        if events:
            # Look for agent response in events
            for event in events:
                if event.get('type') == 'agent_response' or 'content' in event:
                    content = event.get('content', '')
                    if content:
                        response_text = str(content)
                        break
        
        # If no events, try to get response from state or other fields
        if not response_text:
            state = response_data.get('state', {})
            if isinstance(state, dict) and 'content' in state:
                response_text = str(state['content'])
            elif isinstance(state, str):
                response_text = state
        
        # Fallback response if no content found
        if not response_text:
            response_text = "I received your message but was unable to generate a response. Please try again."
        
        logger.info(f"Generated response: {response_text[:100]}...")
        
        # Step 4: Format as OpenAI-compatible response
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
        
    except aiohttp.ClientError as e:
        logger.error(f"Network error communicating with ADK API: {e}")
        raise HTTPException(status_code=502, detail=f"ADK API communication error: {str(e)}")
    except Exception as e:
        logger.error(f"Error processing chat completion: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

if __name__ == "__main__":
    port = int(os.getenv("PORT", "8080"))
    host = os.getenv("HOST", "0.0.0.0")
    
    logger.info(f"Starting ADK OpenAI Adapter on {host}:{port}")
    logger.info(f"ADK API Base: {ADK_API_BASE}")
    logger.info(f"ADK App Name: {ADK_APP_NAME}")
    
    uvicorn.run(app, host=host, port=port)
