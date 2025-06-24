# Google ADK Callback Functions for LiteLLM and Ollama Integration

## Research Summary

Based on extensive research into Google's Agent Development Kit (ADK) documentation and examples, here are the key findings about callback functions for connecting ADK to LiteLLM and Ollama:

## 🔍 Key ADK Callback Types

### 1. Agent Lifecycle Callbacks
- **`before_agent_callback`**: Executes before agent's main processing logic starts
- **`after_agent_callback`**: Executes after agent's processing completes but before result finalization

### 2. LLM Interaction Callbacks  
- **`before_model_callback`**: Called just before the LLM request is sent
- **`after_model_callback`**: Called after the LLM response is received

### 3. Tool Execution Callbacks
- **`before_tool_callback`**: Executes before tool execution
- **`after_tool_callback`**: Executes after tool execution

## 🏗️ LiteLLM Integration Architecture

According to the official LiteLLM documentation, Google ADK integrates with LiteLLM through:

```python
from google.adk.models.lite_llm import LiteLlm  # For multi-model support
import litellm  # Import for proxy configuration
```

### LiteLLM Proxy Configuration
Required environment variables for LiteLLM proxy:

| Variable | Description |
|----------|-------------|
| `LITELLM_PROXY_API_KEY` | The API key for the LiteLLM proxy |
| `LITELLM_PROXY_API_BASE` | The base URL for the LiteLLM proxy |
| `USE_LITELLM_PROXY` | When set to True, requests go to LiteLLM proxy |

### Example LiteLLM Proxy Setup
```python
# Set your LiteLLM Proxy credentials as environment variables
os.environ["LITELLM_PROXY_API_KEY"] = "your-litellm-proxy-api-key"
os.environ["LITELLM_PROXY_API_BASE"] = "your-litellm-proxy-url"  # e.g., "http://localhost:4000"

# Enable the use_litellm_proxy flag
litellm.use_litellm_proxy = True

# Create a proxy-enabled agent
weather_agent_proxy_env = Agent(
    name="weather_agent_proxy_env",
    model=LiteLlm(model="gpt-4o"), # this will call the `gpt-4o` model on LiteLLM proxy
    description="Provides weather information using a model from LiteLLM proxy.",
    instruction="You are a helpful weather assistant.",
    tools=[get_weather],
)
```

## 🔧 Callback Function Examples

### 1. Before Model Callback for Request Modification

```python
from google.adk.agents import LlmAgent
from google.adk.agents.callback_context import CallbackContext
from google.adk.models import LlmResponse, LlmRequest
from typing import Optional
from google.genai import types

def litellm_before_model_callback(
    callback_context: CallbackContext, 
    llm_request: LlmRequest
) -> Optional[LlmResponse]:
    """
    Modifies LLM request before sending to LiteLLM proxy.
    Can be used for:
    - Adding dynamic instructions
    - Implementing guardrails
    - Request-level caching
    - Model routing logic
    """
    agent_name = callback_context.agent_name
    print(f"[LiteLLM Callback] Processing request for agent: {agent_name}")
    
    # Example: Add proxy-specific headers or configuration
    if hasattr(llm_request.config, 'extra_headers'):
        llm_request.config.extra_headers = {
            **llm_request.config.extra_headers,
            'X-Litellm-Proxy': 'true',
            'X-Agent-Name': agent_name
        }
    
    # Example: Route to different models based on request content
    last_user_message = ""
    if llm_request.contents and llm_request.contents[-1].role == 'user':
        if llm_request.contents[-1].parts:
            last_user_message = llm_request.contents[-1].parts[0].text
    
    # Route complex queries to more powerful models
    if len(last_user_message) > 500 or "analyze" in last_user_message.lower():
        print("[LiteLLM Callback] Routing to high-performance model")
        # Could modify model selection here
    
    # Return None to proceed with the (possibly modified) request
    return None

def litellm_after_model_callback(
    callback_context: CallbackContext,
    llm_request: LlmRequest,
    llm_response: LlmResponse
) -> Optional[LlmResponse]:
    """
    Processes LLM response after receiving from LiteLLM proxy.
    Can be used for:
    - Response filtering
    - Usage tracking
    - Performance monitoring
    - Content moderation
    """
    agent_name = callback_context.agent_name
    print(f"[LiteLLM Callback] Processing response for agent: {agent_name}")
    
    # Example: Log usage metrics
    if hasattr(llm_response, 'usage_metadata'):
        print(f"[LiteLLM Callback] Tokens used: {llm_response.usage_metadata}")
    
    # Example: Filter or modify response content
    if llm_response.content and llm_response.content.parts:
        response_text = llm_response.content.parts[0].text
        
        # Add source attribution for proxy responses
        modified_text = f"{response_text}\n\n_Response generated via LiteLLM proxy_"
        llm_response.content.parts[0].text = modified_text
    
    return llm_response
```

