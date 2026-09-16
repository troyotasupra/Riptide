extends Control
## Title screen: pick a name, make your character, host a crew or join one.
##
## Command-line shortcuts for quick co-op testing (pass after `--`):
##   --host  --continue  --join=127.0.0.1  --name=Troy  --seed=1234  --port=24570  --window=x,y,w,h
##   --profile=name (a separate player profile, for several copies on one PC)
##   --free-mouse (don't capture the cursor)  --autopilot[=board|stress|gather] (test drivers)
##   --no-focus (window never takes keyboard focus)  --shot=path.png --shot-delay=seconds
##   --spawn=camp|boat  --face=camp|sea|bow  --time=0.5 (time of day, 0..1)
##   --scenario=camp|client (scripted end-to-end checks)  --hide-ocean  --dev (developer mode)

var _main: VBoxContainer
var _name_edit: LineEdit
var _address_edit: LineEdit
var _port_edit: LineEdit
var _status: Label
var _creator: CharacterCreator
var _settings: SettingsPanel
var _dev_toggle: CheckBox
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

	_main = VBoxContainer.new()
	_main.custom_minimum_size = Vector2(400.0, 0.0)
	_main.add_theme_constant_override("separation", 8)
	center.add_child(_main)

	var title := UiKit.title(_main, "RIPTIDE", 72)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle := UiKit.label(_main, "co-op survival on a hostile sea")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_name_edit = _add_field(_main, "Your name", Profile.player_name)
	var profile_row := HBoxContainer.new()
	profile_row.add_theme_constant_override("separation", 8)
	_main.add_child(profile_row)
	UiKit.button(profile_row, "Character", _open_creator).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.button(profile_row, "Settings", _open_settings).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var dev_toggle := CheckBox.new()
	_dev_toggle = dev_toggle
	dev_toggle.text = "Developer mode when hosting  (F1 menu · V fly)"
	dev_toggle.button_pressed = Settings.developer_mode
	dev_toggle.toggled.connect(func(on: bool) -> void:
		Settings.developer_mode = on
		Settings.save_settings())
	_main.add_child(dev_toggle)

	if SaveGame.has_save():
		UiKit.button(_main, "Continue saved world (host)", _on_continue)
	UiKit.button(_main, "Host new world", _on_host)
	if SaveGame.has_save():
		UiKit.label(_main, "Hosting a new world replaces your save the next time it autosaves.", true)

	_address_edit = _add_field(_main, "Host address (to join)", "127.0.0.1")
	_port_edit = _add_field(_main, "Port", str(Net.DEFAULT_PORT))
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	_main.add_child(join_row)
	UiKit.button(join_row, "Join crew", _on_join).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.button(join_row, "Quit", get_tree().quit).size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_status = UiKit.label(_main, "")
	_status.custom_minimum_size = Vector2(400.0, 48.0)

	_creator = CharacterCreator.new()
	_creator.visible = false
	center.add_child(_creator)
	_creator.closed.connect(_show_main)
	_settings = SettingsPanel.new()
	_settings.visible = false
	center.add_child(_settings)
	_settings.closed.connect(_show_main)
	UiKit.focus_first(_main)


func _add_field(parent: Control, label_text: String, value: String) -> LineEdit:
	UiKit.label(parent, label_text)
	var edit := LineEdit.new()
	edit.text = value
	parent.add_child(edit)
	return edit


func _open_creator() -> void:
	_main.visible = false
	_creator.visible = true


func _open_settings() -> void:
	_main.visible = false
	_settings.visible = true


func _show_main() -> void:
	_main.visible = true
	UiKit.focus_first(_main)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _creator.visible:
			_creator.close()
		elif _settings.visible:
			_settings.close()


func _on_status(message: String) -> void:
	_status.text = message


func _port() -> int:
	return int(_port_edit.text) if _port_edit.text.is_valid_int() else Net.DEFAULT_PORT


func _on_host() -> void:
	Net.set_local_name(_name_edit.text)
	SaveGame.pending = {}
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
	if args.has("mute") or args.has("no-focus"):
		Settings.muted = true
		Settings.apply()
	GameState.free_mouse = args.has("free-mouse")
	if args.has("dev"):
		# Show it ticked for this run, but don't save it: --dev is for one launch.
		Settings.developer_mode = true
		_dev_toggle.set_pressed_no_signal(true)
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
