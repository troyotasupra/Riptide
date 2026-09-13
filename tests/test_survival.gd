extends "res://tests/test_case.gd"

const SurvivalScript = preload("res://player/survival.gd")


func _run(s, seconds: float, env: float, insulation: float, exertion: float) -> void:
	for i in int(seconds):
		s.tick(1.0, env, insulation, exertion)


func test_hunger_and_thirst_drain() -> void:
	var s = SurvivalScript.new()
	_run(s, 60.0, 22.0, 0.0, 0.0)
	check(s.hunger < SurvivalScript.MAX and s.hunger > 90.0, "hunger drains slowly (%.2f)" % s.hunger)
	check(s.thirst < s.hunger, "thirst drains faster than hunger")


func test_exertion_drains_faster() -> void:
	var resting = SurvivalScript.new()
	var sprinting = SurvivalScript.new()
	_run(resting, 120.0, 22.0, 0.0, 0.0)
	_run(sprinting, 120.0, 22.0, 0.0, 1.0)
	check(sprinting.thirst < resting.thirst, "sprinting costs more water")


func test_cold_without_gear_is_deadly() -> void:
	var s = SurvivalScript.new()
	_run(s, 300.0, 2.0, 0.0, 0.0)
	check(s.body_temp < SurvivalScript.HYPOTHERMIA_TEMP, "hypothermia in 2C with no gear (%.2f)" % s.body_temp)
	check(s.health < SurvivalScript.MAX, "hypothermia hurts")


func test_insulation_keeps_you_warm() -> void:
	var s = SurvivalScript.new()
	_run(s, 300.0, 2.0, 0.7, 0.0)
	check(s.body_temp > SurvivalScript.HYPOTHERMIA_TEMP, "warm gear survives 2C (%.2f)" % s.body_temp)


func test_heavy_gear_overheats_in_tropics() -> void:
	check(SurvivalScript.equilibrium_temp(35.0, 1.0) > SurvivalScript.equilibrium_temp(35.0, 0.0),
		"insulation traps heat in hot weather")


func test_starvation_damages_then_food_regens() -> void:
	var s = SurvivalScript.new()
	s.hunger = 0.0
	_run(s, 10.0, 22.0, 0.0, 0.0)
	check(s.health < SurvivalScript.MAX, "starving hurts")
	var hurt: float = s.health
	s.eat(100.0)
	s.drink(100.0)
	_run(s, 10.0, 22.0, 0.0, 0.0)
	check(s.health > hurt, "fed and watered regenerates")


func test_sickness_drains_and_hurts_then_passes() -> void:
	var healthy = SurvivalScript.new()
	var sick = SurvivalScript.new()
	sick.make_sick(60.0)
	_run(healthy, 30.0, 22.0, 0.0, 0.0)
	_run(sick, 30.0, 22.0, 0.0, 0.0)
	check(sick.thirst < healthy.thirst, "sick people get thirsty faster")
	check(sick.health < SurvivalScript.MAX, "sickness hurts")
	_run(sick, 40.0, 22.0, 0.0, 0.0)
	near(sick.sickness, 0.0, 0.0001, "sickness wears off")


func test_warmth_from_a_fire_counts_but_not_in_the_water() -> void:
	var TempScript = load("res://world/environment_temp.gd")
	check(TempScript.felt_temp(0.0, 0.0, false, 12.0) > TempScript.felt_temp(0.0, 0.0, false), "a fire warms you")
	near(TempScript.felt_temp(0.0, 1.0, true, 12.0), TempScript.felt_temp(0.0, 1.0, true), 0.0001, "no fire warms the sea")


func test_round_trips_through_dict() -> void:
	var s = SurvivalScript.new()
	s.hunger = 12.0
	s.body_temp = 35.5
	var copy = SurvivalScript.new()
	copy.from_dict(s.to_dict())
	near(copy.hunger, 12.0, 0.0001, "hunger survives save")
	near(copy.body_temp, 35.5, 0.0001, "body temp survives save")