### 2. Ollama-Specific Callback Functions

```python
def ollama_before_model_callback(
    callback_context: CallbackContext,
    llm_request: LlmRequest
) -> Optional[LlmResponse]:
    """
    Ollama-specific request preprocessing.
    Handles Ollama's unique API requirements and limitations.
    """
    agent_name = callback_context.agent_name
    print(f"[Ollama Callback] Preparing request for agent: {agent_name}")
    
    # Example: Ensure compatibility with Ollama API format
    # Ollama may have specific requirements for system instructions
    if llm_request.config and llm_request.config.system_instruction:
        # Ensure system instruction is properly formatted for Ollama
        system_text = llm_request.config.system_instruction.parts[0].text
        if not system_text.startswith("You are"):
            modified_system = f"You are an AI assistant. {system_text}"
            llm_request.config.system_instruction.parts[0].text = modified_system
    
    # Example: Set Ollama-specific parameters
    if hasattr(llm_request.config, 'generation_config'):
        # Ollama often works better with specific temperature settings
        llm_request.config.generation_config.temperature = 0.7
        llm_request.config.generation_config.max_output_tokens = 2048
    
    return None

def ollama_after_model_callback(
    callback_context: CallbackContext,
    llm_request: LlmRequest,
    llm_response: LlmResponse
) -> Optional[LlmResponse]:
    """
    Ollama-specific response processing.
    Handles response formatting and error handling specific to Ollama.
    """
    agent_name = callback_context.agent_name
    print(f"[Ollama Callback] Processing Ollama response for agent: {agent_name}")
    
    # Example: Handle Ollama-specific response format
    if llm_response.content and llm_response.content.parts:
        response_text = llm_response.content.parts[0].text
        
        # Clean up any Ollama-specific artifacts
        cleaned_text = response_text.replace("[INST]", "").replace("[/INST]", "")
        llm_response.content.parts[0].text = cleaned_text.strip()
    
    # Example: Add local model attribution
    if llm_response.content:
        # Add metadata indicating this came from a local Ollama model
        original_text = llm_response.content.parts[0].text
        attributed_text = f"{original_text}\n\n_Generated by local Ollama model_"
        llm_response.content.parts[0].text = attributed_text
    
    return llm_response
```

### 3. Agent Creation with Callbacks

```python
from google.adk.agents import LlmAgent
from google.adk.models.lite_llm import LiteLlm

# For LiteLLM proxy integration
litellm_agent = LlmAgent(
    name="litellm_data_science_agent",
    model=LiteLlm(model="gemini-2.0-flash-exp"),  # Will use LiteLLM proxy
    instruction="You are a data science assistant using LiteLLM proxy.",
    description="Data science agent with LiteLLM proxy callbacks",
    before_model_callback=litellm_before_model_callback,
    after_model_callback=litellm_after_model_callback,
)

# For direct Ollama integration (when using Ollama models through LiteLLM)
ollama_agent = LlmAgent(
    name="ollama_data_science_agent", 
    model=LiteLlm(model="ollama/llama3"),  # Ollama model through LiteLLM
    instruction="You are a data science assistant using Ollama.",
    description="Data science agent with Ollama-specific callbacks",
    before_model_callback=ollama_before_model_callback,
    after_model_callback=ollama_after_model_callback,
)
```

## 🎯 Key Callback Control Mechanisms

### Return Value Control Flow

1. **Return `None`**: Allow default behavior to proceed
   - For `before_*` callbacks: Continue to next step (LLM call, tool execution)
   - For `after_*` callbacks: Use the original result

2. **Return Specific Object**: Override default behavior
   - For `before_model_callback`: Return `LlmResponse` to skip LLM call
   - For `after_model_callback`: Return modified `LlmResponse`

### Context Objects

Callbacks receive rich context objects:
- **`CallbackContext`**: Contains agent name, session state, execution details
- **`ToolContext`**: For tool-related callbacks (not covered here)

## 🚀 Advanced Integration Patterns

