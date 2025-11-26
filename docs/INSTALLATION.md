# Installation sur VPS

Guide d'installation du système de lobby sur un serveur.

## Prérequis

- **Docker et Docker Compose** installés
- **Un reverse proxy** (nginx, Traefik, Caddy...) pour gérer le SSL
- **Un nom de domaine** avec certificat SSL valide

## Installation

### 1. Cloner le projet

```bash
cd /opt
sudo git clone --recursive https://github.com/Vypf/lobby.git
sudo chown -R $USER:$USER /opt/lobby
cd /opt/lobby
```

### 2. Configurer les images de jeu

```bash
cat > images.json << 'EOF'
{
  "space-chicken": {
    "development": "space-chicken:test",
    "production": "ghcr.io/vypf/space-chicken:latest"
  }
}
EOF
```

### 3. Lancer les conteneurs

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build
```

Le router expose HTTP sur le port `17080`.

### 4. Configurer le reverse proxy

Configurez votre reverse proxy pour :
- Terminer le SSL (HTTPS/WSS)
- Proxifier tout le trafic vers `http://127.0.0.1:17080`
- Activer le support WebSocket

#### Exemple nginx

```nginx
server {
    listen 80;
    server_name games.example.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name games.example.com;

    ssl_certificate /etc/letsencrypt/live/games.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/games.example.com/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    location / {
        proxy_pass http://127.0.0.1:17080;

        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Activer la configuration :

```bash
sudo ln -s /etc/nginx/sites-available/games.example.com /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 5. Vérifier

```bash
curl https://games.example.com/
# Devrait afficher "Hello Gamers!"
```

## Redémarrage automatique (systemd)

```bash
sudo tee /etc/systemd/system/lobby.service << 'EOF'
[Unit]
Description=Godot Multiplayer Lobby System
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/lobby
ExecStart=/usr/bin/docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
ExecStop=/usr/bin/docker compose -f docker-compose.yml -f docker-compose.prod.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable lobby.service
```

## Commandes utiles

```bash
# Logs en temps réel
docker compose logs -f

# Redémarrer
docker compose restart

# Reconstruire après modification
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build

# Voir les instances de jeu
docker ps --filter "name=game-"
```

## Dépannage

```bash
# Vérifier que le router est accessible
curl http://127.0.0.1:17080/

# Logs des services
docker compose logs hub
docker compose logs spawner
docker compose logs router

# Vérifier le socket Docker depuis le spawner
docker exec lobby-spawner-1 docker ps
```
