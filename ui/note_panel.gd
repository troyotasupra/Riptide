class_name NotePanel
extends PanelContainer
## Reads a note found in the world: the captain's logbook, a castaway's journal.

signal close_requested

var _title: Label
var _text: Label


func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_title = UiKit.title(box, "")
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(560.0, 0.0)
	box.add_child(_text)
	UiKit.button(box, "Close", func() -> void: close_requested.emit())


func show_note(note_id: String) -> void:
	var note: Dictionary = NoteTable.NOTES.get(note_id, {})
	_title.text = note.get("title", "")
	_text.text = note.get("text", "")
	visible = true
	UiKit.focus_first(self)
