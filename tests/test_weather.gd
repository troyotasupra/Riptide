extends "res://tests/test_case.gd"

const WeatherScript = preload("res://world/weather_math.gd")
const WavesScript = preload("res://ocean/waves.gd")


func test_weather_moves_between_real_states() -> void:
	for state: String in WeatherScript.ORDER:
		for i in 11:
			var next: String = WeatherScript.next_state(state, i / 10.0)
			check(WeatherScript.STATES.has(next), "%s -> %s is a real state" % [state, next])
	check(WeatherScript.next_state("clear", 0.99) != "storm", "a clear sky doesn't jump straight to a storm")
	check(WeatherScript.next_state("storm", 0.0) == "rain", "storms ease off into rain")


func test_changes_blend_in() -> void:
	var start: Dictionary = WeatherScript.blend("clear", "storm", 0.0)
	var halfway: Dictionary = WeatherScript.blend("clear", "storm", 0.5)
	var done: Dictionary = WeatherScript.blend("clear", "storm", 1.0)
	near(start.rain, 0.0, 0.001, "no rain at the start")
	near(done.rain, 1.0, 0.001, "full rain once it arrives")
	check(halfway.rain > 0.2 and halfway.rain < 0.8, "halfway there, it's raining some (%.2f)" % halfway.rain)


func test_storm_seas_never_loop_over() -> void:
	var steepness := 0.0
	for w: Vector4 in WavesScript.WAVES:
		steepness += w.z
	check(steepness * WavesScript.STORM_MAX_ROUGHNESS < 1.0, "the roughest storm sea keeps its crests (%.2f)" % (steepness * WavesScript.STORM_MAX_ROUGHNESS))


func test_storms_raise_the_sea() -> void:
	var xz := Vector2(300.0, 120.0)
	WavesScript.storm = 0.0
	var calm := 0.0
	for i in 40:
		calm = maxf(calm, absf(WavesScript.displacement(xz, i * 0.7).y))
	WavesScript.storm = 1.0
	var rough := 0.0
	for i in 40:
		rough = maxf(rough, absf(WavesScript.displacement(xz, i * 0.7).y))
	WavesScript.storm = 0.0
	check(rough > calm * 1.3, "storm waves stand taller (%.2f vs %.2f m)" % [rough, calm])


func test_wind_pushes_with_its_direction() -> void:
	var push: Vector2 = WeatherScript.wind_force(0.0, 10.0, 3.0)
	check(push.x > 0.0 and absf(push.y) < 0.001, "an angle of 0 blows along +x")
	check(WeatherScript.wind_force(0.0, 16.0, 3.0).length() > push.length(), "a gale pushes harder")
	near(WeatherScript.wind_from_bearing(PI * 0.5), 0.0, 0.5, "wind blowing toward +z (south) comes from the north")
