extends Node
## Session-wide state shared by the world, HUD and network code.

var world_seed := 0
var world: Node3D = null
var local_player: Node = null
## Fraction of a day added to the ocean clock. The host picks it; joiners copy it.
var day_offset := 0.0
## True while a panel (backpack, book) has the mouse.
var ui_open := false

## Test flags (command line)
var command_line_used := false
var free_mouse := false
var autopilot := ""  ## "", "board" or "stress"
var spawn_override := ""  ## "camp": spawn on the camp island's cove beach
var face := ""  ## "camp": new players look toward the camp island; "sea": away from it
var scenario := ""  ## scripted end-to-end check to run (see ScenarioDriver)
var hide_ocean := false  ## debug: don't draw the sea (to check what's water and what isn't)
var start_time := -1.0  ## 0..1 time of day for a fresh world; -1 uses the default
## Save a screenshot of the world this many seconds in, then quit.
var screenshot_path := ""
var screenshot_delay := 10.0


func find_boat(boat_name: String) -> Boat:
	if boat_name.is_empty() or world == null:
		return null
	return world.find_boat(boat_name)


func time_of_day() -> float:
	return DayNight.time_of_day(Ocean.time, day_offset)
