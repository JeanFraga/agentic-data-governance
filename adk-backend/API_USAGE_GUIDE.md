# ADK API Server Usage Guide

This guide documents how to properly interact with the ADK (Agent Development Kit) API server.

## Starting the Server

```bash
# Using poetry (recommended for development)
poetry run adk api_server --host localhost --port 8001

# Or using the entrypoint script
python entrypoint.py
```

## Available Endpoints

The API server provides 19 endpoints for various operations:

### Core Endpoints
- **GET /docs** - OpenAPI documentation (Swagger UI)
- **GET /openapi.json** - OpenAPI specification
- **GET /list-apps** - List available applications

### Session Management
- **GET /apps/{app_name}/users/{user_id}/sessions** - List user sessions
- **POST /apps/{app_name}/users/{user_id}/sessions** - Create new session
- **GET /apps/{app_name}/users/{user_id}/sessions/{session_id}** - Get session details
- **POST /apps/{app_name}/users/{user_id}/sessions/{session_id}** - Send message to session
- **DELETE /apps/{app_name}/users/{user_id}/sessions/{session_id}** - Delete session

### Evaluation
- **GET /apps/{app_name}/eval_results** - Get evaluation results
- **GET /apps/{app_name}/eval_sets** - Get evaluation sets
- **POST /apps/{app_name}/eval_sets/{eval_set_id}/run_eval** - Run evaluation

### Artifacts & Debugging
- **GET /apps/{app_name}/users/{user_id}/sessions/{session_id}/artifacts** - List session artifacts
- **GET /debug/trace/session/{session_id}** - Debug session trace
- **GET /debug/trace/{event_id}** - Debug event trace

### Message Streaming
- **POST /run** - Run agent (requires specific payload structure)
- **POST /run_sse** - Server-sent events endpoint

## Basic Usage Example

### 1. List Available Apps

```bash
curl -X GET "http://localhost:8001/list-apps"
```

Response:
```json
["data_science_agent", "deployment", "eval", "tests"]
```

### 2. Create a Session

```bash
curl -X POST "http://localhost:8001/apps/data_science_agent/users/user123/sessions" \
  -H "Content-Type: application/json" \
  -d '{"session_id": "session456"}'
```

Response:
```json
{
  "id": "session456",
  "appName": "data_science_agent",
  "userId": "user123",
  "state": "active",
  "events": [],
  "lastUpdateTime": "2024-01-01T00:00:00Z"
}
```

### 3. Send a Message

```bash
curl -X POST "http://localhost:8001/apps/data_science_agent/users/user123/sessions/session456" \
  -H "Content-Type: application/json" \
  -d '{
    "role": "user",
    "content": "Hello! Can you help me analyze some data?"
  }'
```

Response:
```json
{
  "id": "session456",
  "appName": "data_science_agent", 
  "userId": "user123",
  "state": "active",
  "events": [...],
  "lastUpdateTime": "2024-01-01T00:00:01Z"
}
```

## Available Applications

- **data_science_agent** - Main data science and analysis agent
- **deployment** - Deployment-related operations
- **eval** - Evaluation and testing functionality
- **tests** - Test utilities

## Python Example

```python
import requests

# Configuration
base_url = "http://localhost:8001"
app_name = "data_science_agent"
user_id = "test-user-123"
session_id = "test-session-456"

# Create session
session_response = requests.post(
    f"{base_url}/apps/{app_name}/users/{user_id}/sessions",
    json={"session_id": session_id}
)

if session_response.status_code == 200:
    print("✅ Session created successfully")
    
    # Send message
    message_response = requests.post(
        f"{base_url}/apps/{app_name}/users/{user_id}/sessions/{session_id}",
        json={
            "role": "user",
            "content": "Hello! Can you help me analyze some data?"
        }
    )
    
    if message_response.status_code == 200:
        data = message_response.json()
        print(f"✅ Message sent successfully")
        print(f"Session state: {data.get('state')}")
        print(f"Events: {len(data.get('events', []))}")
```

## Error Handling

### Common Error Codes
- **404 Not Found** - App, user, or session not found
- **422 Unprocessable Entity** - Invalid request payload
- **500 Internal Server Error** - Server-side error

### Payload Validation
The `/run` endpoint has strict validation requirements:
- `newMessage` must be an object (not a string)
- Only specific fields are allowed in `newMessage`
- Use session-based endpoints for reliable message sending

## Testing

Use the provided test script to verify API functionality:

```bash
cd adk-backend
poetry run python test_api_server.py
```

The test script verifies:
- Server startup and readiness
- OpenAPI documentation accessibility
- Endpoint discovery
- Application listing
- Session creation and messaging

## Notes

- The `/run` endpoint appears to have specific payload requirements that may not be fully documented
- Session-based endpoints (`/apps/{app_name}/users/{user_id}/sessions/{session_id}`) are the recommended way to interact with agents
- All endpoints support JSON request/response format
- The server includes comprehensive OpenAPI documentation at `/docs`
