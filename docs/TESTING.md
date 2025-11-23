# Tests manuels

Commandes pour tester et débugger le système sans Docker Compose.

> Pour le guide de démarrage rapide avec Docker Compose, voir [README.md](../README.md#guide-de-démarrage-rapide).

## Prérequis

```bash
# Créer le réseau Docker
docker network create lobby-network

# Créer images.json
cat > images.json << 'EOF'
{
  "space-chicken": {
    "development": "space-chicken:test",
    "production": "ghcr.io/vypf/space-chicken:latest"
  }
}
EOF
```

## Build des images

```bash
docker build -t hub -f Dockerfile.hub .
docker build -t lobby-spawner -f Dockerfile.spawner .
docker build -t lobby-router -f Dockerfile.router .
```

## Lancement manuel des services

### Spawner API

```bash
MSYS_NO_PATHCONV=1 docker run -d --name spawner-api -p 8080:8080 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd)/images.json:/app/images.json \
  --network lobby-network lobby-spawner \
  server_type=spawner environment=development images_file=/app/images.json

docker logs spawner-api
```

### Hub

```bash
docker run -d --name hub -p 17018:17018 \
  --network lobby-network hub \
  environment=development \
  spawner_api_url=http://spawner-api:8080 \
  lobby_url=ws://router/lobby

docker logs hub
```

### Router

```bash
docker run -d --name router -p 80:80 \
  --network lobby-network lobby-router

docker logs router
```

## Test des endpoints

### Spawn

```bash
curl -X POST http://localhost:8080/spawn \
  -H "Content-Type: application/json" \
  -d '{
    "game": "space-chicken",
    "code": "ABC123",
    "params": {
      "external_port": "18547",
      "lobby_url": "ws://router/lobby"
    }
  }'

# Vérifier
docker ps --filter "name=game-ABC123"
```

### Delete

```bash
curl -X DELETE http://localhost:8080/container \
  -H "Content-Type: application/json" \
  -d '{"game": "space-chicken", "code": "ABC123"}'

# Vérifier
docker ps -a --filter "name=game-ABC123"
```

## Nettoyage

```bash
# Arrêter les conteneurs de jeu
docker stop $(docker ps -q --filter "name=game-") 2>/dev/null
docker rm $(docker ps -aq --filter "name=game-") 2>/dev/null

# Arrêter les services
docker stop router hub spawner-api 2>/dev/null
docker rm router hub spawner-api 2>/dev/null

# Supprimer le réseau
docker network rm lobby-network
```
