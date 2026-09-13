class_name InventoryScreen
extends Control
## Delta Force-style inventory. Worn gear on the left, what you carry in the
## middle (pockets, chest rig and backpack grids — sized by your gear), an open
## container on the right, and the hotbar along the bottom.
##
## Mouse: drag items anywhere · R rotates while dragging · Shift-drag moves
## half a stack · Ctrl-click or double-click sends an item across · right-click
## for actions · drag outside the panels to drop.
## Controller: move the cursor · A pick up / put down · X actions · Y send across
## · RB rotate · B cancel.

const DROP_OK := Color(0.3, 0.9, 0.4, 0.28)
const DROP_MERGE := Color(0.35, 0.65, 1.0, 0.3)
const DROP_SWAP := Color(1.0, 0.75, 0.25, 0.3)
const DROP_BLOCKED := Color(1.0, 0.25, 0.2, 0.3)

var survivor: Survivor
var camp: CampSystems
var container_id := ""
var container_title := ""
var cell := 54.0

var _content: HBoxContainer
var _pack_column: VBoxContainer
var _pack_views := {}
var _pack_headers := {}
var _container_column: VBoxContainer
var _container_label: Label
var _container_view: GridView
var _container_placeholder: Label
var _equip_views := {}
var _hotbar_views: Array[SlotView] = []
var _stats: RichTextLabel
var _hint: Label
var _tooltip: PanelContainer
var _tooltip_text: RichTextLabel
var _menu: PopupMenu
var _menu_target := {}
var _drag := {}
var _drag_preview: ItemTile
var _last_click := {"uid": 0, "time": 0}
var _cursor := {"kind": "", "view": null, "cell": Vector2i.ZERO}
var _stick := Vector2i.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.03, 0.05, 0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var root := VBoxContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24.0
	root.offset_right = -24.0
	root.offset_top = 16.0
	root.offset_bottom = -12.0

	var title := _label(root, "INVENTORY", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)
	_content = HBoxContainer.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_theme_constant_override("separation", 28)
	center.add_child(_content)

	var gear := _column(_content, "EQUIPMENT")
	var gear_grid := GridContainer.new()
	gear_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gear_grid.columns = 2
	gear_grid.add_theme_constant_override("h_separation", 8)
	gear_grid.add_theme_constant_override("v_separation", 8)
	gear.add_child(gear_grid)
	for slot: String in ["head", "back", "torso", "vest", "legs", "feet"]:
		var view := SlotView.new()
		gear_grid.add_child(view)
		_equip_views[slot] = view
	_stats = RichTextLabel.new()
	_stats.bbcode_enabled = true
	_stats.fit_content = true
	_stats.scroll_active = false
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats.custom_minimum_size = Vector2(230.0, 0.0)
	gear.add_child(_stats)

	_pack_column = _column(_content, "CARRYING")

	_container_column = _column(_content, "")
	_container_label = _container_column.get_child(0)
	_container_view = GridView.new()
	_container_column.add_child(_container_view)
	_container_placeholder = _label(_container_column, "Open a chest, locker, crate or bag to move things in and out.\n\nDrag an item outside these panels to drop it on the ground.", 14)
	_container_placeholder.custom_minimum_size = Vector2(260.0, 0.0)
	_container_placeholder.modulate = Color(1.0, 1.0, 1.0, 0.55)

	var hotbar := HBoxContainer.new()
	hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hotbar.alignment = BoxContainer.ALIGNMENT_CENTER
	hotbar.add_theme_constant_override("separation", 6)
	root.add_child(hotbar)
	for i in Pack.HOTBAR_SIZE:
		var view := SlotView.new()
		hotbar.add_child(view)
		_hotbar_views.append(view)

	_hint = _label(root, "", 13)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.modulate = Color(1.0, 1.0, 1.0, 0.6)

	_tooltip = PanelContainer.new()
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tip_style := StyleBoxFlat.new()
	tip_style.bg_color = Color(0.03, 0.05, 0.07, 0.96)
	tip_style.border_color = Color(0.4, 0.46, 0.52)
	tip_style.set_border_width_all(1)
	tip_style.set_corner_radius_all(4)
	tip_style.set_content_margin_all(10)
	_tooltip.add_theme_stylebox_override("panel", tip_style)
	_tooltip_text = RichTextLabel.new()
	_tooltip_text.bbcode_enabled = true
	_tooltip_text.fit_content = true
	_tooltip_text.scroll_active = false
	_tooltip_text.custom_minimum_size = Vector2(260.0, 0.0)
	_tooltip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.add_child(_tooltip_text)
	_tooltip.visible = false
	_tooltip.z_index = 20
	add_child(_tooltip)

	_menu = PopupMenu.new()
	_menu.id_pressed.connect(_on_menu)
	add_child(_menu)

	Icons.icon_ready.connect(func(_id: String) -> void: _refresh_icons())
	visibility_changed.connect(_on_visibility_changed)


