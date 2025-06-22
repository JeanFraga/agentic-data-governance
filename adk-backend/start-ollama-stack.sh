#!/bin/bash

# Ollama ADK OpenWebUI Startup Script
# This script starts the complete stack: ADK Backend + Ollama Proxy + OpenWebUI

set -e

echo "🚀 Starting Ollama ADK OpenWebUI Stack..."

# Function to check if a service is running
check_service() {
    local url=$1
    local name=$2
    local max_attempts=30
    local attempt=1
    
    echo "⏳ Waiting for $name to start..."
    while [ $attempt -le $max_attempts ]; do
        if curl -s "$url" > /dev/null 2>&1; then
            echo "✅ $name is running"
            return 0
        fi
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo "❌ $name failed to start after $max_attempts attempts"
    return 1
}

# Function to stop all services
cleanup() {
    echo "🛑 Stopping all services..."
    docker-compose -f docker-compose.openwebui.yml down
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

echo "📦 Building and starting all services..."
docker-compose -f docker-compose.openwebui.yml up --build -d

echo "🔍 Checking service health..."

# Check ADK Backend
if check_service "http://localhost:8000" "ADK Backend"; then
    echo "   ADK Backend: http://localhost:8000"
else
    echo "❌ ADK Backend failed to start"
    cleanup
fi

# Check Ollama Proxy
if check_service "http://localhost:11434/health" "Ollama Proxy"; then
    echo "   Ollama Proxy: http://localhost:11434"
    echo "   Available models: http://localhost:11434/api/tags"
else
    echo "❌ Ollama Proxy failed to start"
    cleanup
fi

# Check OpenWebUI
if check_service "http://localhost:3000" "OpenWebUI"; then
    echo "   OpenWebUI: http://localhost:3000"
else
    echo "❌ OpenWebUI failed to start"
    cleanup
fi

echo ""
echo "🎉 All services are running successfully!"
echo ""
echo "📋 Service URLs:"
echo "   • OpenWebUI (Main Interface): http://localhost:3000"
echo "   • Ollama Proxy (API): http://localhost:11434"
echo "   • ADK Backend: http://localhost:8000"
echo ""
echo "🔧 To check logs:"
echo "   docker-compose -f docker-compose.openwebui.yml logs -f [service_name]"
echo ""
echo "🛑 To stop all services:"
echo "   docker-compose -f docker-compose.openwebui.yml down"
echo ""
echo "💡 In OpenWebUI:"
echo "   1. Go to Settings → Models"
echo "   2. The 'adk-agent:latest' model should be available"
echo "   3. Start chatting with your ADK agent!"
echo ""
echo "Press Ctrl+C to stop all services..."

# Keep script running
while true; do
    sleep 10
    # Optional: Add health checks here
done
