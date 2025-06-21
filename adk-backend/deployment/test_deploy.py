#!/usr/bin/env python3
"""Test script for deployment without actually deploying to GCP."""

import subprocess
import sys
import os
from pathlib import Path
import json

def run_deployment_test(test_name: str, args: list[str]) -> bool:
    """Run a deployment test with given arguments."""
    print(f"\n{'='*60}")
    print(f"Running test: {test_name}")
    print(f"{'='*60}")
    
    cmd = [sys.executable, "deploy.py"] + args + ["--dry_run"]
    print(f"Command: {' '.join(cmd)}")
    print()
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
        print(result.stdout)
        if result.stderr:
            print("STDERR:", result.stderr)
        
        success = result.returncode == 0
        print(f"\nTest {'PASSED' if success else 'FAILED'}: {test_name}")
        return success
    except Exception as e:
        print(f"Error running test: {e}")
        return False

def main():
    """Run various deployment test scenarios."""
    # Change to deployment directory
    deployment_dir = Path(__file__).parent
    os.chdir(deployment_dir)
    
    # Test scenarios
    tests = [
        # Test 1: Create with minimal flags
        ("Create with minimal flags", [
            "--create",
            "--project_id", "test-project",
            "--location", "us-central1"
        ]),
        
        # Test 2: Create with all flags
        ("Create with all flags", [
            "--create",
            "--project_id", "test-project",
            "--location", "us-central1",
            "--bucket", "test-bucket",
            "--environment", "staging"
        ]),
        
        # Test 3: Delete operation
        ("Delete operation", [
            "--delete",
            "--resource_id", "projects/test-project/locations/us-central1/reasoningEngines/test-engine",
            "--project_id", "test-project",
            "--location", "us-central1"
        ]),
        
        # Test 4: Missing required flags
        ("Missing required flags", [
            "--create"
        ]),
        
        # Test 5: Development environment
        ("Development environment", [
            "--create",
            "--project_id", "test-project",
            "--location", "us-central1",
            "--environment", "development"
        ]),
    ]
    
    # Run tests
    results = []
    for test_name, args in tests:
        success = run_deployment_test(test_name, args)
        results.append((test_name, success))
    
    # Summary
    print(f"\n{'='*60}")
    print("TEST SUMMARY")
    print(f"{'='*60}")
    
    passed = sum(1 for _, success in results if success)
    total = len(results)
    
    for test_name, success in results:
        status = "✓ PASSED" if success else "✗ FAILED"
        print(f"{status}: {test_name}")
    
    print(f"\nTotal: {passed}/{total} tests passed")
    
    # Check for dry run metadata
    metadata_path = deployment_dir / "deployment_metadata_dryrun.json"
    if metadata_path.exists():
        print(f"\nDry run metadata saved to: {metadata_path}")
        with open(metadata_path, "r") as f:
            metadata = json.load(f)
        print("Last dry run info:")
        print(f"  - Environment: {metadata.get('environment')}")
        print(f"  - Timestamp: {metadata.get('deployed_at')}")
        print(f"  - Resource name: {metadata.get('resource_name')}")

if __name__ == "__main__":
    main()
