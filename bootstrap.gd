extends Node

@onready var lobby_server: LobbyServer = %LobbyServer

func _ready():
	var server_type = Config.arguments.get("server_type", "lobby")

	if server_type == "spawner":
		_start_spawner()
	else:
		_start_lobby()


func _start_lobby():
	lobby_server._paths = Config.arguments.get("paths", {})
	lobby_server._executable_paths = Config.arguments.get("executable_paths", {})
	lobby_server._log_folder = Config.arguments.get("log_folder", "")
	lobby_server._environment = Config.arguments.get("environment", "development")
	lobby_server.start(Config.arguments.get("port", 17018))


func _start_spawner():
	# Hide/remove the lobby server node since we're running as spawner
	lobby_server.queue_free()

	# Load and instantiate the spawner API
	var spawner_script = load("res://spawner_api.gd")
	var spawner = spawner_script.new()
	add_child(spawner)
