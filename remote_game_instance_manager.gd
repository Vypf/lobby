extends RefCounted
class_name RemoteGameInstanceManager

# Manages game instance lifecycle (spawn and delete)
# Remote implementation using HTTP calls to Spawner API - for production environment

var _logger: CustomLogger
var _spawner_api_url: String
var _lobby_url: String
var _environment: String

const INTERNAL_PORT = 18000  # Fixed internal port for all game instances


func _init(spawner_api_url: String, lobby_url: String, environment: String = "production"):
	_logger = CustomLogger.new("RemoteGameInstanceManager")
	_spawner_api_url = spawner_api_url
	_lobby_url = lobby_url
	_environment = environment


func spawn(game: String, code: String, port: int) -> Dictionary:
	_logger.info("Spawning remote instance: game=%s code=%s external_port=%d" % [game, code, port], "spawn")
	_logger.debug("Using spawner_api_url=%s lobby_url=%s environment=%s" % [_spawner_api_url, _lobby_url, _environment], "spawn")

	var url = _spawner_api_url + "/spawn"
	var body = {
		"game": game,
		"code": code,
		"params": {
			"server_type": "room",
			"environment": _environment,
			"code": code,
			"port": str(INTERNAL_PORT),  # Port the container listens on (fixed)
			"external_port": str(port),  # For dev mode: host port mapping
			"lobby_url": _lobby_url
		}
	}

	_logger.debug("Request body: %s" % JSON.stringify(body), "spawn")

	var result = _http_request("POST", url, body)

	if result.success:
		_logger.info("✅ Remote instance spawned: game=%s code=%s" % [game, code], "spawn")
	else:
		_logger.error("Failed to spawn remote instance: " + result.error, "spawn")

	return result


func delete(game: String, code: String) -> Dictionary:
	_logger.info("Deleting remote instance: game=%s code=%s" % [game, code], "delete")

	var url = _spawner_api_url + "/container"
	var body = {
		"game": game,
		"code": code
	}

	var result = _http_request("DELETE", url, body)

	if result.success:
		_logger.info("✅ Remote instance deleted: game=%s code=%s" % [game, code], "delete")
	else:
		_logger.error("Failed to delete remote instance: " + result.error, "delete")

	return result


# ============================================================================
# HTTP Client - Simple synchronous HTTP requests
# ============================================================================

