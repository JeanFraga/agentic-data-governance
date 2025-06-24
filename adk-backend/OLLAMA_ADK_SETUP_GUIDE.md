# Ollama + ADK Data Science Agent Setup Guide

## Overview
This guide shows how to properly configure the Ollama model to communicate with the ADK data science agent running via `poetry run adk api_server`.

## Architecture
```
User Request → ADK API Server → Data Science Agent → Ollama Proxy → Google AI Studio (Gemini)
```

## Prerequisites

1. **Google AI Studio API Key**: Required for the Ollama proxy to communicate with Gemini models
   - Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
   - Create a new API key
   - Save it for use in the environment setup

2. **Poetry Environment**: Ensure dependencies are installed
   ```bash
   poetry install
   ```

## Environment Setup

### 1. Create `.env` file
Create a `.env` file in the `adk-backend` directory:

```bash
# Copy the example and edit it
cp .env.example .env
```

### 2. Configure `.env` file
Edit the `.env` file with your settings:

```bash
# Google AI Studio API Key (REQUIRED for Ollama proxy)
GOOGLE_API_KEY=your_google_ai_studio_api_key_here

# Choose Model Backend: 0 -> Google AI Studio, 1 -> Vertex AI  
GOOGLE_GENAI_USE_VERTEXAI=0

# BigQuery Configuration (if using BQ agent)
BQ_PROJECT_ID=your_gcp_project_id
BQ_DATASET_ID=your_dataset_id

# Google Cloud Project (if using Vertex AI)
GOOGLE_CLOUD_PROJECT=your_gcp_project_id
GOOGLE_CLOUD_LOCATION=us-central1

# ADK Configuration for Ollama Integration
LITELLM_PROXY_API_BASE=http://localhost:11434
ROOT_AGENT_MODEL=gemini-2.0-flash
LITELLM_API_BASE=http://localhost:11434

# Ollama Proxy Configuration
LITELLM_PROVIDER=google_ai_studio
GOOGLE_AI_STUDIO_API_KEY=your_google_ai_studio_api_key_here
PROXY_HOST=0.0.0.0
PROXY_PORT=11434
```

### 3. Source the environment
```bash
source .env
```

## Running the Integration

### Method 1: Automated Integration Test
Use the provided runner script that starts everything automatically:

```bash
poetry run python run_ollama_adk_integration.py
```

This script will:
1. Start the Ollama proxy on port 11434
2. Start the ADK API server on port 8001  
3. Run comprehensive integration tests
4. Clean up all processes when done

### Method 2: Manual Step-by-Step

#### Step 1: Start Ollama Proxy
```bash
poetry run python ollama_proxy.py
```

#### Step 2: Start ADK API Server (in another terminal)
```bash
cd adk-backend
source .env  # Load environment variables
poetry run adk api_server --host localhost --port 8001
```

#### Step 3: Test the Integration
```bash
poetry run python test_ollama_adk_integration.py
```

## Verification

### 1. Check Ollama Proxy Health
```bash
curl http://localhost:11434/health
```

Expected response:
```json
{
  "status": "healthy",
  "provider": "google_ai_studio", 
  "default_model": "gemini-2.0-flash",
  "timestamp": "2025-06-22T..."
}
```

### 2. Check ADK API Server Health
```bash
curl http://localhost:8001/health
```

Expected response:
```json
{
  "status": "healthy",
  "apps": ["data_science_agent", "deployment", "eval", "tests"]
}
```

### 3. Test Available Models
```bash
curl http://localhost:11434/api/tags
```

Should return available Gemini models.

### 4. Test ADK Data Science Agent
```bash
curl -X POST http://localhost:8001/sessions \
  -H "Content-Type: application/json" \
  -d '{"app_name": "data_science_agent", "user_id": "test_user"}'
```

Then send a message to the created session.

## Key Configuration Points

### 1. ADK Agent Model Routing
The ADK agent uses these environment variables to route requests through Ollama:
- `LITELLM_PROXY_API_BASE=http://localhost:11434` - Points ADK to use Ollama proxy
- `ROOT_AGENT_MODEL=gemini-2.0-flash` - Specifies the model to use
- `LITELLM_API_BASE=http://localhost:11434` - Alternative routing configuration

### 2. Ollama Proxy Configuration
The Ollama proxy needs:
- `GOOGLE_API_KEY` or `GOOGLE_AI_STUDIO_API_KEY` - For Google AI Studio access
- `LITELLM_PROVIDER=google_ai_studio` - Provider selection
- Port 11434 (default Ollama port for compatibility)

### 3. ADK Data Science Agent
The data science agent is configured in:
- `data_science_agent/agent.py` - Core agent logic
- Uses the `ROOT_AGENT_MODEL` environment variable for model selection
- Routes through `LITELLM_PROXY_API_BASE` when configured

## Troubleshooting

### Common Issues

1. **"API key not valid"**
   - Ensure `GOOGLE_API_KEY` is set in `.env`
   - Verify the API key is valid in Google AI Studio
   - Check that environment variables are loaded (`source .env`)

2. **"Address already in use"**
   - Kill existing processes on ports 11434 or 8001
   - Use: `lsof -ti:11434 | xargs kill -9`

3. **"Session already exists"**
   - This is normal in tests - sessions persist across requests
   - Use unique session IDs or create new sessions

4. **"No events in ADK response"**
   - Check that ADK agent is properly configured with Ollama proxy
   - Verify environment variables are loaded in ADK process
   - Check ADK agent logs for routing issues

### Debug Commands

```bash
# Check running processes
ps aux | grep -E "(ollama_proxy|adk)"

# Check port usage
lsof -i :11434
lsof -i :8001

# Test environment variables
echo $GOOGLE_API_KEY
echo $LITELLM_PROXY_API_BASE
echo $ROOT_AGENT_MODEL
```

## Success Indicators

When properly configured, you should see:

1. ✅ Ollama proxy starts without API key warnings
2. ✅ ADK API server connects to Ollama proxy 
3. ✅ Test queries return actual model responses
4. ✅ ADK session events contain model-generated content
5. ✅ Integration test passes with >90% success rate

The data science agent should now be successfully routing requests through the Ollama proxy to Google's Gemini models.