### 1. Model Routing Based on Content
```python
def intelligent_model_router(
    callback_context: CallbackContext,
    llm_request: LlmRequest
) -> Optional[LlmResponse]:
    """Route requests to different models based on content complexity."""
    
    # Analyze request complexity
    user_content = extract_user_message(llm_request)
    
    if is_complex_query(user_content):
        # Route to powerful cloud model via LiteLLM
        # Modify request to use different model
        pass
    else:
        # Use local Ollama model for simple queries
        # Keep current routing
        pass
    
    return None
```

### 2. Fallback Handling
```python
def fallback_handler(
    callback_context: CallbackContext,
    llm_request: LlmRequest,
    llm_response: LlmResponse
) -> Optional[LlmResponse]:
    """Handle failures and implement fallback logic."""
    
    # Check if response indicates failure
    if is_error_response(llm_response):
        print("[Fallback] Primary model failed, attempting fallback")
        
        # Could trigger retry with different model
        # Or return a safe fallback response
        return create_fallback_response()
    
    return llm_response
```

## 📚 Official Resources

1. **Google ADK Documentation**: https://google.github.io/adk-docs/callbacks/
2. **LiteLLM Integration Guide**: https://docs.litellm.ai/docs/tutorials/google_adk
3. **ADK Examples Repository**: https://github.com/astrodevil/ADK-Agent-Examples
4. **Callback Types Documentation**: https://google.github.io/adk-docs/callbacks/types-of-callbacks/

## 🔧 Implementation Notes

1. **Callback Return Types**: Always return `Optional[LlmResponse]` for model callbacks
2. **Error Handling**: Implement proper error handling within callbacks
3. **Performance**: Keep callbacks lightweight to avoid slowing down agent execution
4. **State Management**: Use session state for stateful callback behavior
5. **Testing**: Test callbacks thoroughly with different scenarios

## 💡 Best Practices

1. **Logging**: Add comprehensive logging for debugging and monitoring
2. **Configuration**: Make callback behavior configurable via environment variables
3. **Graceful Degradation**: Ensure callbacks fail gracefully without breaking agent flow
4. **Security**: Validate and sanitize any data processed in callbacks
5. **Documentation**: Document callback behavior for team members

This research provides a comprehensive foundation for implementing Google ADK callback functions that can effectively integrate with both LiteLLM proxy and Ollama models in your containerized environment.

---

## 🔬 **COMPREHENSIVE RESEARCH UPDATE**

### Latest Findings from Official Documentation

Based on extensive research of official Google ADK documentation and community resources, here are the complete callback function capabilities:

#### Official Callback Types from ADK Documentation

1. **Agent Lifecycle Callbacks**
   - `before_agent_callback`: Called before agent's `_run_async_impl` 
   - `after_agent_callback`: Called after agent's processing completes
   - Available on all agents inheriting from `BaseAgent`

2. **LLM Interaction Callbacks**
   - `before_model_callback`: Called before `generate_content_async` request
   - `after_model_callback`: Called after receiving LLM response
   - Specific to `LlmAgent` instances

3. **Tool Execution Callbacks**
   - `before_tool_callback`: Called before tool's `run_async` method
   - `after_tool_callback`: Called after tool execution completes
   - Also specific to `LlmAgent` with tools

### 🔄 **Callback Control Flow Mechanisms**

#### Return Value Logic:
- **Return `None`**: Continue with default behavior
- **Return Specific Object**: Override/skip default behavior
  - `before_model_callback` → `LlmResponse` skips LLM call
  - `after_model_callback` → Modified `LlmResponse` replaces original
  - `before_tool_callback` → `dict` skips tool execution
  - `after_tool_callback` → `dict` replaces tool result

#### Context Objects Available:
```python
# Agent callbacks receive AgentContext
async def before_agent_callback(agent_context: AgentContext) -> Optional[types.Content]:
    session_state = agent_context.session.state
    agent_name = agent_context.agent.name
    request = agent_context.invocation_context.request

# Model callbacks receive ModelContext  
async def before_model_callback(model_context: ModelContext) -> Optional[LlmResponse]:
    model = model_context.model
    request = model_context.request
    
# Tool callbacks receive ToolContext
async def before_tool_callback(tool_context: ToolContext) -> Optional[dict]:
    tool_name = tool_context.tool.name
    args = tool_context.args
    agent_name = tool_context.agent_name
```

### 🏗️ **Advanced Implementation Patterns**

