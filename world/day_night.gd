class_name DayNight
extends RefCounted
## Day/night timing: a 20 minute day, 14 minutes of daylight and 6 of night.
## Time of day is derived from the shared ocean clock plus an offset the host
## chooses, so every peer agrees without extra syncing.

const DAY_LENGTH := 1200.0
const SUNRISE := 0.15
const SUNSET := 0.85
## Fresh worlds start mid-morning.
const START_TIME := 0.25


static func time_of_day(clock: float, offset: float) -> float:
	return fposmod(clock / DAY_LENGTH + offset, 1.0)


## +1 at noon, 0 at sunrise and sunset, down to -1 at midnight.
static func sun_elevation(t: float) -> float:
	if is_day(t):
		return sin(PI * (t - SUNRISE) / (SUNSET - SUNRISE))
	return -sin(PI * _night_fraction(t))


## 0 at night, 1 in full day, with a soft dawn and dusk.
static func daylight(t: float) -> float:
	return smoothstep(-0.12, 0.25, sun_elevation(t))


static func is_day(t: float) -> bool:
	return t >= SUNRISE and t <= SUNSET


## Angle along the sky arc (0 rising .. PI setting) of the sun by day or the moon by night.
static func arc_angle(t: float) -> float:
	if is_day(t):
		return PI * (t - SUNRISE) / (SUNSET - SUNRISE)
	return PI * _night_fraction(t)


## Clock hours: daylight spans 06:00–20:00, night 20:00–06:00.
static func clock_hours(t: float) -> float:
	if is_day(t):
		return 6.0 + 14.0 * (t - SUNRISE) / (SUNSET - SUNRISE)
	return fposmod(20.0 + 10.0 * _night_fraction(t), 24.0)


static func clock_text(t: float) -> String:
	var hours := clock_hours(t)
	return "%02d:%02d" % [int(hours), int(fposmod(hours, 1.0) * 60.0)]


static func _night_fraction(t: float) -> float:
	return fposmod(t - SUNSET, 1.0) / (1.0 - (SUNSET - SUNRISE))
