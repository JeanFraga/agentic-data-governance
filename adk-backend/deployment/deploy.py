# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Deployment script for Data Science agent."""

import logging
import os
from pathlib import Path
import json
from datetime import datetime

import vertexai
from absl import app, flags
from dotenv import load_dotenv
from google.api_core import exceptions as google_exceptions
from google.cloud import storage
from vertexai import agent_engines
from vertexai.preview.reasoning_engines import AdkApp

from Helper.poetry_version import DeployConfig
from data_science_agent.agent import root_agent

FLAGS = flags.FLAGS
flags.DEFINE_string("project_id", None, "GCP project ID.")
flags.DEFINE_string("location", None, "GCP location.")
flags.DEFINE_string(
    "bucket", None, "GCP bucket name (without gs:// prefix)."
)  # Changed flag description
flags.DEFINE_string("resource_id", None, "ReasoningEngine resource ID.")
flags.DEFINE_string("environment", "production", "Deployment environment (production, staging, development).")
flags.DEFINE_string("config_file", None, "Path to deployment configuration file.")

flags.DEFINE_bool("create", False, "Create a new agent.")
flags.DEFINE_bool("delete", False, "Delete an existing agent.")
flags.DEFINE_bool("dry_run", False, "Perform a dry run without making actual GCP calls.")
flags.mark_bool_flags_as_mutual_exclusive(["create", "delete"])

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def setup_staging_bucket(
    project_id: str, location: str, bucket_name: str, dry_run: bool = False
) -> str:
    """
    Checks if the staging bucket exists, creates it if not.

    Args:
        project_id: The GCP project ID.
        location: The GCP location for the bucket.
        bucket_name: The desired name for the bucket (without gs:// prefix).
        dry_run: If True, simulates the operation without making actual calls.

    Returns:
        The full bucket path (gs://<bucket_name>).

    Raises:
        google_exceptions.GoogleCloudError: If bucket creation fails.
    """
    if dry_run:
        logger.info("[DRY RUN] Would check if staging bucket gs://%s exists.", bucket_name)
        logger.info("[DRY RUN] Would create bucket if it doesn't exist with:")
        logger.info("  - Project: %s", project_id)
        logger.info("  - Location: %s", location)
        logger.info("  - Uniform bucket-level access: Enabled")
        return f"gs://{bucket_name}"
    
    storage_client = storage.Client(project=project_id)
    try:
        # Check if the bucket exists
        bucket = storage_client.lookup_bucket(bucket_name)
        if bucket:
            logger.info("Staging bucket gs://%s already exists.", bucket_name)
        else:
            logger.info(
                "Staging bucket gs://%s not found. Creating...", bucket_name
            )
            # Create the bucket if it doesn't exist
            new_bucket = storage_client.create_bucket(
                bucket_name, project=project_id, location=location
            )
            logger.info(
                "Successfully created staging bucket gs://%s in %s.",
                new_bucket.name,
                location,
            )
            # Enable uniform bucket-level access for simplicity
            new_bucket.iam_configuration.uniform_bucket_level_access_enabled = (
                True
            )
            new_bucket.patch()
            logger.info(
                "Enabled uniform bucket-level access for gs://%s.",
                new_bucket.name,
            )

    except google_exceptions.Forbidden as e:
        logger.error(
            (
                "Permission denied error for bucket gs://%s. "
                "Ensure the service account has 'Storage Admin' role. Error: %s"
            ),
            bucket_name,
            e,
        )
        raise
    except google_exceptions.Conflict as e:
        logger.warning(
            (
                "Bucket gs://%s likely already exists but owned by another "
                "project or recently deleted. Error: %s"
            ),
            bucket_name,
            e,
        )
        # Assuming we can proceed if it exists, even with a conflict warning
    except google_exceptions.ClientError as e:
        logger.error(
            "Failed to create or access bucket gs://%s. Error: %s",
            bucket_name,
            e,
        )
        raise

    return f"gs://{bucket_name}"


