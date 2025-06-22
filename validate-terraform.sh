#!/bin/bash

# Terraform Configuration Validation Script
# This script validates the Terraform configuration without applying changes

set -e

echo "🔍 Validating Terraform configuration..."

# Change to terraform directory
cd terraform

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo "⚠️  Warning: terraform.tfvars not found. Creating from example..."
    cp terraform.tfvars.example terraform.tfvars
    echo "📝 Please edit terraform/terraform.tfvars with your actual values before deployment."
fi

# Initialize Terraform
echo "🔧 Initializing Terraform..."
terraform init

# Validate configuration
echo "✅ Validating Terraform syntax..."
terraform validate

# Format check
echo "🎨 Checking Terraform formatting..."
terraform fmt -check

# Plan (dry run)
echo "📋 Running Terraform plan..."
terraform plan

echo "✅ Terraform configuration is valid!"
echo ""
echo "Next steps:"
echo "1. Update terraform/terraform.tfvars with your actual values"
echo "2. Run 'terraform apply' to deploy the infrastructure"
echo "3. Configure DNS to point to the ingress IP address"
