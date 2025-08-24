# Kokoro-FastAPI NixOS Module

A NixOS module that automatically fetches, sets up, and runs [Kokoro-FastAPI](https://github.com/remsky/Kokoro-FastAPI) as a system service.

## About Kokoro-FastAPI

Kokoro-FastAPI is a Dockerized text-to-speech (TTS) API wrapper for the Kokoro-82M model that provides:

- OpenAI-compatible speech generation endpoint
- Multi-language TTS support (English, Japanese, Chinese)
- GPU and CPU inference modes
- Voice combination with weighted ratios
- Multiple audio output formats (mp3, wav, opus, flac)
- Streaming audio generation
- Word-level timestamped captions

## Features

- Automatically clones and updates Kokoro-FastAPI repository to latest version
- Configures Docker and docker-compose environment at system level
- Creates system-wide systemd service for automatic startup and management
- Supports both CPU and GPU inference modes
- Configurable port and environment variables
- Optional firewall configuration for network access
- Runs as dedicated system user for security isolation
- Automatic service restart on failure
- System-wide package installation

## Installation

### Method 1: Using Flakes (Recommended)

Add this flake as an input to your NixOS configuration:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    kokoro-fastapi-nix = {
      url = "github:mndfcked/kokoro-fastapi-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, kokoro-fastapi-nix, ... }: {
    nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        kokoro-fastapi-nix.nixosModules.default
        {
          services.kokoro-fastapi = {
            enable = true;
            port = 8880;
            useGpu = false;
            openFirewall = true;
          };
        }
      ];
    };
  };
}
```

### Method 2: Direct Import

Clone this repository and import the module directly into your NixOS configuration:

```nix
{ config, pkgs, ... }:
{
  imports = [ /path/to/kokoro-fastapi-nix/kokoro-fastapi.nix ];
  
  services.kokoro-fastapi = {
    enable = true;
    port = 8880;
    openFirewall = true;
  };
}
```

## Configuration Options

### Basic Options

- `enable` (boolean, default: false) - Enable the Kokoro-FastAPI service
- `port` (integer, default: 8880) - Port on which the service will listen
- `useGpu` (boolean, default: false) - Enable GPU acceleration (requires NVIDIA GPU)
- `openFirewall` (boolean, default: false) - Open firewall port for local network access

### Advanced Options

- `dataDir` (string, default: "/var/lib/kokoro-fastapi") - Directory for data and repository storage
- `user` (string, default: "kokoro-fastapi") - User to run the service under
- `group` (string, default: "kokoro-fastapi") - Group to run the service under
- `environment` (attribute set) - Environment variables for ONNX configuration

### Default Environment Variables

The module sets these ONNX optimization variables by default:

```nix
environment = {
  ONNX_NUM_THREADS = "8";
  ONNX_INTER_OP_THREADS = "4";
  ONNX_EXECUTION_MODE = "parallel";
  ONNX_OPTIMIZATION_LEVEL = "all";
  ONNX_MEMORY_PATTERN = "true";
  ONNX_ARENA_EXTEND_STRATEGY = "kNextPowerOfTwo";
};
```

## Usage Examples

### Basic CPU Configuration

```nix
services.kokoro-fastapi = {
  enable = true;
  port = 8880;
  openFirewall = true;
};
```

### GPU-Enabled Configuration

```nix
services.kokoro-fastapi = {
  enable = true;
  port = 8880;
  useGpu = true;
  openFirewall = true;
  environment = {
    ONNX_NUM_THREADS = "16";
    ONNX_INTER_OP_THREADS = "8";
  };
};
```

### Custom Data Directory

```nix
services.kokoro-fastapi = {
  enable = true;
  dataDir = "/home/user/kokoro-data";
  user = "user";
  group = "users";
};
```

## Service Management

After enabling the module and rebuilding your NixOS configuration:

### Basic Commands

```bash
# Start the service
systemctl start kokoro-fastapi

# Stop the service
systemctl stop kokoro-fastapi

# Enable automatic startup on boot
systemctl enable kokoro-fastapi

# Disable automatic startup
systemctl disable kokoro-fastapi

# Restart the service (updates to latest repository version)
systemctl restart kokoro-fastapi

# Check service status
systemctl status kokoro-fastapi

# View real-time logs
journalctl -u kokoro-fastapi -f

# View recent logs
journalctl -u kokoro-fastapi -n 50
```

## Accessing the Service

Once the service is running, you can access:

- **API Endpoint**: http://localhost:8880
- **API Documentation**: http://localhost:8880/docs
- **Interactive Web Interface**: http://localhost:8880/web

### Example API Usage

Generate speech using curl:

```bash
curl -X POST "http://localhost:8880/v1/audio/speech" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "kokoro",
    "input": "Hello, this is a test of the Kokoro text-to-speech system.",
    "voice": "af_bella"
  }' \
  --output speech.mp3
```

Available voices include:
- af_bella, af_nicole, af_sarah, af_sky
- am_adam, am_michael
- bf_emma, bf_isabella
- bm_george, bm_lewis

## GPU Support

### Requirements

- NVIDIA GPU with CUDA support
- NVIDIA Docker runtime installed
- Sufficient GPU memory (varies by model)

### Setup

1. Install NVIDIA Docker runtime on your system
2. Set `useGpu = true` in your configuration
3. Rebuild your NixOS configuration
4. Restart the service

```nix
services.kokoro-fastapi = {
  enable = true;
  useGpu = true;
  openFirewall = true;
};
```

### Performance

- CPU Mode: Standard processing speed
- GPU Mode: Approximately 35x-100x realtime speed (depending on hardware)

## Troubleshooting

### Service Won't Start

Check Docker status:
```bash
systemctl status docker
```

Verify user permissions:
```bash
groups kokoro-fastapi
```

Check service logs:
```bash
sudo journalctl -u kokoro-fastapi -f
```

### Port Already in Use

Find what's using the port:
```bash
sudo netstat -tlnp | grep 8880
```

Change port in configuration:
```nix
services.kokoro-fastapi.port = 8881;
```

### Repository Update Issues

The service automatically updates to the latest version on restart. To force an update:
```bash
systemctl restart kokoro-fastapi
```

### GPU Not Detected

Verify NVIDIA Docker runtime:
```bash
docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi
```

Check GPU availability:
```bash
nvidia-smi
```

### Memory Issues

For systems with limited RAM, adjust ONNX thread settings:
```nix
services.kokoro-fastapi.environment = {
  ONNX_NUM_THREADS = "4";
  ONNX_INTER_OP_THREADS = "2";
};
```

### Container Build Failures

Clean Docker cache and rebuild:
```bash
docker system prune -a
systemctl restart kokoro-fastapi
```

## Development

To contribute to this module or test changes:

```bash
# Clone the repository
git clone https://github.com/mndfcked/kokoro-fastapi-nix.git
cd kokoro-fastapi-nix

# Enter development shell
nix develop

# Test the module
nix flake check
```

## Requirements

- NixOS system with flakes enabled
- Docker support (automatically configured by the module)
- Internet connection for initial repository clone
- For GPU: NVIDIA GPU with CUDA support and NVIDIA Docker runtime

## License

This module is provided as-is and follows the same licensing terms as the original Kokoro-FastAPI project.

## Contributing

Issues and pull requests are welcome at https://github.com/mndfcked/kokoro-fastapi-nix

For issues with the underlying Kokoro-FastAPI service, please report them at the upstream repository: https://github.com/remsky/Kokoro-FastAPI