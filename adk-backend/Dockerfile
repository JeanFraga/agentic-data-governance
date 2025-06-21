# Stage 1: Builder stage to install dependencies
FROM python:3.13-slim AS builder

# Set environment variables for Poetry
ENV POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_CREATE=true \
    POETRY_VIRTUALENVS_IN_PROJECT=true \
    POETRY_CACHE_DIR='/var/cache/pypoetry'

# Install Poetry
RUN pip install poetry

# Copy only the dependency definition files to leverage Docker cache
WORKDIR /app
COPY pyproject.toml poetry.lock ./

# Install dependencies
RUN poetry install --only=main --no-root

# Stage 2: Final production stage
FROM python:3.13-slim AS final

# Create a non-root user for security
RUN useradd --create-home appuser

# Copy the virtual environment from the builder stage
COPY --from=builder /app/.venv /app/.venv

# Copy the application source code
WORKDIR /home/appuser
COPY --chown=appuser:appuser data_science_agent/ ./data_science_agent/
COPY --chown=appuser:appuser main.py ./main.py
COPY --chown=appuser:appuser entrypoint.py ./entrypoint.py
COPY --chown=appuser:appuser .env ./.env

# Switch to non-root user
USER appuser

# Add virtual environment to PATH
ENV PATH="/app/.venv/bin:$PATH"

# Expose the port the application will run on
EXPOSE 8000

# Command to run the application
CMD ["python", "entrypoint.py"]
