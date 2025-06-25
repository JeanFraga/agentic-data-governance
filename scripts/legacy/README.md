# Legacy Scripts

This folder contains scripts that have been superseded by the unified `adk-mgmt.sh` script or are no longer actively maintained.

## Moved Scripts

### `deploy-gke-production.sh`
- **Status**: Empty file, superseded by `adk-mgmt.sh deploy production`
- **Replacement**: Use `./adk-mgmt.sh deploy production`

### `migrate.sh` & `migrate_new.sh`
- **Status**: Migration helper scripts for transitioning to unified management
- **Replacement**: Direct use of `adk-mgmt.sh` commands

### `oauth-setup-instructions.sh`
- **Status**: OAuth setup helper
- **Replacement**: Use `./adk-mgmt.sh oauth setup`

### `validate-production.sh`
- **Status**: Production validation helper
- **Replacement**: Use `./adk-mgmt.sh test all` or `./adk-mgmt.sh status`

## Current Active Scripts

The following scripts in the parent directory are actively maintained:

- `adk-mgmt.sh` - **Main unified management script**
- `build-with-cloudbuild.sh` - Cloud Build helper (used by adk-mgmt.sh)
- `common.sh` - Shared utility functions

## Migration Guide

If you were using any of the legacy scripts, here are the equivalent commands:

```bash
# Legacy -> New
./deploy-gke-production.sh           -> ./adk-mgmt.sh deploy production
./oauth-setup-instructions.sh       -> ./adk-mgmt.sh oauth setup
./validate-production.sh            -> ./adk-mgmt.sh test all
```

## Major Changes

### Cloud Build Integration
The production deployment now uses **Google Cloud Build** instead of local Docker builds by default:

- ✅ **New (Default)**: `./adk-mgmt.sh build images` - Uses Cloud Build
- ✅ **Explicit**: `./adk-mgmt.sh build cloudbuild` - Uses Cloud Build
- ⚠️ **Legacy**: `./adk-mgmt.sh build legacy` - Uses local Docker (deprecated)

### Benefits of Cloud Build
- 🚀 **Faster builds** - No local Docker daemon required
- 🔒 **More secure** - Builds run in Google's secure environment
- 📊 **Better logging** - Centralized build logs in Google Cloud
- 🌐 **Consistent environment** - Same build environment for all developers
- 💾 **Resource efficient** - No local disk space or CPU usage

### Infrastructure Management
All infrastructure provisioning is now managed by Terraform, including:
- Cloud Build API enablement
- IAM roles for Cloud Build service account
- Artifact Registry permissions
- Build service configuration

## Backwards Compatibility

The legacy local Docker build functionality is preserved but deprecated:

```bash
# Still works but shows deprecation warning
./adk-mgmt.sh build legacy
```

## Future Plans

These legacy scripts may be removed in future versions. Please migrate to using the unified `adk-mgmt.sh` script.
