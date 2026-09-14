extends Node
## Session-wide state shared by the world, HUD and network code.

var world_seed := 0
var world: Node3D = null
var local_player: Node = null
## Fraction of a day added to the ocean clock. The host picks it; joiners copy it.
var day_offset := 0.0
## True while a panel (backpack, book, pause menu) has the mouse.
var ui_open := false
## The host's crew colour and emblem (AppearanceTable indices), sent to joiners.
var crew_color := 4
var emblem := 1
## Objectives the local player has completed this session (id -> true).
var objectives_done := {}
## Item hints already shown this session (item id -> true).
var hints_shown := {}

## Test flags (command line)
var command_line_used := false
var free_mouse := false
var autopilot := ""  ## "", "board", "stress" or "gather"
var spawn_override := ""  ## "camp": camp island beach · "shack": in the fishing shack · "boat": aboard the john boat
var face := ""  ## "camp": look toward the camp island; "sea": away; "bow": toward the bow
var scenario := ""  ## scripted end-to-end check to run (see ScenarioDriver)
var hide_ocean := false  ## debug: don't draw the sea
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
