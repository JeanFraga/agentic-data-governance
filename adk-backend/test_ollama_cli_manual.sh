#!/bin/bash
# Manual Ollama CLI Testing Script
# This script demonstrates how to interact with the Ollama API using CLI tools

set -e

echo "🧪 Manual Ollama CLI Testing Script"
echo "=================================="

# Check if Docker Compose is running
if ! docker ps | grep -q "ollama-proxy"; then
    echo "❌ Ollama proxy container is not running"
    echo "💡 Start it with: docker-compose -f docker-compose.openwebui.yml up -d"
    exit 1
fi

echo "✅ Ollama proxy container is running"

# Test 1: List available models
echo -e "\n🔍 Test 1: Listing available models..."
echo "Command: curl -s http://localhost:11434/api/tags | jq '.models[].name'"
curl -s http://localhost:11434/api/tags | python3 -c "
import sys, json
data = json.load(sys.stdin)
models = data.get('models', [])
print(f'Available models ({len(models)}):')
for model in models:
    print(f'  • {model.get(\"name\", \"Unknown\")}')
"

# Test 2: Test model info
echo -e "\n🔍 Test 2: Getting model info..."
echo "Command: curl -s http://localhost:11434/api/show -d '{\"name\":\"gemini-2.0-flash-exp\"}'"
MODEL_INFO=$(curl -s http://localhost:11434/api/show -H "Content-Type: application/json" -d '{"name":"gemini-2.0-flash-exp"}')
echo "Model info response:"
echo "$MODEL_INFO" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(f'Model: {data.get(\"details\", {}).get(\"family\", \"N/A\")}')
    print(f'Format: {data.get(\"details\", {}).get(\"format\", \"N/A\")}')
except:
    print('Response received (may not be JSON)')
"

# Test 3: Simple generation test (will likely fail without credentials)
echo -e "\n🔍 Test 3: Testing simple generation (may fail without API keys)..."
echo "Command: curl -s http://localhost:11434/api/generate -d '{\"model\":\"gemini-2.0-flash-exp\",\"prompt\":\"Say hello\",\"stream\":false}'"
GENERATE_RESPONSE=$(curl -s http://localhost:11434/api/generate -H "Content-Type: application/json" -d '{"model":"gemini-2.0-flash-exp","prompt":"Say hello","stream":false}')
echo "Generation response:"
echo "$GENERATE_RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if 'response' in data:
        print(f'✅ Generated: {data[\"response\"][:100]}...')
    elif 'detail' in data:
        print(f'⚠️ Error (expected): {data[\"detail\"][:100]}...')
    else:
        print('Response received')
except Exception as e:
    print(f'Raw response: {sys.stdin.read()[:200]}...')
"

# Test 4: Test using docker exec
echo -e "\n🔍 Test 4: Testing commands inside container..."
echo "Command: docker exec ollama-proxy python -c \"import urllib.request, json; ...\""
docker exec ollama-proxy python -c "
import urllib.request
import json
try:
    response = urllib.request.urlopen('http://localhost:11434/api/tags')
    data = json.loads(response.read())
    models = data.get('models', [])
    print(f'✅ Container can access API - {len(models)} models available')
    for model in models[:3]:
        print(f'  • {model.get(\"name\", \"Unknown\")}')
except Exception as e:
    print(f'❌ Container API test failed: {e}')
"

# Test 5: Check service health
echo -e "\n🔍 Test 5: Checking service health..."
echo "Command: curl -s http://localhost:11434/health"
HEALTH_RESPONSE=$(curl -s http://localhost:11434/health)
echo "Health response: $HEALTH_RESPONSE"

# Test 6: Check ADK backend integration
echo -e "\n🔍 Test 6: Testing ADK backend integration..."
echo "Command: curl -s http://localhost:8000/list-apps"
ADK_RESPONSE=$(curl -s http://localhost:8000/list-apps)
echo "ADK apps: $ADK_RESPONSE"

echo -e "\n✅ Manual testing complete!"
echo -e "\n📋 Service URLs:"
echo "   • ADK Backend: http://localhost:8000/docs"
echo "   • Ollama Proxy: http://localhost:11434"
echo "   • OpenWebUI: http://localhost:3000"
echo -e "\n💡 Tips:"
echo "   • Use 'docker-compose -f docker-compose.openwebui.yml logs -f' to see live logs"
echo "   • Use 'docker exec -it ollama-proxy /bin/bash' to access container shell"
echo "   • Check docker-compose.openwebui.yml for service configuration"
