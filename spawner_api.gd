extends Node

# Spawner API - Manages Docker containers for game instances
# Exposes HTTP endpoints to spawn and remove game containers

const DEFAULT_PORT = 8080
const HTTPHelpers = preload("res://http_helpers.gd")

var _server: HTTPHelpers.HTTPServer
var _logger: CustomLogger

# Configuration from command line args
var _network_name: String = "lobby-network"


func _init():
	_logger = CustomLogger.new("SpawnerAPI")


func _ready():
	# Parse command line arguments
	_network_name = Config.arguments.get("network_name", "lobby-network")
	var port = Config.arguments.get("port", DEFAULT_PORT)

	_logger.info("Starting Spawner API on port " + str(port), "_ready")
	_logger.info("Docker network: " + _network_name, "_ready")

	# Create and configure HTTP server
	_server = HTTPHelpers.HTTPServer.new(port, _logger)
	_server.register_route("POST", "/spawn", _handle_spawn)
	_server.register_route("DELETE", "/container", _handle_delete)

	# Start server
	var error = _server.start()
	if error != OK:
		_logger.error("Failed to start server", "_ready")
		get_tree().quit(1)
		return

	_logger.info("✅ Spawner API ready", "_ready")


func _process(_delta):
	if _server:
		_server.poll()


func _handle_spawn(request: HTTPHelpers.Request) -> HTTPHelpers.Response:
	# Validate JSON data
	if request.json_data == null:
		_logger.error("Invalid JSON in request body", "_handle_spawn")
		return HTTPHelpers.Response.error(400, "Invalid JSON")

	var payload = request.json_data
	_logger.debug("Spawn payload: " + JSON.stringify(payload), "_handle_spawn")

	# Validate required fields
	if not payload.has("game") or not payload.has("code") or not payload.has("params"):
		return HTTPHelpers.Response.error(400, "Missing required fields: game, code, params")

	# Spawn the container
	var result = _spawn_container(payload)

	if result.success:
		return HTTPHelpers.Response.success(result)
	else:
		return HTTPHelpers.Response.error(500, result.error)


func _handle_delete(request: HTTPHelpers.Request) -> HTTPHelpers.Response:
	# Validate JSON data
	if request.json_data == null:
		_logger.error("Invalid JSON in request body", "_handle_delete")
		return HTTPHelpers.Response.error(400, "Invalid JSON")

	var payload = request.json_data
	_logger.debug("Delete payload: " + JSON.stringify(payload), "_handle_delete")

	# Validate required fields
	if not payload.has("game") or not payload.has("code"):
		return HTTPHelpers.Response.error(400, "Missing required fields: game, code")

	# Delete the container
	var result = _delete_container(payload)

	if result.success:
		return HTTPHelpers.Response.success(result)
	else:
		return HTTPHelpers.Response.error(500, result.error)


func _spawn_container(payload: Dictionary) -> Dictionary:
	var game = payload.game
	var code = payload.code
	var params = payload.params

	var container_name = game + "-" + code
	_logger.info("Spawning container: " + container_name, "_spawn_container")

	# Build docker run command
	var args = PackedStringArray([
		"run",
		"-d",  # Detached mode
		"--name", container_name,
		"--network", _network_name
	])

	# Convert params object to CMD arguments (key=value format)
	var cmd_args = PackedStringArray()
	for key in params.keys():
		cmd_args.append(str(key) + "=" + str(params[key]))

	# Get image name (we expect it in params or use game name as image)
	var image = params.get("image", "ghcr.io/vypf/" + game + ":latest")

	# Add image name
	args.append(image)

	# Add CMD arguments
	for arg in cmd_args:
		# Skip the "image" param as it's not a CMD argument
		if not arg.begins_with("image="):
			args.append(arg)

	_logger.debug("Docker command: docker " + " ".join(args), "_spawn_container")

	# Execute docker run
	var output = []
	var exit_code = OS.execute("docker", args, output, true)

	if exit_code != 0:
		var error_msg = "Failed to spawn container: " + " ".join(output)
		_logger.error(error_msg, "_spawn_container")
		return {
			"success": false,
			"error": error_msg
		}

	var container_id = output[0].strip_edges()
	_logger.info("✅ Container spawned: " + container_name + " (ID: " + container_id + ")", "_spawn_container")

	return {
		"success": true,
		"container_name": container_name,
		"container_id": container_id,
		"message": "Container spawned successfully"
	}


func _delete_container(payload: Dictionary) -> Dictionary:
	var game = payload.game
	var code = payload.code

	var container_name = game + "-" + code
	_logger.info("Deleting container: " + container_name, "_delete_container")

	# Stop the container first
	var stop_output = []
	var stop_exit_code = OS.execute("docker", PackedStringArray(["stop", container_name]), stop_output, true)

	if stop_exit_code != 0:
		var error_msg = "Failed to stop container: " + " ".join(stop_output)
		_logger.warn(error_msg, "_delete_container")
		# Continue anyway to try to remove it

	# Remove the container
	var rm_output = []
	var rm_exit_code = OS.execute("docker", PackedStringArray(["rm", container_name]), rm_output, true)

	if rm_exit_code != 0:
		var error_msg = "Failed to remove container: " + " ".join(rm_output)
		_logger.error(error_msg, "_delete_container")
		return {
			"success": false,
			"error": error_msg
		}

	_logger.info("✅ Container deleted: " + container_name, "_delete_container")

	return {
		"success": true,
		"container_name": container_name,
		"message": "Container deleted successfully"
	}


func _exit_tree():
	if _server:
		_server.stop()
	_logger.info("Spawner API stopped", "_exit_tree")
