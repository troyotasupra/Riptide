class_name SlotView
extends Control
## A single square slot holding one item of any size: a hotbar slot or a
## worn-gear slot. Shows the item's picture fitted to the square.

## "hotbar" or "equip"
var area := "hotbar"
var index := 0
var slot := ""
var caption := ""
var stack: Dictionary = {}
var selected := false
var cursor := false
var hidden_item := false
var highlight_color := Color.TRANSPARENT
var box := 60.0

var _tile: ItemTile


func setup(p_area: String, p_index: int, p_slot: String, p_caption: String, p_box: float) -> void:
	area = p_area
	index = p_index
	slot = p_slot
	caption = p_caption
	box = p_box
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(box, box)
	size = custom_minimum_size


func show_stack(p_stack: Variant) -> void:
	stack = p_stack if p_stack is Dictionary else {}
	if _tile != null:
		_tile.queue_free()
		_tile = null
	if not stack.is_empty():
		_tile = ItemTile.new()
		_tile.setup(stack, Vector2(box, box), false)
		_tile.modulate.a = 0.3 if hidden_item else 1.0
		add_child(_tile)
	queue_redraw()


func refresh_icon() -> void:
	if _tile != null:
		_tile.refresh_icon()


func set_hidden(value: bool) -> void:
	hidden_item = value
	if _tile != null:
		_tile.modulate.a = 0.3 if value else 1.0


func set_state(p_selected: bool, p_cursor: bool, p_highlight: Color) -> void:
	selected = p_selected
	cursor = p_cursor
	highlight_color = p_highlight
	queue_redraw()


func center() -> Vector2:
	return global_position + size * 0.5


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.06, 0.08, 0.85))
	draw_rect(Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0)), Color(0.13, 0.16, 0.19, 0.95))
	var font := ThemeDB.fallback_font
	if stack.is_empty() and not caption.is_empty():
		draw_string(font, Vector2(6.0, size.y * 0.5 + 5.0), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x - 12.0, 12, Color(1.0, 1.0, 1.0, 0.35))
	if area == "hotbar":
		draw_string(font, Vector2(5.0, 15.0), "%d" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 1.0, 1.0, 0.7))
	draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.82, 0.35) if selected else Color(0.35, 0.42, 0.48, 0.8), false, 3.0 if selected else 1.5)
	if highlight_color.a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), highlight_color)
	if cursor:
		draw_rect(Rect2(Vector2(3.0, 3.0), size - Vector2(6.0, 6.0)), Color(1.0, 0.85, 0.3), false, 3.0)
