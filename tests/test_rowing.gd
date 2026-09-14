extends "res://tests/test_case.gd"

const Row = preload("res://boats/row_math.gd")


func test_both_oars_row_straight() -> void:
	var drive: Vector2 = Row.thrust(Row.oars_for(1.0, 1.0, 0.0))
	check(drive.x > 0.9, "both strokes drive forward (%.2f)" % drive.x)
	near(drive.y, 0.0, 0.001, "and don't turn")


func test_one_oar_turns_away_from_it() -> void:
	var left_only: Vector2 = Row.thrust(Row.oars_for(1.0, 0.0, 0.0))
	check(left_only.x > 0.0 and left_only.y < 0.0, "a left stroke creeps forward and turns right (clockwise)")
	var right_only: Vector2 = Row.thrust(Row.oars_for(0.0, 1.0, 0.0))
	check(right_only.y > 0.0, "a right stroke turns left")


func test_back_rowing_goes_backward() -> void:
	var drive: Vector2 = Row.thrust(Row.oars_for(-1.0, -1.0, 0.0))
	check(drive.x < -0.9, "back-rowing both oars reverses (%.2f)" % drive.x)


func test_side_seats_share_a_boat() -> void:
	check(Row.oars_for(1.0, 1.0, -0.8) == Vector2(1.0, 0.0), "sitting to port works only the left oar")
	check(Row.oars_for(0.0, 1.0, 0.8) == Vector2(0.0, 1.0), "sitting to starboard works only the right oar, whichever key")
	var crew: Vector2 = Row.thrust(Row.oars_for(1.0, 0.0, -0.8) + Row.oars_for(0.0, 1.0, 0.8))
	check(crew.x > 0.9 and absf(crew.y) < 0.001, "two rowers, one each side, go straight")


func test_rowing_is_not_exhausting() -> void:
	check(Row.power_seconds(100.0) >= 20.0, "a full bar buys at least 20 s of hard rowing (%.1f)" % Row.power_seconds(100.0))
	check(Row.ROWING_STAMINA_REGEN > 0.0, "plain rowing lets you catch your breath")


func test_a_whole_crew_is_capped() -> void:
	var six := Vector2.ZERO
	for i in 6:
		six += Row.oars_for(1.0, 1.0, 0.0) * Row.POWER
	check(Row.thrust(six).x <= Row.MAX_OAR + 0.001, "six rowers can't make a speedboat")
