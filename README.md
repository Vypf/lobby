# Godot Multiplayer Lobby System

Système de lobby multijoueur pour Godot 4.5 qui permet de créer dynamiquement des instances de jeu. Le projet se compose de trois briques principales qui peuvent être déployées ensemble ou séparément.

## Table des matières

- [Architecture](#architecture)
- [Composants](#composants)
  - [Hub](#1-hub)
  - [Spawner API](#2-spawner-api)
  - [Router](#3-router)
- [Environnements](#environnements)
- [Modes de déploiement](#modes-de-déploiement)
  - [Mode Docker](#mode-docker-avec-spawner-api)
  - [Mode local sans Docker](#mode-local-sans-docker)
- [Guide de démarrage rapide](#guide-de-démarrage-rapide)
- [Configuration avancée](#configuration-avancée)
- [Déploiement](#déploiement)

---

## Architecture

```
                                    ┌───────────┐
                                    │  Clients  │
                                    └─────┬─────┘
                                          │ WebSocket
                                          ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│    ┌──────────┐         Nginx reverse proxy                                 │
│    │  Router  │         - /lobby     → hub:17018                            │
│    │  :80/443 │         - /{CODE}    → game-{CODE}:18000                    │
│    └────┬─────┘                                                             │
│         │                                                                   │
│    ┌────┴────────────────────┐                                              │
│    │                         │                                              │
│    ▼                         ▼                                              │
│ ┌──────────┐            ┌──────────────┐                                    │
│ │  Lobby   │            │ game-{CODE}  │  Instances de jeu                  │
│ │  Server  │            │    :18000    │  (conteneurs Docker)               │
│ │  :17018  │            └──────────────┘                                    │
│ └────┬─────┘                   ▲                                            │
│      │                         │ docker run                                 │
│      │ HTTP POST /spawn        │                                            │
│      ▼                         │                                            │
│ ┌───────────┐                  │                                            │
│ │  Spawner  │ ─────────────────┘                                            │
│ │    API    │                                                               │
│ │   :8080   │                                                               │
│ └───────────┘                                                               │
│                                                                             │
│                            lobby-network (Docker)                           │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Flux de création d'un lobby :**
1. Le client demande la création d'un lobby via WebSocket (`create_lobby`)
2. Le Hub appelle le Spawner API en HTTP POST
3. Le Spawner API crée un conteneur Docker `game-{CODE}`
4. Le client reçoit le code et peut rejoindre via `/{CODE}`

---

## Composants

### 1. Hub

**Rôle** : Serveur WebSocket central qui gère les connexions des clients et la création des lobbies.

#### Fonctionnement

1. Accepte les connexions WebSocket des clients de jeu
2. Génère un code unique à 6 caractères pour chaque nouveau lobby
3. Fait appel au Spawner API pour créer l'instance de jeu
4. Transmet le code au client pour qu'il puisse rejoindre via `/{CODE}`

> En développement uniquement : un port externe (18000-19000) est alloué et exposé pour permettre un accès direct sans passer par le router.

#### Protocole WebSocket

Tous les messages sont au format JSON : `{"type": string, "data": any}`

| Direction | Type | Data | Description |
|-----------|------|------|-------------|
| Client → Server | `create_lobby` | `{game: string}` | Demande de création d'un lobby |
| Client → Server | `register_lobby` | `lobby_info` | Instance de jeu s'enregistrant |
| Client → Server | `register_client` | `{game: string}` | Client s'enregistrant pour un jeu |
| Server → Client | `lobby_created` | `string` (code) | Code du lobby créé |
| Server → Client | `lobbies_updated` | `Dictionary` | Liste des lobbies pour ce jeu |
| Server → Client | `lobby_connected` | `{peer_id, lobby_info}` | Nouveau lobby enregistré |
| Server → Client | `lobby_disconnected` | `int` (peer_id) | Lobby déconnecté |

**Structure de `lobby_info`** :
```json
{
  "game": "string",   // Nom du jeu
  "code": "string",   // Code à 6 caractères du lobby
  "port": "int",      // Port de l'instance
  "pId": "int"        // Peer ID du host
}
```

#### Options de configuration

| Argument | Type | Défaut | Description |
|----------|------|--------|-------------|
| `port` | int | `17018` | Port d'écoute du serveur WebSocket |
| `environment` | string | `development` | `development` ou `production` |
| `spawner_api_url` | string | `http://localhost:8080/spawn` | URL de l'API Spawner |
| `lobby_url` | string | - | URL publique du lobby (pour les callbacks) |
| `log_folder` | string | - | Dossier pour les logs des instances |
| `paths` | dict | `{}` | Mapping nom_jeu → chemin_projet |

#### Exemple de lancement

```bash
# Development
godot --headless -- \
  environment=development \
  spawner_api_url=http://localhost:8080/spawn \
  log_folder=./logs \
  port=17018

# Production
godot --headless -- \
  environment=production \
  spawner_api_url=http://spawner:8080/spawn \
  lobby_url=wss://games.example.com/lobby \
  log_folder=/app/logs \
  port=17018
```

---

### 2. Spawner API

**Rôle** : Service HTTP qui crée et gère les conteneurs Docker pour les instances de jeu.

#### Fonctionnement

1. Reçoit une requête HTTP POST du Hub
2. Sélectionne l'image Docker depuis `images.json`
3. Crée un conteneur nommé `game-{CODE}`
4. En développement, expose le port pour un accès direct

#### Endpoints

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| `POST` | `/spawn` | Créer une instance de jeu |
| `DELETE` | `/container` | Supprimer une instance |

> Documentation détaillée des endpoints : [docs/SPAWNER_API.md](./docs/SPAWNER_API.md)

#### Options de configuration

| Argument | Type | Défaut | Description |
|----------|------|--------|-------------|
| `server_type` | string | - | Doit être `spawner` |
| `port` | int | `8080` | Port d'écoute |
| `environment` | string | `development` | `development` ou `production` |
| `network_name` | string | `lobby-network` | Nom du réseau Docker |
| `images_file` | string | - | Chemin vers `images.json` |

#### Configuration des images (`images.json`)

```json
{
  "space-chicken": {
    "development": "space-chicken:test",
    "production": "ghcr.io/vypf/space-chicken:latest"
  }
}
```

#### Exemple de lancement

```bash
godot --headless -- \
  server_type=spawner \
  environment=development \
  images_file=/app/images.json \
  port=8080
```

---

### 3. Router

**Rôle** : Reverse proxy Nginx qui route le trafic WebSocket et gère la terminaison SSL.

#### Fonctionnement

1. Reçoit les connexions HTTPS/WSS sur le port 443
2. Route `/lobby` vers le Hub
3. Route `/{CODE}` (6 lettres majuscules) vers le conteneur `game-{CODE}`
4. Gère les certificats Let's Encrypt

#### Règles de routage

| Path | Destination | Description |
|------|-------------|-------------|
| `/lobby` | `hub:17018` | Connexion au Hub |
| `/{CODE}` | `game-{CODE}:18000` | Connexion à une instance de jeu |
| `/` | 200 OK | Health check |

#### Fichiers de configuration

| Fichier | Usage |
|---------|-------|
| `nginx/default.conf` | HTTP (développement) |
| `nginx/default.ssl.conf` | HTTPS avec SSL (production) |

---

## Environnements

### Docker Compose : dev vs prod

La principale différence entre les deux configurations Docker Compose est le **protocole de communication** :

| Aspect | Development | Production |
|--------|-------------|------------|
| **Protocole** | HTTP (`ws://`) | HTTPS (`wss://`) |
| **Port Router** | 80 | 80 + 443 |
| **Certificats SSL** | Non | Let's Encrypt |
| **Ports debug exposés** | hub:17018, spawner:8080 | Non |
| **lobby_url** | `ws://router/lobby` | `wss://games.example.com/lobby` |

### Effet de la variable `environment`

La variable `environment` passée au Spawner API affecte le comportement du spawn des conteneurs :

| Aspect | `development` | `production` |
|--------|---------------|--------------|
| **Ports des instances** | Exposés (`-p ext:18000`) | Non exposés |
| **Image Docker utilisée** | `images.json` → "development" | `images.json` → "production" |
| **Accès aux instances** | Direct via port | Via router (`/{CODE}`) |

### Configuration de l'environnement

L'environnement peut être défini de deux façons :
1. Argument : `environment=production`
2. Variable d'environnement : `ENVIRONMENT=production`

---

## Modes de déploiement

Le Hub peut fonctionner selon deux modes, déterminé par la présence de `spawner_api_url` :

### Mode Docker (avec Spawner API)

```
Hub ──HTTP──> Spawner API ──Docker──> game-{CODE}
```

- Le Hub communique avec le Spawner API via HTTP
- Le Spawner API crée des conteneurs Docker
- **Utilisé pour** : Docker Compose, production, environnements conteneurisés

### Mode local sans Docker

```
Hub ──OS.create_process()──> Processus Godot local
```

- Le Hub spawne directement des processus Godot locaux
- Pas besoin de Spawner API ni de Docker
- **Utilisé pour** : développement local rapide, tests

**Arguments spécifiques au mode local** (passés au Hub) :

| Argument | Type | Description |
|----------|------|-------------|
| `paths` | dict | Mapping `nom_jeu` → chemin du projet Godot |
| `executable_paths` | dict | Mapping `nom_jeu` → chemin de l'exécutable Godot |
| `log_folder` | string | Dossier pour les fichiers log |
| `lobby_url` | string | URL pour que les instances se reconnectent au Hub |

**Exemple** :
```bash
godot --headless -- \
  environment=development \
  paths space-chicken=C:\Games\SpaceChicken \
  executable_paths space-chicken=C:\Godot\Godot.exe \
  log_folder=./logs \
  lobby_url=ws://localhost:17018 \
  port=17018
```


---

## Guide de démarrage rapide

### Prérequis

- Docker et Docker Compose
- Git avec support des submodules
- (Optionnel) Godot 4.5 pour le développement local

### Option 1 : Docker Compose (recommandé)

```bash
# 1. Cloner le projet
git clone --recursive https://github.com/Vypf/lobby.git
cd lobby

# 2. Créer le réseau Docker
docker network create lobby-network

# 3. Configurer les images de jeu
cat > images.json << 'EOF'
{
  "space-chicken": {
    "development": "space-chicken:test",
    "production": "ghcr.io/vypf/space-chicken:latest"
  }
}
EOF

# 4. Lancer en développement
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --build

# 5. Vérifier les logs
docker compose logs -f
```

**URLs d'accès (développement)** :
- Lobby : `ws://localhost:17018` ou `ws://localhost/lobby`
- Spawner API : `http://localhost:8080`
- Instances de jeu : `ws://localhost:{port_exposé}`

### Option 2 : Local sans Docker

Un seul terminal suffit - le Hub spawne directement les processus :

```bash
godot --headless -- \
  environment=development \
  paths space-chicken=C:\Games\SpaceChicken \
  executable_paths space-chicken=C:\Godot\Godot.exe \
  log_folder=./logs \
  lobby_url=ws://localhost:17018 \
  port=17018
```

> Sans `spawner_api_url`, le Hub utilise le mode local et spawne des processus Godot directement.

### Option 3 : Production

```bash
# 1. Configurer SSL (Let's Encrypt)
# Les certificats doivent être dans /etc/letsencrypt

# 2. Lancer en production
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# 3. Vérifier
curl https://games.example.com/
```

**URLs d'accès (production)** :
- Lobby : `wss://games.example.com/lobby`
- Instances de jeu : `wss://games.example.com/{CODE}`

---

## Configuration avancée

### Structure des arguments

Le fichier `config.gd` parse les arguments avec les formats suivants :

```bash
# Valeur simple
--key=value
key=value

# Dictionnaire
--paths game1=/path/to/game1 game2=/path/to/game2

# Flag booléen
--headless
```

### Ajout d'un nouveau jeu

1. Ajouter l'image dans `images.json` :
```json
{
  "nouveau-jeu": {
    "development": "nouveau-jeu:dev",
    "production": "ghcr.io/org/nouveau-jeu:latest"
  }
}
```

2. S'assurer que l'image de jeu :
   - Accepte les arguments `server_type=room code={CODE} port=18000 lobby_url={URL}`
   - S'enregistre auprès du Hub via WebSocket

### Personnalisation du logger

```gdscript
# Niveaux disponibles : DEBUG, INFO, WARN, ERROR
CustomLogger.set_global_level(CustomLogger.Level.DEBUG)

# Format des logs :
# [timestamp][prefix][context] LEVEL: message
```

---

## Déploiement

### Images Docker publiées

Les images sont automatiquement construites et publiées sur GitHub Container Registry :

| Image | Description |
|-------|-------------|
| `ghcr.io/vypf/lobby:latest` | Hub |
| `ghcr.io/vypf/lobby-spawner:latest` | Spawner API |
| `ghcr.io/vypf/lobby-router:latest` | Router |

### Workflow CI/CD

Le workflow `.github/workflows/docker-publish.yml` se déclenche sur :
- Push sur `main`
- Tags de version (`v*`)
- Pull requests
- Déclenchement manuel

---

## Documentation complémentaire

- [docs/SPAWNER_API.md](./docs/SPAWNER_API.md) - Référence détaillée des endpoints
- [docs/TESTING.md](./docs/TESTING.md) - Commandes Docker manuelles pour debug

---

## Structure du projet

```
lobby/
├── bootstrap.gd              # Point d'entrée, sélection du mode
├── config.gd                 # Parser d'arguments (autoload)
├── spawner_api.gd            # Serveur HTTP du Spawner
├── local_game_instance_manager.gd   # Spawner local (dev)
├── remote_game_instance_manager.gd  # Spawner distant (Docker)
├── images.json               # Configuration des images Docker
│
├── docs/
│   ├── SPAWNER_API.md        # Référence API détaillée
│   └── TESTING.md            # Commandes de test manuelles
│
├── addons/godot_multiplayer/ # Addon (git submodule)
│
├── nginx/
│   ├── default.conf          # Config HTTP
│   └── default.ssl.conf      # Config HTTPS
│
├── Dockerfile.hub
├── Dockerfile.spawner
├── Dockerfile.router
├── docker-compose.yml
├── docker-compose.dev.yml
└── docker-compose.prod.yml
```