def create(env_vars: dict[str, str], deploy_config: DeployConfig, dry_run: bool = False) -> None:
    """Creates and deploys the agent."""
    deployment_settings = deploy_config.get_deployment_config()
    
    # Validate wheel file exists
    wheel_path = deploy_config.get_wheel_path()
    if not wheel_path.exists():
        logger.error("Agent wheel file not found at: %s", wheel_path)
        raise FileNotFoundError(f"Agent wheel file not found: {wheel_path}")
    
    # Get wheel file size for dry run info
    wheel_size_mb = wheel_path.stat().st_size / (1024 * 1024)
    
    if dry_run:
        logger.info("[DRY RUN] Would create ADK App with:")
        logger.info("  - Agent: %s", type(root_agent).__name__)
        logger.info("  - Enable tracing: %s", deployment_settings.get("enable_tracing", False))
        logger.info("  - Wheel file: %s (%.2f MB)", wheel_path, wheel_size_mb)
        logger.info("  - Environment: %s", deploy_config.environment)
        
        logger.info("\n[DRY RUN] Deployment settings:")
        for key, value in deployment_settings.items():
            logger.info("  - %s: %s", key, value)
        
        logger.info("\n[DRY RUN] Environment variables to be set:")
        for key, value in env_vars.items():
            if value:
                logger.info("  - %s: %s", key, "***" if "KEY" in key or "SECRET" in key else value)
            else:
                logger.warning("  - %s: NOT SET (missing)", key)
        
        # Simulate resource name
        fake_resource_name = f"projects/{FLAGS.project_id or 'PROJECT_ID'}/locations/{FLAGS.location or 'LOCATION'}/reasoningEngines/fake-{datetime.now().strftime('%Y%m%d%H%M%S')}"
        
        logger.info("\n[DRY RUN] Would create agent with resource name: %s", fake_resource_name)
        
        # Save dry run metadata
        metadata_path = Path(__file__).parent / "deployment_metadata_dryrun.json"
        dry_run_metadata = {
            "dry_run": True,
            "resource_name": fake_resource_name,
            "deployed_at": str(datetime.now()),
            "environment": deploy_config.environment,
            "deployment_config": deployment_settings,
            "wheel_info": {
                "path": str(wheel_path),
                "size_mb": wheel_size_mb,
                "exists": wheel_path.exists()
            }
        }
        
        with open(metadata_path, "w") as f:
            json.dump(dry_run_metadata, f, indent=2)
        
        logger.info("[DRY RUN] Saved dry run metadata to: %s", metadata_path)
        print(f"\n[DRY RUN] Successfully simulated agent creation: {fake_resource_name}")
        return
    
    adk_app = AdkApp(
        agent=root_agent,
        enable_tracing=deployment_settings.get("enable_tracing", False),
    )

    logger.info("Using agent wheel file: %s", wheel_path)
    logger.info("Deployment configuration: %s", deployment_settings)

    remote_agent = agent_engines.create(
        adk_app,
        requirements=[str(wheel_path)],
        extra_packages=[str(wheel_path)],
        env_vars=env_vars
    )
    logger.info("Created remote agent: %s", remote_agent.resource_name)
    print(f"\nSuccessfully created agent: {remote_agent.resource_name}")
    
    # Save deployment metadata
    metadata_path = Path(__file__).parent / "deployment_metadata.json"
    deploy_config.config["deployment_metadata"] = {
        "resource_name": remote_agent.resource_name,
        "deployed_at": str(Path().resolve()),
        "environment": deploy_config.environment
    }
    deploy_config.save_config(metadata_path)
    logger.info("Saved deployment metadata to: %s", metadata_path)


def delete(resource_id: str, dry_run: bool = False) -> None:
    """Deletes the specified agent."""
    logger.info("Attempting to delete agent: %s", resource_id)
    
    if dry_run:
        logger.info("[DRY RUN] Would attempt to get agent: %s", resource_id)
        logger.info("[DRY RUN] Would delete agent with force=True")
        print(f"\n[DRY RUN] Successfully simulated deletion of agent: {resource_id}")
        return
    
    try:
        remote_agent = agent_engines.get(resource_id)
        remote_agent.delete(force=True)
        logger.info("Successfully deleted remote agent: %s", resource_id)
        print(f"\nSuccessfully deleted agent: {resource_id}")
    except google_exceptions.NotFound:
        logger.error("Agent with resource ID %s not found.", resource_id)
        print(f"\nAgent{resource_id} not found.")
        print(f"\nAgent not found: {resource_id}")
    except Exception as e:
        logger.error(
            "An error occurred while deleting agent %s: %s", resource_id, e
        )
        print(f"\nError deleting agent {resource_id}: {e}")


