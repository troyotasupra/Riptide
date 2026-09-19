extends "res://tests/test_case.gd"

const Hit = preload("res://items/hit_math.gd")

const FEET := Vector3(10.0, 0.0, 0.0)


func test_a_round_through_the_chest_connects() -> void:
	var at := Hit.along_segment(Vector3(0.0, 1.2, 0.0), Vector3(20.0, 1.2, 0.0), FEET, Hit.STANDING_HEIGHT)
	check(at > 0.0, "a shot down the line hits")
	check(absf(at - (10.0 - Hit.BODY_RADIUS)) < 0.05, "at the near side of them, not their middle (%.2f m)" % at)


func test_a_miss_is_a_miss() -> void:
	check(Hit.along_segment(Vector3(0.0, 1.2, 0.0), Vector3(20.0, 1.2, 1.5), FEET, Hit.STANDING_HEIGHT) < 0.0, "wide to the side")
	check(Hit.along_segment(Vector3(0.0, 3.0, 0.0), Vector3(20.0, 3.0, 0.0), FEET, Hit.STANDING_HEIGHT) < 0.0, "clean over their head")
	check(Hit.along_segment(Vector3(0.0, -1.0, 0.0), Vector3(20.0, -1.0, 0.0), FEET, Hit.STANDING_HEIGHT) < 0.0, "into the ground short of them")
	check(Hit.along_segment(Vector3(0.0, 1.2, 0.0), Vector3(5.0, 1.2, 0.0), FEET, Hit.STANDING_HEIGHT) < 0.0, "and one that falls short this tick")


func test_crouching_makes_you_smaller() -> void:
	var over := Vector3(0.0, 1.5, 0.0)
	check(Hit.along_segment(over, Vector3(20.0, 1.5, 0.0), FEET, Hit.STANDING_HEIGHT) > 0.0, "standing, it catches you")
	check(Hit.along_segment(over, Vector3(20.0, 1.5, 0.0), FEET, Hit.CROUCH_HEIGHT) < 0.0, "crouched, it goes over")


func test_the_head_counts_double_and_more() -> void:
	check(Hit.is_head(1.65, 0.0, Hit.STANDING_HEIGHT), "high up is the head")
	check(not Hit.is_head(1.1, 0.0, Hit.STANDING_HEIGHT), "the chest isn't")
	check(Hit.damage_for(30.0, 1.7, 0.0, Hit.STANDING_HEIGHT) > Hit.damage_for(30.0, 1.1, 0.0, Hit.STANDING_HEIGHT),
		"and a head shot hurts more")
