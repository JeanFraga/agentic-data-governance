#!/usr/bin/env python3
"""
Entrypoint script to load environment variables from .env file before starting the ADK web server.
"""

import os
import sys
from pathlib import Path

# Load environment variables from .env file if it exists
env_file = Path(".env")
if env_file.exists():
    try:
        from dotenv import load_dotenv
        load_dotenv(dotenv_path=env_file, override=True)
        print(f"Loaded environment variables from {env_file}")
    except ImportError:
        # If dotenv is not available, manually parse the .env file
        print("python-dotenv not available, manually parsing .env file")
        with open(env_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    # Remove quotes if present
                    value = value.strip("'\"")
                    os.environ[key.strip()] = value
                    print(f"Set {key.strip()}={value}")
else:
    print(f"No .env file found at {env_file}")

# Import and run the ADK web command
if __name__ == "__main__":
    import subprocess
    
    # Run adk web with the specified arguments
    cmd = ["adk", "web", "--host", "0.0.0.0", "--port", "8000"]
    print(f"Starting ADK web server: {' '.join(cmd)}")
    subprocess.run(cmd)
