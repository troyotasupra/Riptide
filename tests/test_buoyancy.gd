extends "res://tests/test_case.gd"

const BuoyancyScript = preload("res://boats/buoyancy.gd")
const WavesScript = preload("res://ocean/waves.gd")
const SpecsScript = preload("res://boats/hull_specs.gd")

const DT := 1.0 / 120.0
const MASS := 350.0


## One step of a 1-D heave simulation: a hull whose bottom is at state.y.
func _step(state: Dictionary, water: float, water_vy: float) -> void:
	var depth: float = water - state.y
	var force := BuoyancyScript.probe_force(depth, water_vy, state.vy, MASS * BuoyancyScript.GRAVITY)
	state.vy += (force / MASS - BuoyancyScript.GRAVITY) * DT
	state.y += state.vy * DT


func _water_vy(xz: Vector2, t: float) -> float:
	var dt: float = BuoyancyScript.WATER_VELOCITY_DT
	return (WavesScript.height_at(xz, t) - WavesScript.height_at(xz, t - dt)) / dt


func test_raft_has_real_freeboard() -> void:
	var freeboard: float = SpecsScript.RAFT_SIZE.y - BuoyancyScript.DEFAULT_FLOAT_DEPTH
	check(freeboard >= 0.3, "deck should ride at least 0.3 m above calm water (%.2f)" % freeboard)


func test_raft_rides_the_swell_with_a_dry_deck() -> void:
	var xz := Vector2(0.0, 70.0)  # just off the start island
	var hull: float = SpecsScript.RAFT_SIZE.y
	var state := {"y": WavesScript.height_at(xz, 0.0) - BuoyancyScript.DEFAULT_FLOAT_DEPTH, "vy": 0.0}
	var steps := int(60.0 / DT)
	var dry := 0
	for i in steps:
		var t := i * DT
		_step(state, WavesScript.height_at(xz, t), _water_vy(xz, t))
		if state.y + hull > WavesScript.height_at(xz, t + DT):
			dry += 1
	var fraction := float(dry) / steps
	check(fraction >= 0.97, "deck dry %.1f%% of the time, want >= 97%%" % (fraction * 100.0))


func test_dropped_raft_settles_quickly() -> void:
	var state := {"y": 1.0, "vy": 0.0}  # hull bottom 1 m above flat water
	for i in int(3.0 / DT):
		_step(state, 0.0, 0.0)
	near(-state.y, BuoyancyScript.DEFAULT_FLOAT_DEPTH, 0.05, "settled draft")
	check(absf(state.vy) < 0.15, "settled vertical speed %.3f" % state.vy)


func test_no_force_out_of_water() -> void:
	near(BuoyancyScript.probe_force(-0.2, 0.0, 0.0, 1000.0), 0.0, 0.0001, "dry probe pushes nothing")
