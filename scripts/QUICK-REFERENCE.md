# 🚀 Quick Reference Card - Unified ADK Management

## 🆕 New Unified Commands

### Essential Commands
```bash
./adk-mgmt.sh env check               # Check environment
./adk-mgmt.sh deploy local            # Deploy locally
./adk-mgmt.sh test all                # Test everything
./adk-mgmt.sh status                  # Show status
```

### Environment & Setup
```bash
./adk-mgmt.sh env setup               # Interactive environment setup
./adk-mgmt.sh domain setup            # Configure custom domain
./adk-mgmt.sh dns setup               # Set up DNS
./adk-mgmt.sh oauth setup             # Configure OAuth
```

### Deployment Options
```bash
./adk-mgmt.sh deploy local            # Local/development
./adk-mgmt.sh deploy production       # GKE production
./adk-mgmt.sh deploy quick            # Quick with auto-setup
./adk-mgmt.sh deploy quota-limited    # Minimal resources
```

### Testing & Validation
```bash
./adk-mgmt.sh test all                # Comprehensive test suite
./adk-mgmt.sh test auth               # Authentication tests
./adk-mgmt.sh test dns                # DNS configuration tests
./adk-mgmt.sh test connectivity       # Network connectivity tests
```

### Backend Development & Stack Management
```bash
./adk-mgmt.sh backend config          # Configure Ollama integration
./adk-mgmt.sh backend start           # Start ADK backend services
./adk-mgmt.sh backend stop            # Stop ADK backend services
./adk-mgmt.sh backend test            # Test backend integration
./adk-mgmt.sh stack start             # Start full Ollama+ADK+OpenWebUI stack
./adk-mgmt.sh stack stop              # Stop full stack
```

### Management & Operations
```bash
./adk-mgmt.sh status                  # Deployment status
./adk-mgmt.sh logs                    # Show logs
./adk-mgmt.sh info                    # Connection information
./adk-mgmt.sh restart                 # Restart services
./adk-mgmt.sh scale 3                 # Scale to 3 replicas
./adk-mgmt.sh cleanup                 # Clean up resources
```

### Troubleshooting
```bash
./adk-mgmt.sh debug                   # Debug information
./adk-mgmt.sh fix oauth               # Fix OAuth issues
./adk-mgmt.sh fix quota               # Quota troubleshooting
```

## 🔄 Quick Workflows

### 🆕 First-Time Setup
```bash
./adk-mgmt.sh env setup               # Setup environment
./adk-mgmt.sh deploy local            # Deploy
./adk-mgmt.sh test all                # Test
```

### 🚀 Production Deployment
```bash
./adk-mgmt.sh env check               # Verify environment
./adk-mgmt.sh dns setup               # Setup DNS
./adk-mgmt.sh deploy production       # Deploy to production
```

### 🧪 Development Cycle
```bash
./adk-mgmt.sh deploy local            # Deploy changes
./adk-mgmt.sh test auth               # Test features
./adk-mgmt.sh restart                 # Restart if needed
```

### � Troubleshooting
```bash
./adk-mgmt.sh status                  # Check status
./adk-mgmt.sh debug                   # Get debug info
./adk-mgmt.sh logs                    # Check logs
```

## � Convenience Wrapper

Use the shorter syntax with `run-script.sh`:

```bash
./run-script.sh env check             # Same as ./adk-mgmt.sh env check
./run-script.sh deploy local          # Same as ./adk-mgmt.sh deploy local
./run-script.sh test all              # Same as ./adk-mgmt.sh test all
```

## 🎛️ Advanced Options

### Custom Configuration
```bash
# Custom namespace
./adk-mgmt.sh deploy local -n my-namespace

# Custom release name
./adk-mgmt.sh deploy local -r my-release

# Custom values file
./adk-mgmt.sh deploy local -f my-values.yaml

# Verbose output
./adk-mgmt.sh deploy local -v
```

### Combining Commands
```bash
# Full workflow
./adk-mgmt.sh env check && ./adk-mgmt.sh deploy local && ./adk-mgmt.sh test all

# Quick troubleshooting
./adk-mgmt.sh status && ./adk-mgmt.sh logs && ./adk-mgmt.sh debug
```

## 🔄 Migration from Legacy Scripts

### Automatic Migration
```bash
./scripts/migrate.sh check-env-simple  # Shows new equivalent command
```

### Common Mappings
| Legacy Script | New Unified Command |
|---------------|-------------------|
| `check-env-simple.sh` | `adk-mgmt.sh env check` |
| `deploy-secure.sh` | `adk-mgmt.sh deploy local` |
| `deploy-gke-production.sh` | `adk-mgmt.sh deploy production` |
| `test-dual-auth.sh` | `adk-mgmt.sh test auth` |
| `setup-domain.sh` | `adk-mgmt.sh domain setup` |

## 🆘 Getting Help

```bash
./adk-mgmt.sh --help                  # Full help system
./scripts/migrate.sh                  # Migration assistance
```

## 🗂️ File Locations

```
scripts/
├── adk-mgmt.sh              # 🆕 Main unified script
├── migrate.sh               # Migration helper
├── common.sh                # Shared functions
└── legacy/                  # Old scripts (backup)
```

## � Pro Tips

- Use `./run-script.sh` for shorter commands
- All legacy scripts are preserved in `scripts/legacy/`
- The unified script has better error handling and help
- Use `-v` flag for verbose output when troubleshooting
- Commands are hierarchical: `command subcommand [options]`
