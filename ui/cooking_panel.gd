class_name CookingPanel
extends PanelContainer
## What's on the fire (or the stove, or the drying rack): every slot with what it
## will become and how far along it is, so you can watch it cook and take out the
## piece you want instead of everything at once.

var station_id := ""

var _title: Label
var _state: Label
var _rows: Array[Dictionary] = []
var _take_all: Button


func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(430.0, 0.0)
	add_child(box)
	_title = UiKit.title(box, "Fire", 26)
	_state = UiKit.label(box, "", true)
	for i in CookStation.SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(38.0, 38.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var label := Label.new()
		label.custom_minimum_size = Vector2(190.0, 0.0)
		row.add_child(label)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(110.0, 14.0)
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var index := i
		var take := UiKit.button(row, "Take", func() -> void: _take(index), 70.0)
		_rows.append({"icon": icon, "label": label, "bar": bar, "take": take})
	_take_all = UiKit.button(box, "Take everything that's ready", func() -> void: _take(-1))
	UiKit.label(box, "Hold food, water or firewood and press E on it to put something on.", true)
	visibility_changed.connect(func() -> void:
		if visible:
			_recenter())


## The panel only knows its real height after a layout pass, so it's re-centred
## once it has one (otherwise it sits too high and runs off the top).
func _recenter() -> void:
	await get_tree().process_frame
	if not is_inside_tree() or not visible:
		return
	reset_size()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


func show_station(id: String, title: String) -> void:
	station_id = id
	_title.text = title
	_refresh()


func _process(_delta: float) -> void:
	if visible:
		_refresh()


func _station() -> CookStation:
	var camp: CampSystems = GameState.world.camp if GameState.world != null else null
	return camp.stations.get(station_id) if camp != null else null


func _refresh() -> void:
	var station := _station()
	if station == null:
		return
	if station.needs_fire():
		_state.text = "Burning · %ds of fuel left" % int(station.fuel) if station.lit else "Not lit — light it before anything will cook"
	else:
		_state.text = "Drying"
	var now: float = Ocean.time
	var ready := false
	for i in CookStation.SLOTS:
		var row: Dictionary = _rows[i]
		var slot = station.slots[i]
		var icon: TextureRect = row.icon
		var label: Label = row.label
		var bar: ProgressBar = row.bar
		var take: Button = row.take
		if slot == null:
			icon.texture = null
			label.text = "— empty —"
			bar.value = 0.0
			take.disabled = true
			continue
		icon.texture = Icons.get_icon(String(slot.id))
		var done: bool = now >= float(slot.done_at)
		var total := CookStation.COOK_SECONDS if station.mode == "cook" else CookStation.DRY_SECONDS
		var left := maxf(0.0, float(slot.done_at) - now)
		bar.value = clampf(1.0 - left / total, 0.0, 1.0)
		take.disabled = not done
		ready = ready or done
		if done:
			label.text = "%s — ready" % ItemTable.display_name(String(slot.result))
		else:
			label.text = "%s → %s (%ds)" % [ItemTable.display_name(String(slot.id)), ItemTable.display_name(String(slot.result)), ceili(left)]
	_take_all.disabled = not ready


func _take(index: int) -> void:
	if station_id.is_empty():
		return
	Sound.play("pot", -8.0)
	GameState.world.camp.rpc_id(1, "request_take_cooked", station_id, index)
