class_name Hud
extends CanvasLayer
## The in-game screen: survival bars, clock and compass, hotbar with item
## pictures, the interaction prompt (with hold progress and controller-aware
## button names), objectives, messages, the sleep countdown, the F3 debug
## overlay, and every panel — the inventory screen, survival book, notes, pause
## menu and settings.

const MESSAGE_SECONDS := 5.0
const CARDINALS := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

var _info: Label
var _clock: Label
var _markers: Label
var _prompt: Label
var _sleep_line: Label
var _messages: Label
var _temperature: Label
var _bars := {}
var _status: VBoxContainer
var _hotbar: HBoxContainer
var _hotbar_views: Array[SlotView] = []
var _inventory: InventoryScreen
var _book: BookPanel
var _note: NotePanel
var _pause: PauseMenu
var _settings: SettingsPanel
var _sleep_overlay: ColorRect
var _message_log: Array = []
var _lan_addresses := ""
var _bound: Survivor = null
var _camp: CampSystems
var _objective_accum := 1.0
var _objectives: PackedStringArray = []


func _ready() -> void:
	var crosshair := ColorRect.new()
	crosshair.color = Color(1.0, 1.0, 1.0, 0.85)
	crosshair.custom_minimum_size = Vector2(4.0, 4.0)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crosshair)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

	_info = _label(14)
	_info.position = Vector2(16.0, 10.0)

	_clock = _label(20)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_KEEP_SIZE, 10)
	_clock.grow_horizontal = Control.GROW_DIRECTION_BOTH

	_markers = _label(13)
	_markers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_markers.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_KEEP_SIZE, 40)
	_markers.grow_horizontal = Control.GROW_DIRECTION_BOTH

	_prompt = _label(18)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.offset_top += 42.0
	_prompt.offset_bottom += 42.0

	_sleep_line = _label(16)
	_sleep_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sleep_line.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_KEEP_SIZE, 64)
	_sleep_line.grow_horizontal = Control.GROW_DIRECTION_BOTH

	_messages = _label(15)
	_messages.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_messages.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 16)
	_messages.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	_build_bars()
	_build_hotbar()

	_sleep_overlay = ColorRect.new()
	_sleep_overlay.color = Color(0.0, 0.0, 0.03, 0.85)
	_sleep_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sleep_overlay.visible = false
	add_child(_sleep_overlay)
	_sleep_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sleep_label := Label.new()
	sleep_label.text = "Sleeping... the night passes once most of the crew turns in.\nPress any button to get up."
	sleep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sleep_overlay.add_child(sleep_label)
	sleep_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	sleep_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sleep_label.grow_vertical = Control.GROW_DIRECTION_BOTH

	_inventory = InventoryScreen.new()
	_inventory.visible = false
	add_child(_inventory)
	_book = _panel(BookPanel.new())
	_note = _panel(NotePanel.new())
	_pause = _panel(PauseMenu.new())
	_settings = _panel(SettingsPanel.new())
	_note.close_requested.connect(func() -> void: _close_all())
	_pause.resume_requested.connect(func() -> void: _close_all())
	_pause.settings_requested.connect(func() -> void:
		_pause.visible = false
		_settings.visible = true)
	_settings.closed.connect(func() -> void:
		_pause.visible = true
		_sync_ui_state())

	var addresses: PackedStringArray = []
	for address in IP.get_local_addresses():
		if address.contains(".") and not address.begins_with("127.") and not address.begins_with("169.254."):
			addresses.append(address)
	_lan_addresses = ", ".join(addresses)

	_camp = GameState.world.camp
	_inventory.camp = _camp
	_book.camp = _camp
	_camp.container_opened.connect(_on_container_opened)
	_camp.container_changed.connect(func(id: String) -> void:
		if _inventory.container_id == id:
			_inventory.refresh())
	_camp.container_closed.connect(func(id: String) -> void:
		if _inventory.container_id == id:
			_inventory.container_id = ""
			_inventory.refresh())
	_camp.recipes_changed.connect(func() -> void: _book.refresh())
	_camp.sleeping_changed.connect(func(asleep: bool) -> void: _sleep_overlay.visible = asleep)
	Icons.icon_ready.connect(func(_id: String) -> void:
		for view: SlotView in _hotbar_views:
			view.refresh_icon())


func _panel(panel: PanelContainer) -> Variant:
	panel.visible = false
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	return panel


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	add_child(label)
	return label


