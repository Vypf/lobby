extends Node

@onready var lobby_server: LobbyServer = %LobbyServer

func _ready():
	var server_type = Config.arguments.get("server_type", "lobby")

	if server_type == "spawner":
		_start_spawner()
	else:
		_start_lobby()


func _start_lobby():
	var environment = Config.arguments.get("environment", "development")
	var paths = Config.arguments.get("paths", {})
	var executable_paths = Config.arguments.get("executable_paths", {})
	var log_folder = Config.arguments.get("log_folder", "")

	# Create and inject the instance manager
	var instance_manager = GameInstanceManager.new(environment, paths, executable_paths, log_folder)
	lobby_server._instance_manager = instance_manager

	lobby_server.start(Config.arguments.get("port", 17018))


func _start_spawner():
	# Hide/remove the lobby server node since we're running as spawner
	lobby_server.queue_free()

	# Load and instantiate the spawner API
	var spawner_script = load("res://spawner_api.gd")
	var spawner = spawner_script.new()
	add_child(spawner)
