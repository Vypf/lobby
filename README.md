# Lobby Server & Spawner API

A Godot 4.5 multiplayer lobby system with two Docker images:
- **Lobby Server**: WebSocket server managing client connections and lobby creation
- **Spawner API**: HTTP API for spawning and managing game instance containers

## Architecture

```
┌──────────────┐     WebSocket      ┌──────────────┐      HTTP       ┌──────────────┐
│              │ <────────────────> │              │ ──────────────> │              │
│ Game Clients │                    │ Lobby Server │                 │ Spawner API  │
│              │                    │              │ <────────────── │              │
└──────────────┘                    └──────────────┘    Response     └──────────────┘
																			  │
																			  │ Docker
																			  ↓
																	  ┌──────────────┐
																	  │Game Container│
																	  │  (game-CODE) │
																	  └──────────────┘
```

**Components:**
- **Lobby Server**: Central WebSocket server that manages lobby creation and client connections
- **Spawner API**: HTTP service that spawns Docker containers for game instances
- **Game Clients**: Connect to the lobby server to create or join lobbies
- **Game Containers**: Docker containers running game instances (managed via Spawner API)

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

This project provides two Docker images:

### 1. Lobby Server Image

**Build:**
```bash
docker build -t lobby-server -f Dockerfile .
```

**Run:**
```bash
docker run -p 17018:17018 \
  -v $(pwd)/logs:/app/logs \
  ghcr.io/vypf/lobby:latest \
  environment=production \
  log_folder=/app/logs \
  port=17018
```

### 2. Spawner API Image

**Build:**
```bash
docker build -t lobby-spawner -f Dockerfile.spawner .
```

**Run:**
```bash
docker run -p 8080:8080 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ghcr.io/vypf/lobby-spawner:latest
```

**Important:** The spawner needs access to the Docker socket to manage containers.

### Using Pre-built Images from GitHub Container Registry

**Lobby Server:**
```bash
docker pull ghcr.io/vypf/lobby:latest
docker run -p 17018:17018 ghcr.io/vypf/lobby:latest
```

**Spawner API:**
```bash
docker pull ghcr.io/vypf/lobby-spawner:latest
docker run -p 8080:8080 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ghcr.io/vypf/lobby-spawner:latest
```

## API Documentation

For detailed Spawner API documentation, see [API.md](./API.md).

**Spawner API Endpoints:**
- `POST /spawn` - Spawn a new game container
- `DELETE /container` - Remove a game container

## Publishing to GHCR

Both images are automatically built and published to GitHub Container Registry on:
- Pushes to `main` branch
- Version tags (e.g., `v1.0.0`)

**Published images:**
- `ghcr.io/vypf/lobby:latest` - Lobby Server
- `ghcr.io/vypf/lobby-spawner:latest` - Spawner API

To make packages public:
1. Go to your repository on GitHub
2. Navigate to "Packages" in the right sidebar
3. Click on each package (`lobby` and `lobby-spawner`)
4. Go to "Package settings"
5. Scroll to "Danger Zone"
6. Click "Change visibility" and select "Public"

## Deployment

Docker images are automatically built and published to GitHub Container Registry via the `.github/workflows/docker-publish.yml` workflow on pushes to main and version tags.

The workflow builds both images in parallel:
- **Lobby Server** from `Dockerfile`
- **Spawner API** from `Dockerfile.spawner`
