extends Control
## Title screen: pick a name, host a crew or join one by IP.
##
## Command-line shortcuts for quick co-op testing (pass after `--`):
##   --host  --join=127.0.0.1  --name=Troy  --seed=1234  --port=24570  --window=x,y,w,h
##   --free-mouse (don't capture the cursor)  --autopilot[=board|stress] (raft test driver)
##   --no-focus (window never takes keyboard focus)  --shot=path.png --shot-delay=seconds
##   --spawn=camp (start on the camp island)  --face=camp (look toward it)  --time=0.5 (time of day, 0..1)
##   --autopilot=gather (walk to props, harvest, eat; logs [inventory] and [notify])

var _name_edit: LineEdit
var _address_edit: LineEdit
var _port_edit: LineEdit
var _status: Label
var _seed_override := 0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_ui()
	_status.text = Net.last_message
	Net.status.connect(_on_status)
	_apply_command_line.call_deferred()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.05, 0.17, 0.25)
	add_child(background)
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(380.0, 0.0)
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)

	var title := Label.new()
	title.text = "RIPTIDE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "co-op survival on a hostile sea"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	_name_edit = _add_field(box, "Your name", Net.local_name)
	_address_edit = _add_field(box, "Host address (to join)", "127.0.0.1")
	_port_edit = _add_field(box, "Port", str(Net.DEFAULT_PORT))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	_add_button(buttons, "Host new world", _on_host)
	_add_button(buttons, "Join crew", _on_join)
	_add_button(buttons, "Quit", get_tree().quit)
	if SaveGame.has_save():
		var continue_button := Button.new()
		continue_button.text = "Continue saved world (host)"
		continue_button.pressed.connect(_on_continue)
		box.add_child(continue_button)
		var warning := Label.new()
		warning.text = "Hosting a new world replaces your save the next time it autosaves."
		warning.modulate = Color(1.0, 1.0, 1.0, 0.6)
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(warning)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(380.0, 48.0)
	box.add_child(_status)


func _add_field(parent: Control, label_text: String, value: String) -> LineEdit:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var edit := LineEdit.new()
	edit.text = value
	parent.add_child(edit)
	return edit


func _add_button(parent: Control, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)


func _on_status(message: String) -> void:
	_status.text = message


func _port() -> int:
	return int(_port_edit.text) if _port_edit.text.is_valid_int() else Net.DEFAULT_PORT


func _on_host() -> void:
	Net.set_local_name(_name_edit.text)
	GameState.world_seed = _seed_override if _seed_override != 0 else randi_range(1, 2147483646)
	Net.host_game(_port())


func _on_continue() -> void:
	var data := SaveGame.read()
	if data.is_empty():
		_status.text = "Couldn't read the save file."
		return
	Net.set_local_name(_name_edit.text)
	GameState.world_seed = data.get("seed", 1)
	SaveGame.pending = data
	Net.host_game(_port())


func _on_join() -> void:
	Net.set_local_name(_name_edit.text)
	Net.join_game(_address_edit.text.strip_edges(), _port())


func _apply_command_line() -> void:
	# Only the first menu of a process obeys the command line; coming back to the
	# menu after a session ends must never auto-host or auto-join again.
	if GameState.command_line_used:
		return
	GameState.command_line_used = true
	var args := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var parts := arg.substr(2).split("=", true, 1)
			args[parts[0]] = parts[1] if parts.size() > 1 else ""
	if args.has("no-focus") and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	if args.has("window") and DisplayServer.get_name() != "headless":
		var v: PackedStringArray = String(args["window"]).split(",")
		if v.size() == 4:
			DisplayServer.window_set_position(Vector2i(int(v[0]), int(v[1])))
			DisplayServer.window_set_size(Vector2i(int(v[2]), int(v[3])))
	GameState.free_mouse = args.has("free-mouse")
	if args.has("autopilot"):
		GameState.autopilot = "board" if String(args["autopilot"]).is_empty() else String(args["autopilot"])
	GameState.spawn_override = args.get("spawn", "")
	GameState.face = args.get("face", "")
	GameState.scenario = args.get("scenario", "")
	GameState.hide_ocean = args.has("hide-ocean")
	if String(args.get("time", "")).is_valid_float():
		GameState.start_time = clampf(float(args["time"]), 0.0, 1.0)
	GameState.screenshot_path = args.get("shot", "")
	if String(args.get("shot-delay", "")).is_valid_float():
		GameState.screenshot_delay = float(args["shot-delay"])
	if args.has("name"):
		_name_edit.text = args["name"]
	if args.has("port"):
		_port_edit.text = args["port"]
	if args.has("seed"):
		_seed_override = int(args["seed"])
	if args.has("continue"):
		_on_continue()
	elif args.has("host"):
		_on_host()
	elif args.has("join"):
		if not String(args["join"]).is_empty():
			_address_edit.text = args["join"]
		_on_join()
