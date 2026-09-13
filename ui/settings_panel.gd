class_name SettingsPanel
extends PanelContainer
## Look sensitivity, field of view, audio and display settings. Changes apply
## immediately and are saved when the panel closes.

signal closed


func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.custom_minimum_size = Vector2(460.0, 0.0)
	add_child(box)
	UiKit.title(box, "Settings")
	_slider(box, "Mouse sensitivity", "mouse_sensitivity", 0.2, 3.0, 0.05)
	_slider(box, "Controller look speed", "stick_sensitivity", 0.2, 3.0, 0.05)
	_check(box, "Invert look up/down", "invert_y")
	_slider(box, "Controller stick deadzone", "deadzone", 0.05, 0.5, 0.01)
	_slider(box, "Field of view", "fov", 60.0, 100.0, 1.0)
	_slider(box, "Master volume", "master_volume", 0.0, 1.0, 0.05)
	_slider(box, "Effects volume", "sfx_volume", 0.0, 1.0, 0.05)
	_slider(box, "Ocean volume", "ambience_volume", 0.0, 1.0, 0.05)
	_check(box, "Fullscreen", "fullscreen")
	_choice(box, "Graphics quality", "graphics", ["Low", "Medium", "High"])
	UiKit.button(box, "Back", close)
	visibility_changed.connect(func() -> void:
		if visible:
			UiKit.focus_first(self))


func close() -> void:
	Settings.save_settings()
	visible = false
	closed.emit()


func _slider(parent: Control, text: String, key: String, low: float, high: float, step: float) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.custom_minimum_size = Vector2(210.0, 0.0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = Settings.get(key)
	slider.custom_minimum_size = Vector2(220.0, 24.0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var show := func(value: float) -> void:
		label.text = "%s: %s" % [text, ("%d" % int(value)) if step >= 1.0 else ("%d%%" % int(value * 100.0) if high <= 1.0 else "%.2f" % value)]
	show.call(slider.value)
	slider.value_changed.connect(func(value: float) -> void:
		Settings.set(key, value)
		Settings.apply()
		show.call(value))


func _choice(parent: Control, text: String, key: String, options: Array) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(210.0, 0.0)
	row.add_child(label)
	var picker := OptionButton.new()
	for option: String in options:
		picker.add_item(option)
	picker.selected = int(Settings.get(key))
	picker.item_selected.connect(func(index: int) -> void:
		Settings.set(key, index)
		Settings.apply())
	row.add_child(picker)


func _check(parent: Control, text: String, key: String) -> void:
	var box := CheckBox.new()
	box.text = text
	box.button_pressed = Settings.get(key)
	box.toggled.connect(func(on: bool) -> void:
		Settings.set(key, on)
		Settings.apply())
	parent.add_child(box)
