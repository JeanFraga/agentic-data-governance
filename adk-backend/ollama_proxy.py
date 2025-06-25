#!/usr/bin/env python3
"""
Ollama Proxy for ADK Backend Integration

This proxy server translates OpenWebUI's Ollama-compatible API requests 
to ADK backend API calls, enabling seamless integration between 
OpenWebUI frontend and Google ADK agents.

Architecture:
OpenWebUI → Ollama Proxy (this script) → ADK Backend → Google Vertex AI

The proxy exposes an Ollama-compatible API on port 11434 and forwards
requests to the ADK backend running on port 8000.
"""

import asyncio
import json
import logging
import os
import uuid
from datetime import datetime
from typing import AsyncGenerator, Dict, List, Optional

import httpx
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Configuration
ADK_BACKEND_URL = os.getenv("ADK_BACKEND_URL", "http://localhost:8000")
PROXY_PORT = int(os.getenv("PROXY_PORT", "11434"))
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")

# Set log level
logger.setLevel(getattr(logging, LOG_LEVEL.upper()))

app = FastAPI(title="Ollama Proxy for ADK Backend", version="1.0.0")

# Pydantic models for API requests/responses
class ChatMessage(BaseModel):
    role: str
    content: str

class ChatRequest(BaseModel):
    model: str
    messages: List[ChatMessage]
    stream: Optional[bool] = False
    temperature: Optional[float] = 0.7
    max_tokens: Optional[int] = None

class ChatResponse(BaseModel):
    model: str
    created_at: str
    message: ChatMessage
    done: bool

class ModelInfo(BaseModel):
    name: str
    modified_at: str
    size: int = 0
    digest: str = ""

class ModelsResponse(BaseModel):
    models: List[ModelInfo]

@app.get("/")
async def root():
    """Root endpoint for health checks"""
    return {"status": "ok", "service": "ollama-proxy", "backend": ADK_BACKEND_URL}

@app.get("/health")
async def health():
    """Health check endpoint"""
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(f"{ADK_BACKEND_URL}/health", timeout=5.0)
            backend_healthy = response.status_code == 200
    except Exception as e:
        logger.warning(f"Backend health check failed: {e}")
        backend_healthy = False
    
    return {
        "status": "ok" if backend_healthy else "degraded",
        "proxy": "healthy",
        "backend": "healthy" if backend_healthy else "unhealthy",
        "timestamp": datetime.utcnow().isoformat()
    }

@app.get("/api/tags")
async def list_models():
    """List available models (Ollama API compatibility)"""
    # Return available ADK agents as "models"
    models = [
        ModelInfo(
            name="data-science-agent",
            modified_at=datetime.utcnow().isoformat(),
            size=1024000,  # Placeholder size
            digest="sha256:adk-data-science"
        ),
        ModelInfo(
            name="adk-agent",
            modified_at=datetime.utcnow().isoformat(),
            size=1024000,  # Placeholder size
            digest="sha256:adk-default"
        )
    ]
    
    return ModelsResponse(models=models)

@app.post("/api/chat")
async def chat_completion(request: ChatRequest):
    """Handle chat completion requests"""
    logger.info(f"Received chat request for model: {request.model}")
    logger.debug(f"Messages: {request.messages}")
    
    try:
        # Convert OpenWebUI/Ollama format to ADK format
        adk_request = await convert_to_adk_format(request)
        
        # Forward to ADK backend
        if request.stream:
            return StreamingResponse(
                stream_adk_response(adk_request, request.model),
                media_type="application/x-ndjson"
            )
        else:
            response = await call_adk_backend(adk_request)
            return await convert_from_adk_format(response, request.model)
            
    except Exception as e:
        logger.error(f"Error processing chat request: {e}")
        raise HTTPException(status_code=500, detail=str(e))

async def convert_to_adk_format(request: ChatRequest) -> Dict:
    """Convert Ollama/OpenWebUI format to ADK backend format"""
    # Extract the user's message (last message with role 'user')
    user_message = ""
    for msg in reversed(request.messages):
        if msg.role == "user":
            user_message = msg.content
            break
    
    # Build conversation history for context
    conversation_history = []
    for msg in request.messages[:-1]:  # Exclude the last message as it's the current query
        conversation_history.append({
            "role": msg.role,
            "content": msg.content
        })
    
    # ADK backend expects a specific format
    adk_request = {
        "query": user_message,
        "conversation_history": conversation_history,
        "model": request.model,
        "temperature": request.temperature,
        "max_tokens": request.max_tokens,
        "stream": request.stream
    }
    
    logger.debug(f"Converted to ADK format: {adk_request}")
    return adk_request

