extends "res://tests/test_case.gd"

const Vote = preload("res://crafting/sleep_vote.gd")


func test_a_majority_is_needed() -> void:
	check(Vote.needed(1) == 1, "alone, you decide")
	check(Vote.needed(4) == 3, "three of four")
	check(not Vote.enough(2, 4), "half the crew isn't enough")
	check(Vote.enough(3, 4), "but three of four is")


func test_the_last_one_in_bed_cuts_the_wait() -> void:
	check(Vote.countdown(3, 4) == Vote.COUNTDOWN, "with someone still up, the crew waits")
	check(Vote.countdown(4, 4) == Vote.COUNTDOWN_ALL, "everyone in bed: the night goes right away")
	check(Vote.countdown(1, 1) == Vote.COUNTDOWN_ALL, "and alone, right away too")
	check(Vote.COUNTDOWN_ALL == 5.0, "which is five seconds")