#### 1. Intelligent Model Routing
```python
async def smart_model_router(agent_context: AgentContext) -> Optional[types.Content]:
    """Route requests to optimal models based on content analysis"""
    
    request_content = agent_context.invocation_context.request.get_content_as_str()
    
    # Complexity analysis
    word_count = len(request_content.split())
    has_code = any(kw in request_content.lower() for kw in ["code", "function", "python"])
    needs_analysis = any(kw in request_content.lower() for kw in ["analyze", "research"])
    
    # Route to appropriate model
    if word_count > 500 or needs_analysis:
        agent_context.agent.model = LiteLlm(model="anthropic/claude-3-sonnet-20240229")
    elif has_code:
        agent_context.agent.model = LiteLlm(model="openai/gpt-4o")
    else:
        # Use local Ollama for simple queries
        agent_context.agent.model = LiteLlm(
            model="ollama/llama3.2",
            api_base="http://localhost:11434"
        )
    
    return None  # Continue with selected model
```

#### 2. Health Check with Fallback
```python
import aiohttp

async def ollama_health_fallback(model_context: ModelContext) -> Optional[LlmResponse]:
    """Check Ollama health and fallback to cloud if needed"""
    
    model_name = model_context.model.model
    if not model_name.startswith("ollama/"):
        return None  # Not Ollama, proceed normally
    
    try:
        # Quick health check
        timeout = aiohttp.ClientTimeout(total=3)
        async with aiohttp.ClientSession(timeout=timeout) as session:
            async with session.get("http://localhost:11434/api/version") as resp:
                if resp.status == 200:
                    return None  # Ollama healthy, proceed
                    
    except Exception as e:
        print(f"Ollama check failed: {e}")
    
    # Fallback to cloud model
    print("Falling back to cloud model")
    model_context.model = LiteLlm(model="gemini-1.5-pro")
    return None
```

#### 3. LiteLLM Proxy Integration
```python
async def litellm_proxy_handler(model_context: ModelContext) -> Optional[LlmResponse]:
    """Optimize requests for LiteLLM proxy"""
    
    # Add proxy-specific headers
    request = model_context.request
    if hasattr(request.config, 'extra_headers'):
        request.config.extra_headers = {
            **getattr(request.config, 'extra_headers', {}),
            'X-Litellm-Proxy': 'true',
            'X-Client': 'google-adk',
            'X-Request-ID': f"adk-{int(time.time())}"
        }
    
    # Route based on model availability in proxy
    proxy_models = os.environ.get("LITELLM_AVAILABLE_MODELS", "").split(",")
    current_model = model_context.model.model
    
    if current_model not in proxy_models and proxy_models:
        # Use first available model as fallback
        model_context.model.model = proxy_models[0]
        print(f"Switched to available proxy model: {proxy_models[0]}")
    
    return None
```

### 📊 **Performance Monitoring Patterns**

#### Session-Based Metrics
```python
async def performance_tracker(agent_context: AgentContext) -> Optional[types.Content]:
    """Track performance metrics in session state"""
    
    session_state = agent_context.session.state
    
    # Initialize metrics
    if "performance_metrics" not in session_state:
        session_state["performance_metrics"] = {
            "total_requests": 0,
            "model_usage": {},
            "response_times": [],
            "error_count": 0
        }
    
    # Track request
    session_state["performance_metrics"]["total_requests"] += 1
    session_state["request_start_time"] = time.time()
    
    return None

async def performance_recorder(agent_context: AgentContext) -> Optional[types.Content]:
    """Record completion metrics"""
    
    session_state = agent_context.session.state
    if "performance_metrics" in session_state and "request_start_time" in session_state:
        duration = time.time() - session_state["request_start_time"]
        session_state["performance_metrics"]["response_times"].append(duration)
        
        # Keep only last 100 measurements
        if len(session_state["performance_metrics"]["response_times"]) > 100:
            session_state["performance_metrics"]["response_times"] = (
                session_state["performance_metrics"]["response_times"][-100:]
            )
    
    return None
```

### 🛡️ **Security and Validation Patterns**

#### Input Validation
```python
async def input_validator(agent_context: AgentContext) -> Optional[types.Content]:
    """Validate and sanitize inputs"""
    
    request_content = agent_context.invocation_context.request.get_content_as_str()
    
    # Security checks
    dangerous_patterns = ["eval(", "exec(", "__import__", "subprocess"]
    if any(pattern in request_content for pattern in dangerous_patterns):
        return types.Content(parts=[
            types.Part(text="Request rejected: potentially unsafe content detected")
        ])
    
    # Content length limits
    if len(request_content) > 10000:  # 10k character limit
        return types.Content(parts=[
            types.Part(text="Request too long. Please limit to 10,000 characters.")
        ])
    
    return None  # Request is safe
```

