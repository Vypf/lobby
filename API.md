# Spawner API Documentation

The Spawner API manages Docker containers for game instances. It provides HTTP endpoints to spawn and remove game containers dynamically.

## Architecture

```
┌──────────────┐         HTTP          ┌──────────────┐
│              │ ─────────────────────> │              │
│ Lobby Server │                        │ Spawner API  │
│              │ <───────────────────── │              │
└──────────────┘      Response          └──────────────┘
                                               │
                                               │ Docker API
                                               ↓
                                        ┌──────────────┐
                                        │ Docker Engine│
                                        └──────────────┘
                                               │
                                               │ Spawns/Manages
                                               ↓
                                        ┌──────────────┐
                                        │Game Container│
                                        │(game-CODE)   │
                                        └──────────────┘
```

## Base URL

```
http://localhost:8080
```

## Endpoints

### POST /spawn

Spawns a new game container.

#### Request

**Headers:**
```
Content-Type: application/json
```

**Body:**
```json
{
  "game": "space-chicken",
  "code": "ABCDEF",
  "params": {
    "image": "ghcr.io/vypf/space-chicken:latest",
    "port": "18547",
    "environment": "production",
    "code": "ABCDEF"
  }
}
```

**Fields:**
- `game` (string, required): Game identifier used in container naming
- `code` (string, required): Unique 6-character lobby code
- `params` (object, required): Parameters to pass to the container
  - `image` (string, optional): Docker image to use (defaults to `ghcr.io/vypf/{game}:latest`)
  - All other fields are passed as CMD arguments in `key=value` format

#### Response

**Success (200):**
```json
{
  "success": true,
  "container_name": "space-chicken-ABCDEF",
  "container_id": "a1b2c3d4e5f6...",
  "message": "Container spawned successfully"
}
```

**Error (400/500):**
```json
{
  "success": false,
  "error": "Error message describing what went wrong"
}
```

#### Docker Command Generated

The API executes:
```bash
docker run -d \
  --name {game}-{code} \
  --network lobby-network \
  {image} \
  key1=value1 key2=value2 ...
```

**Example:**
```bash
docker run -d \
  --name space-chicken-ABCDEF \
  --network lobby-network \
  ghcr.io/vypf/space-chicken:latest \
  port=18547 environment=production code=ABCDEF
```

### DELETE /container

Stops and removes a game container.

#### Request

**Headers:**
```
Content-Type: application/json
```

**Body:**
```json
{
  "game": "space-chicken",
  "code": "ABCDEF"
}
```

**Fields:**
- `game` (string, required): Game identifier
- `code` (string, required): Lobby code

#### Response

**Success (200):**
```json
{
  "success": true,
  "container_name": "space-chicken-ABCDEF",
  "message": "Container deleted successfully"
}
```

**Error (500):**
```json
{
  "success": false,
  "error": "Failed to remove container: ..."
}
```

#### Docker Commands Generated

The API executes:
```bash
docker stop {game}-{code}
docker rm {game}-{code}
```

**Example:**
```bash
docker stop space-chicken-ABCDEF
docker rm space-chicken-ABCDEF
```

## Running the Spawner API

### With Docker (Recommended)

```bash
docker run -d \
  --name lobby-spawner \
  -p 8080:8080 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ghcr.io/vypf/lobby-spawner:latest
```

**Important:** The spawner API needs access to the Docker socket (`/var/run/docker.sock`) to manage containers.

### Locally (Development)

```bash
godot --headless -- \
  server_type=spawner \
  port=8080 \
  network_name=lobby-network
```

## Configuration

Command-line arguments:

- `server_type=spawner` (required): Run in spawner mode
- `port=8080` (optional): HTTP server port (default: 8080)
- `network_name=lobby-network` (optional): Docker network name (default: lobby-network)

## Network Setup

Before running the spawner API, create the Docker network:

```bash
docker network create lobby-network
```

This network allows containers to communicate with each other and with the nginx reverse proxy.

## Example Usage

### Spawn a game instance

```bash
curl -X POST http://localhost:8080/spawn \
  -H "Content-Type: application/json" \
  -d '{
    "game": "space-chicken",
    "code": "ABCDEF",
    "params": {
      "image": "ghcr.io/vypf/space-chicken:latest",
      "port": "18547",
      "environment": "production",
      "code": "ABCDEF"
    }
  }'
```

**Response:**
```json
{
  "success": true,
  "container_name": "space-chicken-ABCDEF",
  "container_id": "a1b2c3d4e5f6789012345678901234567890123456789012345678901234",
  "message": "Container spawned successfully"
}
```

### Delete a game instance

```bash
curl -X DELETE http://localhost:8080/container \
  -H "Content-Type: application/json" \
  -d '{
    "game": "space-chicken",
    "code": "ABCDEF"
  }'
```

**Response:**
```json
{
  "success": true,
  "container_name": "space-chicken-ABCDEF",
  "message": "Container deleted successfully"
}
```

## Security Considerations

- **Docker Socket Access**: The spawner API has full access to the Docker daemon. Run it in a trusted environment.
- **Input Validation**: The API validates required fields but additional validation may be needed for production.
- **Network Isolation**: Use Docker networks to isolate game containers from external access.
- **Rate Limiting**: Consider implementing rate limiting to prevent abuse.
- **Authentication**: Add authentication for production deployments.

## Error Handling

The API returns appropriate HTTP status codes:

- `200 OK`: Request successful
- `400 Bad Request`: Invalid JSON or missing required fields
- `404 Not Found`: Unknown endpoint
- `500 Internal Server Error`: Docker command failed

All error responses include a JSON body with `success: false` and an `error` message.