func _column(parent: Control, heading: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	parent.add_child(column)
	_label(column, heading, 15).modulate = Color(0.75, 0.85, 0.95)
	return column


func _label(parent: Control, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


# --- opening, closing, refreshing ------------------------------------------------

func show_container(id: String, title: String) -> void:
	container_id = id
	container_title = title
	refresh()


func hide_container() -> void:
	if not container_id.is_empty() and camp != null:
		camp.rpc_id(1, "request_close", container_id)
	container_id = ""
	refresh()


func _on_visibility_changed() -> void:
	if visible:
		refresh()
		if Controls.using_gamepad:
			_place_cursor_start()
	else:
		_cancel_drag()
		_tooltip.visible = false
		if not container_id.is_empty():
			hide_container()


func refresh() -> void:
	if survivor == null or not is_inside_tree():
		return
	cell = clampf(floorf(get_viewport_rect().size.y / 15.5), 40.0, 58.0)
	var pack := survivor.inventory

	for name: String in _pack_views.keys():
		if pack.grid(name) == null:
			_pack_views[name].queue_free()
			_pack_headers[name].queue_free()
			_pack_views.erase(name)
			_pack_headers.erase(name)
	for name: String in pack.grid_names():
		if not _pack_views.has(name):
			_pack_headers[name] = _label(_pack_column, "", 13)
			var view := GridView.new()
			_pack_column.add_child(view)
			_pack_views[name] = view
		var grid: ItemGrid = pack.grid(name)
		_pack_headers[name].text = "%s  %d×%d" % [Pack.GRID_NAMES[name], grid.width, grid.height]
		_pack_views[name].bind(grid, name, "", cell)
	for name: String in Pack.GRID_ORDER:
		if _pack_views.has(name):
			_pack_column.move_child(_pack_headers[name], -1)
			_pack_column.move_child(_pack_views[name], -1)

	var has_container := not container_id.is_empty() and camp != null and camp.containers.has(container_id)
	_container_view.visible = has_container
	_container_placeholder.visible = not has_container
	_container_label.text = container_title.to_upper() if has_container else "NEARBY"
	if has_container:
		_container_view.bind(camp.containers[container_id], "container", container_id, cell)

	for slot: String in _equip_views:
		var view: SlotView = _equip_views[slot]
		view.setup("equip", 0, slot, Equipment.SLOT_NAMES[slot], cell * 1.7)
		view.show_stack(survivor.equipment.worn.get(slot, {}))
	for i in Pack.HOTBAR_SIZE:
		_hotbar_views[i].setup("hotbar", i, "", "", cell * 1.2)
		_hotbar_views[i].show_stack(pack.hotbar[i])
		_hotbar_views[i].set_state(i == survivor.selected_slot, false, Color.TRANSPARENT)

	var equipment := survivor.equipment
	var weight := survivor.total_weight()
	var speed := LoadoutMath.speed_multiplier(weight)
	_stats.text = "[color=#9fb4c4]Weight[/color]  %.1f kg%s\n[color=#9fb4c4]Warmth[/color]  %d%%\n[color=#9fb4c4]Armour[/color]  head %d · body %d" % [
		weight, "  [color=#e0a050](%d%% speed)[/color]" % int(speed * 100.0) if speed < 0.999 else "",
		int(equipment.insulation() * 100.0), equipment.armor("head"), equipment.armor("vest")]
	if Controls.using_gamepad:
		_hint.text = "(A) pick up / put down · RB rotate · (X) actions · (Y) send across · (B) cancel / close"
	else:
		_hint.text = "Drag to move · R rotate · Shift-drag half a stack · Ctrl-click or double-click send across · Right-click actions · Drag outside to drop · Tab close"
	# Panels may have been rebuilt or shrunk under the controller cursor.
	if _cursor.kind == "grid":
		var view = _cursor.view
		if not is_instance_valid(view) or view.is_queued_for_deletion() or not _all_grid_views().has(view):
			_place_cursor_start()
		else:
			_cursor.cell = Vector2i(_cursor.cell).clamp(Vector2i.ZERO, Vector2i(view.grid.width - 1, view.grid.height - 1))
	_refresh_cursor_visuals()


func _refresh_icons() -> void:
	if not visible:
		return
	for view: GridView in _pack_views.values():
		view.refresh_icons()
	_container_view.refresh_icons()
	for view: SlotView in _equip_views.values():
		view.refresh_icon()
	for view: SlotView in _hotbar_views:
		view.refresh_icon()


# --- hit testing -------------------------------------------------------------------

## What's under a screen point: a grid cell, a hotbar slot, a gear slot, or nothing.
func _hit(point: Vector2) -> Dictionary:
	for view: GridView in _all_grid_views():
		if view.is_visible_in_tree() and view.get_global_rect().has_point(point):
			var c := view.cell_at(point)
			return {"kind": "grid", "view": view, "cell": c, "item": view.grid.item_at(c)}
	for view: SlotView in _hotbar_views:
		if view.get_global_rect().has_point(point):
			return {"kind": "hotbar", "view": view, "item": view.stack}
	for slot: String in _equip_views:
		var view: SlotView = _equip_views[slot]
		if view.get_global_rect().has_point(point):
			return {"kind": "equip", "view": view, "item": view.stack}
	return {"kind": "none", "item": {}, "outside": not _content.get_global_rect().grow(8.0).has_point(point) and not _hotbar_views[0].get_parent().get_global_rect().has_point(point)}


func _all_grid_views() -> Array:
	var views: Array = _pack_views.values()
	if _container_view.visible:
		views.append(_container_view)
	return views


func _source_of(hit: Dictionary) -> String:
	if hit.kind == "grid" and hit.view.area == "container":
		return container_id
	return ""


# --- mouse -------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if survivor == null:
		return
	if event is InputEventMouseMotion:
		if not _drag.is_empty():
			_update_drag(event.position, false)
		else:
			_update_tooltip(_hit(event.position), event.position)
		return
	if not event is InputEventMouseButton:
		return
	var hit := _hit(event.position)
	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if hit.item.is_empty():
			return
		var uid := int(hit.item.get("uid", 0))
		var now := Time.get_ticks_msec()
		var double: bool = int(_last_click.uid) == uid and now - int(_last_click.time) < 350
		_last_click = {"uid": uid, "time": now}
		if (event.ctrl_pressed or double) and hit.kind != "equip":
			_quick_move(hit)
			return
		_begin_drag(hit, event.shift_pressed)
		_update_drag(event.position, false)
	elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and not _drag.is_empty():
		_finish_drag(event.position, false)
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if not _drag.is_empty():
			_cancel_drag()
		elif not hit.item.is_empty():
			_open_menu(hit, event.position)
	accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or survivor == null:
		return
	if event is InputEventKey and event.pressed and event.is_action_pressed("rotate") and not _drag.is_empty():
		_rotate_drag()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_gamepad_input(event)


# --- dragging ------------------------------------------------------------------------

func _begin_drag(hit: Dictionary, half: bool) -> void:
	var item: Dictionary = hit.item
	var count := int(item.get("count", 1))
	var rot := bool(item.get("rot", false))
	# Which cell of the item the pointer holds, so dropping puts that cell under
	# the pointer (and a click without moving leaves the item where it was).
	var footprint := ItemGrid.footprint(item.id, rot)
	var grab := (footprint - Vector2i.ONE) / 2
	if hit.kind == "grid":
		grab = Vector2i(hit.cell) - Vector2i(int(item.get("x", 0)), int(item.get("y", 0)))
	_drag = {
		"source": _source_of(hit),
		"uid": int(item.get("uid", 0)),
		"id": item.id,
		"count": count / 2 if half and count > 1 else 0,
		"rot": rot,
		"grab": grab.clamp(Vector2i.ZERO, footprint - Vector2i.ONE),
		"equip_slot": hit.view.slot if hit.kind == "equip" else "",
		"stack": item,
	}
	Sound.play("pickup", -10.0)
	_set_hidden(int(_drag.uid), true)
	_drag_preview = ItemTile.new()
	add_child(_drag_preview)
	_rebuild_preview()
	_tooltip.visible = false


func _rebuild_preview() -> void:
	var footprint := ItemGrid.footprint(_drag.id, _drag.rot)
	var shown: Dictionary = _drag.stack.duplicate()
	if int(_drag.count) > 0:
		shown.count = _drag.count
	for child in _drag_preview.get_children():
		child.queue_free()
	_drag_preview.setup(shown, Vector2(footprint) * cell, _drag.rot)
	_drag_preview.modulate = Color(1.0, 1.0, 1.0, 0.85)
	_drag_preview.z_index = 10


func _rotate_drag() -> void:
	_drag.rot = not _drag.rot
	var grab: Vector2i = _drag.grab
	_drag.grab = Vector2i(grab.y, grab.x).clamp(Vector2i.ZERO, ItemGrid.footprint(_drag.id, _drag.rot) - Vector2i.ONE)
	_rebuild_preview()
	_update_drag(_drag.get("point", get_local_mouse_position()), bool(_drag.get("cursor", false)))


## `from_cursor`: the point is the controller cursor, and grid targets use it as the item's top-left.
func _update_drag(point: Vector2, from_cursor: bool) -> void:
	_drag.point = point
	_drag.cursor = from_cursor
	_drag_preview.position = point - (Vector2(_drag.grab) + Vector2(0.5, 0.5)) * cell if not from_cursor else point - Vector2(cell, cell) * 0.5
	_clear_highlights()
	var target := _target_for(point, from_cursor)
	var state := _evaluate(target)
	var color: Color = {"ok": DROP_OK, "merge": DROP_MERGE, "swap": DROP_SWAP, "blocked": DROP_BLOCKED, "drop": DROP_BLOCKED, "none": Color.TRANSPARENT}[state]
	match target.kind:
		"grid":
			target.view.set_highlight(Rect2i(target.cell, ItemGrid.footprint(_drag.id, _drag.rot)), color)
		"hotbar", "equip":
			target.view.set_state(target.view.selected, target.view.cursor, color)


func _target_for(point: Vector2, from_cursor: bool) -> Dictionary:
	var hit := _hit(point)
	if hit.kind == "grid" and not from_cursor:
		hit.cell = hit.view.cell_at(point) - Vector2i(_drag.grab)
	return hit


## How a drop at `target` would go: ok, merge, swap, blocked, drop (to the ground) or none.
func _evaluate(target: Dictionary) -> String:
	var id: String = _drag.id
	var whole := int(_drag.count) <= 0
	match target.kind:
		"grid":
			if not _drag.equip_slot.is_empty():
				# Taking something off always goes into the pack (the host picks the spot).
				return "blocked" if target.view.area == "container" else "ok"
			var grid: ItemGrid = target.view.grid
			var c: Vector2i = target.cell
			if not grid.in_bounds(id, c.x, c.y, _drag.rot):
				return "blocked"
			var hits := grid.overlapping(id, c.x, c.y, _drag.rot, int(_drag.uid) if whole else 0)
			if hits.is_empty():
				return "ok"
			if hits.size() == 1 and _mergeable(hits[0]):
				return "merge"
			if hits.size() == 1 and whole:
				return "swap"
			return "blocked"
		"hotbar":
			if not _drag.equip_slot.is_empty():
				return "ok" if target.item.is_empty() else "blocked"
			if target.item.is_empty() or int(target.item.get("uid", 0)) == int(_drag.uid):
				return "ok"
			if _mergeable(target.item):
				return "merge"
			return "swap" if whole else "blocked"
		"equip":
			if not _drag.equip_slot.is_empty():
				return "blocked"
			return "ok" if Equipment.slot_for(id) == target.view.slot else "blocked"
		"none":
			return "drop" if target.get("outside", false) and _drag.equip_slot.is_empty() else "none"
	return "none"


func _mergeable(other: Dictionary) -> bool:
	return other.id == _drag.id and int(other.get("uid", 0)) != int(_drag.uid) and not other.has("uses") \
		and not _drag.stack.has("uses") and int(other.count) < int(ItemTable.get_item(other.id).get("stack", 1))


func _finish_drag(point: Vector2, from_cursor: bool) -> void:
	var target := _target_for(point, from_cursor)
	var state := _evaluate(target)
	var uid := int(_drag.uid)
	var source: String = _drag.source
	var slot: String = _drag.equip_slot
	match state:
		"ok", "merge", "swap":
			if not slot.is_empty():
				survivor.request_take_off(slot)
			elif target.kind == "equip":
				Sound.play("cloth", -6.0)
				camp.rpc_id(1, "request_wear_item", source, uid)
			elif target.kind == "hotbar":
				camp.rpc_id(1, "request_move_item", source, uid, int(_drag.count), {"area": "hotbar", "index": target.view.index})
				Sound.play("select", -8.0)
			else:
				var c: Vector2i = target.cell
				camp.rpc_id(1, "request_move_item", source, uid, int(_drag.count), {
					"area": target.view.area, "container": target.view.container_id, "x": c.x, "y": c.y, "rot": _drag.rot})
				Sound.play("select", -8.0)
		"drop":
			if slot.is_empty():
				Sound.play("drop", -4.0)
				camp.rpc_id(1, "request_drop_item", source, uid)
		"blocked":
			Sound.play("error", -10.0)
	_cancel_drag()


func _cancel_drag() -> void:
	if _drag.is_empty():
		return
	_set_hidden(int(_drag.uid), false)
	_drag = {}
	if _drag_preview != null:
		_drag_preview.queue_free()
		_drag_preview = null
	_clear_highlights()


func _set_hidden(uid: int, hidden: bool) -> void:
	for view: GridView in _all_grid_views():
		view.set_hidden(uid if hidden else 0)
	for view: SlotView in _hotbar_views + _equip_views.values():
		if int(view.stack.get("uid", -1)) == uid:
			view.set_hidden(hidden)


func _clear_highlights() -> void:
	for view: GridView in _all_grid_views():
		view.set_highlight(Rect2i(), Color.TRANSPARENT)
	for view: SlotView in _hotbar_views:
		view.set_state(view.index == survivor.selected_slot, view.cursor, Color.TRANSPARENT)
	for view: SlotView in _equip_views.values():
		view.set_state(false, view.cursor, Color.TRANSPARENT)


# --- quick actions, context menu, tooltip ----------------------------------------------

func _quick_move(hit: Dictionary) -> void:
	Sound.play("pickup", -8.0)
	camp.rpc_id(1, "request_quick_move", _source_of(hit), int(hit.item.uid))


func _open_menu(hit: Dictionary, point: Vector2) -> void:
	_menu.clear()
	var item: Dictionary = hit.item
	_menu_target = {"source": _source_of(hit), "uid": int(item.get("uid", 0)), "slot": hit.view.slot if hit.kind == "equip" else "", "id": item.id}
	if hit.kind == "equip":
		_menu.add_item("Take off", 5)
	else:
		var category := ItemTable.category(item.id)
		if _menu_target.source.is_empty() and category in ["food", "drink", "medical", "page", "book", "chart", "note"]:
			_menu.add_item({"food": "Eat", "drink": "Drink", "medical": "Apply", "note": "Read", "book": "Read", "page": "Read", "chart": "Study"}[category], 0)
		if category == "wearable":
			_menu.add_item("Wear", 1)
		if int(item.get("count", 1)) > 1:
			_menu.add_item("Split stack", 2)
		_menu.add_item("Move to pack" if not _menu_target.source.is_empty() else ("Move to %s" % container_title.to_lower() if not container_id.is_empty() else "Hotbar ⇄ storage"), 3)
		_menu.add_item("Drop", 4)
	_menu.position = Vector2i(get_screen_position() + point)
	_menu.popup()
	_tooltip.visible = false


func _on_menu(id: int) -> void:
	var uid: int = _menu_target.get("uid", 0)
	var source: String = _menu_target.get("source", "")
	match id:
		0:
			survivor.use_item(uid)
		1:
			Sound.play("cloth", -6.0)
			camp.rpc_id(1, "request_wear_item", source, uid)
		2:
			camp.rpc_id(1, "request_split_item", source, uid)
		3:
			camp.rpc_id(1, "request_quick_move", source, uid)
		4:
			Sound.play("drop", -4.0)
			camp.rpc_id(1, "request_drop_item", source, uid)
		5:
			survivor.request_take_off(_menu_target.slot)


func _update_tooltip(hit: Dictionary, point: Vector2) -> void:
	if hit.get("item", {}).is_empty():
		_tooltip.visible = false
		return
	_tooltip_text.text = describe(hit.item)
	_tooltip.visible = true
	_tooltip.reset_size()
	var viewport := get_viewport_rect().size
	var pos := point + Vector2(18.0, 18.0)
	pos.x = minf(pos.x, viewport.x - _tooltip.size.x - 8.0)
	pos.y = minf(pos.y, viewport.y - _tooltip.size.y - 8.0)
	_tooltip.position = pos


## The tooltip text for a stack: name in its rarity colour, then what matters about it.
static func describe(stack: Dictionary) -> String:
	var id: String = stack.id
	var item := ItemTable.get_item(id)
	var rarity := ItemTable.rarity(id)
	var size := ItemTable.size_of(id)
	var lines: PackedStringArray = []
	lines.append("[font_size=17][color=#%s]%s[/color][/font_size]" % [ItemTable.RARITY_COLORS[rarity].lightened(0.25).to_html(false), item.get("name", id)])
	lines.append("[color=#8a9aa8]%s · %s · %d×%d · %.2f kg[/color]" % [ItemTable.RARITY_NAMES[rarity], String(item.get("category", "")).capitalize(), size.x, size.y, float(item.get("weight", 0.0))])
	if item.has("food") or item.has("water"):
		lines.append("Food +%d · Water +%d" % [int(item.get("food", 0.0)), int(item.get("water", 0.0))])
	if item.has("sickness"):
		lines.append("[color=#d98a5a]%d%% chance to make you sick[/color]" % int(float(item.get("sick_chance", 1.0)) * 100.0))
	if item.has("heal"):
		lines.append("Heals %d" % int(item.heal))
	if item.has("insulation") and float(item.insulation) > 0.0:
		lines.append("Warmth +%d%%" % int(float(item.insulation) * 100.0))
	if item.has("armor"):
		lines.append("Armour class %d" % int(item.armor))
	if ItemTable.STORAGE.has(id):
		lines.append("Adds %d×%d storage" % [ItemTable.STORAGE[id][0], ItemTable.STORAGE[id][1]])
	if item.has("fuel"):
		lines.append("Burns for %ds" % int(item.fuel))
	if stack.has("uses"):
		lines.append("%d uses left" % int(stack.uses))
	var spoil: float = item.get("spoil", 0.0)
	if spoil > 0.0 and float(stack.get("spoils_at", 0.0)) > 0.0:
		var left := maxf(0.0, float(stack.spoils_at) - Ocean.time)
		lines.append("[color=#c8b060]Spoils in %d:%02d[/color]" % [int(left / 60.0), int(fmod(left, 60.0))])
	if item.has("hint") and item.hint != ItemTable.COMING_SOON:
		lines.append("[color=#b8c4ce]%s[/color]" % item.hint)
	elif item.get("hint", "") == ItemTable.COMING_SOON:
		lines.append("[color=#7d8a95]%s[/color]" % item.hint)
	return "\n".join(lines)


# --- controller cursor ------------------------------------------------------------------

func _place_cursor_start() -> void:
	if _pack_views.has("pockets"):
		_cursor = {"kind": "grid", "view": _pack_views.pockets, "cell": Vector2i.ZERO}
	_refresh_cursor_visuals()


func _cursor_point() -> Vector2:
	match _cursor.kind:
		"grid":
			return _cursor.view.cell_center(_cursor.cell)
		"hotbar", "equip":
			return _cursor.view.center()
	return get_viewport_rect().size * 0.5


func _refresh_cursor_visuals() -> void:
	for view: GridView in _all_grid_views():
		view.set_cursor(_cursor.cell if _cursor.kind == "grid" and _cursor.view == view and Controls.using_gamepad else Vector2i(-1, -1))
	for view: SlotView in _hotbar_views:
		view.set_state(view.index == survivor.selected_slot if survivor != null else false, Controls.using_gamepad and _cursor.view == view, Color.TRANSPARENT)
	for view: SlotView in _equip_views.values():
		view.set_state(false, Controls.using_gamepad and _cursor.view == view, Color.TRANSPARENT)


func _gamepad_input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion:
		# The stick moves the cursor one step each time it's pushed past halfway.
		var motion := event as InputEventJoypadMotion
		if motion.axis != JOY_AXIS_LEFT_X and motion.axis != JOY_AXIS_LEFT_Y:
			return
		var push := 0 if absf(motion.axis_value) < 0.5 else int(signf(motion.axis_value))
		var horizontal := motion.axis == JOY_AXIS_LEFT_X
		var previous := _stick.x if horizontal else _stick.y
		if horizontal:
			_stick.x = push
		else:
			_stick.y = push
		if push != 0 and push != previous:
			_move_cursor(Vector2(push, 0) if horizontal else Vector2(0, push))
		get_viewport().set_input_as_handled()
		return
	var handled := true
	var direction := Vector2.ZERO
	if event.is_action_pressed("ui_left"):
		direction = Vector2.LEFT
	elif event.is_action_pressed("ui_right"):
		direction = Vector2.RIGHT
	elif event.is_action_pressed("ui_up"):
		direction = Vector2.UP
	elif event.is_action_pressed("ui_down"):
		direction = Vector2.DOWN
	if direction != Vector2.ZERO:
		_move_cursor(direction)
	elif event.is_action_pressed("ui_accept"):
		var point := _cursor_point()
		if _drag.is_empty():
			var hit := _hit(point)
			if not hit.item.is_empty():
				_begin_drag(hit, false)
				_update_drag(point, true)
		else:
			_finish_drag(point, true)
	elif event.is_action_pressed("ui_cancel") and not _drag.is_empty():
		_cancel_drag()
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_RIGHT_SHOULDER and not _drag.is_empty():
		_rotate_drag()
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_X:
		var hit := _hit(_cursor_point())
		if not hit.item.is_empty():
			_open_menu(hit, _cursor_point())
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y:
		var hit := _hit(_cursor_point())
		if not hit.item.is_empty() and hit.kind != "equip":
			_quick_move(hit)
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


## Moves the cursor to the nearest cell or slot in `direction`, across panels.
func _move_cursor(direction: Vector2) -> void:
	var from := _cursor_point()
	# Lambdas capture locals by value, so the running best lives in a shared dictionary.
	var search := {"best": {}, "score": INF}
	var consider := func(candidate: Dictionary, point: Vector2) -> void:
		var offset := point - from
		var along := offset.dot(direction)
		if along < cell * 0.4:
			return
		var across := absf(offset.dot(Vector2(-direction.y, direction.x)))
		var score := along + across * 2.5
		if score < float(search.score):
			search.score = score
			search.best = candidate
	for view: GridView in _all_grid_views():
		for y in view.grid.height:
			for x in view.grid.width:
				consider.call({"kind": "grid", "view": view, "cell": Vector2i(x, y)}, view.cell_center(Vector2i(x, y)))
	for view: SlotView in _hotbar_views:
		consider.call({"kind": "hotbar", "view": view, "cell": Vector2i.ZERO}, view.center())
	for view: SlotView in _equip_views.values():
		consider.call({"kind": "equip", "view": view, "cell": Vector2i.ZERO}, view.center())
	if search.best.is_empty():
		return
	_cursor = search.best
	Sound.play("click", -16.0)
	_refresh_cursor_visuals()
	var point := _cursor_point()
	if _drag.is_empty():
		_update_tooltip(_hit(point), point)
	else:
		_update_drag(point, true)