def validate_configuration(project_id: str, location: str, bucket_name: str, 
                         env_vars: dict[str, str], deploy_config: DeployConfig) -> bool:
    """Validate configuration before deployment."""
    valid = True
    
    logger.info("\n=== Configuration Validation ===")
    
    # Check required parameters
    if not project_id:
        logger.error("❌ Missing GCP Project ID")
        valid = False
    else:
        logger.info("✓ GCP Project ID: %s", project_id)
    
    if not location:
        logger.error("❌ Missing GCP Location")
        valid = False
    else:
        logger.info("✓ GCP Location: %s", location)
    
    if not bucket_name:
        logger.error("❌ Missing GCS Bucket Name")
        valid = False
    else:
        logger.info("✓ GCS Bucket Name: %s", bucket_name)
    
    # Check wheel file
    wheel_path = deploy_config.get_wheel_path()
    if not wheel_path.exists():
        logger.error("❌ Wheel file not found: %s", wheel_path)
        valid = False
    else:
        wheel_size_mb = wheel_path.stat().st_size / (1024 * 1024)
        logger.info("✓ Wheel file exists: %s (%.2f MB)", wheel_path.name, wheel_size_mb)
    
    # Check environment variables
    logger.info("\n=== Environment Variables ===")
    missing_env_vars = []
    for key, value in env_vars.items():
        if not value:
            logger.warning("⚠️  %s: NOT SET", key)
            missing_env_vars.append(key)
        else:
            logger.info("✓ %s: SET", key)
    
    if missing_env_vars:
        logger.warning("\nMissing environment variables: %s", ", ".join(missing_env_vars))
        logger.warning("Some features may not work properly without these variables.")
    
    logger.info("\n=== Deployment Configuration ===")
    logger.info("Environment: %s", deploy_config.environment)
    logger.info("Package name: %s", deploy_config.config["wheel"]["package_name"])
    logger.info("Version: %s", deploy_config.config["wheel"]["version"])
    
    deployment_settings = deploy_config.get_deployment_config()
    for key, value in deployment_settings.items():
        logger.info("%s: %s", key, value)
    
    return valid


