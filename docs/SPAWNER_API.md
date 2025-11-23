# Spawner API - Référence

Documentation détaillée des endpoints HTTP du Spawner API.

> Pour une vue d'ensemble du projet et les guides de démarrage, voir [README.md](../README.md).

## Endpoints

### POST /spawn

Crée un nouveau conteneur Docker pour une instance de jeu.

**Request :**
```http
POST /spawn
Content-Type: application/json

{
  "game": "space-chicken",
  "code": "ABCDEF",
  "params": {
    "external_port": "18547",
    "lobby_url": "ws://router/lobby"
  }
}
```

| Champ | Type | Requis | Description |
|-------|------|--------|-------------|
| `game` | string | oui | Identifiant du jeu (pour sélectionner l'image dans `images.json`) |
| `code` | string | oui | Code unique à 6 caractères |
| `params.external_port` | string | non | Port à exposer sur l'hôte (développement uniquement) |
| `params.lobby_url` | string | non | URL pour que l'instance se reconnecte au Hub |

**Champs auto-dérivés** (ajoutés automatiquement par le Spawner) :
- `server_type=room`
- `code={code}`
- `port=18000`
- `environment={environment du spawner}`

**Response (200) :**
```json
{
  "success": true,
  "container_name": "game-ABCDEF",
  "container_id": "a1b2c3d4e5f6...",
  "message": "Container spawned successfully"
}
```

**Response (400) :**
```json
{
  "success": false,
  "error": "Missing required fields: game, code"
}
```

**Response (500) :**
```json
{
  "success": false,
  "error": "No image configured for game 'xxx' in environment 'development'"
}
```

---

### DELETE /container

Arrête et supprime un conteneur de jeu.

**Request :**
```http
DELETE /container
Content-Type: application/json

{
  "game": "space-chicken",
  "code": "ABCDEF"
}
```

| Champ | Type | Requis | Description |
|-------|------|--------|-------------|
| `game` | string | oui | Identifiant du jeu |
| `code` | string | oui | Code du lobby |

**Response (200) :**
```json
{
  "success": true,
  "container_name": "game-ABCDEF",
  "message": "Container deleted successfully"
}
```

**Response (500) :**
```json
{
  "success": false,
  "error": "Failed to remove container: ..."
}
```

---

## Codes d'erreur HTTP

| Code | Signification |
|------|---------------|
| `200` | Succès |
| `400` | JSON invalide ou champs requis manquants |
| `404` | Endpoint inconnu |
| `500` | Commande Docker échouée |

---

## Sécurité

- **Accès Docker Socket** : Le Spawner a un accès complet au daemon Docker. À exécuter dans un environnement de confiance.
- **Isolation réseau** : Utiliser les réseaux Docker pour isoler les conteneurs de jeu.
- **Authentification** : Non implémentée. À ajouter pour les déploiements en production.
