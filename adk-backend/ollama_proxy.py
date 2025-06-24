#!/usr/bin/env python3
"""
LiteLLM-based Ollama-compatible proxy for seamless integration with OpenWebUI.
This proxy provides an Ollama-compatible API that routes requests to various LLM providers
(Google Vertex AI, Google AI Studio, OpenAI, Anthropic) via LiteLLM.
"""

import os
import json
import logging
import asyncio
from datetime import datetime
from typing import Dict, List, Optional, Any, AsyncGenerator
from contextlib import asynccontextmanager

import uvicorn
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import StreamingResponse, JSONResponse
from pydantic import BaseModel, Field
import litellm

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Environment variables for configuration
LITELLM_PROVIDER = os.getenv("LITELLM_PROVIDER", "google_ai_studio")
PROXY_HOST = os.getenv("PROXY_HOST", "0.0.0.0")
PROXY_PORT = int(os.getenv("PROXY_PORT", "11434"))

# Provider-specific environment setup
def setup_provider_environment():
    """Set up environment variables based on the selected provider."""
    provider = LITELLM_PROVIDER.lower()
    
    if provider in ["vertex_ai", "google_vertex_ai"]:
        # Vertex AI setup
        adc_path = os.path.expanduser("~/.config/gcloud/application_default_credentials.json")
        if os.path.exists(adc_path) and not os.getenv("GOOGLE_APPLICATION_CREDENTIALS"):
            os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = adc_path
            logger.info(f"Set GOOGLE_APPLICATION_CREDENTIALS to {adc_path}")
        
        project_id = os.getenv("VERTEX_PROJECT_ID") or os.getenv("GOOGLE_CLOUD_PROJECT")
        if project_id:
            os.environ["VERTEX_PROJECT"] = project_id
            logger.info(f"Set VERTEX_PROJECT to {project_id}")
        else:
            logger.warning("VERTEX_PROJECT_ID not set for Vertex AI")
            
        location = os.getenv("VERTEX_LOCATION") or os.getenv("GOOGLE_CLOUD_LOCATION", "us-central1")
        os.environ["VERTEX_LOCATION"] = location
        logger.info(f"Set VERTEX_LOCATION to {location}")
        
    elif provider in ["google_ai_studio", "gemini"]:
        # Google AI Studio setup
        api_key = os.getenv("GOOGLE_AI_STUDIO_API_KEY") or os.getenv("GEMINI_API_KEY")
        if api_key:
            os.environ["GOOGLE_API_KEY"] = api_key
        else:
            logger.warning("No API key found for Google AI Studio")
            
    elif provider == "openai":
        # OpenAI setup
        api_key = os.getenv("OPENAI_API_KEY")
        if not api_key:
            logger.warning("OPENAI_API_KEY not set")
            
    elif provider == "anthropic":
        # Anthropic setup
        api_key = os.getenv("ANTHROPIC_API_KEY")
        if not api_key:
            logger.warning("ANTHROPIC_API_KEY not set")

# Set up provider environment on import
setup_provider_environment()

# Enhanced model mapping with latest models
MODEL_MAPPING = {
    # Google AI Studio / Gemini models
    "gemini-2.0-flash": "gemini/gemini-2.0-flash",
    "gemini-2.0-flash-exp": "gemini/gemini-2.0-flash-exp",
    "gemini-1.5-flash": "gemini/gemini-1.5-flash",
    "gemini-1.5-flash-8b": "gemini/gemini-1.5-flash-8b",
    "gemini-1.5-pro": "gemini/gemini-1.5-pro",
    "gemini-pro": "gemini/gemini-pro",
    "gemini-pro-vision": "gemini/gemini-pro-vision",
    
    # Vertex AI models (matching ADK configuration)
    "gemini-2.0-flash-001": "vertex_ai/gemini-2.0-flash-001",
    "gemini-2.0-flash-vertex": "vertex_ai/gemini-2.0-flash-001", 
    "gemini-1.5-flash-vertex": "vertex_ai/gemini-1.5-flash",
    "gemini-1.5-pro-vertex": "vertex_ai/gemini-1.5-pro",
    "gemini-pro-vertex": "vertex_ai/gemini-pro",
    
    # OpenAI models
    "gpt-4o": "openai/gpt-4o",
    "gpt-4o-mini": "openai/gpt-4o-mini",
    "gpt-4-turbo": "openai/gpt-4-turbo",
    "gpt-4": "openai/gpt-4",
    "gpt-3.5-turbo": "openai/gpt-3.5-turbo",
    "o1": "openai/o1",
    "o1-mini": "openai/o1-mini",
    
    # Anthropic models
    "claude-3-5-sonnet": "anthropic/claude-3-5-sonnet-20241022",
    "claude-3-5-haiku": "anthropic/claude-3-5-haiku-20241022",
    "claude-3-opus": "anthropic/claude-3-opus-20240229",
    "claude-3-sonnet": "anthropic/claude-3-sonnet-20240229",
    "claude-3-haiku": "anthropic/claude-3-haiku-20240307",
}

