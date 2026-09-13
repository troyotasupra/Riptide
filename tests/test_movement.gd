extends "res://tests/test_case.gd"

const TuningScript = preload("res://player/movement_tuning.gd")
const SpecsScript = preload("res://boats/hull_specs.gd")
const BuoyancyScript = preload("res://boats/buoyancy.gd")


## Apex height and total airtime of a jump launched at `v0` from flat ground.
func _jump_arc(v0: float) -> Dictionary:
	var g: float = TuningScript.GRAVITY
	var apex := v0 * v0 / (2.0 * g)
	var rise := v0 / g
	var fall := sqrt(2.0 * apex / (g * TuningScript.FALL_MULTIPLIER))
	return {"apex": apex, "airtime": rise + fall}


func test_jump_is_snappy_not_floaty() -> void:
	var arc := _jump_arc(TuningScript.JUMP_VELOCITY)
	check(arc.airtime >= 0.45 and arc.airtime <= 0.65, "airtime %.3f s should be 0.45–0.65" % arc.airtime)
	check(arc.apex >= 0.9 and arc.apex <= 1.1, "apex %.3f m should be 0.9–1.1" % arc.apex)


func test_swim_jump_clears_the_raft_deck() -> void:
	var freeboard: float = SpecsScript.RAFT_SIZE.y - BuoyancyScript.DEFAULT_FLOAT_DEPTH
	var needed: float = TuningScript.SWIM_FLOAT_DEPTH + freeboard + 0.1
	var apex: float = _jump_arc(TuningScript.SWIM_JUMP_VELOCITY).apex
	check(apex >= needed, "swim jump apex %.2f m must reach %.2f m to climb aboard" % [apex, needed])
