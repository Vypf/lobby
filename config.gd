extends Node

var arguments := {}:
	get:
		var parsed_args := {}
		var args = OS.get_cmdline_args()

		for i in range(args.size()):
			var arg = args[i]

			if arg.begins_with("--"):
				var key = arg.trim_prefix("--")

				# format --key=value
				if "=" in arg:
					var kv = arg.split("=")
					key = kv[0].trim_prefix("--")
					var value = _convert_value(kv[1])
					_add_argument(parsed_args, key, value)

				# format --key VALUE (séparés par un espace)
				elif i + 1 < args.size() and not args[i + 1].begins_with("--"):
					var value = _convert_value(args[i + 1])
					_add_argument(parsed_args, key, value)

				# format --flag (bool)
				else:
					parsed_args[key] = true
			else:
				# Fallback for arguments without -- (format: key=value)
				if "=" in arg:
					var kv = arg.split("=")
					var key = kv[0]
					var value = _convert_value(kv[1])
					_add_argument(parsed_args, key, value)

		# fallback environment
		if not parsed_args.has("environment"):
			var env_environment = OS.get_environment("ENVIRONMENT")
			if env_environment != "":
				parsed_args["environment"] = env_environment

		parsed_args.headless = DisplayServer.get_window_list().size() == 0
		return parsed_args


var is_production: bool:
	get:
		var args = arguments
		return (
			OS.has_feature("production")
			or (args.has("environment") and args["environment"] == "production")
		)


func _ready():
	if arguments.has("username"):
		get_window().title = arguments["username"]


func _add_argument(parsed: Dictionary, key: String, value) -> void:
	# auto-détection dictionnaire ou array
	if typeof(value) == TYPE_STRING and "=" in value:
		var kv = value.split("=")
		if kv.size() == 2:
			if not parsed.has(key) or typeof(parsed[key]) != TYPE_DICTIONARY:
				parsed[key] = {}
			parsed[key][kv[0]] = _convert_value(kv[1])
	else:
		if not parsed.has(key):
			parsed[key] = value
		elif typeof(parsed[key]) == TYPE_ARRAY:
			parsed[key].append(value)
		else:
			parsed[key] = [parsed[key], value]


func _convert_value(raw: String):
	# essaie de caster en bool, int ou float
	var lower = raw.to_lower()
	if lower == "true":
		return true
	elif lower == "false":
		return false
	elif raw.is_valid_int():
		return int(raw)
	elif raw.is_valid_float():
		return float(raw)
	return raw
