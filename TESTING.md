# Test local - Lobby & Spawner API

## Setup

### 1. Créer le fichier de configuration des images

Créer `images.json`:
```json
{
  "space-chicken": {
    "development": "space-chicken:test",
    "production": "ghcr.io/vypf/space-chicken:latest"
  }
}
```

### 2. Créer le réseau Docker

```bash
docker network create lobby-network
```

### 3. Build les images

```bash
docker build -t lobby-server -f Dockerfile .
docker build -t lobby-spawner -f Dockerfile.spawner .
docker build -t lobby-router -f Dockerfile.router .
```

## Lancer les services

### Mode développement (accès direct aux ports)

#### Spawner API

```bash
MSYS_NO_PATHCONV=1 docker run -d --name spawner-api -p 8080:8080 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd)/images.json:/app/images.json \
  --network lobby-network lobby-spawner \
  server_type=spawner environment=development images_file=/app/images.json

# Vérifier les logs
docker logs spawner-api
```

#### Lobby Server

```bash
docker run -d --name lobby-server -p 17018:17018 \
  --network lobby-network lobby-server \
  environment=development \
  spawner_api_url=http://spawner-api:8080 \
  lobby_url=ws://lobby-server:17018

# Vérifier les logs
docker logs lobby-server
```

### Mode développement avec router (HTTP)

#### Spawner API

```bash
MSYS_NO_PATHCONV=1 docker run -d --name spawner-api -p 8080:8080 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd)/images.json:/app/images.json \
  --network lobby-network lobby-spawner \
  server_type=spawner environment=development images_file=/app/images.json

# Vérifier les logs
docker logs spawner-api
```

#### Lobby Server

```bash
docker run -d --name lobby-server \
  --network lobby-network lobby-server \
  environment=development \
  spawner_api_url=http://spawner-api:8080 \
  lobby_url=ws://router/lobby

# Vérifier les logs
docker logs lobby-server
```

#### Router (nginx - HTTP only)

```bash
docker run -d --name router -p 80:80 \
  --network lobby-network lobby-router

# Vérifier les logs
docker logs router
```

Client access: `ws://localhost/lobby` et `ws://localhost/CODE`

### Mode production (avec SSL)

#### Router (nginx - HTTPS)

```bash
MSYS_NO_PATHCONV=1 docker run -d --name router -p 80:80 -p 443:443 \
  -v $(pwd)/nginx/default.ssl.conf:/etc/nginx/conf.d/default.conf:ro \
  -v /etc/letsencrypt:/etc/letsencrypt:ro \
  --network lobby-network lobby-router

# Vérifier les logs
docker logs router
```

Pour le lobby server en production, utiliser `lobby_url=wss://games.yvonnickfrin.dev/lobby`

## Comportement des ports selon l'environnement

| Environnement | Ports game instances | Accès client |
|---------------|---------------------|--------------|
| `development` | Exposés (`-p external:18000`) | `ws://localhost:{port}` |
| `production` | Non exposés | `wss://games.../CODE` via router |

Les game instances écoutent toujours sur le port interne **18000**.

## Test des endpoints Spawner API

### POST /spawn

```bash
curl -X POST http://localhost:8080/spawn \
  -H "Content-Type: application/json" \
  -d '{
    "game": "space-chicken",
    "code": "ABC123",
    "params": {
      "server_type": "room",
      "environment": "development",
      "code": "ABC123",
      "port": "18000",
      "external_port": "18547"
    }
  }'

# Vérifier que le conteneur tourne
docker ps --filter "name=game-ABC123"
```

### DELETE /container

```bash
curl -X DELETE http://localhost:8080/container \
  -H "Content-Type: application/json" \
  -d '{"game": "space-chicken", "code": "ABC123"}'

# Vérifier que le conteneur est supprimé
docker ps -a --filter "name=game-ABC123"
```

## Nettoyage

```bash
# Arrêter les conteneurs de jeu
docker stop $(docker ps -q --filter "name=game-") 2>/dev/null
docker rm $(docker ps -aq --filter "name=game-") 2>/dev/null

# Arrêter les services
docker stop router lobby-server spawner-api 2>/dev/null
docker rm router lobby-server spawner-api 2>/dev/null

# Supprimer le réseau
docker network rm lobby-network
```
