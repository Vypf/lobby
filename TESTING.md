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
```

## Lancer les services

### Spawner API

```bash
MSYS_NO_PATHCONV=1 docker run -d --name spawner-api -p 8080:8080 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd)/images.json:/app/images.json \
  --network lobby-network lobby-spawner \
  server_type=spawner environment=development images_file=/app/images.json

# Vérifier les logs
docker logs spawner-api
```

### Lobby Server

```bash
docker run -d --name lobby-server -p 17018:17018 \
  --network lobby-network lobby-server \
  spawner_api_url=http://spawner-api:8080 \
  lobby_url=ws://lobby-server:17018

# Vérifier les logs
docker logs lobby-server
```

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
      "port": "18547"
    }
  }'

# Vérifier que le conteneur tourne
docker ps --filter "name=space-chicken-ABC123"
```

### DELETE /container

```bash
curl -X DELETE http://localhost:8080/container \
  -H "Content-Type: application/json" \
  -d '{"game": "space-chicken", "code": "ABC123"}'

# Vérifier que le conteneur est supprimé
docker ps -a --filter "name=space-chicken-ABC123"
```

## Nettoyage

```bash
# Arrêter les conteneurs de jeu
docker stop $(docker ps -q --filter "name=space-chicken-") 2>/dev/null
docker rm $(docker ps -aq --filter "name=space-chicken-") 2>/dev/null

# Arrêter les services
docker stop lobby-server spawner-api
docker rm lobby-server spawner-api

# Supprimer le réseau
docker network rm lobby-network
```
