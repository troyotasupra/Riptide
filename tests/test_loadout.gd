extends "res://tests/test_case.gd"

const LoadoutScript = preload("res://player/loadout_math.gd")


func test_light_loadout_has_no_penalty() -> void:
	near(LoadoutScript.speed_multiplier(0.0), 1.0, 0.0001, "naked is full speed")
	near(LoadoutScript.speed_multiplier(LoadoutScript.FREE_WEIGHT_KG), 1.0, 0.0001, "free weight is full speed")
	near(LoadoutScript.stamina_drain_multiplier(5.0), 1.0, 0.0001, "light kit drains normally")


func test_heavier_is_slower() -> void:
	var last := 2.0
	for kg in range(0, 60, 4):
		var m := LoadoutScript.speed_multiplier(kg)
		check(m <= last, "speed never increases with weight (%d kg)" % kg)
		last = m
	near(LoadoutScript.speed_multiplier(80.0), LoadoutScript.MIN_SPEED_MULT, 0.0001, "speed floors out")


func test_heavier_drains_more_stamina() -> void:
	check(LoadoutScript.stamina_drain_multiplier(35.0) > LoadoutScript.stamina_drain_multiplier(15.0),
		"plates and a rifle cost stamina")


func test_insulation_layers_diminish() -> void:
	near(LoadoutScript.combined_insulation([]), 0.0, 0.0001, "no clothes, no insulation")
	var one := LoadoutScript.combined_insulation([0.4])
	var two := LoadoutScript.combined_insulation([0.4, 0.4])
	near(one, 0.4, 0.0001, "single layer is its own value")
	check(two > one and two < 0.8, "second layer helps less than the first (%.3f)" % two)
	check(LoadoutScript.combined_insulation([0.95, 0.95, 0.95]) < 1.0, "never fully immune")
