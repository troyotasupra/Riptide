extends Node
## The host's save file: one world, written as Godot text variants so vectors,
## transforms and whole numbers come back exactly.

const DIRECTORY := "user://saves"
const PATH := "user://saves/world.save"
## Scripted test runs save here so they never touch the real save.
const TEST_PATH := "user://saves/scenario_test.save"

## A loaded save waiting for the world to apply it (set by the menu's Continue).
var pending: Dictionary = {}


func path() -> String:
	return PATH if GameState.scenario.is_empty() else TEST_PATH


func has_save() -> bool:
	return FileAccess.file_exists(path())


func read() -> Dictionary:
	if not has_save():
		return {}
	var file := FileAccess.open(path(), FileAccess.READ)
	if file == null:
		return {}
	var data = str_to_var(file.get_as_text())
	return data if data is Dictionary else {}


func write(data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	var file := FileAccess.open(path(), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(var_to_str(data))
	return true
