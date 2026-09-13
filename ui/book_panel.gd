class_name BookPanel
extends PanelContainer
## The survival book: every recipe the crew knows, what it needs, and a Craft
## button. Recipes are shared by the whole crew.

var survivor: Survivor
var camp: CampSystems
var _list: VBoxContainer


func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var title := Label.new()
	title.text = "Survival book"
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620.0, 360.0)
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	var hint := Label.new()
	hint.text = "Recipes are shared with your whole crew. Torn pages teach more.  B / Esc to close."
	box.add_child(hint)


func refresh() -> void:
	if not visible or survivor == null or camp == null:
		return
	for child in _list.get_children():
		child.queue_free()
	if camp.known_recipes.is_empty():
		var empty := Label.new()
		empty.text = "You don't know how to make anything yet.\nThere's a survival book in the sailboat's sea chest — read it (left click) to learn the basics."
		_list.add_child(empty)
		return
	for id: String in RecipeTable.RECIPES:
		if not camp.known_recipes.has(id):
			continue
		var recipe: Dictionary = RecipeTable.RECIPES[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_list.add_child(row)
		var name_label := Label.new()
		name_label.text = recipe.name
		name_label.custom_minimum_size = Vector2(140.0, 0.0)
		row.add_child(name_label)
		var needs: PackedStringArray = []
		for item: String in recipe.needs:
			needs.append("%s %d/%d" % [ItemTable.display_name(item), survivor.inventory.count_of(item), recipe.needs[item]])
		var needs_label := Label.new()
		needs_label.text = " · ".join(needs)
		needs_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var craftable := RecipeTable.can_craft(survivor.inventory, id)
		needs_label.modulate = Color.WHITE if craftable else Color(1.0, 0.65, 0.6)
		row.add_child(needs_label)
		var button := Button.new()
		button.text = "Craft"
		button.disabled = not craftable
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void: camp.rpc_id(1, "request_craft", id))
		row.add_child(button)
