class_name ContainerPanel
extends PanelContainer
## An open chest, locker or crate next to your pack. Click an item to move it
## across; the host checks every transfer and updates everyone looking inside.

var survivor: Survivor
var camp: CampSystems
var container_id := ""
var _title: Label
var _storage_grid: GridContainer
var _pack_buttons: Array[Button] = []
var _storage_buttons: Array[Button] = []


func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	box.add_child(_title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	box.add_child(row)
	_storage_grid = _column(row, "Inside")
	var pack_grid := _column(row, "Your pack")
	for i in Inventory.SIZE:
		_pack_buttons.append(_slot_button(pack_grid, _on_pack_slot.bind(i)))
	var hint := Label.new()
	hint.text = "Click an item to move it across.  E / Esc to close."
	box.add_child(hint)


func _column(parent: Control, heading: String) -> GridContainer:
	var column := VBoxContainer.new()
	parent.add_child(column)
	var label := Label.new()
	label.text = heading
	column.add_child(label)
	var grid := GridContainer.new()
	grid.columns = 6
	column.add_child(grid)
	return grid


func _slot_button(grid: GridContainer, action: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(96.0, 54.0)
	button.clip_text = true
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	grid.add_child(button)
	return button


func open(id: String, title: String) -> void:
	container_id = id
	_title.text = title
	for button in _storage_buttons:
		button.queue_free()
	_storage_buttons.clear()
	var inventory: Inventory = camp.containers.get(id)
	var size := inventory.slots.size() if inventory != null else 0
	_storage_grid.columns = 4 if size <= 12 else 6
	for i in size:
		_storage_buttons.append(_slot_button(_storage_grid, _on_storage_slot.bind(i)))
	visible = true
	refresh()


func close() -> void:
	if not container_id.is_empty():
		camp.rpc_id(1, "request_close", container_id)
	camp.open_container = ""
	container_id = ""
	visible = false


func refresh() -> void:
	if not visible or survivor == null:
		return
	var inventory: Inventory = camp.containers.get(container_id)
	if inventory != null:
		for i in mini(_storage_buttons.size(), inventory.slots.size()):
			_storage_buttons[i].text = InventoryPanel.slot_text(inventory.slots[i])
	for i in Inventory.SIZE:
		_pack_buttons[i].text = InventoryPanel.slot_text(survivor.inventory.slots[i])


func _on_storage_slot(index: int) -> void:
	camp.rpc_id(1, "request_transfer", container_id, true, index)


func _on_pack_slot(index: int) -> void:
	camp.rpc_id(1, "request_transfer", container_id, false, index)
