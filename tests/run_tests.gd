extends SceneTree
## Headless test runner:
##   godot --headless --path C:\src\riptide --script res://tests/run_tests.gd
## Runs every test_* method in each suite; exit code 1 on any failure.

const SUITES := [
	"res://tests/test_waves.gd",
	"res://tests/test_survival.gd",
	"res://tests/test_loadout.gd",
	"res://tests/test_island.gd",
	"res://tests/test_movement.gd",
	"res://tests/test_buoyancy.gd",
	"res://tests/test_camp_island.gd",
	"res://tests/test_scatter.gd",
	"res://tests/test_day_night.gd",
	"res://tests/test_crafting.gd",
	"res://tests/test_character.gd",
	"res://tests/test_grid_inventory.gd",
	"res://tests/test_rowing.gd",
	"res://tests/test_sharks.gd",
]


func _init() -> void:
	var passed := 0
	var failed := 0
	for path: String in SUITES:
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			printerr("FAIL could not compile %s (suites must not depend on autoloads)" % path)
			failed += 1
			continue
		for method in script.get_script_method_list():
			var test_name: String = method.name
			if not test_name.begins_with("test_"):
				continue
			var suite = script.new()
			suite.call(test_name)
			if suite.errors.is_empty():
				passed += 1
			else:
				failed += 1
				for e: String in suite.errors:
					printerr("FAIL %s::%s — %s" % [path.get_file(), test_name, e])
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
