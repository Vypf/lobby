extends Node

@onready var lobby_server: LobbyServer = %LobbyServer

const SERVER_TYPES := {
	"LOBBY": "lobby",
	"SPAWNER": "spawner"
}

func _ready():
	var server_type = Config.arguments.get("server_type", SERVER_TYPES.LOBBY)

	if server_type == SERVER_TYPES.SPAWNER:
		_start_spawner()
	else:
		_start_lobby()


func _start_lobby():
	var logger = CustomLogger.new("Bootstrap")
	var spawner_api_url = Config.arguments.get("spawner_api_url", "")
	var lobby_url = Config.arguments.get("lobby_url", "")
	var environment = Config.arguments.get("environment", "development")

	logger.info("Starting lobby server", "_start_lobby")
	logger.info("  environment: %s" % environment, "_start_lobby")
	logger.info("  spawner_api_url: %s" % [spawner_api_url if not spawner_api_url.is_empty() else "(not set - using local)"], "_start_lobby")
	logger.info("  lobby_url: %s" % [lobby_url if not lobby_url.is_empty() else "(not set)"], "_start_lobby")

	# Create the appropriate instance manager based on spawner_api_url presence
	var instance_manager
	if not spawner_api_url.is_empty():
		logger.info("Using RemoteGameInstanceManager", "_start_lobby")
		instance_manager = RemoteGameInstanceManager.new(spawner_api_url, lobby_url, environment)
	else:
		var paths = Config.arguments.get("paths", {})
		var executable_paths = Config.arguments.get("executable_paths", {})
		var log_folder = Config.arguments.get("log_folder", "")
		logger.info("Using LocalGameInstanceManager", "_start_lobby")
		logger.debug("  paths: %s" % JSON.stringify(paths), "_start_lobby")
		logger.debug("  executable_paths: %s" % JSON.stringify(executable_paths), "_start_lobby")
		logger.debug("  log_folder: %s" % log_folder, "_start_lobby")
		instance_manager = LocalGameInstanceManager.new(paths, executable_paths, log_folder, lobby_url)

	lobby_server._instance_manager = instance_manager
	lobby_server.start(Config.arguments.get("port", 17018))


func _start_spawner():
	# Hide/remove the lobby server node since we're running as spawner
	lobby_server.queue_free()

	# Load and instantiate the spawner API
	var spawner = SpawnerAPI.new()
	add_child(spawner)