# Default models per provider
DEFAULT_MODELS = {
    "google_ai_studio": "gemini-2.0-flash",
    "gemini": "gemini-2.0-flash",
    "vertex_ai": "gemini-2.0-flash-001",  # Updated to match ADK config
    "google_vertex_ai": "gemini-2.0-flash-001",  # Updated to match ADK config
    "openai": "gpt-4o",
    "anthropic": "claude-3-5-sonnet",
}

def get_default_model() -> str:
    """Get the default model for the current provider."""
    return DEFAULT_MODELS.get(LITELLM_PROVIDER.lower(), "gemini-2.0-flash")

def map_model_name(ollama_model: str) -> str:
    """Map Ollama model name to LiteLLM format."""
    # Direct mapping first
    if ollama_model in MODEL_MAPPING:
        return MODEL_MAPPING[ollama_model]
    
    # Provider-specific fallbacks
    provider = LITELLM_PROVIDER.lower()
    
    if provider in ["google_ai_studio", "gemini"]:
        if "gemini" not in ollama_model:
            return f"gemini/{get_default_model()}"
        return f"gemini/{ollama_model}"
    elif provider in ["vertex_ai", "google_vertex_ai"]:
        if "gemini" not in ollama_model:
            return f"vertex_ai/{get_default_model()}"
        # Handle specific ADK model names
        if ollama_model == "gemini-2.0-flash-001":
            return "vertex_ai/gemini-2.0-flash-001"
        return f"vertex_ai/{ollama_model}"
    elif provider == "openai":
        if "gpt" not in ollama_model.lower() and "o1" not in ollama_model.lower():
            return f"openai/{get_default_model()}"
        return f"openai/{ollama_model}"
    elif provider == "anthropic":
        if "claude" not in ollama_model.lower():
            return f"anthropic/{MODEL_MAPPING[get_default_model()]}"
        return f"anthropic/{ollama_model}"
    
    # Fallback to default model
    return MODEL_MAPPING[get_default_model()]

# Pydantic models for request/response
class ChatMessage(BaseModel):
    role: str
    content: str

class ChatRequest(BaseModel):
    model: str
    messages: List[ChatMessage]
    stream: bool = False
    temperature: Optional[float] = None
    max_tokens: Optional[int] = None
    top_p: Optional[float] = None

class GenerateRequest(BaseModel):
    model: str
    prompt: str
    stream: bool = False
    temperature: Optional[float] = None
    max_tokens: Optional[int] = None

class ModelInfo(BaseModel):
    name: str
    size: Optional[int] = None
    digest: Optional[str] = None
    details: Optional[Dict[str, Any]] = None

class ModelListResponse(BaseModel):
    models: List[ModelInfo]

