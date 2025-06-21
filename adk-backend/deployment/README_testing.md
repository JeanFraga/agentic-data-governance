# Testing Deployment Without GCP

This guide explains how to test the deployment script without actually deploying to Google Cloud Platform.

## Dry Run Mode

The deployment script supports a `--dry_run` flag that simulates deployment operations without making actual GCP API calls.

### Basic Usage

```bash
# Test agent creation
python deploy.py --create --dry_run \
  --project_id your-project-id \
  --location us-central1

# Test agent deletion
python deploy.py --delete --dry_run \
  --resource_id projects/your-project/locations/us-central1/reasoningEngines/your-engine \
  --project_id your-project-id \
  --location us-central1
```

### What Dry Run Does

1. **Validates Configuration**: Checks all required parameters and files
2. **Simulates Operations**: Shows what would happen without making GCP calls
3. **Saves Metadata**: Creates a `deployment_metadata_dryrun.json` file
4. **Validates Environment**: Checks environment variables and settings

### Running Test Suite

Use the provided test script to run multiple scenarios:

```bash
# Make the test script executable
chmod +x test_deploy.py

# Run all tests
python test_deploy.py
```

## Test Scenarios

### 1. Configuration Validation

Test that all required configuration is present:

```bash
python deploy.py --create --dry_run \
  --project_id test-project \
  --location us-central1 \
  --environment production
```

Expected output:
- ✓ Configuration validation results
- ✓ Wheel file existence check
- ✓ Environment variable status

### 2. Environment-Specific Testing

Test different deployment environments:

```bash
# Development environment (more resources, tracing enabled)
python deploy.py --create --dry_run \
  --environment development \
  --project_id test-project \
  --location us-central1

# Staging environment
python deploy.py --create --dry_run \
  --environment staging \
  --project_id test-project \
  --location us-central1

# Production environment (optimized resources, no tracing)
python deploy.py --create --dry_run \
  --environment production \
  --project_id test-project \
  --location us-central1
```

### 3. Missing Configuration Testing

Test error handling for missing configuration:

```bash
# Missing project ID
python deploy.py --create --dry_run --location us-central1

# Missing wheel file
mv data_science_agent-*.whl data_science_agent-*.whl.bak
python deploy.py --create --dry_run \
  --project_id test-project \
  --location us-central1
mv data_science_agent-*.whl.bak data_science_agent-*.whl
```

### 4. Custom Configuration File

Test with a custom configuration file:

```bash
# Create a test config
cat > test_config.toml << EOF
[wheel]
package_name = "custom_agent"
python_tag = "py3"
abi_tag = "none"
platform_tag = "any"

[deployment]
enable_tracing = true
memory = "8Gi"
cpu = "8"
EOF

# Run with custom config
python deploy.py --create --dry_run \
  --config_file test_config.toml \
  --project_id test-project \
  --location us-central1
```

## Interpreting Results

### Successful Dry Run Output

```
🔍 Running in DRY RUN mode - no actual GCP resources will be created/deleted

=== Configuration Validation ===
✓ GCP Project ID: test-project
✓ GCP Location: us-central1
✓ GCS Bucket Name: test-project-adk-staging
✓ Wheel file exists: data_science_agent-0.1.0-py3-none-any.whl (2.34 MB)

=== Environment Variables ===
✓ ROOT_AGENT_MODEL: SET
✓ ANALYTICS_AGENT_MODEL: SET
⚠️  BQ_DATASET_ID: NOT SET

[DRY RUN] Would create ADK App with:
  - Agent: RootAgent
  - Enable tracing: False
  - Wheel file: /path/to/wheel (2.34 MB)
  - Environment: production

[DRY RUN] Successfully simulated agent creation: projects/test-project/locations/us-central1/reasoningEngines/fake-20240115123456
```

### Validation Failure Output

```
=== Configuration Validation ===
❌ Missing GCP Project ID
✓ GCP Location: us-central1
❌ Wheel file not found: /path/to/wheel

❌ Configuration validation failed. Fix the issues above before proceeding.
💡 Tip: Use --dry_run flag to test your configuration without deploying.
```

## Build Wheel for Testing

Before testing, ensure you have built the wheel file:

```bash
# Build the wheel
cd ..  # Go to project root
poetry build --format=wheel

# Copy to deployment directory
cp dist/*.whl deployment/

# Or use the custom output directory
poetry build --format=wheel --output=deployment
```

## Environment Variables

Create a `.env` file for testing:

```bash
cat > .env << EOF
GOOGLE_CLOUD_PROJECT=test-project
GOOGLE_CLOUD_LOCATION=us-central1
GOOGLE_CLOUD_STORAGE_BUCKET=test-bucket

# Agent models
ROOT_AGENT_MODEL=gemini-2.0-flash-001
ANALYTICS_AGENT_MODEL=gemini-1.5-flash-001
BASELINE_NL2SQL_MODEL=gemini-1.5-pro-001
BIGQUERY_AGENT_MODEL=gemini-1.5-flash-001
BQML_AGENT_MODEL=gemini-1.5-flash-001
CHASE_NL2SQL_MODEL=gemini-1.5-pro-001

# BigQuery settings
BQ_DATASET_ID=test_dataset
BQ_PROJECT_ID=test-project
BQML_RAG_CORPUS_NAME=test_corpus

# Extensions
CODE_INTERPRETER_EXTENSION_NAME=code_interpreter
NL2SQL_METHOD=baseline
EOF
```

## Continuous Integration

Add this to your CI pipeline to validate deployments:

```yaml
# .github/workflows/test-deployment.yml
name: Test Deployment

on:
  pull_request:
    paths:
      - 'deployment/**'
      - 'data_science_agent/**'
      - 'pyproject.toml'

jobs:
  test-deployment:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      
      - name: Install Poetry
        uses: snok/install-poetry@v1
      
      - name: Install dependencies
        run: poetry install
      
      - name: Build wheel
        run: poetry build --format=wheel --output=deployment
      
      - name: Test deployment dry run
        run: |
          cd deployment
          python deploy.py --create --dry_run \
            --project_id test-project \
            --location us-central1 \
            --environment development
```

## Tips

1. **Always test with dry run first** before actual deployment
2. **Check the validation output** carefully for any warnings
3. **Save dry run outputs** for documentation and debugging
4. **Test all environments** (dev, staging, prod) separately
5. **Verify wheel file** is up-to-date before deployment
