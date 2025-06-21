# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Deployment configuration management for data science agent."""

import os
from pathlib import Path
from typing import Dict, Optional, Any
import json

import toml


class VersionManager:
    """Handles version detection from various sources."""
    
    @staticmethod
    def get_project_version() -> str:
        """Read version from pyproject.toml or environment."""
        # First try environment variable
        env_version = os.getenv("AGENT_VERSION")
        if env_version:
            return env_version
            
        # Then try pyproject.toml
        pyproject_path = Path(__file__).parent.parent.parent / "pyproject.toml"
        if pyproject_path.exists():
            try:
                with open(pyproject_path, "r", encoding='UTF-8') as f:
                    data = toml.load(f)
                    return data["tool"]["poetry"]["version"]
            except (KeyError, toml.TomlDecodeError) as e:
                print(f"Warning: Could not read version from pyproject.toml: {e}")
        
        # Fallback version
        return "0.1.0"


class DeployConfig:
    """Manages deployment configuration with validation and flexibility."""
    
    DEFAULT_CONFIG = {
        "wheel": {
            "package_name": "data_science_agent",  # More descriptive name
            "python_tag": "py3",
            "abi_tag": "none",
            "platform_tag": "any"
        },
        "deployment": {
            "enable_tracing": False,
            "timeout_seconds": 3600,
            "memory": "2Gi",
            "cpu": "2"
        },
        "environment": "production"
    }
    
    def __init__(self, config_file: Optional[Path] = None, environment: str = "production"):
        """
        Initialize deployment configuration.
        
        Args:
            config_file: Optional path to configuration file
            environment: Deployment environment (production, staging, development)
        """
        self.environment = environment
        self.config = self._load_config(config_file)
        self.config["wheel"]["version"] = VersionManager.get_project_version()
        self._validate_config()
    
    def _load_config(self, config_file: Optional[Path]) -> Dict[str, Any]:
        """Load configuration from file or use defaults."""
        config = self.DEFAULT_CONFIG.copy()
        
        if config_file and config_file.exists():
            try:
                with open(config_file, "r", encoding='UTF-8') as f:
                    if config_file.suffix == ".json":
                        file_config = json.load(f)
                    elif config_file.suffix == ".toml":
                        file_config = toml.load(f)
                    else:
                        raise ValueError(f"Unsupported config file format: {config_file.suffix}")
                
                # Deep merge configurations
                self._merge_configs(config, file_config)
            except Exception as e:
                print(f"Warning: Could not load config from {config_file}: {e}")
        
        # Apply environment-specific overrides
        env_overrides = self._get_environment_overrides()
        self._merge_configs(config, env_overrides)
        
        return config
    
    def _merge_configs(self, base: Dict[str, Any], override: Dict[str, Any]) -> None:
        """Deep merge override config into base config."""
        for key, value in override.items():
            if key in base and isinstance(base[key], dict) and isinstance(value, dict):
                self._merge_configs(base[key], value)
            else:
                base[key] = value
    
    def _get_environment_overrides(self) -> Dict[str, Any]:
        """Get environment-specific configuration overrides."""
        overrides = {
            "development": {
                "deployment": {
                    "enable_tracing": True,
                    "memory": "1Gi",
                    "cpu": "1"
                }
            },
            "staging": {
                "deployment": {
                    "enable_tracing": True,
                    "memory": "2Gi",
                    "cpu": "2"
                }
            },
            "production": {
                "deployment": {
                    "enable_tracing": False,
                    "memory": "4Gi",
                    "cpu": "4"
                }
            }
        }
        return overrides.get(self.environment, {})
    
    def _validate_config(self) -> None:
        """Validate the configuration."""
        # Validate wheel configuration
        wheel_config = self.config.get("wheel", {})
        required_wheel_fields = ["package_name", "version", "python_tag", "abi_tag", "platform_tag"]
        for field in required_wheel_fields:
            if field not in wheel_config:
                raise ValueError(f"Missing required wheel configuration field: {field}")
        
        # Validate version format
        version = wheel_config["version"]
        if not version or not isinstance(version, str):
            raise ValueError(f"Invalid version: {version}")
        
        # Validate deployment configuration
        deployment_config = self.config.get("deployment", {})
        if "memory" in deployment_config:
            memory = deployment_config["memory"]
            if not memory.endswith(("Mi", "Gi")):
                raise ValueError(f"Invalid memory format: {memory}. Use format like '2Gi' or '512Mi'")
    
    def get_wheel_filename(self) -> str:
        """
        Generate wheel filename from configuration.
        
        Returns:
            Formatted wheel filename following PEP 427 naming convention
        """
        wheel_config = self.config["wheel"]
        return (
            f"{wheel_config['package_name']}-"
            f"{wheel_config['version']}-"
            f"{wheel_config['python_tag']}-"
            f"{wheel_config['abi_tag']}-"
            f"{wheel_config['platform_tag']}.whl"
        )
    
    def get_wheel_path(self) -> Path:
        """Get the full path to the wheel file."""
        deployment_dir = Path(__file__).parent.parent
        return deployment_dir / self.get_wheel_filename()
    
    def get_deployment_config(self) -> Dict[str, Any]:
        """Get deployment-specific configuration."""
        return self.config.get("deployment", {})
    
    def to_dict(self) -> Dict[str, Any]:
        """Return the full configuration as a dictionary."""
        return self.config
    
    def save_config(self, output_path: Path) -> None:
        """Save the current configuration to a file."""
        with open(output_path, "w", encoding='UTF-8') as f:
            if output_path.suffix == ".json":
                json.dump(self.config, f, indent=2)
            elif output_path.suffix == ".toml":
                toml.dump(self.config, f)
            else:
                raise ValueError(f"Unsupported output format: {output_path.suffix}")


# Convenience function for backward compatibility
def get_wheel_filename(config: Dict[str, Any]) -> str:
    """Legacy function to get wheel filename from config dict."""
    deploy_config = DeployConfig()
    deploy_config.config = config
    return deploy_config.get_wheel_filename()


if __name__ == "__main__":
    # Example usage
    config = DeployConfig(environment="production")
    print("Deployment Configuration:")
    print(json.dumps(config.to_dict(), indent=2))
    print(f"\nWheel filename: {config.get_wheel_filename()}")
    print(f"Wheel path: {config.get_wheel_path()}")
