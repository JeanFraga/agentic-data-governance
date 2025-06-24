# ADK + LiteLLM + Open Web UI Integration Guide

This setup provides a complete integration between Google ADK agents, LiteLLM middleware, and Open Web UI for a production-ready AI chat interface.

## Architecture

```
Open Web UI → LiteLLM Proxy → ADK OpenAI Adapter → ADK API Server → Data Science Agent
    :3000         :4000            :8080              :8000
```

## Services

### 1. ADK Backend (Port 8000)
- Runs the Google ADK API server using `poetry run adk api_server`
- Hosts the data science agent with BigQuery integration
- Provides ADK-native API endpoints

### 2. ADK OpenAI Adapter (Port 8080)
- Translates between OpenAI API format and ADK API format
- Makes ADK agents compatible with LiteLLM
- Handles session management and response formatting

### 3. LiteLLM Proxy (Port 4000)
- Acts as middleware between Open Web UI and ADK
- Provides OpenAI-compatible API endpoints
- Manages model routing and request/response translation

### 4. Open Web UI (Port 3000)
- User-facing chat interface
- Connects to LiteLLM proxy as an OpenAI-compatible backend
- Provides a modern web UI for interacting with ADK agents

## Quick Start

1. **Prerequisites**
   ```bash
   # Ensure you have Docker and Docker Compose installed
   docker --version
   docker-compose --version
   
   # Ensure Google Cloud credentials are available
   gcloud auth application-default login
   ```

2. **Start all services**
   ```bash
   docker-compose up --build
   ```

3. **Access the interfaces**
   - **Open Web UI**: http://localhost:3000
   - **LiteLLM Proxy**: http://localhost:4000
   - **ADK OpenAI Adapter**: http://localhost:8080
   - **ADK Backend**: http://localhost:8000

## Configuration

### Available Models

The following models are available in Open Web UI:
- `adk-data-science-agent` - Primary data science agent
- `data-science-agent` - Alternative name for the same agent

## API Documentation

- **LiteLLM API**: http://localhost:4000/docs
- **ADK OpenAI Adapter**: http://localhost:8080/docs
- **Open Web UI**: Built-in interface at http://localhost:3000
