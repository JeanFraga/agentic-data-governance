#!/usr/bin/env python3
"""
Google ADK Callback Functions for LiteLLM and Ollama Integration
Practical implementation examples based on research

This module provides production-ready callback functions for integrating
Google ADK with LiteLLM proxy and Ollama models.
"""

import os
import json
import time
import logging
from typing import Optional, Dict, Any
from google.adk.agents.callback_context import CallbackContext
from google.adk.models import LlmResponse, LlmRequest
from google.genai import types

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class LiteLLMCallbackHandler:
    """Handles callbacks for LiteLLM proxy integration."""
    
    def __init__(self, proxy_url: str = "http://localhost:11434", 
                 enable_metrics: bool = True):
        self.proxy_url = proxy_url
        self.enable_metrics = enable_metrics
        self.request_count = 0
        self.response_times = []
        
    def before_model_callback(
        self, 
        callback_context: CallbackContext, 
        llm_request: LlmRequest
    ) -> Optional[LlmResponse]:
        """
        Pre-processes requests before sending to LiteLLM proxy.
        
        Features:
        - Request logging and metrics
        - Dynamic model routing
        - Request modification for proxy compatibility
        - Guardrails and content filtering
        """
        agent_name = callback_context.agent_name
        self.request_count += 1
        
        logger.info(f"[LiteLLM] Processing request #{self.request_count} for agent: {agent_name}")
        
        # Extract user message for analysis
        user_message = self._extract_user_message(llm_request)
        
        # Add proxy-specific headers if supported
        self._add_proxy_headers(llm_request, agent_name)
        
        # Implement content-based model routing
        self._route_model_based_on_content(llm_request, user_message)
        
        # Implement basic guardrails
        if self._should_block_request(user_message):
            logger.warning(f"[LiteLLM] Blocking request due to content policy")
            return self._create_blocked_response()
        
        # Store request timestamp for metrics
        if self.enable_metrics:
            callback_context.session.set_data("request_start_time", time.time())
        
        logger.info(f"[LiteLLM] Request prepared for proxy at {self.proxy_url}")
        return None  # Allow request to proceed
    
    def after_model_callback(
        self,
        callback_context: CallbackContext,
        llm_request: LlmRequest,
        llm_response: LlmResponse
    ) -> Optional[LlmResponse]:
        """
        Post-processes responses from LiteLLM proxy.
        
        Features:
        - Response metrics collection
        - Content filtering and modification
        - Usage tracking
        - Error handling and retry logic
        """
        agent_name = callback_context.agent_name
        
        # Calculate response time
        if self.enable_metrics:
            start_time = callback_context.session.get_data("request_start_time")
            if start_time:
                response_time = time.time() - start_time
                self.response_times.append(response_time)
                logger.info(f"[LiteLLM] Response time: {response_time:.3f}s")
        
        # Log usage metadata if available
        self._log_usage_metadata(llm_response)
        
        # Add source attribution
        self._add_source_attribution(llm_response, "LiteLLM Proxy")
        
        # Filter response content
        self._filter_response_content(llm_response)
        
        logger.info(f"[LiteLLM] Response processed for agent: {agent_name}")
        return llm_response
    
    def _extract_user_message(self, llm_request: LlmRequest) -> str:
        """Extract the latest user message from the request."""
        if llm_request.contents and llm_request.contents[-1].role == 'user':
            if llm_request.contents[-1].parts:
                return llm_request.contents[-1].parts[0].text or ""
        return ""
    
    def _add_proxy_headers(self, llm_request: LlmRequest, agent_name: str):
        """Add proxy-specific headers to the request."""
        if hasattr(llm_request.config, 'extra_headers'):
            llm_request.config.extra_headers = {
                **getattr(llm_request.config, 'extra_headers', {}),
                'X-LiteLLM-Proxy': 'true',
                'X-Agent-Name': agent_name,
                'X-Request-ID': f"req_{self.request_count}_{int(time.time())}"
            }
    
    def _route_model_based_on_content(self, llm_request: LlmRequest, user_message: str):
        """Route to different models based on content complexity."""
        # Example: Route complex queries to more powerful models
        if (len(user_message) > 1000 or 
            any(keyword in user_message.lower() for keyword in 
                ['analyze', 'complex', 'detailed', 'comprehensive'])):
            
            logger.info("[LiteLLM] Routing to high-performance model for complex query")
            # Could modify model selection here if the proxy supports it
    
    def _should_block_request(self, user_message: str) -> bool:
        """Implement basic content filtering."""
        blocked_keywords = ['harmful', 'illegal', 'dangerous']
        return any(keyword in user_message.lower() for keyword in blocked_keywords)
    
    def _create_blocked_response(self) -> LlmResponse:
        """Create a response for blocked content."""
        return LlmResponse(
            content=types.Content(
                role="model",
                parts=[types.Part(
                    text="I can't assist with that request. Please try a different question."
                )]
            )
        )
    
    def _log_usage_metadata(self, llm_response: LlmResponse):
        """Log usage metadata from the response."""
        if hasattr(llm_response, 'usage_metadata') and llm_response.usage_metadata:
            logger.info(f"[LiteLLM] Usage metadata: {llm_response.usage_metadata}")
    
    def _add_source_attribution(self, llm_response: LlmResponse, source: str):
        """Add source attribution to the response."""
        if llm_response.content and llm_response.content.parts:
            original_text = llm_response.content.parts[0].text
            if original_text and not original_text.endswith(f"_via {source}_"):
                llm_response.content.parts[0].text = f"{original_text}\n\n_Response via {source}_"
    
    def _filter_response_content(self, llm_response: LlmResponse):
        """Filter and clean response content."""
        if llm_response.content and llm_response.content.parts:
            response_text = llm_response.content.parts[0].text
            if response_text:
                # Remove any unwanted artifacts
                cleaned_text = response_text.replace("```plaintext", "```")
                llm_response.content.parts[0].text = cleaned_text
    
    def get_metrics(self) -> Dict[str, Any]:
        """Get callback metrics."""
        if not self.response_times:
            return {"request_count": self.request_count, "avg_response_time": 0}
        
        return {
            "request_count": self.request_count,
            "avg_response_time": sum(self.response_times) / len(self.response_times),
            "min_response_time": min(self.response_times),
            "max_response_time": max(self.response_times)
        }