func _build_bars() -> void:
	var bars := VBoxContainer.new()
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bars)
	_status = bars
	for spec: Array in [
			["health", "Health", Color(0.85, 0.25, 0.25)],
			["hunger", "Food", Color(0.90, 0.60, 0.20)],
			["thirst", "Water", Color(0.30, 0.60, 0.95)],
			["stamina", "Stamina", Color(0.90, 0.90, 0.40)]]:
		var row := HBoxContainer.new()
		bars.add_child(row)
		var name_label := Label.new()
		name_label.text = spec[1]
		name_label.custom_minimum_size = Vector2(64.0, 0.0)
		name_label.add_theme_constant_override("outline_size", 5)
		name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
		row.add_child(name_label)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(170.0, 14.0)
		bar.show_percentage = false
		bar.max_value = 100.0
		var fill := StyleBoxFlat.new()
		fill.bg_color = spec[2]
		bar.add_theme_stylebox_override("fill", fill)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		_bars[spec[0]] = bar
	_temperature = Label.new()
	_temperature.add_theme_constant_override("outline_size", 5)
	_temperature.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	bars.add_child(_temperature)
	bars.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	bars.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _build_hotbar() -> void:
	_hotbar = HBoxContainer.new()
	_hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hotbar.add_theme_constant_override("separation", 5)
	add_child(_hotbar)
	for i in Pack.HOTBAR_SIZE:
		var view := SlotView.new()
		view.setup("hotbar", i, "", "", 62.0)
		_hotbar.add_child(view)
		_hotbar_views.append(view)
	_hotbar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 12)
	_hotbar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hotbar.grow_vertical = Control.GROW_DIRECTION_BEGIN


# --- panels --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if GameState.local_player == null or _bound == null:
		return
	var cancel := event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")
	var handled := true
	if event.is_action_pressed("debug"):
		Settings.show_debug = not Settings.show_debug
	elif _settings.visible:
		if cancel:
			_settings.close()
		else:
			handled = false
	elif _pause.visible:
		if cancel:
			_close_all()
		else:
			handled = false
	elif _inventory.visible:
		if cancel or event.is_action_pressed("inventory") or (event is InputEventKey and event.is_action_pressed("interact")):
			_close_all()
		else:
			handled = false
	elif _note.visible:
		if cancel:
			_close_all()
		else:
			handled = false
	elif _book.visible:
		if cancel or event.is_action_pressed("book"):
			_close_all()
		elif event.is_action_pressed("inventory"):
			_show_only(_inventory)
		else:
			handled = false
	elif event.is_action_pressed("inventory"):
		Sound.play("open", -8.0)
		_show_only(_inventory)
	elif event.is_action_pressed("book"):
		Sound.play("book_open", -6.0)
		_show_only(_book)
	elif event.is_action_pressed("pause"):
		_show_only(_pause)
	else:
		handled = false
	if handled:
		_sync_ui_state()
		get_viewport().set_input_as_handled()


func _show_only(panel: Control) -> void:
	for other: Control in [_inventory, _book, _note, _pause, _settings]:
		other.visible = other == panel
	_hotbar.visible = panel == null


func _close_all() -> void:
	_show_only(null)
	_sync_ui_state()


func _sync_ui_state() -> void:
	var open := _inventory.visible or _book.visible or _note.visible or _pause.visible or _settings.visible
	_hotbar.visible = not open
	# Full-screen panels get a clean backdrop: no compass, objectives or bars behind them.
	for overlay: Control in [_info, _clock, _markers, _prompt, _status]:
		if overlay != null:
			overlay.visible = not open
	if open == GameState.ui_open:
		return
	GameState.ui_open = open
	if open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif not GameState.free_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_container_opened(id: String, title: String) -> void:
	_inventory.container_id = id
	_inventory.container_title = title
	_show_only(_inventory)
	_inventory.refresh()
	_sync_ui_state()


func _bind(survivor: Survivor) -> void:
	if _bound != null and is_instance_valid(_bound):
		_bound.notified.disconnect(_on_message)
		_bound.inventory_changed.disconnect(_refresh_items)
		_bound.note_requested.disconnect(_on_note_requested)
		_bound.book_requested.disconnect(_on_book_requested)
	_bound = survivor
	if _bound != null:
		_bound.notified.connect(_on_message)
		_bound.inventory_changed.connect(_refresh_items)
		_bound.note_requested.connect(_on_note_requested)
		_bound.book_requested.connect(_on_book_requested)
	_inventory.survivor = _bound
	_book.survivor = _bound
	_refresh_items()


func _on_note_requested(note_id: String) -> void:
	_show_only(_note)
	_note.show_note(note_id)
	_sync_ui_state()


func _on_book_requested() -> void:
	_show_only(_book)
	_sync_ui_state()


func _on_message(message: String) -> void:
	if message.is_empty():
		return
	_message_log.append({"text": message, "until": Time.get_ticks_msec() / 1000.0 + MESSAGE_SECONDS})
	if _message_log.size() > 5:
		_message_log.pop_front()


func _refresh_items() -> void:
	if _bound == null:
		return
	for i in Pack.HOTBAR_SIZE:
		_hotbar_views[i].show_stack(_bound.inventory.hotbar[i])
		_hotbar_views[i].set_state(i == _bound.selected_slot, false, Color.TRANSPARENT)
	if _inventory.visible:
		_inventory.refresh()
	_book.refresh()


# --- per frame -------------------------------------------------------------------

