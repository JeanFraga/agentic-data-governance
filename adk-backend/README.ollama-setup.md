# Ollama ADK Proxy for OpenWebUI

This setup provides a translation layer between OpenWebUI and the ADK (Agent Development Kit) backend using an Ollama-compatible proxy service.

## Architecture

```
OpenWebUI ←→ Ollama Proxy ←→ ADK Backend
   :3000        :11434          :8000
```

- **OpenWebUI** (Port 3000): Modern web interface for AI interactions
- **Ollama Proxy** (Port 11434): Translation layer that converts Ollama API calls to ADK format
- **ADK Backend** (Port 8000): Your existing ADK agent service

## Quick Start

### Option 1: One-Click Startup (Recommended)

```bash
./start-ollama-stack.sh
```

This script will:
- Build and start all services (ADK Backend + Ollama Proxy + OpenWebUI)
- Check health of all services
- Display service URLs and instructions
- Keep running until you press Ctrl+C

### Option 2: Manual Docker Compose

1. **Start all services:**
   ```bash
   docker-compose -f docker-compose.openwebui.yml up -d
   ```

2. **Access OpenWebUI:**
   Open your browser to `http://localhost:3000`

3. **Configure the model in OpenWebUI:**
   - Go to Settings → Models
   - The `adk-agent:latest` model should be automatically available
   - Start chatting with your ADK agent through the OpenWebUI interface

## Service Details

### Ollama Proxy Service

The Ollama proxy (`ollama_proxy.py`) acts as a translation layer that:

- Receives OpenAI-compatible requests from OpenWebUI via the Ollama API
- Translates them to your ADK backend format
- Forwards requests to the ADK service
- Translates ADK responses back to Ollama format
- Returns responses to OpenWebUI

**Key Features:**
- Full Ollama API compatibility
- Streaming and non-streaming responses
- Health checks and error handling
- Configurable ADK backend URL

### Configuration

Edit `.env.ollama-proxy` to customize the proxy behavior:

```env
ADK_BACKEND_URL=http://adk-backend:8000
PROXY_PORT=11434
LOG_LEVEL=INFO
DEFAULT_MODEL=adk-agent
MODEL_TEMPERATURE=0.7
REQUEST_TIMEOUT=30
ENABLE_STREAMING=true
```

## Manual Setup (Alternative)

If you prefer to run services separately:

1. **Start ADK Backend:**
   ```bash
   docker-compose up adk-backend -d
   ```

2. **Start Ollama Proxy:**
   ```bash
   docker build -f Dockerfile.ollama-proxy -t ollama-proxy .
   docker run -d --name ollama-proxy --network adk-backend_adk-network \
     -p 11434:11434 \
     -e ADK_BACKEND_URL=http://adk-backend:8000 \
     ollama-proxy
   ```

3. **Start OpenWebUI:**
   ```bash
   docker run -d --name openwebui --network adk-backend_adk-network \
     -p 3000:8080 \
     -e OLLAMA_BASE_URL=http://ollama-proxy:11434 \
     -v openwebui-data:/app/backend/data \
     ghcr.io/open-webui/open-webui:main
   ```

## Customizing the ADK Integration

The proxy service needs to be adapted to your specific ADK API format. Key areas to modify in `ollama_proxy.py`:

### 1. Request Translation (`translate_ollama_to_adk`)

Update this method to match your ADK API's expected input format:

```python
def translate_ollama_to_adk(self, ollama_request: Dict[str, Any]) -> Dict[str, Any]:
    # Modify this based on your ADK API structure
    messages = ollama_request.get("messages", [])
    user_message = messages[-1].get("content", "") if messages else ""
    
    return {
        "query": user_message,  # Adjust field names
        "context": messages[:-1],  # Adjust format
        "parameters": {
            "temperature": ollama_request.get("temperature", 0.7)
        }
    }
```

### 2. Response Translation (`translate_adk_to_ollama`)

Update this method to handle your ADK API's response format:

```python
def translate_adk_to_ollama(self, adk_response: Dict[str, Any], model: str) -> Dict[str, Any]:
    # Adjust based on your ADK response structure
    content = adk_response.get("answer", "")  # Change field name as needed
    
    return {
        "model": model,
        "created_at": "2023-08-04T08:52:19.385406455-07:00",
        "message": {
            "role": "assistant",
            "content": content
        },
        "done": True
    }
```

### 3. ADK Endpoint (`forward_to_adk`)

Update the endpoint URL to match your ADK API:

```python
async with session.post(
    f"{self.adk_url}/your-adk-endpoint",  # Change this
    json=adk_request,
    headers={"Content-Type": "application/json"}
) as response:
```

## Troubleshooting

### Check Service Health

```bash
# Check all services
docker-compose -f docker-compose.openwebui.yml ps

# Check logs
docker-compose -f docker-compose.openwebui.yml logs ollama-proxy
docker-compose -f docker-compose.openwebui.yml logs adk-backend
docker-compose -f docker-compose.openwebui.yml logs openwebui
```

### Test Individual Services

```bash
# Test ADK Backend
curl http://localhost:8000/health

# Test Ollama Proxy
curl http://localhost:11434/health
curl http://localhost:11434/api/tags

# Test OpenWebUI
curl http://localhost:3000
```

### Common Issues

1. **"Model not found" in OpenWebUI:**
   - Check that the Ollama proxy is running and accessible
   - Verify the `OLLAMA_BASE_URL` in OpenWebUI configuration

2. **ADK Backend connection errors:**
   - Ensure ADK backend is running and healthy
   - Check the `ADK_BACKEND_URL` in proxy configuration
   - Verify network connectivity between services

3. **Authentication issues:**
   - Make sure Google Cloud credentials are properly mounted
   - Check the ADK backend logs for authentication errors

## Stopping Services

```bash
docker-compose -f docker-compose.openwebui.yml down
```

To also remove volumes:
```bash
docker-compose -f docker-compose.openwebui.yml down -v
```

## Next Steps

1. Customize the proxy translation logic for your specific ADK API
2. Add authentication and security measures for production use
3. Configure proper logging and monitoring
4. Set up SSL/TLS for secure connections
5. Implement rate limiting and error handling as needed