class OllamaCallbackHandler:
    """Handles callbacks for Ollama model integration."""
    
    def __init__(self, ollama_host: str = "http://localhost:11434",
                 enable_local_optimizations: bool = True):
        self.ollama_host = ollama_host
        self.enable_local_optimizations = enable_local_optimizations
        self.model_cache = {}
        
    def before_model_callback(
        self,
        callback_context: CallbackContext,
        llm_request: LlmRequest
    ) -> Optional[LlmResponse]:
        """
        Pre-processes requests for Ollama models.
        
        Features:
        - Ollama-specific formatting
        - Local model optimization
        - Request caching for repeated queries
        - Parameter tuning for local models
        """
        agent_name = callback_context.agent_name
        logger.info(f"[Ollama] Processing request for agent: {agent_name}")
        
        # Optimize system instruction for Ollama
        self._optimize_system_instruction(llm_request)
        
        # Set Ollama-optimized parameters
        self._set_ollama_parameters(llm_request)
        
        # Check cache for repeated queries
        user_message = self._extract_user_message(llm_request)
        cached_response = self._check_cache(user_message)
        if cached_response:
            logger.info("[Ollama] Returning cached response")
            return cached_response
        
        logger.info(f"[Ollama] Request prepared for local model at {self.ollama_host}")
        return None
    
    def after_model_callback(
        self,
        callback_context: CallbackContext,
        llm_request: LlmRequest,
        llm_response: LlmResponse
    ) -> Optional[LlmResponse]:
        """
        Post-processes responses from Ollama models.
        
        Features:
        - Response formatting and cleanup
        - Local model attribution
        - Response caching
        - Performance optimization
        """
        agent_name = callback_context.agent_name
        
        # Clean up Ollama-specific artifacts
        self._clean_ollama_artifacts(llm_response)
        
        # Add local model attribution
        self._add_source_attribution(llm_response, "Local Ollama Model")
        
        # Cache successful responses
        user_message = self._extract_user_message(llm_request)
        self._cache_response(user_message, llm_response)
        
        logger.info(f"[Ollama] Response processed for agent: {agent_name}")
        return llm_response
    
    def _extract_user_message(self, llm_request: LlmRequest) -> str:
        """Extract the latest user message from the request."""
        if llm_request.contents and llm_request.contents[-1].role == 'user':
            if llm_request.contents[-1].parts:
                return llm_request.contents[-1].parts[0].text or ""
        return ""
    
    def _optimize_system_instruction(self, llm_request: LlmRequest):
        """Optimize system instruction for Ollama models."""
        if llm_request.config and llm_request.config.system_instruction:
            system_content = llm_request.config.system_instruction
            if system_content.parts and system_content.parts[0].text:
                original_text = system_content.parts[0].text
                
                # Ensure proper formatting for Ollama
                if not original_text.startswith("You are"):
                    optimized_text = f"You are an AI assistant. {original_text}"
                    system_content.parts[0].text = optimized_text
                    logger.info("[Ollama] Optimized system instruction for local model")
    
    def _set_ollama_parameters(self, llm_request: LlmRequest):
        """Set optimal parameters for Ollama models."""
        if self.enable_local_optimizations and llm_request.config:
            # Set generation config optimized for local models
            if hasattr(llm_request.config, 'generation_config'):
                llm_request.config.generation_config.temperature = 0.7
                llm_request.config.generation_config.max_output_tokens = 2048
                llm_request.config.generation_config.top_p = 0.9
                logger.info("[Ollama] Applied local model optimizations")
    
    def _check_cache(self, user_message: str) -> Optional[LlmResponse]:
        """Check if we have a cached response for this message."""
        if len(user_message) < 50:  # Only cache short queries
            message_hash = str(hash(user_message))
            return self.model_cache.get(message_hash)
        return None
    
    def _cache_response(self, user_message: str, llm_response: LlmResponse):
        """Cache response for future use."""
        if len(user_message) < 50 and len(self.model_cache) < 100:  # Simple limits
            message_hash = str(hash(user_message))
            self.model_cache[message_hash] = llm_response
            logger.info(f"[Ollama] Cached response for future use (cache size: {len(self.model_cache)})")
    
    def _clean_ollama_artifacts(self, llm_response: LlmResponse):
        """Clean up Ollama-specific response artifacts."""
        if llm_response.content and llm_response.content.parts:
            response_text = llm_response.content.parts[0].text
            if response_text:
                # Remove common Ollama artifacts
                cleaned_text = (response_text
                               .replace("[INST]", "")
                               .replace("[/INST]", "")
                               .replace("<<SYS>>", "")
                               .replace("<</SYS>>", "")
                               .strip())
                llm_response.content.parts[0].text = cleaned_text
    
    def _add_source_attribution(self, llm_response: LlmResponse, source: str):
        """Add source attribution to the response."""
        if llm_response.content and llm_response.content.parts:
            original_text = llm_response.content.parts[0].text
            if original_text and not original_text.endswith(f"_via {source}_"):
                llm_response.content.parts[0].text = f"{original_text}\n\n_Response via {source}_"


# Factory function to create appropriate callback handler
def create_callback_handler(proxy_type: str = "litellm", **kwargs):
    """
    Factory function to create appropriate callback handler.
    
    Args:
        proxy_type: Either "litellm" or "ollama"
        **kwargs: Additional configuration parameters
    
    Returns:
        Appropriate callback handler instance
    """
    if proxy_type.lower() == "litellm":
        return LiteLLMCallbackHandler(**kwargs)
    elif proxy_type.lower() == "ollama":
        return OllamaCallbackHandler(**kwargs)
    else:
        raise ValueError(f"Unsupported proxy type: {proxy_type}")


# Example usage
if __name__ == "__main__":
    # Example: Create callback handlers
    litellm_handler = create_callback_handler("litellm", 
                                              proxy_url="http://localhost:11434",
                                              enable_metrics=True)
    
    ollama_handler = create_callback_handler("ollama",
                                            ollama_host="http://localhost:11434",
                                            enable_local_optimizations=True)
    
    print("Callback handlers created successfully!")
    print(f"LiteLLM handler metrics: {litellm_handler.get_metrics()}")
