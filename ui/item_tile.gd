class_name ItemTile
extends Control
## One item as drawn in the inventory: its picture on a rarity-tinted card,
## with the stack count, charges, or how fresh it is.

var stack: Dictionary = {}
## A long item shown in a square slot gets a diagonal picture that fills it.
var _square := false
var _icon: TextureRect
var _fallback: Label


## `box` is the tile's size in pixels; `rot` turns the picture sideways.
func setup(p_stack: Dictionary, box: Vector2, rot: bool) -> void:
	stack = p_stack
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = box
	custom_minimum_size = box
	var cells := ItemTable.size_of(stack.id)
	_square = is_equal_approx(box.x, box.y) and cells.x != cells.y
	var rarity := ItemTable.rarity_color(stack.id)

	var card := Panel.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = rarity.darkened(0.7)
	style.bg_color.a = 0.95
	style.border_color = rarity
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = 2
	card.add_theme_stylebox_override("panel", style)
	add_child(card)
	card.position = Vector2(2.0, 2.0)
	card.size = box - Vector2(4.0, 4.0)

	var glow := ColorRect.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.color = Color(rarity, 0.18)
	glow.position = Vector2(4.0, box.y * 0.55)
	glow.size = Vector2(box.x - 8.0, box.y * 0.45 - 4.0)
	add_child(glow)

	_icon = TextureRect.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var inner := box - Vector2(8.0, 8.0)
	_icon.size = Vector2(inner.y, inner.x) if rot else inner
	_icon.pivot_offset = _icon.size * 0.5
	_icon.position = (box - _icon.size) * 0.5
	_icon.rotation = -PI / 2.0 if rot else 0.0
	add_child(_icon)

	_fallback = Label.new()
	_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fallback.text = ItemTable.display_name(stack.id)
	_fallback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fallback.add_theme_font_size_override("font_size", 11)
	_fallback.position = Vector2(4.0, 4.0)
	_fallback.size = box - Vector2(8.0, 8.0)
	add_child(_fallback)

	var spoil: float = ItemTable.get_item(stack.id).get("spoil", 0.0)
	if float(stack.get("spoils_at", 0.0)) > 0.0 and spoil > 0.0:
		var fresh := clampf((float(stack.spoils_at) - Ocean.time) / spoil, 0.0, 1.0)
		var bar := ColorRect.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.color = Color(0.9, 0.25, 0.2).lerp(Color(0.35, 0.85, 0.35), fresh)
		bar.position = Vector2(6.0, 6.0)
		bar.size = Vector2((box.x - 12.0) * fresh, 3.0)
		add_child(bar)

	var text := ""
	if stack.has("uses"):
		text = "%d" % int(stack.uses)
	elif int(stack.get("count", 1)) > 1:
		text = "×%d" % int(stack.count)
	if not text.is_empty():
		var count := Label.new()
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count.text = text
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.add_theme_font_size_override("font_size", 12)
		count.add_theme_constant_override("outline_size", 4)
		count.add_theme_color_override("font_outline_color", Color.BLACK)
		count.position = Vector2(0.0, box.y - 22.0)
		count.size = Vector2(box.x - 6.0, 18.0)
		add_child(count)
	refresh_icon()


func refresh_icon() -> void:
	var texture := Icons.get_icon(stack.get("id", ""), _square)
	_icon.texture = texture
	_fallback.visible = texture == null