async def call_adk_backend(adk_request: Dict) -> Dict:
    """Call the ADK backend API"""
    async with httpx.AsyncClient(timeout=120.0) as client:
        try:
            # Use the ADK API server endpoint
            response = await client.post(
                f"{ADK_BACKEND_URL}/query",  # ADK API server endpoint
                json=adk_request,
                headers={"Content-Type": "application/json"}
            )
            response.raise_for_status()
            return response.json()
        except httpx.HTTPStatusError as e:
            logger.error(f"ADK backend HTTP error: {e.response.status_code} - {e.response.text}")
            raise HTTPException(
                status_code=e.response.status_code,
                detail=f"ADK backend error: {e.response.text}"
            )
        except Exception as e:
            logger.error(f"ADK backend connection error: {e}")
            raise HTTPException(
                status_code=503,
                detail=f"Cannot connect to ADK backend: {e}"
            )

async def convert_from_adk_format(adk_response: Dict, model: str) -> ChatResponse:
    """Convert ADK response back to Ollama format"""
    # Extract the response content from ADK
    content = adk_response.get("response", adk_response.get("answer", "No response from ADK backend"))
    
    return ChatResponse(
        model=model,
        created_at=datetime.utcnow().isoformat(),
        message=ChatMessage(role="assistant", content=content),
        done=True
    )

async def stream_adk_response(adk_request: Dict, model: str) -> AsyncGenerator[str, None]:
    """Stream response from ADK backend in Ollama format"""
    try:
        async with httpx.AsyncClient(timeout=120.0) as client:
            async with client.stream(
                "POST",
                f"{ADK_BACKEND_URL}/query",
                json=adk_request,
                headers={"Content-Type": "application/json"}
            ) as response:
                response.raise_for_status()
                
                async for chunk in response.aiter_text():
                    if chunk.strip():
                        try:
                            # Try to parse as JSON (for structured responses)
                            data = json.loads(chunk)
                            content = data.get("response", data.get("answer", chunk))
                        except json.JSONDecodeError:
                            # Use chunk as-is if not JSON
                            content = chunk
                        
                        # Format as Ollama streaming response
                        ollama_chunk = {
                            "model": model,
                            "created_at": datetime.utcnow().isoformat(),
                            "message": {
                                "role": "assistant",
                                "content": content
                            },
                            "done": False
                        }
                        
                        yield f"data: {json.dumps(ollama_chunk)}\n\n"
                
                # Send final chunk
                final_chunk = {
                    "model": model,
                    "created_at": datetime.utcnow().isoformat(),
                    "message": {
                        "role": "assistant",
                        "content": ""
                    },
                    "done": True
                }
                yield f"data: {json.dumps(final_chunk)}\n\n"
                
    except Exception as e:
        logger.error(f"Streaming error: {e}")
        error_chunk = {
            "model": model,
            "created_at": datetime.utcnow().isoformat(),
            "message": {
                "role": "assistant",
                "content": f"Error: {str(e)}"
            },
            "done": True
        }
        yield f"data: {json.dumps(error_chunk)}\n\n"

# Additional Ollama API endpoints for compatibility
@app.post("/api/generate")
async def generate_completion(request: Request):
    """Handle generate completion requests (legacy Ollama API)"""
    data = await request.json()
    
    # Convert to chat format
    chat_request = ChatRequest(
        model=data.get("model", "adk-agent"),
        messages=[ChatMessage(role="user", content=data.get("prompt", ""))],
        stream=data.get("stream", False),
        temperature=data.get("temperature", 0.7)
    )
    
    return await chat_completion(chat_request)

@app.get("/api/show")
async def show_model():
    """Show model information"""
    return {
        "license": "Apache 2.0",
        "modelfile": "# ADK Agent Model\nFROM data-science-agent\n",
        "parameters": "temperature 0.7\ntop_p 0.9",
        "template": "{{ .Prompt }}",
        "details": {
            "family": "adk",
            "format": "agent",
            "parameter_size": "multi-agent",
            "quantization_level": "fp16"
        }
    }

if __name__ == "__main__":
    import uvicorn
    logger.info(f"Starting Ollama Proxy on port {PROXY_PORT}")
    logger.info(f"Forwarding to ADK Backend at {ADK_BACKEND_URL}")
    
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=PROXY_PORT,
        log_level=LOG_LEVEL.lower(),
        access_log=LOG_LEVEL.upper() == "DEBUG"
    )
