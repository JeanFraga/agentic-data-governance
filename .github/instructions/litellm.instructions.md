---
applyTo: adk-backend/
---
The Architectural Challenge: Agents vs. Model Front-Ends

First, it's important to understand why a direct connection isn't straightforward. The two systems are designed with different primary functions:

Google ADK is a framework for building the logic and orchestration of an AI agent. An ADK agent can use tools, manage workflows, and compose multiple sub-agents to accomplish complex tasks. It comes with a built-in developer UI (adk web) for testing and debugging, but this is not intended as a full-featured, multi-user chat platform.   
Open Web UI is a polished, user-facing front-end designed to interact with Large Language Models (LLMs). It expects to connect to a backend that behaves like a model, typically through an OpenAI-compatible API.   
The challenge, therefore, is to make your complex ADK agent appear to Open Web UI as a simple, callable model. This is where middleware becomes essential.

The Solution: LiteLLM as the Universal Middleware

The most flexible and powerful way to bridge ADK and Open Web UI is by using LiteLLM as a middleware proxy. LiteLLM is a tool that can receive requests in a standard format (like OpenAI's) and translate them to over 100 different model backends, including custom APIs.   

This approach involves three main steps:

Step 1: Expose Your ADK Agent as a FastAPI Service

First, you need to wrap your ADK agent in a web server so it can be accessed over the network. The most common way to do this is with the FastAPI framework, which integrates well with ADK.   

Your agent.py file will contain the core logic of your ADK agent, defining its tools and prompts. You would then create a separate api.py file to launch a FastAPI server that exposes your agent through a specific endpoint, for example, /run_agent.

This turns your ADK agent from a standalone Python script into a network-accessible service.

Step 2: Configure LiteLLM to Act as Middleware

Next, you set up a LiteLLM proxy server. In your LiteLLM config.yaml file, you will define a new "custom model" that points to the FastAPI endpoint you created in the previous step.   

Your configuration would instruct LiteLLM that whenever it receives a request for a model named, for instance, my-adk-agent, it should forward that request by making a POST call to http://<your_fastapi_server_ip>:8000/run_agent.

In this setup, LiteLLM acts as the central hub. It knows how to talk to Open Web UI using the standard OpenAI API format, and it knows how to talk to your custom ADK agent using the specific FastAPI endpoint you defined.

Step 3: Connect Open Web UI to the LiteLLM Proxy

Finally, you configure Open Web UI to talk to LiteLLM instead of directly to Ollama or another model provider.

In Open Web UI, navigate to Settings > Connections.   
Add a new OpenAI-compatible API connection.
Set the URL to your LiteLLM proxy's address (e.g., http://localhost:4000).   
Provide the necessary API key that you configured within LiteLLM.   
Once connected, Open Web UI will query the LiteLLM proxy for available models. Because of your configuration in Step 2, my-adk-agent will appear in the model list. When a user selects this "model" and sends a message, the request flows seamlessly from Open Web UI, through the LiteLLM middleware, to your ADK agent, which then executes its logic and returns a response.