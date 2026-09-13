extends Node
## Who you are on this computer: a stable player id (so the host remembers your
## gear even if you change your name), your name, how your character looks,
## and the crew colour and emblem you fly when you host.
##
## `--profile=name` on the command line uses a separate profile, so several
## copies of the game on one PC can test co-op as different people.

const DEFAULT_PATH := "user://profile.cfg"

var player_id := ""
var player_name := "Sailor"
var look := AppearanceTable.DEFAULT_LOOK.duplicate()
var crew_color := 4
var emblem := 1

var _path := DEFAULT_PATH


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="):
			_path = "user://profile_%s.cfg" % arg.substr(10).validate_filename()
	load_profile()
	if player_id.is_empty():
		player_id = Crypto.new().generate_random_bytes(8).hex_encode()
		save_profile()


func load_profile() -> void:
	var config := ConfigFile.new()
	if config.load(_path) != OK:
		return
	player_id = config.get_value("profile", "id", "")
	player_name = config.get_value("profile", "name", player_name)
	look = AppearanceTable.sanitize(config.get_value("profile", "look", {}))
	crew_color = clampi(config.get_value("profile", "crew_color", crew_color), 0, AppearanceTable.CREW_COLORS.size() - 1)
	emblem = clampi(config.get_value("profile", "emblem", emblem), 0, AppearanceTable.EMBLEMS.size() - 1)


func save_profile() -> void:
	var config := ConfigFile.new()
	config.set_value("profile", "id", player_id)
	config.set_value("profile", "name", player_name)
	config.set_value("profile", "look", look)
	config.set_value("profile", "crew_color", crew_color)
	config.set_value("profile", "emblem", emblem)
	config.save(_path)
