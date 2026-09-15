class_name BookPanel
extends PanelContainer
## The survival book: every recipe the crew knows, what it needs, and a Craft
## button. Recipes are shared by the whole crew.

var survivor: Survivor
var camp: CampSystems
var _list: VBoxContainer
var _hint: Label


func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	UiKit.title(box, "Survival book")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(680.0, 380.0)
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	_hint = UiKit.label(box, "", true)
	visibility_changed.connect(func() -> void:
		if visible:
			refresh()
			UiKit.focus_first(_list))


func refresh() -> void:
	if not visible or survivor == null or camp == null:
		return
	_hint.text = "Recipes are shared with your whole crew. Torn book pages teach more.  %s close" % ("(B)" if Controls.using_gamepad else "B / Esc:")
	for child in _list.get_children():
		child.queue_free()
	if camp.known_recipes.is_empty():
		UiKit.label(_list, "You don't know how to make anything yet.\nThere's a survival book in the fishing shack on the big island — put it in your hotbar and use it to learn the basics.")
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
		for need: String in recipe.needs:
			needs.append("%s %d/%d" % [RecipeTable.need_label(need), RecipeTable.have(survivor.inventory, need), recipe.needs[need]])
		var tool := RecipeTable.missing_tool(survivor.inventory, id)
		if recipe.has("tool"):
			needs.append("needs a %s%s" % [recipe.tool, " (missing)" if not tool.is_empty() else ""])
		var needs_label := Label.new()
		needs_label.text = " · ".join(needs)
		needs_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var craftable := RecipeTable.can_craft(survivor.inventory, id)
		needs_label.modulate = Color.WHITE if craftable else Color(1.0, 0.65, 0.6)
		row.add_child(needs_label)
		var button := Button.new()
		button.text = "Craft"
		button.disabled = not craftable
		button.pressed.connect(func() -> void:
			Sound.play("craft", -4.0)
			camp.rpc_id(1, "request_craft", id))
		row.add_child(button)
	_add_fish_log()


## Every species, with how many you've caught and your best — "???" until you land one.
func _add_fish_log() -> void:
	var caught := 0
	for id: String in FishTable.SPECIES:
		if survivor.fish_log.has(id):
			caught += 1
	var heading := UiKit.label(_list, "")
	heading.text = "\nFISH LOG — %d of %d species" % [caught, FishTable.SPECIES.size()]
	for id: String in FishTable.SPECIES:
		var entry: Dictionary = survivor.fish_log.get(id, {})
		if entry.is_empty():
			UiKit.label(_list, "   ???", true)
		else:
			UiKit.label(_list, "   %s — %d caught · best %.1f kg" % [FishTable.SPECIES[id].name, int(entry.count), float(entry.best)])
