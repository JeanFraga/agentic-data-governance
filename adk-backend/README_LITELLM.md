# LiteLLM Ollama Proxy Integration

This document describes the enhanced LiteLLM-based Ollama proxy that enables seamless integration between OpenWebUI and various cloud LLM providers, bypassing ADK extension permission issues.

## 🚀 Overview

The LiteLLM Ollama Proxy provides:

- **Ollama-compatible API** that works with OpenWebUI
- **Multiple LLM provider support** (Google Gemini, OpenAI, Anthropic, etc.)
- **Latest model support** including Gemini 2.0 Flash (2x faster than 1.5)
- **Streaming responses** for real-time chat
- **Automatic model mapping** from Ollama names to cloud models
- **Robust error handling** and logging

## 🏗️ Architecture

```
OpenWebUI → Ollama API (port 11434) → LiteLLM Proxy → Cloud LLM Providers
                                                    ↳ Vertex AI (Gemini)
                                                    ↳ Google AI Studio
                                                    ↳ OpenAI (GPT-4, etc.)
                                                    ↳ Anthropic (Claude)
```

## 📦 What's Included

### Enhanced Files
- `ollama_proxy.py` - Complete LiteLLM-based proxy implementation
- `Dockerfile.ollama-proxy` - Container setup with LiteLLM
- `docker-compose.openwebui.yml` - Full stack deployment config
- `test_litellm_proxy.py` - Test suite for proxy functionality

### Latest Model Support
- **Gemini 2.0 Flash Experimental** (Default - 2x faster than 1.5)
- **Gemini 1.5 Pro** (Most capable)
- **Gemini 1.5 Flash** (Fast and efficient)
- **OpenAI GPT-4o, GPT-4, GPT-3.5-turbo** (If API key provided)
- **Anthropic Claude** (If API key provided)

## 🛠️ Setup Instructions

### Option 1: Using Vertex AI (Recommended for GCP)

1. **Authenticate with Google Cloud**:
   ```bash
   gcloud auth application-default login
   ```

2. **Set environment variables**:
   ```bash
   export GOOGLE_CLOUD_PROJECT="your-project-id"
   export GOOGLE_GENAI_USE_VERTEXAI="TRUE"
   export VERTEXAI_LOCATION="us-central1"  # Optional, defaults to us-central1
   ```

3. **Start the services**:
   ```bash
   cd adk-backend
   docker-compose -f docker-compose.openwebui.yml up -d
   ```

### Option 2: Using Google AI Studio API Key

1. **Get your API key** from [Google AI Studio](https://aistudio.google.com/)

2. **Set environment variables**:
   ```bash
   export GOOGLE_AI_STUDIO_API_KEY="your-api-key"
   # OR
   export GEMINI_API_KEY="your-api-key"
   ```

3. **Update docker-compose.openwebui.yml**:
   Uncomment the Google AI Studio API key lines and comment out Vertex AI lines.

4. **Start the services**:
   ```bash
   cd adk-backend
   docker-compose -f docker-compose.openwebui.yml up -d
   ```

### Option 3: Using OpenAI

1. **Get your OpenAI API key**

2. **Set environment variables**:
   ```bash
   export OPENAI_API_KEY="your-api-key"
   ```

3. **Update docker-compose.openwebui.yml**:
   Uncomment the OpenAI API key line and set DEFAULT_MODEL to an OpenAI model.

4. **Start the services**:
   ```bash
   cd adk-backend
   docker-compose -f docker-compose.openwebui.yml up -d
   ```

## 🔧 Configuration Options

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DEFAULT_MODEL` | Default LLM model to use | `gemini-2.0-flash-exp` |
| `PROXY_PORT` | Port for Ollama proxy | `11434` |
| `LOG_LEVEL` | Logging level (DEBUG/INFO/WARNING) | `INFO` |
| `GOOGLE_GENAI_USE_VERTEXAI` | Use Vertex AI authentication | `TRUE` |
| `VERTEXAI_PROJECT` | GCP project ID for Vertex AI | - |
| `VERTEXAI_LOCATION` | GCP region for Vertex AI | `us-central1` |
| `GEMINI_API_KEY` | Google AI Studio API key | - |
| `OPENAI_API_KEY` | OpenAI API key | - |
| `ANTHROPIC_API_KEY` | Anthropic API key | - |

### Model Mapping

The proxy automatically maps common Ollama model names to cloud models:

| Ollama Model | Mapped To | Provider |
|--------------|-----------|----------|
| `adk-agent:latest` | `gemini-2.0-flash-exp` | Google |
| `llama3.1` | `gemini-2.0-flash-exp` | Google |
| `llama3` | `gemini-2.0-flash-exp` | Google |
| `gpt-4` | `gpt-4-turbo` | OpenAI |
| `gemini-2.0-flash` | `gemini-2.0-flash-exp` | Google |

## 🧪 Testing

### Test the Proxy
```bash
cd adk-backend
python test_litellm_proxy.py
```

### Manual API Testing
```bash
# Health check
curl http://localhost:11434/health

# List models
curl http://localhost:11434/api/tags

# Chat completion
curl -X POST http://localhost:11434/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "adk-agent:latest",
    "messages": [{"role": "user", "content": "Hello!"}],
    "stream": false
  }'
```

## 📊 Usage with OpenWebUI

1. **Access OpenWebUI**: http://localhost:3000
2. **Configure Ollama endpoint**: Should auto-detect `http://localhost:11434`
3. **Select model**: Choose from available models (adk-agent:latest, gemini-2.0-flash, etc.)
4. **Start chatting**: Enjoy seamless cloud LLM access through Ollama API!

## 🔍 Monitoring & Logs

### View Proxy Logs
```bash
docker logs ollama-proxy -f
```

### Health Status
Check the health endpoint for provider status:
```bash
curl http://localhost:11434/health | jq
```

## 🐛 Troubleshooting

### Common Issues

1. **Authentication Failed**
   - Verify your API keys or Google Cloud authentication
   - Check `docker logs ollama-proxy` for specific auth errors

2. **Model Not Found**
   - Ensure the model name is in the mapping table
   - Check available models: `curl http://localhost:11434/api/tags`

3. **Rate Limiting**
   - Verify your API usage limits
   - Consider using different providers or models

4. **Connection Errors**
   - Ensure all containers are running: `docker ps`
   - Check network connectivity: `docker network ls`

### Debug Mode
Enable detailed logging:
```bash
# Set LOG_LEVEL=DEBUG in docker-compose.openwebui.yml
docker-compose -f docker-compose.openwebui.yml up -d ollama-proxy
```

## 🚀 Advanced Features

### Custom Model Mapping
Modify `MODEL_MAPPING` in `ollama_proxy.py` to add custom model mappings.

### Multi-Provider Fallback
The proxy automatically detects available providers and falls back appropriately.

### Streaming Support
All endpoints support streaming for real-time responses in OpenWebUI.

## 📝 Contributing

To enhance the proxy:

1. **Add new providers**: Update `setup_litellm()` and `get_provider_model()`
2. **Add new models**: Update `MODEL_MAPPING` and model info in `/api/tags`
3. **Improve error handling**: Enhance exception handling in completion methods

## 🔗 Resources

- [LiteLLM Documentation](https://docs.litellm.ai/)
- [OpenWebUI Documentation](https://docs.openwebui.com/)
- [Google AI Studio](https://aistudio.google.com/)
- [Vertex AI](https://cloud.google.com/vertex-ai)

---

**Need help?** Check the logs, review the configuration, and ensure your API keys are properly set!
