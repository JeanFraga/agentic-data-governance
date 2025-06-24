#!/bin/bash

# Security Pre-Commit Check
# Run this script before committing to ensure no sensitive information is included

echo "🔒 Running Security Pre-Commit Check..."
echo "================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ISSUES_FOUND=0

# Check for sensitive values in files that would be committed
echo "🔍 Checking for sensitive information..."

# Check for OAuth secrets
OAUTH_CHECK=$(find . -type f \( -name "*.md" -o -name "*.yml" -o -name "*.yaml" -o -name "*.sh" -o -name "*.py" -o -name "*.toml" -o -name "*.json" \) ! -path "./.git/*" ! -path "./adk-backend/.venv/*" ! -path "./terraform/.terraform/*" ! -path "./security-check.sh" | xargs grep -E "(GOCSPX-[A-Za-z0-9_-]{28})" 2>/dev/null)
if [ ! -z "$OAUTH_CHECK" ]; then
    echo -e "${RED}❌ Found OAuth client secret:${NC}"
    echo "$OAUTH_CHECK"
    ISSUES_FOUND=1
fi

# Check for OAuth client IDs
CLIENT_ID_CHECK=$(find . -type f \( -name "*.md" -o -name "*.yml" -o -name "*.yaml" -o -name "*.sh" -o -name "*.py" -o -name "*.toml" -o -name "*.json" \) ! -path "./.git/*" ! -path "./adk-backend/.venv/*" ! -path "./terraform/.terraform/*" ! -path "./security-check.sh" | xargs grep -E "[0-9]{12}-[a-z0-9]{32}\.apps\.googleusercontent\.com" 2>/dev/null)
if [ ! -z "$CLIENT_ID_CHECK" ]; then
    echo -e "${RED}❌ Found OAuth client ID:${NC}"
    echo "$CLIENT_ID_CHECK"
    ISSUES_FOUND=1
fi

# Check for project IDs (specific patterns)
PROJECT_ID_CHECK=$(find . -type f \( -name "*.md" -o -name "*.yml" -o -name "*.yaml" -o -name "*.sh" -o -name "*.py" -o -name "*.toml" -o -name "*.json" \) ! -path "./.git/*" ! -path "./adk-backend/.venv/*" ! -path "./terraform/.terraform/*" ! -path "./security-check.sh" | xargs grep -E "agenticds-hackathon-[0-9]{5}" 2>/dev/null)
if [ ! -z "$PROJECT_ID_CHECK" ]; then
    echo -e "${RED}❌ Found hardcoded project ID:${NC}"
    echo "$PROJECT_ID_CHECK"
    ISSUES_FOUND=1
fi

# Check for personal email
EMAIL_CHECK=$(find . -type f \( -name "*.md" -o -name "*.yml" -o -name "*.yaml" -o -name "*.sh" -o -name "*.py" -o -name "*.toml" -o -name "*.json" \) ! -path "./.git/*" ! -path "./adk-backend/.venv/*" ! -path "./terraform/.terraform/*" ! -path "./security-check.sh" | xargs grep -E "fragajean7@gmail\.com" 2>/dev/null)
if [ ! -z "$EMAIL_CHECK" ]; then
    echo -e "${RED}❌ Found personal email:${NC}"
    echo "$EMAIL_CHECK"
    ISSUES_FOUND=1
fi

# Check for admin password
PASSWORD_CHECK=$(find . -type f \( -name "*.md" -o -name "*.yml" -o -name "*.yaml" -o -name "*.sh" -o -name "*.py" -o -name "*.toml" -o -name "*.json" \) ! -path "./.git/*" ! -path "./adk-backend/.venv/*" ! -path "./terraform/.terraform/*" ! -path "./security-check.sh" | xargs grep -E "secureAdmin123" 2>/dev/null)
if [ ! -z "$PASSWORD_CHECK" ]; then
    echo -e "${RED}❌ Found hardcoded admin password:${NC}"
    echo "$PASSWORD_CHECK"
    ISSUES_FOUND=1
fi

# Check for personal repository references
REPO_CHECK=$(find . -type f \( -name "*.md" -o -name "*.yml" -o -name "*.yaml" -o -name "*.sh" -o -name "*.py" -o -name "*.toml" -o -name "*.json" \) ! -path "./.git/*" ! -path "./adk-backend/.venv/*" ! -path "./terraform/.terraform/*" ! -path "./security-check.sh" | xargs grep -E "JeanFraga/agentic-data-governance" 2>/dev/null)
if [ ! -z "$REPO_CHECK" ]; then
    echo -e "${RED}❌ Found personal repository reference:${NC}"
    echo "$REPO_CHECK"
    ISSUES_FOUND=1
fi

# Check that sensitive files are not being tracked
echo ""
echo "🔍 Checking file protection..."

if [ -f ".env" ] && git ls-files --error-unmatch .env > /dev/null 2>&1; then
    echo -e "${RED}❌ .env file is being tracked by git!${NC}"
    ISSUES_FOUND=1
fi

if [ -f "terraform/terraform.tfvars" ] && git ls-files --error-unmatch terraform/terraform.tfvars > /dev/null 2>&1; then
    echo -e "${RED}❌ terraform.tfvars file is being tracked by git!${NC}"
    ISSUES_FOUND=1
fi

# Summary
echo ""
echo "================================================"
if [ $ISSUES_FOUND -eq 0 ]; then
    echo -e "${GREEN}✅ Security check passed! No sensitive information found.${NC}"
    echo -e "${GREEN}✅ Repository is safe to commit to GitHub.${NC}"
    exit 0
else
    echo -e "${RED}❌ Security check failed! Sensitive information found.${NC}"
    echo -e "${YELLOW}Please remove the sensitive information before committing.${NC}"
    exit 1
fi
