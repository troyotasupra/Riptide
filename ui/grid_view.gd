class_name GridView
extends Control
## Draws one ItemGrid — pockets, rig, backpack or a container — as a field of
## cells with item cards on top, plus the drop highlight and controller cursor.
## Input is handled by the InventoryScreen that owns it.

var grid: ItemGrid
## "pockets" | "rig" | "backpack" | "container"
var area := ""
var container_id := ""
var cell := 54.0
var hidden_uid := 0
var highlight := Rect2i()
var highlight_color := Color.TRANSPARENT
var cursor := Vector2i(-1, -1)

var _tiles := {}
var _overlay: Control


func bind(p_grid: ItemGrid, p_area: String, p_container: String, p_cell: float) -> void:
	grid = p_grid
	area = p_area
	container_id = p_container
	cell = p_cell
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rebuild()


func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_tiles.clear()
	if grid == null:
		return
	custom_minimum_size = Vector2(grid.width, grid.height) * cell
	size = custom_minimum_size
	for item: Dictionary in grid.items:
		var tile := ItemTile.new()
		var rect := ItemGrid.rect_of(item)
		tile.setup(item, Vector2(rect.size) * cell, bool(item.get("rot", false)))
		tile.position = Vector2(rect.position) * cell
		tile.modulate.a = 0.3 if int(item.uid) == hidden_uid else 1.0
		add_child(tile)
		_tiles[int(item.uid)] = tile
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.size = size
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	queue_redraw()


func refresh_icons() -> void:
	for tile: ItemTile in _tiles.values():
		tile.refresh_icon()


func set_hidden(uid: int) -> void:
	hidden_uid = uid
	for key: int in _tiles:
		_tiles[key].modulate.a = 0.3 if key == uid else 1.0


func set_highlight(rect: Rect2i, color: Color) -> void:
	highlight = rect
	highlight_color = color
	if _overlay != null:
		_overlay.queue_redraw()


func set_cursor(p_cursor: Vector2i) -> void:
	cursor = p_cursor
	if _overlay != null:
		_overlay.queue_redraw()


func cell_at(global_point: Vector2) -> Vector2i:
	var local := global_point - global_position
	return Vector2i(floori(local.x / cell), floori(local.y / cell))


func cell_center(c: Vector2i) -> Vector2:
	return global_position + (Vector2(c) + Vector2(0.5, 0.5)) * cell


func _draw() -> void:
	if grid == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.05, 0.06, 0.9))
	for y in grid.height:
		for x in grid.width:
			draw_rect(Rect2(Vector2(x, y) * cell + Vector2(1.0, 1.0), Vector2(cell - 2.0, cell - 2.0)), Color(0.13, 0.16, 0.19, 0.95))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.35, 0.42, 0.48, 0.8), false, 1.5)


func _draw_overlay() -> void:
	if highlight_color.a > 0.0:
		var rect := Rect2(Vector2(highlight.position) * cell, Vector2(highlight.size) * cell)
		_overlay.draw_rect(rect, highlight_color)
		_overlay.draw_rect(rect, Color(highlight_color, 1.0), false, 2.0)
	if cursor.x >= 0:
		_overlay.draw_rect(Rect2(Vector2(cursor) * cell + Vector2(2.0, 2.0), Vector2(cell - 4.0, cell - 4.0)), Color(1.0, 0.85, 0.3), false, 3.0)
