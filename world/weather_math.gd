class_name WeatherMath
extends RefCounted
## Weather and wind rules, free of engine singletons so tests can check them.
## The sky moves between four states; each blends in over CHANGE_SECONDS.
##   clouds 0..1 · rain 0..1 · storm 0..1 (rougher seas, lightning)
##   wind: typical m/s · light: sunlight multiplier · chill: °C colder

const STATES := {
	"clear": {"clouds": 0.1, "rain": 0.0, "storm": 0.0, "wind": 4.0, "light": 1.0, "chill": 0.0},
	"cloudy": {"clouds": 0.65, "rain": 0.0, "storm": 0.1, "wind": 7.0, "light": 0.8, "chill": 1.0},
	"rain": {"clouds": 0.9, "rain": 0.75, "storm": 0.35, "wind": 10.0, "light": 0.6, "chill": 3.0},
	"storm": {"clouds": 1.0, "rain": 1.0, "storm": 1.0, "wind": 16.0, "light": 0.38, "chill": 5.0},
}
const ORDER := ["clear", "cloudy", "rain", "storm"]
## Where the weather can go next, with odds.
const NEXT := {
	"clear": [["clear", 0.45], ["cloudy", 0.55]],
	"cloudy": [["clear", 0.4], ["cloudy", 0.2], ["rain", 0.4]],
	"rain": [["cloudy", 0.55], ["rain", 0.25], ["storm", 0.2]],
	"storm": [["rain", 0.8], ["storm", 0.2]],
}
const MIN_SECONDS := 150.0
const MAX_SECONDS := 360.0
const CHANGE_SECONDS := 40.0
## Wind pushes on a boat's side area: newtons per m² per m/s of wind.
const WIND_PUSH := 12.0
## Radians a second the wind direction can wander.
const WIND_WANDER := 0.02
## Rain soaks someone in the open from dry to soaked in this many seconds at full rain.
const SOAK_SECONDS := 45.0


static func next_state(current: String, roll: float) -> String:
	var options: Array = NEXT.get(current, NEXT.clear)
	var cumulative := 0.0
	for option: Array in options:
		cumulative += float(option[1])
		if roll < cumulative:
			return option[0]
	return options[options.size() - 1][0]


static func duration(roll: float) -> float:
	return lerpf(MIN_SECONDS, MAX_SECONDS, clampf(roll, 0.0, 1.0))


## Every value of `from` blended toward `to` by `t` (0..1).
static func blend(from: String, to: String, t: float) -> Dictionary:
	var a: Dictionary = STATES.get(from, STATES.clear)
	var b: Dictionary = STATES.get(to, STATES.clear)
	var out := {}
	var k := smoothstep(0.0, 1.0, clampf(t, 0.0, 1.0))
	for key: String in a:
		out[key] = lerpf(float(a[key]), float(b[key]), k)
	return out


## The wind as a world-space (x, z) vector: `angle` is the direction it blows toward.
static func wind_vector(angle: float, speed: float) -> Vector2:
	return Vector2.from_angle(angle) * speed


static func wind_force(angle: float, speed: float, area: float) -> Vector2:
	return wind_vector(angle, 1.0) * speed * area * WIND_PUSH


## Compass bearing (degrees) the wind blows FROM, as sailors say it.
static func wind_from_bearing(angle: float) -> float:
	var from := -wind_vector(angle, 1.0)
	return fposmod(rad_to_deg(atan2(from.x, -from.y)), 360.0)
