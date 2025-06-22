# Security Guidelines

## Overview
This document outlines security best practices for this project to ensure sensitive information is not committed to version control.

## Sensitive Information Handling

### Environment Variables
- **Never commit actual values** to `.env` files
- Use `.env.example` files with placeholder values
- Keep actual `.env` files local and excluded by `.gitignore`

### Required Environment Variables
Create a local `.env` file with the following variables:

```bash
# Google OAuth Configuration
OAUTH_CLIENT_ID=your-google-client-id.apps.googleusercontent.com
OAUTH_CLIENT_SECRET=your-google-client-secret

# Google Cloud Project Configuration
GCP_PROJECT_ID=your-gcp-project-id

# Admin Configuration
ADMIN_EMAIL=your-admin-email@example.com
ADMIN_PASSWORD=your-secure-admin-password

# Other configurations...
```

### Terraform Variables
- Never commit `terraform.tfvars` files with actual values
- Use `terraform.tfvars.example` as a template
- Set sensitive variables through environment variables or GitHub Secrets

### GitHub Secrets
Configure the following secrets in your GitHub repository settings:

1. `GCP_PROJECT_NUMBER` - Your numeric Google Cloud project number
2. `OAUTH_CLIENT_ID` - Google OAuth Client ID  
3. `OAUTH_CLIENT_SECRET` - Google OAuth Client Secret

### Protected File Patterns
The following patterns are protected by `.gitignore`:

- `.env` (actual environment files)
- `terraform.tfvars` (actual Terraform variables)
- `*.tfstate*` (Terraform state files)
- `*secret*` (any files containing "secret")
- `*credential*` (any files containing "credential")
- `*password*` (any files containing "password")
- `*key*.json` (service account keys)

## Before Committing

### Pre-commit Checklist
- [ ] No hardcoded secrets in any files
- [ ] All example files use placeholder values
- [ ] No personal information (emails, names, project IDs) in templates
- [ ] `.env` files are not tracked
- [ ] `terraform.tfvars` files are not tracked

### Automated Checks
Run these commands before committing:

```bash
# Check for potential secrets
git diff --cached | grep -E "(password|secret|key|token|credential)"

# Ensure sensitive files are not staged
git status --porcelain | grep -E "(\.env$|terraform\.tfvars$)"
```

## Incident Response

If sensitive information is accidentally committed:

1. **Immediately revoke/rotate** all exposed credentials
2. **Remove the sensitive data** from git history using `git filter-branch` or BFG Repo-Cleaner
3. **Force push** the cleaned history
4. **Notify team members** to re-clone the repository

## Contact

For security concerns, contact the repository maintainers immediately.
