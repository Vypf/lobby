extends Node

@onready var lobby_server: LobbyServer = %LobbyServer

func _ready():
	lobby_server._paths = Config.arguments.get("paths", {})
	lobby_server._executable_paths = Config.arguments.get("executable_paths", {})
	lobby_server._log_folder = Config.arguments.get("log_folder", "")
	lobby_server._environment = Config.arguments.get("environment", "development")
	lobby_server.start(Config.arguments.get("port", 17018))
