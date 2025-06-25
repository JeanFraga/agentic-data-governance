#!/bin/bash

# Terraform Environment Manager
# This script helps manage separate Terraform state files for local and production environments

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 <environment> <terraform-command> [args...]"
    echo ""
    echo "Environments:"
    echo "  local      - Use local Docker Desktop deployment (isolated state)"
    echo "  production - Use production GCP deployment (isolated state)"
    echo ""
    echo "Examples:"
    echo "  $0 local plan"
    echo "  $0 local apply"
    echo "  $0 production plan -var-file=terraform.tfvars.production"
    echo "  $0 production apply -var-file=terraform.tfvars.production"
    echo ""
    echo "The script will automatically:"
    echo "  - Use the appropriate backend configuration"
    echo "  - Use the appropriate variable file"
    echo "  - Ensure state isolation between environments"
}

if [ $# -lt 2 ]; then
    usage
    exit 1
fi

ENVIRONMENT="$1"
shift
TERRAFORM_CMD="$1"
shift

# Validate environment
if [[ "$ENVIRONMENT" != "local" && "$ENVIRONMENT" != "production" ]]; then
    echo -e "${RED}Error: Environment must be 'local' or 'production'${NC}"
    usage
    exit 1
fi

# Set environment-specific configurations
if [ "$ENVIRONMENT" = "local" ]; then
    BACKEND_CONFIG="backend-local.tf"
    VAR_FILE="terraform.tfvars.local"
    STATE_FILE="terraform-local.tfstate"
    echo -e "${BLUE}🏠 Using LOCAL environment configuration${NC}"
    echo -e "${YELLOW}   Backend: Local state file (${STATE_FILE})${NC}"
    echo -e "${YELLOW}   Variables: ${VAR_FILE}${NC}"
else
    BACKEND_CONFIG="backend-production.tf"
    VAR_FILE="terraform.tfvars.production"
    STATE_FILE="terraform-production.tfstate"
    echo -e "${GREEN}🚀 Using PRODUCTION environment configuration${NC}"
    echo -e "${YELLOW}   Backend: Local state file (${STATE_FILE})${NC}"
    echo -e "${YELLOW}   Variables: ${VAR_FILE}${NC}"
fi

# Ensure backend config exists
if [ ! -f "$BACKEND_CONFIG" ]; then
    echo -e "${RED}Error: Backend configuration file $BACKEND_CONFIG not found${NC}"
    exit 1
fi

# Ensure variable file exists
if [ ! -f "$VAR_FILE" ]; then
    echo -e "${RED}Error: Variable file $VAR_FILE not found${NC}"
    exit 1
fi

# Copy the appropriate backend configuration to the main terraform configuration
echo -e "${BLUE}Setting up backend configuration...${NC}"
cp "$BACKEND_CONFIG" backend.tf

# Initialize terraform if needed (when backend changes or first time)
if [ ! -f ".terraform/terraform.tfstate" ] || [ "$TERRAFORM_CMD" = "init" ]; then
    echo -e "${BLUE}Initializing Terraform...${NC}"
    terraform init -reconfigure
fi

# Build terraform command with appropriate arguments
TERRAFORM_ARGS=()

# Add variable file if not already specified in arguments
VAR_FILE_SPECIFIED=false
for arg in "$@"; do
    if [[ $arg == -var-file* ]]; then
        VAR_FILE_SPECIFIED=true
        break
    fi
done

if [ "$VAR_FILE_SPECIFIED" = false ]; then
    TERRAFORM_ARGS+=("-var-file=$VAR_FILE")
fi

# Add user-provided arguments
TERRAFORM_ARGS+=("$@")

# Safety check for production
if [ "$ENVIRONMENT" = "production" ]; then
    echo -e "${RED}⚠️  WARNING: You are about to run Terraform against PRODUCTION environment!${NC}"
    echo -e "${YELLOW}This will affect real GCP resources and may incur costs.${NC}"
    read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirm
    if [ "$confirm" != "yes" ]; then
        echo -e "${YELLOW}Operation cancelled.${NC}"
        exit 0
    fi
fi

# Run terraform command
echo -e "${BLUE}Running: terraform $TERRAFORM_CMD ${TERRAFORM_ARGS[*]}${NC}"
terraform "$TERRAFORM_CMD" "${TERRAFORM_ARGS[@]}"

# Cleanup
rm -f backend.tf

echo -e "${GREEN}✅ Terraform operation completed successfully${NC}"