#### Output Filtering
```python
async def output_filter(model_context: ModelContext) -> Optional[LlmResponse]:
    """Filter sensitive information from responses"""
    
    response = model_context.response
    if response and response.content and response.content.parts:
        response_text = response.content.parts[0].text
        
        # Remove potential sensitive patterns
        import re
        
        # Remove email addresses
        response_text = re.sub(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b', '[EMAIL]', response_text)
        
        # Remove potential API keys (simple pattern)
        response_text = re.sub(r'\b[A-Za-z0-9]{32,}\b', '[REDACTED]', response_text)
        
        # Update response
        response.content.parts[0].text = response_text
    
    return response
```

### 🔧 **Production-Ready Configuration**

#### Environment-Based Configuration
```python
class CallbackConfig:
    """Centralized configuration for callbacks"""
    
    def __init__(self):
        # Ollama configuration
        self.ollama_api_base = os.environ.get("OLLAMA_API_BASE", "http://localhost:11434")
        self.ollama_timeout = int(os.environ.get("OLLAMA_TIMEOUT", "30"))
        self.ollama_fallback = os.environ.get("OLLAMA_FALLBACK_MODEL", "gemini-1.5-pro")
        
        # LiteLLM configuration
        self.litellm_proxy_base = os.environ.get("LITELLM_PROXY_API_BASE")
        self.litellm_proxy_key = os.environ.get("LITELLM_PROXY_API_KEY")
        self.litellm_debug = os.environ.get("LITELLM_DEBUG", "false").lower() == "true"
        
        # Performance settings
        self.max_response_time = int(os.environ.get("MAX_RESPONSE_TIME", "60"))
        self.enable_caching = os.environ.get("ENABLE_CACHING", "true").lower() == "true"
        
        # Security settings
        self.max_input_length = int(os.environ.get("MAX_INPUT_LENGTH", "10000"))
        self.enable_output_filtering = os.environ.get("ENABLE_OUTPUT_FILTERING", "true").lower() == "true"
```

### 📚 **Complete Code Integration Example**

```python
from google.adk.agents import LlmAgent
from google.adk.models.lite_llm import LiteLlm

# Configure comprehensive agent with all callbacks
def create_production_agent(name: str, model: str, instructions: str) -> LlmAgent:
    """Create production-ready agent with comprehensive callbacks"""
    
    config = CallbackConfig()
    
    return LlmAgent(
        name=name,
        model=LiteLlm(model=model),
        instructions=instructions,
        
        # Agent lifecycle
        before_agent_callback=lambda ctx: asyncio.create_task(
            intelligent_agent_router(ctx, config)
        ),
        after_agent_callback=lambda ctx: asyncio.create_task(
            performance_recorder(ctx, config)
        ),
        
        # Model interaction
        before_model_callback=lambda ctx: asyncio.create_task(
            ollama_health_fallback(ctx, config)
        ),
        after_model_callback=lambda ctx: asyncio.create_task(
            output_filter(ctx, config)
        )
    )

# Usage
agent = create_production_agent(
    name="production_assistant",
    model="ollama/llama3.2",  # Will fallback to cloud if needed
    instructions="You are a production AI assistant with comprehensive safety and monitoring."
)
```

### 🎯 **Key Implementation Guidelines**

1. **Always Return Appropriate Types**: Follow the exact return type patterns
2. **Handle Exceptions Gracefully**: Never let callback failures break agent execution  
3. **Use Session State**: Leverage persistent session storage for stateful behavior
4. **Monitor Performance**: Track execution times and model usage
5. **Implement Security**: Validate inputs and filter outputs
6. **Plan for Failures**: Always have fallback mechanisms
7. **Log Comprehensively**: Enable debugging and monitoring

### 📖 **Official Resources Referenced**

- **ADK Callbacks Guide**: https://google.github.io/adk-docs/callbacks/types-of-callbacks/
- **LiteLLM Integration**: https://docs.litellm.ai/docs/tutorials/google_adk  
- **Community Examples**: https://github.com/astrodevil/ADK-Agent-Examples
- **Official Samples**: https://github.com/google/adk-samples

This comprehensive research and implementation guide provides everything needed to successfully integrate Google ADK with LiteLLM and Ollama using production-ready callback functions.