func _process(delta: float) -> void:
	var player := GameState.local_player as Player
	if player != null and player.survivor != _bound:
		_bind(player.survivor)

	var now := Time.get_ticks_msec() / 1000.0
	_message_log = _message_log.filter(func(m: Dictionary) -> bool: return m.until > now)
	_messages.text = "\n".join(PackedStringArray(_message_log.map(func(m: Dictionary) -> String: return m.text)))

	_objective_accum += delta
	if player != null and _objective_accum >= 0.5:
		_objective_accum = 0.0
		_objectives = Objectives.upcoming(GameState.world, player)
	_update_info(player)

	if player == null or _bound == null:
		return
	var survival := _bound.survival
	_bars["health"].value = survival.health
	_bars["hunger"].value = survival.hunger
	_bars["thirst"].value = survival.thirst
	_bars["stamina"].value = player.stamina
	var temperature := "Body %.1f°C · feels %.0f°C" % [survival.body_temp, _bound.air_temp]
	if _bound.warmth > 0.0:
		temperature += " · sheltered"
	if _bound.wetness > 0.05:
		temperature += " · soaked" if _bound.wetness > 0.6 else " · damp"
	if survival.sickness > 0.0:
		temperature += " · SICK"
	_temperature.text = temperature
	if survival.sickness > 0.0:
		_temperature.modulate = Color(0.7, 1.0, 0.45)
	elif survival.body_temp < 35.0:
		_temperature.modulate = Color(0.55, 0.75, 1.0)
	elif survival.body_temp > 38.5:
		_temperature.modulate = Color(1.0, 0.5, 0.4)
	else:
		_temperature.modulate = Color.WHITE

	var here := player.world_transform().origin
	var heading := 0.0
	if player.camera != null:
		var forward := -player.camera.global_basis.z
		heading = fposmod(rad_to_deg(atan2(forward.x, -forward.z)), 360.0)
	_clock.text = "%s    %s %03d°" % [DayNight.clock_text(GameState.time_of_day()), CARDINALS[int(round(heading / 45.0)) % 8], int(heading)]
	_markers.text = _chart_markers(here) if _camp.chart_read else ""
	_prompt.text = "" if GameState.ui_open else _prompt_text(player)

	var status: Dictionary = _camp.sleep_status
	if float(status.left) >= 0.0:
		_sleep_line.text = "Night skips in %ds — %d of the crew in bed" % [ceili(float(status.left)), int(status.asleep)]
	elif int(status.asleep) > 0:
		_sleep_line.text = "%d in bed — %d of the crew need to sleep to skip the night" % [int(status.asleep), int(status.needed)]
	else:
		_sleep_line.text = ""


func _prompt_text(player: Player) -> String:
	if player.is_placing():
		return "%s Build here   %s Rotate   (pick another hotbar slot to cancel)" % [Controls.tag("primary"), Controls.tag("rotate")]
	if not player.focus_text.is_empty():
		var tool: String = ItemTable.get_item(player.held_id).get("tool", "")
		var keys := Controls.tag("interact")
		if Player.SWING_TOOLS.has(tool) and player.focus_id.begins_with("res:"):
			keys = "%s / %s" % [Controls.tag("primary"), keys]
		var text := "%s  %s" % [keys, player.focus_text]
		var progress := player.hold_fraction()
		if progress > 0.0:
			var filled := int(round(progress * 10.0))
			text += "   " + "▰".repeat(filled) + "▱".repeat(10 - filled)
		return text
	return player.give_text


func _chart_markers(here: Vector3) -> String:
	var world := GameState.world
	var marks: PackedStringArray = []
	marks.append("Start island %03d°" % _bearing(here, Vector2.ZERO))
	if world.camp_island != null:
		marks.append("Camp island %03d°" % _bearing(here, world.camp_island.center))
		var beyond: Vector2 = world.camp_island.center + Vector2.from_angle(world.camp_island.center.angle() + 0.6) * 1400.0
		marks.append("Uncharted waters %03d°" % _bearing(here, beyond))
	return "Chart:  " + "  ·  ".join(marks)


static func _bearing(from: Vector3, to: Vector2) -> int:
	var d := to - Vector2(from.x, from.z)
	return int(fposmod(rad_to_deg(atan2(d.x, -d.y)), 360.0))


func _update_info(player: Player) -> void:
	var lines: PackedStringArray = []
	if not _objectives.is_empty():
		lines.append("NEXT")
		for objective in _objectives:
			lines.append("  • " + objective)
	if Net.roster.size() > 1:
		var names: PackedStringArray = []
		for id: int in Net.roster:
			names.append(Net.roster[id]["name"])
		lines.append("Crew: " + ", ".join(names))
	if player != null and player.platform != null and player.platform.can_paddle:
		lines.append("%s paddle%s" % [Controls.tag("paddle"), " — WASD steers, %s pulls hard" % Controls.tag("sprint") if player.paddling else ""])
	if Settings.show_debug:
		lines.append("")
		lines.append("RIPTIDE M1c-pre · %s · peer %d" % ["HOST" if multiplayer.is_server() else "CREW", multiplayer.get_unique_id()])
		if multiplayer.is_server():
			lines.append("Join: %s port %d" % [_lan_addresses, Net.port])
		lines.append("FPS %d" % Engine.get_frames_per_second())
		if player != null:
			var p := player.world_transform().origin
			lines.append("Pos %.0f, %.0f, %.0f · %.1f kg" % [p.x, p.y, p.z, player.carried_weight_kg])
	_info.text = "\n".join(lines)
