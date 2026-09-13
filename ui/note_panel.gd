class_name NotePanel
extends PanelContainer
## Reads a note found in the world: the captain's logbook, a castaway's journal.

var _title: Label
var _text: Label


func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	box.add_child(_title)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(560.0, 0.0)
	box.add_child(_text)
	var hint := Label.new()
	hint.text = "Esc to close."
	hint.modulate = Color(1.0, 1.0, 1.0, 0.7)
	box.add_child(hint)


func show_note(note_id: String) -> void:
	var note: Dictionary = NoteTable.NOTES.get(note_id, {})
	_title.text = note.get("title", "")
	_text.text = note.get("text", "")
	visible = true
