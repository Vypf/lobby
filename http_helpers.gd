extends RefCounted

# HTTP Helper Classes for parsing and building HTTP requests/responses
# Simplifies HTTP server implementation by handling low-level parsing

# ============================================================================
# HTTP Server - Abstracts TCP connection management and request routing
# ============================================================================

class HTTPServer:
	signal request_received(method: String, path: String, request: Request)

	var _tcp_server: TCPServer
	var _connections: Array[Dictionary] = []
	var _port: int
	var _logger: CustomLogger
	var _routes: Dictionary = {}  # {method_path: Callable}
	var _is_running: bool = false

	func _init(port: int, logger: CustomLogger = null):
		_port = port
		_tcp_server = TCPServer.new()
		_logger = logger

	func register_route(method: String, path: String, handler: Callable) -> void:
		var key = method + " " + path
		_routes[key] = handler
		if _logger:
			_logger.debug("Route registered: " + key, "HTTPServer")

	func start() -> int:
		var error = _tcp_server.listen(_port)
		if error != OK:
			if _logger:
				_logger.error("Failed to start server on port " + str(_port), "HTTPServer")
			return error

		_is_running = true
		if _logger:
			_logger.info("HTTP Server listening on port " + str(_port), "HTTPServer")
		return OK

	func stop() -> void:
		_is_running = false
		if _tcp_server:
			_tcp_server.stop()
		if _logger:
			_logger.info("HTTP Server stopped", "HTTPServer")

	func poll() -> void:
		if not _is_running:
			return

		# Accept new connections
		if _tcp_server.is_connection_available():
			var peer = _tcp_server.take_connection()
			_connections.append({
				"peer": peer,
				"request": "",
				"time": Time.get_ticks_msec()
			})
			if _logger:
				_logger.debug("New connection accepted", "HTTPServer")

		# Process existing connections
		var to_remove = []
		for i in range(_connections.size()):
			var conn = _connections[i]
			var peer: StreamPeerTCP = conn.peer

			# Check if connection is still alive
			if peer.get_status() == StreamPeerTCP.STATUS_NONE or peer.get_status() == StreamPeerTCP.STATUS_ERROR:
				to_remove.append(i)
				continue

			# Timeout after 5 seconds
			if Time.get_ticks_msec() - conn.time > 5000:
				if _logger:
					_logger.warn("Connection timeout", "HTTPServer")
				peer.disconnect_from_host()
				to_remove.append(i)
				continue

			# Read available data
			var available = peer.get_available_bytes()
			if available > 0:
				var data = peer.get_data(available)
				if data[0] == OK:
					conn.request += data[1].get_string_from_utf8()

					# Check if request is complete
					if "\r\n\r\n" in conn.request:
						_handle_request(peer, conn.request)
						to_remove.append(i)

		# Remove closed connections
		for i in range(to_remove.size() - 1, -1, -1):
			_connections.remove_at(to_remove[i])

	func _handle_request(peer: StreamPeerTCP, raw_request: String) -> void:
		if _logger:
			_logger.debug("Processing request", "HTTPServer")

		# Parse HTTP request
		var request = Request.parse(raw_request)
		if request == null:
			_send_response(peer, Response.error(400, "Bad Request"))
			return

		if _logger:
			_logger.info("%s %s" % [request.method, request.path], "HTTPServer")

		# Find matching route
		var route_key = request.method + " " + request.path
		if _routes.has(route_key):
			var handler = _routes[route_key]
			var response = handler.call(request)
			_send_response(peer, response)
		else:
			_send_response(peer, Response.error(404, "Not Found"))

	func _send_response(peer: StreamPeerTCP, response: Response) -> void:
		peer.put_data(response.build().to_utf8_buffer())
		peer.disconnect_from_host()


# ============================================================================
# HTTP Request - Represents a parsed HTTP request
# ============================================================================


class Request:
	var method: String
	var path: String
	var headers: Dictionary
	var body: String
	var json_data: Variant

	static func parse(raw_request: String) -> Request:
		var request = Request.new()
		var lines = raw_request.split("\r\n")

		if lines.size() == 0:
			return null

		# Parse request line (GET /path HTTP/1.1)
		var request_line = lines[0].split(" ")
		if request_line.size() < 3:
			return null

		request.method = request_line[0]
		request.path = request_line[1]

		# Parse headers
		request.headers = {}
		var i = 1
		while i < lines.size() and lines[i] != "":
			var header_line = lines[i]
			if ":" in header_line:
				var parts = header_line.split(":", false, 1)
				var key = parts[0].strip_edges()
				var value = parts[1].strip_edges() if parts.size() > 1 else ""
				request.headers[key] = value
			i += 1

		# Parse body
		var body_start = raw_request.find("\r\n\r\n")
		if body_start != -1:
			var content_length = int(request.headers.get("Content-Length", "0"))
			request.body = raw_request.substr(body_start + 4, content_length)

			# Auto-parse JSON if Content-Type is application/json
			if request.headers.get("Content-Type", "").contains("application/json"):
				var json = JSON.new()
				if json.parse(request.body) == OK:
					request.json_data = json.data

		return request


class Response:
	var status_code: int
	var status_text: String
	var headers: Dictionary
	var body: String

	func _init(code: int = 200, data: Variant = null):
		status_code = code
		status_text = _get_status_text(code)
		headers = {
			"Content-Type": "application/json",
			"Connection": "close"
		}

		if data != null:
			body = JSON.stringify(data)
		else:
			body = ""

	func _get_status_text(code: int) -> String:
		match code:
			200: return "OK"
			201: return "Created"
			400: return "Bad Request"
			404: return "Not Found"
			500: return "Internal Server Error"
			_: return "Unknown"

	func build() -> String:
		var response = "HTTP/1.1 %d %s\r\n" % [status_code, status_text]

		# Add Content-Length
		headers["Content-Length"] = str(body.length())

		# Add headers
		for key in headers:
			response += "%s: %s\r\n" % [key, headers[key]]

		response += "\r\n"
		response += body

		return response

	static func success(data: Dictionary) -> Response:
		return Response.new(200, data)

	static func error(code: int, message: String) -> Response:
		return Response.new(code, {
			"success": false,
			"error": message
		})
