#!/bin/bash

# Quick script runner for Agentic Data Governance
# Usage: ./run-script.sh <command> [args...]

set -e

# Check for the new unified script first
if [ -f "./scripts/adk-mgmt.sh" ]; then
    echo "🚀 Using Unified ADK Management Script"
    echo "======================================"
    echo ""
    
    if [ $# -eq 0 ]; then
        echo "💡 The scripts have been consolidated into a unified management tool!"
        echo ""
        echo "Quick commands:"
        echo "  ./run-script.sh env check          - Check environment"
        echo "  ./run-script.sh deploy local       - Deploy locally"
        echo "  ./run-script.sh test all           - Run all tests"
        echo "  ./run-script.sh status             - Show status"
        echo ""
        echo "� For full help:"
        ./scripts/adk-mgmt.sh --help
        exit 0
    fi
    
    # Pass all arguments to the unified script
    exec ./scripts/adk-mgmt.sh "$@"
fi

# Legacy support - if someone still tries to use old script names
SCRIPT_NAME="$1"
SCRIPTS_DIR="./scripts"

# Check if it's a legacy script name and redirect to migration helper
if [ -n "$SCRIPT_NAME" ] && [ -f "$SCRIPTS_DIR/legacy/$SCRIPT_NAME.sh" ]; then
    echo "⚠️  Script '$SCRIPT_NAME' has been moved to legacy/"
    echo "🔄 Checking for unified equivalent..."
    exec ./scripts/migrate.sh "$SCRIPT_NAME"
fi

# Check if script exists in legacy directory
SCRIPT_PATH="$SCRIPTS_DIR/legacy/$SCRIPT_NAME.sh"

if [ ! -f "$SCRIPT_PATH" ]; then
    echo "❌ Script '$SCRIPT_NAME.sh' not found"
    echo ""
    echo "💡 Try the new unified commands:"
    echo "   ./run-script.sh env check"
    echo "   ./run-script.sh deploy local" 
    echo "   ./run-script.sh test all"
    echo ""
    echo "📖 For full help: ./run-script.sh"
    exit 1
fi

# Make script executable if it isn't
if [ ! -x "$SCRIPT_PATH" ]; then
    chmod +x "$SCRIPT_PATH"
fi

# Shift the script name out of arguments
shift

# Run the legacy script with remaining arguments
echo "🚀 Running legacy script: $SCRIPT_NAME.sh $*"
echo ""
exec "$SCRIPT_PATH" "$@"
