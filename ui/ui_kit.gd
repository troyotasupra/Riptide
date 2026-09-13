class_name UiKit
extends RefCounted
## Small helpers shared by the menus and panels.

static func title(parent: Control, text: String, size: int = 22) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label


static func label(parent: Control, text: String, dim: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if dim:
		node.modulate = Color(1.0, 1.0, 1.0, 0.65)
	parent.add_child(node)
	return node


static func button(parent: Control, text: String, action: Callable, min_width: float = 0.0) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(min_width, 36.0)
	node.pressed.connect(func() -> void:
		Sound.play("click", -6.0)
		action.call())
	parent.add_child(node)
	return node


## Focuses the first focusable control inside `root` (for controllers).
static func focus_first(root: Node) -> void:
	for node in root.find_children("*", "Control", true, false):
		var control := node as Control
		if control.focus_mode != Control.FOCUS_NONE and control.is_visible_in_tree() and not (control is Button and control.disabled):
			control.grab_focus.call_deferred()
			return