def main(argv: list[str]) -> None:  # pylint: disable=unused-argument
    """Main execution function."""
    load_dotenv()
    env_vars = {}

    # Initialize deployment configuration
    config_file = Path(FLAGS.config_file) if FLAGS.config_file else None
    deploy_config = DeployConfig(config_file=config_file, environment=FLAGS.environment)
    
    logger.info("Using deployment environment: %s", FLAGS.environment)
    logger.info("Deployment configuration loaded: %s", deploy_config.get_wheel_filename())

    project_id = (
        FLAGS.project_id
        if FLAGS.project_id
        else os.getenv("GOOGLE_CLOUD_PROJECT")
    )
    location = (
        FLAGS.location if FLAGS.location else os.getenv("GOOGLE_CLOUD_LOCATION")
    )
    # Default bucket name convention if not provided
    default_bucket_name = f"{project_id}-adk-staging" if project_id else None
    bucket_name = (
        FLAGS.bucket
        if FLAGS.bucket
        else os.getenv("GOOGLE_CLOUD_STORAGE_BUCKET", default_bucket_name)
    )
    # Don't set "GOOGLE_CLOUD_PROJECT" or "GOOGLE_CLOUD_LOCATION"
    # when deploying to Agent Engine. Those are set by the backend.
    env_vars["ROOT_AGENT_MODEL"] = os.getenv("ROOT_AGENT_MODEL")
    env_vars["ANALYTICS_AGENT_MODEL"] = os.getenv("ANALYTICS_AGENT_MODEL")
    env_vars["BASELINE_NL2SQL_MODEL"] = os.getenv("BASELINE_NL2SQL_MODEL")
    env_vars["BIGQUERY_AGENT_MODEL"] = os.getenv("BIGQUERY_AGENT_MODEL")
    env_vars["BQML_AGENT_MODEL"] = os.getenv("BQML_AGENT_MODEL")
    env_vars["CHASE_NL2SQL_MODEL"] = os.getenv("CHASE_NL2SQL_MODEL")
    env_vars["BQ_DATASET_ID"] = os.getenv("BQ_DATASET_ID")
    env_vars["BQ_PROJECT_ID"] = os.getenv("BQ_PROJECT_ID")
    env_vars["BQML_RAG_CORPUS_NAME"] = os.getenv("BQML_RAG_CORPUS_NAME")
    env_vars["CODE_INTERPRETER_EXTENSION_NAME"] = os.getenv(
        "CODE_INTERPRETER_EXTENSION_NAME")
    env_vars["NL2SQL_METHOD"] = os.getenv("NL2SQL_METHOD")

    logger.info("Using PROJECT: %s", project_id)
    logger.info("Using LOCATION: %s", location)
    logger.info("Using BUCKET NAME: %s", bucket_name)

    # --- Input Validation ---
    if not project_id:
        print("\nError: Missing required GCP Project ID.")
        print(
            "Set the GOOGLE_CLOUD_PROJECT environment variable or use --project_id flag."
        )
        return
    if not location:
        print("\nError: Missing required GCP Location.")
        print(
            "Set the GOOGLE_CLOUD_LOCATION environment variable or use --location flag."
        )
        return
    if not bucket_name:
        print("\nError: Missing required GCS Bucket Name.")
        print(
            "Set the GOOGLE_CLOUD_STORAGE_BUCKET environment variable or use --bucket flag."
        )
        return
    if not FLAGS.create and not FLAGS.delete:
        print("\nError: You must specify either --create or --delete flag.")
        return
    if FLAGS.delete and not FLAGS.resource_id:
        print(
            "\nError: --resource_id is required when using the --delete flag."
        )
        return
    # --- End Input Validation ---

    # Validate configuration
    if FLAGS.dry_run:
        logger.info("\n🔍 Running in DRY RUN mode - no actual GCP resources will be created/deleted\n")
    
    config_valid = validate_configuration(project_id, location, bucket_name, env_vars, deploy_config)
    
    if not config_valid and not FLAGS.dry_run:
        logger.error("\n❌ Configuration validation failed. Fix the issues above before proceeding.")
        logger.info("💡 Tip: Use --dry_run flag to test your configuration without deploying.")
        return
    elif not config_valid and FLAGS.dry_run:
        logger.warning("\n⚠️  Configuration has issues, but continuing with dry run...")

    try:
        # Setup staging bucket
        staging_bucket_uri=None
        if FLAGS.create:
            staging_bucket_uri = setup_staging_bucket(
                project_id, location, bucket_name, dry_run=FLAGS.dry_run
            )

        # Initialize Vertex AI *after* bucket setup and validation
        if not FLAGS.dry_run:
            vertexai.init(
                project=project_id,
                location=location,
                staging_bucket=staging_bucket_uri, # Stagin is passed directly to create/update methods
            )
        else:
            logger.info("[DRY RUN] Would initialize Vertex AI with:")
            logger.info("  - Project: %s", project_id)
            logger.info("  - Location: %s", location)
            logger.info("  - Staging bucket: %s", staging_bucket_uri)

        if FLAGS.create:
            create(env_vars, deploy_config, dry_run=FLAGS.dry_run)
        elif FLAGS.delete:
            delete(FLAGS.resource_id, dry_run=FLAGS.dry_run)

    except google_exceptions.Forbidden as e:
        print(
            "Permission Error: Ensure the service account/user has necessary "
            "permissions (e.g., Storage Admin, Vertex AI User)."
            f"\nDetails: {e}"
        )
    except FileNotFoundError as e:
        print(f"\nFile Error: {e}")
        print(
            "Please ensure the agent wheel file exists in the 'deployment' "
            "directory and you have run the build script "
            "(e.g., poetry build --format=wheel --output=deployment')."
        )
    except Exception as e:
        print(f"\nAn unexpected error occurred: {e}")
        logger.exception(
            "Unhandled exception in main:"
        )  # Log the full traceback


if __name__ == "__main__":

    app.run(main)
