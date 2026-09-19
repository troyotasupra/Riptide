extends Node
## Player settings: look sensitivity, field of view, audio levels, display.
## Saved to user://settings.cfg and applied immediately when changed.

signal changed

const PATH := "user://settings.cfg"

var mouse_sensitivity := 1.0
var stick_sensitivity := 1.0
var invert_y := false
var fov := 80.0
var deadzone := 0.2
var master_volume := 0.9
var sfx_volume := 1.0
var ambience_volume := 0.7
var fullscreen := false
## 0 low · 1 medium · 2 high: ambient occlusion, glow, shadow range, antialiasing.
var graphics := 2
## Hosting with developer mode on: F1 panel (spawn items, weather, time, teleports), V to fly.
var developer_mode := false
## Not saved: F3 debug overlay.
var show_debug := false
## Not saved: silences everything (--mute, and test windows started with --no-focus).
var muted := false
## Not saved: a --no-focus test window. It shares Troy's settings file, so it must
## never write to it, and it stays windowed and silent whatever that file says.
var test_window := false


func _ready() -> void:
	for bus: String in ["SFX", "Ambience"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")
	load_settings()
	# Decided before the first apply, so a test window never makes a sound or goes fullscreen.
	var args := OS.get_cmdline_user_args()
	test_window = args.has("--no-focus")
	if test_window:
		fullscreen = false
	muted = test_window or args.has("--mute")
	apply()


func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(master_volume, 0.0001, 1.0)))
	AudioServer.set_bus_mute(0, muted)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(clampf(sfx_volume, 0.0001, 1.0)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambience"), linear_to_db(clampf(ambience_volume, 0.0001, 1.0)))
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.window_get_mode()
		var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		if fullscreen and not is_full:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif not fullscreen and is_full:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	Controls.set_deadzone(deadzone)
	changed.emit()


func save_settings() -> void:
	if test_window:
		return
	var config := ConfigFile.new()
	for key: String in _keys():
		config.set_value("settings", key, get(key))
	config.save(PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	for key: String in _keys():
		set(key, config.get_value("settings", key, get(key)))


static func _keys() -> Array[String]:
	return ["mouse_sensitivity", "stick_sensitivity", "invert_y", "fov", "deadzone", "master_volume", "sfx_volume", "ambience_volume", "fullscreen", "graphics", "developer_mode"]
