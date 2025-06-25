# Stage 1: Builder stage to install dependencies
FROM python:3.13-slim as builder

# Set environment variables for Poetry
ENV POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_CREATE=false \
    POETRY_CACHE_DIR='/var/cache/pypoetry' \
    POETRY_HOME='/opt/poetry' \
    POETRY_VENV_PATH='/opt/poetry-venv'

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Poetry
RUN pip install poetry

# Copy only the dependency definition files to leverage Docker cache
WORKDIR /app
COPY pyproject.toml poetry.lock ./

# Install only production dependencies
RUN poetry install --only=main --no-root

# Stage 2: Final production stage
FROM python:3.13-slim as final

# Install system dependencies needed at runtime
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for security
RUN useradd --create-home --shell /bin/bash appuser
USER appuser
WORKDIR /home/appuser

# Copy the installed dependencies from the builder stage
COPY --from=builder /usr/local/lib/python3.13/site-packages /usr/local/lib/python3.13/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy the application source code
COPY --chown=appuser:appuser . ./

# Set environment variables for the ADK agent
ENV PYTHONPATH=/home/appuser \
    PATH=/usr/local/bin:$PATH \
    GOOGLE_GENAI_USE_VERTEXAI=TRUE \
    ADK_LOCAL_MODE=FALSE

# Expose the port the ADK API server will run on
EXPOSE 8000

# Health check to ensure the API server is running
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Command to run the ADK API server using Poetry
CMD ["poetry", "run", "adk", "api_server", "--host", "0.0.0.0", "--port", "8000"]
