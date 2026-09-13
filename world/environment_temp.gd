class_name EnvironmentTemp
extends RefCounted
## The air temperature a crew member actually feels. Survival.equilibrium_temp
## turns this plus their clothing into body temperature.

const DAY_AIR := 28.0
const NIGHT_AIR := 17.0
const WATER := 21.0
## Water pulls heat away faster than air at the same temperature.
const IMMERSION_CHILL := 4.0
## Being soaked makes the air feel this much colder.
const WET_CHILL := 7.0


## `warmth`: °C from a nearby fire or shelter (not counted while in the water).
static func felt_temp(daylight: float, wetness: float, in_water: bool, warmth: float = 0.0) -> float:
	var air := lerpf(NIGHT_AIR, DAY_AIR, clampf(daylight, 0.0, 1.0))
	if in_water:
		return minf(air, WATER) - IMMERSION_CHILL - WET_CHILL * clampf(wetness, 0.0, 1.0)
	return air - WET_CHILL * clampf(wetness, 0.0, 1.0) + warmth
