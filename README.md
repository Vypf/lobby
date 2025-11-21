# Lobby Server

A Godot 4.5 multiplayer lobby server that dynamically spawns game instances. The lobby server manages WebSocket connections and creates separate Godot processes for each active lobby.

## Architecture

```
┌──────────────┐         WebSocket          ┌──────────────┐
│              │ <────────────────────────> │              │
│ Game Clients │                             │ Lobby Server │
│              │                             │              │
└──────────────┘                             └──────────────┘
                                                     │
                                                     │ Spawns
                                                     ↓
                                             ┌──────────────┐
                                             │ Game Instance│
                                             └──────────────┘
```

**Components:**
- **Lobby Server**: Central WebSocket server that manages lobby creation and client connections
- **Game Clients**: Connect to the lobby server to create or join lobbies
- **Game Instances**: Separate Godot processes for each active lobby

## Quick Start

### Prerequisites

- Godot 4.5 (headless or standard)
- Git with submodules support

### Local Setup

Clone the repository with submodules:

```bash
git clone --recursive https://github.com/Vypf/lobby.git
cd lobby
```

### Running Locally

Example command:

```bash
godot --headless -- \
  environment=development \
  log_folder=./logs \
  executable_paths=space-chicken=/path/to/Godot.exe \
  paths=space-chicken=/path/to/game \
  port=17018
```

### Command-line Arguments

- `environment` (string): `development` or `production` (default: `development`)
- `port` (int): Server port (default: `17018`)
- `log_folder` (string): Directory for lobby instance logs
- `executable_paths` (dictionary): Mapping of game names to Godot executable paths (development mode)
- `paths` (dictionary): Mapping of game names to project root paths

**Example with multiple games:**

```bash
godot --headless -- \
  environment=development \
  log_folder=./logs \
  executable_paths game1=/path/to/Godot.exe game2=/path/to/Godot.exe \
  paths game1=/path/to/game1 game2=/path/to/game2 \
  port=17018
```

## Docker

### Building the Image

```bash
docker build -t lobby-server .
```

### Running with Docker

Basic usage:

```bash
docker run -p 17018:17018 lobby-server
```

With custom arguments:

```bash
docker run -p 17018:17018 \
  -v $(pwd)/logs:/app/logs \
  lobby-server \
  environment=production \
  log_folder=/app/logs \
  port=17018
```

### Using Pre-built Images from GitHub Container Registry

Pull the latest image:

```bash
docker pull ghcr.io/vypf/lobby:latest
```

Run the pre-built image:

```bash
docker run -p 17018:17018 ghcr.io/vypf/lobby:latest
```

### Publishing to GHCR

Images are automatically built and published to GitHub Container Registry on:
- Pushes to `main` branch
- Version tags (e.g., `v1.0.0`)

To make the package public:
1. Go to your repository on GitHub
2. Navigate to "Packages" in the right sidebar
3. Click on the `lobby` package
4. Go to "Package settings"
5. Scroll to "Danger Zone"
6. Click "Change visibility" and select "Public"

## Deployment

Docker images are automatically built and published to GitHub Container Registry via the `.github/workflows/docker-publish.yml` workflow on pushes to main and version tags.
