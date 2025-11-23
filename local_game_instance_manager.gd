extends RefCounted
class_name LocalGameInstanceManager

# Manages game instance lifecycle (spawn and delete)
# Local implementation using OS.create_process() - for development only

var _logger: CustomLogger
var _paths: Dictionary
var _executable_paths: Dictionary
var _log_folder: String
var _lobby_url: String


func _init(paths: Dictionary = {}, executable_paths: Dictionary = {}, log_folder: String = "", lobby_url: String = ""):
	_logger = CustomLogger.new("LocalGameInstanceManager")
	_paths = paths
	_executable_paths = executable_paths
	_log_folder = log_folder
	_lobby_url = lobby_url


func spawn(game: String, code: String, port: int) -> Dictionary:
	_logger.info("Spawning instance: game=%s code=%s port=%d" % [game, code, port], "spawn")

	var root := _get_root(game)
	if root.is_empty():
		var error_msg = "No path configured for game '%s'. Add it with: paths %s=/path/to/project" % [game, game]
		_logger.error(error_msg, "spawn")
		return {
			"success": false,
			"error": error_msg
		}

	var log_path := _get_log_path(code)
	var executable_path := _get_executable_path(game)

	var args := _get_args(code, port)
	args = _add_log_path_to_args(log_path, args)
	args = _add_root_to_args(root, args)

	_logger.debug("Executable: %s Args: %s" % [executable_path, str(args)], "spawn")
	var pid = OS.create_process(executable_path, args)

	if pid == -1:
		_logger.error("Failed to spawn instance", "spawn")
		return {
			"success": false,
			"error": "Failed to create process"
		}

	_logger.info("✅ Instance spawned: game=%s code=%s pid=%d" % [game, code, pid], "spawn")

	return {
		"success": true,
		"code": code,
		"pid": pid,
		"message": "Instance spawned successfully"
	}


func delete(game: String, code: String) -> Dictionary:
	_logger.info("Deleting instance: game=%s code=%s" % [game, code], "delete")

	# Note: Local process spawning doesn't track PIDs, so we can't kill processes
	# This method is a placeholder for implementations that support deletion (like Docker)
	_logger.warn("Local implementation does not support instance deletion", "delete")

	return {
		"success": false,
		"error": "Local implementation does not support instance deletion"
	}


# ============================================================================
# Private helper methods
# ============================================================================

func _get_root(game: String) -> String:
	if _paths.is_empty() or not _paths.has(game):
		return ""
	return _paths[game]


func _get_executable_path(game: String) -> String:
	return (
		_executable_paths[game]
		if not _executable_paths.is_empty() and _executable_paths.has(game)
		else OS.get_executable_path()
	)


func _get_log_path(code: String) -> String:
	if not _log_folder.is_empty():
		if not DirAccess.dir_exists_absolute(_log_folder):
			var error = DirAccess.make_dir_absolute(_log_folder)
			if error:
				_logger.error(str(error) + ": Can't create logs folder " + _log_folder, "_get_log_path")
				return ""
		return _log_folder.path_join(code + ".log")
	return ""


func _get_args(code: String, port: int) -> PackedStringArray:
	var args = PackedStringArray([
		"server_type=room",
		"environment=development",
		"code=" + code,
		"port=" + str(port)
	])
	if not _lobby_url.is_empty():
		args.append("lobby_url=" + _lobby_url)
	return args


func _add_log_path_to_args(log_path: String, args: PackedStringArray) -> PackedStringArray:
	if not log_path.is_empty():
		args = args + PackedStringArray(["--log-file", log_path])
	return args


func _add_root_to_args(root: String, args: PackedStringArray) -> PackedStringArray:
	if not root.is_empty():
		args = args + PackedStringArray(["--path", root])
	return args
