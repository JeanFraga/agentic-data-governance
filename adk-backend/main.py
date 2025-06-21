# This file creates a FastAPI web server to expose the agent.
import os
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from typing import List, Dict, Any

from google.adk.runtime.fastapi_adapter import get_fast_api_app
from google.adk.runtime.runner import Runner
from google.adk.runtime.sync_runner import run_sync
from google.adk.runtime.event import Event
from google.adk.runtime.message import Message

# This is the crucial OpenAI compatibility bridge.
# Define Pydantic models to match the OpenAI API request structure.
class OpenAIMessage(BaseModel):
    role: str
    content: str

class OpenAIRequest(BaseModel):
    model: str
    messages: List[OpenAIMessage]
    stream: bool = False

# Create the standard ADK FastAPI app.
app = get_fast_api_app(
    agent_path="data_science_agent",
    serve_web_ui=False,  # We only need the API, not the ADK's dev UI.
)

# Define the OpenAI-compatible endpoint.
@app.post("/v1/chat/completions")
async def chat_completions(request: OpenAIRequest):
    # Extract the last user message from the request.
    user_prompt = request.messages[-1].content

    # Use ADK's synchronous runner to execute the agent.
    final_event = run_sync("data_science_agent", user_prompt)

    # Extract the agent's text response from the final event.
    response_text = ""
    if final_event and final_event.is_final_response():
        response_text = final_event.message.parts.text

    # Format the response to match the OpenAI API structure.
    response_payload = {
        "id": "chatcmpl-123", # Dummy ID
        "object": "chat.completion",
        "created": 1677652288, # Dummy timestamp
        "model": request.model,
        "choices": [
            {
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": response_text,
                },
                "finish_reason": "stop",
            }
        ],
        "usage": {
            "prompt_tokens": 0, # Dummy values
            "completion_tokens": 0,
            "total_tokens": 0,
        },
    }
    return JSONResponse(content=response_payload)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)