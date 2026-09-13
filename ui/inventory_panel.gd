class_name InventoryPanel
extends PanelContainer
## The backpack: the 8 hotbar slots on top, 16 backpack slots below. Click an
## item, then click where it should go. The host checks every move.

var survivor: Survivor
var _weight: Label
var _buttons: Array[Button] = []
var _from := -1


static func slot_text(slot) -> String:
	if slot == null:
		return ""
	var text := "%s\n×%d" % [ItemTable.display_name(slot.id), slot.count]
	if slot.has("uses"):
		text = "%s\n%d uses" % [ItemTable.display_name(slot.id), slot.uses]
	return text


func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var title := Label.new()
	title.text = "Backpack"
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	_weight = Label.new()
	box.add_child(_weight)
	var grid := GridContainer.new()
	grid.columns = Inventory.HOTBAR_SIZE
	box.add_child(grid)
	for i in Inventory.SIZE:
		var button := Button.new()
		button.custom_minimum_size = Vector2(100.0, 58.0)
		button.clip_text = true
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_slot_pressed.bind(i))
		grid.add_child(button)
		_buttons.append(button)
	var hint := Label.new()
	hint.text = "Top row is your hotbar (keys 1–8, left click uses). Click an item, then a slot to move it.  I / Esc to close."
	box.add_child(hint)
	visibility_changed.connect(func() -> void: _from = -1)


func refresh() -> void:
	if survivor == null:
		return
	var inventory := survivor.inventory
	for i in Inventory.SIZE:
		_buttons[i].text = slot_text(inventory.slots[i])
		if i == _from:
			_buttons[i].modulate = Color(1.0, 0.85, 0.4)
		elif i < Inventory.HOTBAR_SIZE:
			_buttons[i].modulate = Color(0.8, 0.95, 1.0)
		else:
			_buttons[i].modulate = Color.WHITE
	_weight.text = "Carrying %.1f kg" % inventory.total_weight()


func _on_slot_pressed(index: int) -> void:
	if survivor == null:
		return
	if _from == -1:
		if survivor.inventory.slots[index] != null:
			_from = index
	else:
		if _from != index:
			survivor.move_item(_from, index)
		_from = -1
	refresh()
