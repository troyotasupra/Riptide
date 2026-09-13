class_name Hud
extends CanvasLayer
## Prototype HUD: survival bars, clock and compass, hotbar, the interaction
## prompt (with hold progress), messages, the crew roster, the sleep screen,
## and the backpack, storage, survival book and note panels.

const MESSAGE_SECONDS := 5.0
const CARDINALS := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

var _info: Label
var _clock: Label
var _markers: Label
var _prompt: Label
var _messages: Label
var _temperature: Label
var _bars := {}
var _hotbar_labels: Array[Label] = []
var _hotbar_panels: Array[PanelContainer] = []
var _inventory: InventoryPanel
var _storage: ContainerPanel
var _book: BookPanel
var _note: NotePanel
var _sleep_overlay: ColorRect
var _message_log: Array = []
var _lan_addresses := ""
var _bound: Survivor = null
var _camp: CampSystems


func _ready() -> void:
	var crosshair := ColorRect.new()
	crosshair.color = Color(1.0, 1.0, 1.0, 0.85)
	crosshair.custom_minimum_size = Vector2(4.0, 4.0)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crosshair)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

	_info = _label(13)
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

	var help := _label(12)
	help.text = "WASD move · Shift sprint/paddle hard · Space jump · C crouch · F paddle\nE interact (hold to gather) · LMB use/build · R rotate · 1–8 hotbar · I backpack · B book · F10 leave"
	help.modulate = Color(1.0, 1.0, 1.0, 0.7)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 12)
	help.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	_messages = _label(15)
	_messages.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_messages.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 16)
	_messages.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_messages.offset_top += 44.0
	_messages.offset_bottom += 44.0

	_build_bars()
	_build_hotbar()

	_sleep_overlay = ColorRect.new()
	_sleep_overlay.color = Color(0.0, 0.0, 0.03, 0.85)
	_sleep_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sleep_overlay.visible = false
	add_child(_sleep_overlay)
	_sleep_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sleep_label := Label.new()
	sleep_label.text = "Sleeping... waiting for the rest of the crew to turn in.\nPress any key to get up."
	sleep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sleep_overlay.add_child(sleep_label)
	sleep_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	sleep_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sleep_label.grow_vertical = Control.GROW_DIRECTION_BOTH

	_inventory = _panel(InventoryPanel.new())
	_storage = _panel(ContainerPanel.new())
	_book = _panel(BookPanel.new())
	_note = _panel(NotePanel.new())

	var addresses: PackedStringArray = []
	for address in IP.get_local_addresses():
		if address.contains(".") and not address.begins_with("127.") and not address.begins_with("169.254."):
			addresses.append(address)
	_lan_addresses = ", ".join(addresses)

	_camp = GameState.world.camp
	_storage.camp = _camp
	_book.camp = _camp
	_camp.container_opened.connect(_on_container_opened)
	_camp.container_changed.connect(func(_id: String) -> void: _storage.refresh())
	_camp.recipes_changed.connect(func() -> void: _book.refresh())
	_camp.sleeping_changed.connect(func(asleep: bool) -> void: _sleep_overlay.visible = asleep)


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
	var hotbar := HBoxContainer.new()
	hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hotbar.add_theme_constant_override("separation", 4)
	add_child(hotbar)
	for i in Inventory.HOTBAR_SIZE:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(88.0, 50.0)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 12)
		panel.add_child(label)
		hotbar.add_child(panel)
		_hotbar_panels.append(panel)
		_hotbar_labels.append(label)
	hotbar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 12)
	hotbar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hotbar.grow_vertical = Control.GROW_DIRECTION_BEGIN


# --- panels --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if GameState.local_player == null or _bound == null:
		return
	var handled := true
	if _storage.visible and (event.is_action_pressed("pause") or event.is_action_pressed("interact") or event.is_action_pressed("inventory")):
		_storage.close()
	elif _note.visible and event.is_action_pressed("pause"):
		_note.visible = false
	elif event.is_action_pressed("inventory") or (_inventory.visible and event.is_action_pressed("pause")):
		_show_only(null if _inventory.visible else _inventory)
	elif event.is_action_pressed("book") or (_book.visible and event.is_action_pressed("pause")):
		_show_only(null if _book.visible else _book)
	else:
		handled = false
	if handled:
		_sync_ui_state()
		get_viewport().set_input_as_handled()


func _show_only(panel: PanelContainer) -> void:
	for other: PanelContainer in [_inventory, _book, _note]:
		other.visible = other == panel
	if _storage.visible and panel != null:
		_storage.close()
	if panel == _inventory:
		_inventory.refresh()
	elif panel == _book:
		_book.refresh()


func _sync_ui_state() -> void:
	var open := _inventory.visible or _storage.visible or _book.visible or _note.visible
	if open == GameState.ui_open:
		return
	GameState.ui_open = open
	if open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif not GameState.free_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_container_opened(id: String, title: String) -> void:
	_show_only(null)
	_storage.open(id, title)
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
	_storage.survivor = _bound
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
	_message_log.append({"text": message, "until": Time.get_ticks_msec() / 1000.0 + MESSAGE_SECONDS})
	if _message_log.size() > 5:
		_message_log.pop_front()


func _refresh_items() -> void:
	if _bound == null:
		return
	for i in Inventory.HOTBAR_SIZE:
		var slot = _bound.inventory.slots[i]
		_hotbar_labels[i].text = "%d" % (i + 1) if slot == null else InventoryPanel.slot_text(slot)
		_hotbar_panels[i].modulate = Color(1.0, 0.9, 0.5) if i == _bound.selected_slot else Color(1.0, 1.0, 1.0, 0.75)
	_inventory.refresh()
	_storage.refresh()
	_book.refresh()


# --- per frame -------------------------------------------------------------------

func _process(_delta: float) -> void:
	var player := GameState.local_player as Player
	if player != null and player.survivor != _bound:
		_bind(player.survivor)
	_update_info(player)

	var now := Time.get_ticks_msec() / 1000.0
	_message_log = _message_log.filter(func(m: Dictionary) -> bool: return m.until > now)
	_messages.text = "\n".join(PackedStringArray(_message_log.map(func(m: Dictionary) -> String: return m.text)))

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

	var prompt := "" if player.focus_text.is_empty() else "[E]  " + player.focus_text
	var progress := player.hold_fraction()
	if progress > 0.0:
		var filled := int(round(progress * 10.0))
		prompt += "   " + "▰".repeat(filled) + "▱".repeat(10 - filled)
	elif player.is_placing():
		prompt = "[LMB] Build here   [R] Rotate   (select another slot to cancel)"
	_prompt.text = prompt


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
	lines.append("RIPTIDE · M1b · %s" % ("HOST" if multiplayer.is_server() else "CREW"))
	if multiplayer.is_server():
		lines.append("Friends join at: %s  (port %d)" % [_lan_addresses, Net.port])
	var names: PackedStringArray = []
	for id: int in Net.roster:
		names.append(Net.roster[id]["name"])
	lines.append("Crew %d/%d: %s" % [Net.roster.size(), Net.MAX_PLAYERS, ", ".join(names)])
	if player == null:
		lines.append("Waiting for the host...")
	else:
		if player.platform != null:
			var status := ""
			if player.platform.can_paddle:
				status = " — PADDLING (WASD, Shift to pull hard, F to stop)" if player.paddling else " — F to paddle"
			lines.append("Aboard the %s%s" % [player.platform.name, status])
		elif player.swimming:
			lines.append("Swimming")
		lines.append("FPS %d" % Engine.get_frames_per_second())
	_info.text = "\n".join(lines)
