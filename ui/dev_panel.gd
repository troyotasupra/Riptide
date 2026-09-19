class_name DevPanel
extends PanelContainer
## Developer mode panel (F1 while the host allows it): fly and god mode, time,
## weather and wind, teleports, handy kits, sharks, and any item by name.

var _search: LineEdit
var _items: ItemList
var _ids: Array[String] = []
var _god := false
var _fast_bites := false


func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	UiKit.title(box, "Developer mode")
	_row(box, "You", [
		["Fly (V)", func() -> void: _player().set_flying(not _player().flying)],
		["God mode", func() -> void:
			_god = not _god
			_player().god = _god
			_send("god", [_god])],
		["Heal", func() -> void: _send("heal", [])],
		["Friendly fire", func() -> void: _send("friendly_fire", [not GameState.friendly_fire])],
		["Learn all recipes", func() -> void: _send("learn_all", [])],
		["Empty pack", func() -> void: _send("clear_pack", [])],
	])
	_row(box, "Time", [
		["Dawn", func() -> void: _send("time", [0.16])],
		["Noon", func() -> void: _send("time", [0.5])],
		["Dusk", func() -> void: _send("time", [0.84])],
		["Midnight", func() -> void: _send("time", [0.97])],
	])
	var weather_row: Array = []
	for state: String in WeatherMath.ORDER:
		var chosen := state
		weather_row.append([state.capitalize(), func() -> void: _send("weather", [chosen, true])])
	weather_row.append(["Turn wind", func() -> void: _send("wind", [_weather().wind_angle + PI * 0.5, _weather().wind_speed])])
	weather_row.append(["Calm", func() -> void: _send("wind", [_weather().wind_angle, 1.0])])
	weather_row.append(["Gale", func() -> void: _send("wind", [_weather().wind_angle, 18.0])])
	_row(box, "Weather", weather_row)
	var places: Array = []
	for place: String in DevTools.PLACES:
		var chosen := place
		places.append([DevTools.PLACES[place], func() -> void: _send("teleport", [chosen])])
	_row(box, "Go to", places)
	_row(box, "Spawn", [
		["Fishing kit", func() -> void: _send("fishing_kit", [])],
		["Raft materials", func() -> void: _send("raft_kit", [])],
		["Guns + ammo", func() -> void: _send("gun_kit", [])],
		["Attachments", func() -> void: _send("attachment_kit", [])],
		["Raft here", func() -> void: _send("raft", [])],
		["Shark here", func() -> void: _send("shark", [])],
		["Start a fire", func() -> void: _send("fire", [])],
		["Put fires out", func() -> void: _send("put_out", [])],
		["Kill sharks", func() -> void: _send("kill_sharks", [])],
		["Fast bites", func() -> void:
			_fast_bites = not _fast_bites
			_send("fast_bites", [_fast_bites])],
	])

	_search = LineEdit.new()
	_search.placeholder_text = "Search items…"
	_search.text_changed.connect(_fill)
	box.add_child(_search)
	_items = ItemList.new()
	_items.custom_minimum_size = Vector2(640.0, 220.0)
	_items.fixed_icon_size = Vector2i(24, 24)
	_items.item_activated.connect(func(index: int) -> void: _give(index, 1))
	box.add_child(_items)
	var give_row := HBoxContainer.new()
	give_row.add_theme_constant_override("separation", 8)
	box.add_child(give_row)
	UiKit.button(give_row, "Give 1", func() -> void: _give_selected(false))
	UiKit.button(give_row, "Give a stack", func() -> void: _give_selected(true))
	UiKit.label(give_row, "Double-click an item to give one. F1 / Esc closes.", true).autowrap_mode = TextServer.AUTOWRAP_OFF
	_fill("")
	visibility_changed.connect(func() -> void:
		if visible:
			_fill(_search.text)
			_search.grab_focus()
			_recenter())


## Flow rows only know their wrapped height after a layout pass, so re-centre the
## panel once they have one (otherwise it sits too high and is cut off at the top).
func _recenter() -> void:
	await get_tree().process_frame
	if not is_inside_tree() or not visible:
		return
	reset_size()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


func _row(parent: Control, title: String, entries: Array) -> void:
	# Rows wrap to the panel's width (the item list sets it) instead of running off screen.
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 4)
	parent.add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(70.0, 0.0)
	row.add_child(label)
	for entry: Array in entries:
		UiKit.button(row, entry[0], entry[1])


func _fill(filter: String) -> void:
	_items.clear()
	_ids.clear()
	var needle := filter.strip_edges().to_lower()
	var ids: Array = ItemTable.ITEMS.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return ItemTable.display_name(a) < ItemTable.display_name(b))
	for id: String in ids:
		var name := ItemTable.display_name(id)
		if needle.is_empty() or name.to_lower().contains(needle) or id.contains(needle):
			_items.add_item("%s   (%s)" % [name, id], Icons.get_icon(id))
			_ids.append(id)


func _give_selected(stack: bool) -> void:
	var selected := _items.get_selected_items()
	if selected.is_empty():
		return
	var id := _ids[selected[0]]
	_give(selected[0], int(ItemTable.get_item(id).get("stack", 1)) if stack else 1)


func _give(index: int, count: int) -> void:
	if index < 0 or index >= _ids.size():
		return
	Sound.play("pickup", -8.0)
	_send("give", [_ids[index], count])


func _send(command: String, args: Array) -> void:
	GameState.world.dev.rpc_id(1, "request", command, args)


func _player() -> Player:
	return GameState.local_player as Player


func _weather() -> Weather:
	return GameState.world.weather
