# Test local - Spawner API

## Setup

```bash
# Créer le réseau Docker
docker network create lobby-network

# Build et lancer le spawner
docker build -t lobby-spawner -f Dockerfile.spawner .
MSYS_NO_PATHCONV=1 docker run -d --name spawner-api -p 8080:8080 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --network lobby-network lobby-spawner

# Vérifier que le spawner est prêt
docker logs spawner-api
```

## Test POST /spawn

```bash
curl -X POST http://localhost:8080/spawn \
  -H "Content-Type: application/json" \
  -d '{
    "game": "space-chicken",
    "code": "ABC123",
    "params": {
      "image": "ghcr.io/vypf/space-chicken:latest",
      "server_type": "room",
      "environment": "production",
      "code": "ABC123",
      "port": "18547"
    }
  }'

# Vérifier que le conteneur tourne
docker ps --filter "name=space-chicken-ABC123"
```

## Test DELETE /container

```bash
curl -X DELETE http://localhost:8080/container \
  -H "Content-Type: application/json" \
  -d '{"game": "space-chicken", "code": "ABC123"}'

# Vérifier que le conteneur est supprimé
docker ps -a --filter "name=space-chicken-ABC123"
```

## Nettoyage

```bash
docker stop spawner-api && docker rm spawner-api
docker network rm lobby-network
```
