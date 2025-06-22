#!/bin/bash

# Simple Environment Variables Check
# Verifies that .env file exists and contains required variables

ENV_FILE=".env"

echo "🔍 Environment Variables Check"
echo "=============================="

if [ ! -f "$ENV_FILE" ]; then
    echo "❌ .env file not found"
    echo "Please copy .env.example to .env and fill in your values"
    exit 1
fi

echo "✅ .env file found"
echo ""

echo "📋 Environment variables in .env:"
while IFS='=' read -r key value; do
    # Skip comments and empty lines
    if [[ ! $key =~ ^#.*$ ]] && [[ -n $key ]]; then
        if [[ $key == *"SECRET"* ]] || [[ $key == *"KEY"* ]] || [[ $key == *"PASSWORD"* ]]; then
            echo "   $key=***MASKED***"
        else
            echo "   $key=$value"
        fi
    fi
done < "$ENV_FILE"

echo ""
echo "✅ Ready to deploy with: ./deploy-secure.sh"
