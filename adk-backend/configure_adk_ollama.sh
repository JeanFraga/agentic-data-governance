#!/bin/bash
"""
Configure ADK Data Science Agent to use Ollama Proxy
This script sets up the environment variables needed to route the ADK agent through our Ollama proxy.
"""

# Ollama Proxy Configuration
export LITELLM_PROXY_API_BASE="http://localhost:11434"
export ROOT_AGENT_MODEL="gemini-2.0-flash"  # Available via our Ollama proxy

# Optional: Set specific API base for LiteLLM models
export LITELLM_API_BASE="http://localhost:11434"

# Print configuration
echo "🔧 ADK Agent Configuration for Ollama Integration"
echo "================================================="
echo "LITELLM_PROXY_API_BASE: $LITELLM_PROXY_API_BASE"
echo "ROOT_AGENT_MODEL: $ROOT_AGENT_MODEL"
echo "LITELLM_API_BASE: $LITELLM_API_BASE"
echo ""
echo "✅ Environment configured for Ollama integration"
echo ""
echo "📋 Next steps:"
echo "1. Source this file: source configure_adk_ollama.sh"
echo "2. Start ADK server: poetry run adk api_server"
echo "3. Run integration test: python test_ollama_adk_integration.py"
