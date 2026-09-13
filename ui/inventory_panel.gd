class_name InventoryPanel
extends PanelContainer
## The backpack: what you're wearing on the left, the 8 hotbar slots and 16
## backpack slots on the right. Click an item then a slot to move it; click a
## worn piece to take it off. The host checks every change.

var survivor: Survivor
var _stats: Label
var _hint: Label
var _buttons: Array[Button] = []
var _worn_buttons := {}
var _from := -1
var _hover := -1


static func slot_text(slot) -> String:
	if slot == null:
		return ""
	if slot.has("uses"):
		return "%s\n%d uses" % [ItemTable.display_name(slot.id), slot.uses]
	return "%s\n×%d" % [ItemTable.display_name(slot.id), slot.count]


func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	UiKit.title(box, "Backpack")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)

	var gear := VBoxContainer.new()
	row.add_child(gear)
	UiKit.label(gear, "Wearing")
	for slot: String in Equipment.SLOTS:
		var button := Button.new()
		button.custom_minimum_size = Vector2(170.0, 44.0)
		button.clip_text = true
		button.pressed.connect(_on_worn_pressed.bind(slot))
		gear.add_child(button)
		_worn_buttons[slot] = button
	_stats = UiKit.label(gear, "")

	var pack := VBoxContainer.new()
	row.add_child(pack)
	UiKit.label(pack, "Hotbar (top row) and pack")
	var grid := GridContainer.new()
	grid.columns = Inventory.HOTBAR_SIZE
	pack.add_child(grid)
	for i in Inventory.SIZE:
		var button := Button.new()
		button.custom_minimum_size = Vector2(98.0, 56.0)
		button.clip_text = true
		button.pressed.connect(_on_slot_pressed.bind(i))
		button.gui_input.connect(_on_slot_gui_input.bind(i))
		button.mouse_entered.connect(func() -> void: _hover = i)
		button.focus_entered.connect(func() -> void: _hover = i)
		grid.add_child(button)
		_buttons.append(button)
	_hint = UiKit.label(box, "", true)
	visibility_changed.connect(func() -> void:
		_from = -1
		if visible:
			refresh())


func refresh() -> void:
	if survivor == null or not visible:
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
	for slot: String in Equipment.SLOTS:
		var worn: Dictionary = survivor.equipment.worn.get(slot, {})
		_worn_buttons[slot].text = "%s: %s" % [Equipment.SLOT_NAMES[slot], ItemTable.display_name(worn.id) if not worn.is_empty() else "—"]
		_worn_buttons[slot].modulate = Color(0.85, 1.0, 0.85) if _from != -1 and Equipment.slot_for(_selected_id()) == slot else Color.WHITE
	var equipment := survivor.equipment
	_stats.text = "Carrying %.1f kg\nWarmth %d%%\nArmour: head %d · body %d" % [
		survivor.total_weight(), int(equipment.insulation() * 100.0), equipment.armor("head"), equipment.armor("vest")]
	if Controls.using_gamepad:
		_hint.text = "(A) pick up / place · (X) split stack · (Y) hotbar ⇄ pack · (LT) drop · (B) close"
	else:
		_hint.text = "Click an item, then a slot to move it (or a worn slot to put it on) · Right-click: split · Shift-click: hotbar ⇄ pack · Q: drop · I/Esc: close"


func _selected_id() -> String:
	if _from < 0 or survivor.inventory.slots[_from] == null:
		return ""
	return survivor.inventory.slots[_from].id


func _on_slot_pressed(index: int) -> void:
	if survivor == null:
		return
	if Input.is_key_pressed(KEY_SHIFT):
		_from = -1
		survivor.request_quick_move(index)
		return
	if _from == -1:
		if survivor.inventory.slots[index] != null:
			_from = index
			Sound.play("select", -8.0)
	else:
		if _from != index:
			survivor.move_item(_from, index)
		_from = -1
	refresh()


func _on_worn_pressed(slot: String) -> void:
	if survivor == null:
		return
	if _from != -1:
		if Equipment.slot_for(_selected_id()) == slot:
			survivor.request_wear(_from)
		else:
			Sound.play("error", -8.0)
		_from = -1
	elif survivor.equipment.is_wearing(slot):
		survivor.request_take_off(slot)
	refresh()


func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		survivor.request_split(index)
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or survivor == null or _hover < 0:
		return
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_X:
			survivor.request_split(_hover)
		elif event.button_index == JOY_BUTTON_Y:
			survivor.request_quick_move(_hover)
		else:
			return
		get_viewport().set_input_as_handled()
	elif (event is InputEventKey and event.is_action_pressed("drop")) or (event is InputEventJoypadMotion and event.is_action_pressed("secondary")):
		_from = -1
		survivor.request_drop(_hover)
		get_viewport().set_input_as_handled()
