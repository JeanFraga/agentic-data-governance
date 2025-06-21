# Docker Compose Setup for ADK Backend

This directory contains Docker Compose configurations for running the ADK backend in different environments.

## Prerequisites

1. **Docker and Docker Compose** installed on your system
2. **Google Cloud SDK** installed and authenticated locally (for development)
3. **Poetry** for dependency management (if building locally)

## Files

- `docker-compose.yml` - Main development configuration
- `docker-compose.dev.yml` - Explicit development configuration
- `docker-compose.prod.yml` - Production configuration template

## Development Setup

### Option 1: Using the main docker-compose.yml

```bash
# Build and start the service
docker-compose up --build

# Run in background
docker-compose up -d --build

# View logs
docker-compose logs -f

# Stop the service
docker-compose down
```

### Option 2: Using the development-specific file

```bash
# Build and start with development configuration
docker-compose -f docker-compose.dev.yml up --build

# Run in background
docker-compose -f docker-compose.dev.yml up -d --build
```

## Production Setup

### Prerequisites for Production

1. Create a Google Cloud service account
2. Download the service account key file
3. Place it as `service-account-key.json` in the adk-backend directory

```bash
# For production deployment
docker-compose -f docker-compose.prod.yml up -d --build
```

## Authentication Setup

### For Development (Using Local Credentials)

Make sure you're authenticated with Google Cloud:

```bash
gcloud auth application-default login
```

The Docker Compose file will automatically mount your local Google Cloud credentials.

### For Production (Using Service Account)

1. Go to Google Cloud Console → IAM & Admin → Service Accounts
2. Create a new service account or use existing one
3. Download the JSON key file
4. Rename it to `service-account-key.json` and place in the adk-backend directory
5. **Important:** Add `service-account-key.json` to your `.gitignore` file

## Environment Variables

You can override environment variables by:

1. **Adding them to the docker-compose.yml file:**
   ```yaml
   environment:
     - GOOGLE_CLOUD_PROJECT=your-project-id
     - BQ_PROJECT_ID=your-project-id
   ```

2. **Using a .env file:**
   Create a `.env` file in the same directory as docker-compose.yml:
   ```
   GOOGLE_CLOUD_PROJECT=your-project-id
   BQ_PROJECT_ID=your-project-id
   ```

## Useful Commands

```bash
# Build only
docker-compose build

# View running containers
docker-compose ps

# Execute commands in running container
docker-compose exec adk-backend bash

# View logs
docker-compose logs adk-backend

# Follow logs in real-time
docker-compose logs -f adk-backend

# Stop and remove containers
docker-compose down

# Stop, remove containers, and remove volumes
docker-compose down -v

# Rebuild from scratch (no cache)
docker-compose build --no-cache
```

## Accessing the Application

Once running, the ADK backend will be available at:
- **Web Interface:** http://localhost:8000
- **API Documentation:** http://localhost:8000/docs (if available)

## Troubleshooting

### Authentication Issues

If you see Google Cloud authentication errors:

1. **For Development:** Ensure you're logged in with `gcloud auth application-default login`
2. **For Production:** Verify the service account key file exists and has proper permissions

### Port Conflicts

If port 8000 is already in use:

```bash
# Use a different port
docker-compose up --build -e "PORTS=8001:8000"
```

Or modify the ports section in docker-compose.yml:
```yaml
ports:
  - "8001:8000"  # Use port 8001 instead
```

### Container Won't Start

Check the logs:
```bash
docker-compose logs adk-backend
```

Common issues:
- Missing or invalid Google Cloud credentials
- Port conflicts
- Insufficient memory or disk space

## Security Notes

- Never commit service account key files to version control
- Use environment-specific configurations
- Regularly rotate service account keys in production
- Consider using Google Cloud's Workload Identity for Kubernetes deployments
