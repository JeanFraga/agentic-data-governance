#!/usr/bin/env python3
"""
Ollama Proxy Service
This service acts as a translation layer between OpenWebUI and the ADK agent.
It receives OpenAI-compatible requests from OpenWebUI via Ollama and forwards them to the ADK backend.
"""

import json
import logging
import os
import aiohttp
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import StreamingResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
from typing import Dict, Any
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Ollama ADK Proxy", description="Proxy service between Ollama/OpenWebUI and ADK Agent")

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configuration
ADK_BACKEND_URL = os.getenv("ADK_BACKEND_URL", "http://adk-backend:8000")
PROXY_PORT = int(os.getenv("PROXY_PORT", "11434"))

class OllamaADKTranslator:
    """Handles translation between Ollama/OpenWebUI format and ADK format"""
    
    def __init__(self, adk_url: str):
        self.adk_url = adk_url
        self.session = None
    
    async def get_session(self):
        if self.session is None:
            self.session = aiohttp.ClientSession()
        return self.session
    
    async def close_session(self):
        if self.session:
            await self.session.close()
    
    def translate_ollama_to_adk(self, ollama_request: Dict[str, Any]) -> Dict[str, Any]:
        """Convert Ollama chat completion request to ADK format"""
        messages = ollama_request.get("messages", [])
        user_message = ""
        
        if messages:
            for msg in reversed(messages):
                if msg.get("role") == "user":
                    user_message = msg.get("content", "")
                    break
        
        # ADK web interface format for /run endpoint
        # Correct message format: parts must contain objects with "text" field
        adk_request = {
            "appName": "data_science_agent",
            "userId": "openwebui_user",
            "sessionId": "openwebui_session",
            "newMessage": {
                "role": "user",
                "parts": [{"text": user_message}]
            }
        }
        
        return adk_request
    
    def translate_adk_to_ollama(self, adk_response: Dict[str, Any], model: str) -> Dict[str, Any]:
        """Convert ADK response to Ollama chat completion format"""
        content = ""
        
        # ADK returns a list of events, find the one with content
        if isinstance(adk_response, list):
            for event in adk_response:
                if isinstance(event, dict) and event.get("content"):
                    content_obj = event["content"]
                    if isinstance(content_obj, dict) and content_obj.get("parts"):
                        parts = content_obj["parts"]
                        if isinstance(parts, list) and len(parts) > 0:
                            first_part = parts[0]
                            if isinstance(first_part, dict) and first_part.get("text"):
                                content = first_part["text"]
                                break
        
        # Fallback to string representation if no content found
        if not content:
            content = str(adk_response)
        
        current_time = datetime.now().strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"
        
        return {
            "model": model,
            "created_at": current_time,
            "message": {
                "role": "assistant",
                "content": content
            },
            "done": True
        }
    
    async def forward_to_adk(self, adk_request: Dict[str, Any]) -> Dict[str, Any]:
        """Forward request to ADK backend and get response"""
        session = await self.get_session()
        
        try:
            # First ensure session exists
            session_url = f"{self.adk_url}/apps/{adk_request['appName']}/users/{adk_request['userId']}/sessions"
            try:
                async with session.post(
                    session_url,
                    json={"appName": adk_request['appName'], "userId": adk_request['userId']},
                    timeout=10
                ) as response:
                    if response.status == 200:
                        session_data = await response.json()
                        actual_session_id = session_data.get('id', adk_request['sessionId'])
                        adk_request['sessionId'] = actual_session_id
            except:
                pass  # Session might already exist, continue with original session_id
            
            # Send message using /run endpoint
            async with session.post(
                f"{self.adk_url}/run",
                json=adk_request,
                headers={"Content-Type": "application/json"},
                timeout=30
            ) as response:
                if response.status == 200:
                    return await response.json()
                else:
                    error_text = await response.text()
                    logger.error(f"ADK backend error {response.status}: {error_text}")
                    raise HTTPException(status_code=503, detail=f"ADK backend error: {error_text}")
                    
        except aiohttp.ClientError as e:
            logger.error(f"Connection error to ADK backend: {e}")
            raise HTTPException(status_code=503, detail="ADK backend unavailable")

# Initialize translator
translator = OllamaADKTranslator(ADK_BACKEND_URL)

@app.on_event("startup")
async def startup_event():
    logger.info("Starting Ollama ADK Proxy on port %s", PROXY_PORT)

@app.on_event("shutdown")
async def shutdown_event():
    await translator.close_session()

@app.get("/api/tags")
async def get_models():
    """Return available models (required by Ollama API)"""
    return {
        "models": [
            {
                "model": "adk-agent:latest",  # Changed from "name" to "model"
                "name": "adk-agent:latest",   # Keep "name" for compatibility
                "modified_at": datetime.now().strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z",
                "size": 3826793677,
                "digest": "sha256:bc07c81de745696fdf5afca05e065818a8149fb0c77266fb584d9b2cba3711ab"
            }
        ]
    }

@app.post("/api/chat")
async def chat_completion(request: Request):
    """Handle chat completion requests from Ollama/OpenWebUI"""
    try:
        ollama_request = await request.json()
        logger.info("Received Ollama request")
        
        adk_request = translator.translate_ollama_to_adk(ollama_request)
        adk_response = await translator.forward_to_adk(adk_request)
        
        model = ollama_request.get("model", "adk-agent")
        ollama_response = translator.translate_adk_to_ollama(adk_response, model)
        
        return JSONResponse(ollama_response)
            
    except Exception as e:
        logger.error("Error processing chat request: %s", e)
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "ollama-adk-proxy"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=PROXY_PORT, log_level="info")