# Global FastAPI app
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan management."""
    # Startup
    logger.info(f"Starting LiteLLM Ollama Proxy on {PROXY_HOST}:{PROXY_PORT}")
    logger.info(f"Provider: {LITELLM_PROVIDER}")
    logger.info(f"Default model: {get_default_model()}")
    
    # Set LiteLLM configuration
    litellm.drop_params = True
    litellm.set_verbose = False
    
    yield
    
    # Shutdown
    logger.info("Shutting down LiteLLM Ollama Proxy")

app = FastAPI(title="LiteLLM Ollama Proxy", lifespan=lifespan)

@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "provider": LITELLM_PROVIDER,
        "default_model": get_default_model(),
        "timestamp": datetime.now().isoformat()
    }

@app.get("/api/tags")
async def get_models():
    """Get available models (Ollama-compatible endpoint)."""
    try:
        # Return available models based on current provider
        provider = LITELLM_PROVIDER.lower()
        available_models = []
        
        if provider in ["google_ai_studio", "gemini"]:
            models = ["gemini-2.0-flash", "gemini-2.0-flash-exp", "gemini-1.5-flash", 
                     "gemini-1.5-flash-8b", "gemini-1.5-pro", "gemini-pro"]
        elif provider in ["vertex_ai", "google_vertex_ai"]:
            models = ["gemini-2.0-flash-001", "gemini-2.0-flash-vertex", "gemini-1.5-flash-vertex", 
                     "gemini-1.5-pro-vertex", "gemini-pro-vertex"]
        elif provider == "openai":
            models = ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "gpt-4", "gpt-3.5-turbo", "o1", "o1-mini"]
        elif provider == "anthropic":
            models = ["claude-3-5-sonnet", "claude-3-5-haiku", "claude-3-opus", "claude-3-sonnet", "claude-3-haiku"]
        else:
            models = list(MODEL_MAPPING.keys())
        
        for model in models:
            available_models.append({
                "name": model,
                "size": 0,
                "digest": f"sha256:{model.replace('-', '')}",
                "details": {
                    "provider": provider,
                    "litellm_model": map_model_name(model)
                }
            })
        
        return {"models": available_models}
    
    except Exception as e:
        logger.error(f"Error getting models: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error getting models: {str(e)}")

@app.post("/api/chat")
async def chat_completion(request: ChatRequest):
    """Chat completion endpoint (Ollama-compatible)."""
    try:
        litellm_model = map_model_name(request.model)
        
        # Convert messages to LiteLLM format
        messages = [{"role": msg.role, "content": msg.content} for msg in request.messages]
        
        # Prepare arguments for LiteLLM
        kwargs = {
            "model": litellm_model,
            "messages": messages,
            "stream": request.stream,
        }
        
        # Add optional parameters
        if request.temperature is not None:
            kwargs["temperature"] = request.temperature
        if request.max_tokens is not None:
            kwargs["max_tokens"] = request.max_tokens
        if request.top_p is not None:
            kwargs["top_p"] = request.top_p
        
        if request.stream:
            return StreamingResponse(
                stream_chat_response(kwargs),
                media_type="application/x-ndjson"
            )
        else:
            response = await litellm.acompletion(**kwargs)
            
            # Convert to Ollama format
            ollama_response = {
                "model": request.model,
                "created_at": datetime.now().isoformat(),
                "message": {
                    "role": response.choices[0].message.role,
                    "content": response.choices[0].message.content
                },
                "done": True
            }
            
            return ollama_response
            
    except Exception as e:
        logger.error(f"Error in chat completion: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Chat completion error: {str(e)}")

async def stream_chat_response(kwargs: Dict[str, Any]) -> AsyncGenerator[str, None]:
    """Stream chat completion responses."""
    try:
        response = await litellm.acompletion(**kwargs)
        
        async for chunk in response:
            if chunk.choices and chunk.choices[0].delta:
                delta = chunk.choices[0].delta
                if hasattr(delta, 'content') and delta.content:
                    ollama_chunk = {
                        "model": kwargs.get("model", "").split("/")[-1],
                        "created_at": datetime.now().isoformat(),
                        "message": {
                            "role": "assistant",
                            "content": delta.content
                        },
                        "done": False
                    }
                    yield f"data: {json.dumps(ollama_chunk)}\n\n"
        
        # Send final chunk
        final_chunk = {
            "model": kwargs.get("model", "").split("/")[-1],
            "created_at": datetime.now().isoformat(),
            "message": {
                "role": "assistant",
                "content": ""
            },
            "done": True
        }
        yield f"data: {json.dumps(final_chunk)}\n\n"
        
    except Exception as e:
        logger.error(f"Error in streaming: {str(e)}")
        error_chunk = {
            "error": str(e),
            "done": True
        }
        yield f"data: {json.dumps(error_chunk)}\n\n"

@app.post("/api/generate")
async def generate_completion(request: GenerateRequest):
    """Generate completion endpoint (Ollama-compatible)."""
    try:
        litellm_model = map_model_name(request.model)
        
        # Convert prompt to messages format
        messages = [{"role": "user", "content": request.prompt}]
        
        # Prepare arguments for LiteLLM
        kwargs = {
            "model": litellm_model,
            "messages": messages,
            "stream": request.stream,
        }
        
        # Add optional parameters
        if request.temperature is not None:
            kwargs["temperature"] = request.temperature
        if request.max_tokens is not None:
            kwargs["max_tokens"] = request.max_tokens
        
        if request.stream:
            return StreamingResponse(
                stream_generate_response(kwargs),
                media_type="application/x-ndjson"
            )
        else:
            response = await litellm.acompletion(**kwargs)
            
            # Convert to Ollama format
            ollama_response = {
                "model": request.model,
                "created_at": datetime.now().isoformat(),
                "response": response.choices[0].message.content,
                "done": True
            }
            
            return ollama_response
            
    except Exception as e:
        logger.error(f"Error in generate completion: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Generate completion error: {str(e)}")

async def stream_generate_response(kwargs: Dict[str, Any]) -> AsyncGenerator[str, None]:
    """Stream generate completion responses."""
    try:
        response = await litellm.acompletion(**kwargs)
        
        async for chunk in response:
            if chunk.choices and chunk.choices[0].delta:
                delta = chunk.choices[0].delta
                if hasattr(delta, 'content') and delta.content:
                    ollama_chunk = {
                        "model": kwargs.get("model", "").split("/")[-1],
                        "created_at": datetime.now().isoformat(),
                        "response": delta.content,
                        "done": False
                    }
                    yield f"data: {json.dumps(ollama_chunk)}\n\n"
        
        # Send final chunk
        final_chunk = {
            "model": kwargs.get("model", "").split("/")[-1],
            "created_at": datetime.now().isoformat(),
            "response": "",
            "done": True
        }
        yield f"data: {json.dumps(final_chunk)}\n\n"
        
    except Exception as e:
        logger.error(f"Error in streaming: {str(e)}")
        error_chunk = {
            "error": str(e),
            "done": True
        }
        yield f"data: {json.dumps(error_chunk)}\n\n"

@app.post("/api/pull")
async def pull_model(request: Request):
    """Pull model endpoint (Ollama-compatible) - simulated for compatibility."""
    try:
        body = await request.json()
        model_name = body.get("name", "")
        
        # Simulate pulling by validating the model exists
        if model_name in MODEL_MAPPING or any(model_name in models for models in [
            ["gemini-2.0-flash", "gemini-1.5-flash", "gemini-1.5-pro"],
            ["gpt-4o", "gpt-4", "gpt-3.5-turbo"],
            ["claude-3-5-sonnet", "claude-3-haiku"]
        ]):
            return {
                "status": "success",
                "message": f"Model {model_name} is available"
            }
        else:
            raise HTTPException(status_code=404, detail=f"Model {model_name} not found")
            
    except Exception as e:
        logger.error(f"Error pulling model: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Pull model error: {str(e)}")

@app.delete("/api/delete")
async def delete_model(request: Request):
    """Delete model endpoint (Ollama-compatible) - simulated for compatibility."""
    try:
        body = await request.json()
        model_name = body.get("name", "")
        
        # Simulate deletion (no-op for cloud models)
        return {
            "status": "success",
            "message": f"Model {model_name} deletion simulated (cloud models cannot be deleted)"
        }
        
    except Exception as e:
        logger.error(f"Error deleting model: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Delete model error: {str(e)}")

if __name__ == "__main__":
    uvicorn.run(
        "ollama_proxy:app",
        host=PROXY_HOST,
        port=PROXY_PORT,
        reload=False,
        log_level="info"
    )