func _http_request(method: String, url: String, body: Dictionary) -> Dictionary:
	# Parse URL to get host and port
	var uri = url.replace("http://", "").replace("https://", "")
	var path_start = uri.find("/")
	var host_port = uri.substr(0, path_start) if path_start != -1 else uri
	var path = uri.substr(path_start) if path_start != -1 else "/"

	var host: String
	var port: int

	if ":" in host_port:
		var parts = host_port.split(":")
		host = parts[0]
		port = int(parts[1])
	else:
		host = host_port
		port = 80

	_logger.debug("HTTP %s %s:%d%s" % [method, host, port, path], "_http_request")

	# Create TCP connection
	var tcp = StreamPeerTCP.new()
	var error = tcp.connect_to_host(host, port)

	if error != OK:
		_logger.error("connect_to_host failed with error %d for %s:%d" % [error, host, port], "_http_request")
		return {
			"success": false,
			"error": "Failed to connect to %s:%d (error %d)" % [host, port, error]
		}

	# Wait for connection
	var timeout = 5000
	var start_time = Time.get_ticks_msec()

	_logger.debug("Waiting for TCP connection to %s:%d..." % [host, port], "_http_request")

	while tcp.get_status() == StreamPeerTCP.STATUS_CONNECTING:
		tcp.poll()
		if Time.get_ticks_msec() - start_time > timeout:
			_logger.error("Connection timeout after %dms to %s:%d" % [timeout, host, port], "_http_request")
			return {
				"success": false,
				"error": "Connection timeout to %s:%d" % [host, port]
			}
		OS.delay_msec(10)

	var status = tcp.get_status()
	if status != StreamPeerTCP.STATUS_CONNECTED:
		var status_name = _get_tcp_status_name(status)
		_logger.error("Failed to establish connection to %s:%d (status: %s)" % [host, port, status_name], "_http_request")
		return {
			"success": false,
			"error": "Failed to establish connection to %s:%d (status: %s)" % [host, port, status_name]
		}

	_logger.debug("TCP connected to %s:%d" % [host, port], "_http_request")

	# Build HTTP request
	var json_body = JSON.stringify(body)
	var request = "%s %s HTTP/1.1\r\n" % [method, path]
	request += "Host: %s\r\n" % host
	request += "Content-Type: application/json\r\n"
	request += "Content-Length: %d\r\n" % json_body.length()
	request += "Connection: close\r\n"
	request += "\r\n"
	request += json_body

	# Send request
	var send_error = tcp.put_data(request.to_utf8_buffer())
	if send_error != OK:
		_logger.error("Failed to send HTTP request (error %d)" % send_error, "_http_request")
		tcp.disconnect_from_host()
		return {
			"success": false,
			"error": "Failed to send HTTP request (error %d)" % send_error
		}

	_logger.debug("HTTP request sent, waiting for response...", "_http_request")

	# Read response
	var response_data = PackedByteArray()
	start_time = Time.get_ticks_msec()

	while true:
		tcp.poll()
		status = tcp.get_status()

		# Check if socket is still valid for reading
		if status != StreamPeerTCP.STATUS_CONNECTED:
			_logger.debug("TCP status changed to %s after %dms" % [_get_tcp_status_name(status), Time.get_ticks_msec() - start_time], "_http_request")
			break

		var available = tcp.get_available_bytes()
		if available > 0:
			var chunk = tcp.get_data(available)
			if chunk[0] == OK:
				response_data.append_array(chunk[1])
				_logger.debug("Received %d bytes (total: %d)" % [available, response_data.size()], "_http_request")

		if Time.get_ticks_msec() - start_time > timeout:
			_logger.warn("Response read timeout after %dms (received %d bytes)" % [timeout, response_data.size()], "_http_request")
			break

		OS.delay_msec(10)

	tcp.disconnect_from_host()

	# Parse response
	var response_str = response_data.get_string_from_utf8()

	if response_str.is_empty():
		_logger.error("Empty response from server", "_http_request")
		return {
			"success": false,
			"error": "Empty response from server"
		}

	# Extract status line
	var first_line_end = response_str.find("\r\n")
	var status_line = response_str.substr(0, first_line_end) if first_line_end != -1 else response_str.substr(0, 50)
	_logger.debug("HTTP response: %s" % status_line, "_http_request")

	# Extract body from response
	var body_start = response_str.find("\r\n\r\n")
	if body_start == -1:
		_logger.error("Invalid HTTP response (no body separator)", "_http_request")
		return {
			"success": false,
			"error": "Invalid HTTP response"
		}

	var response_body = response_str.substr(body_start + 4)
	_logger.debug("Response body: %s" % response_body, "_http_request")

	# Parse JSON response
	var json = JSON.new()
	var parse_result = json.parse(response_body)

	if parse_result != OK:
		_logger.error("Failed to parse JSON: %s" % response_body, "_http_request")
		return {
			"success": false,
			"error": "Failed to parse JSON response: " + response_body
		}

	return json.data


func _get_tcp_status_name(status: int) -> String:
	match status:
		StreamPeerTCP.STATUS_NONE:
			return "NONE"
		StreamPeerTCP.STATUS_CONNECTING:
			return "CONNECTING"
		StreamPeerTCP.STATUS_CONNECTED:
			return "CONNECTED"
		StreamPeerTCP.STATUS_ERROR:
			return "ERROR"
		_:
			return "UNKNOWN(%d)" % status
