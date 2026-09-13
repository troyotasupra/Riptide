class_name SkyController
extends Node
## Moves the sun (and the moon at night) and recolours sky, fog and ambient
## light through the day.

const DAY_TOP := Color(0.30, 0.54, 0.86)
const DAY_HORIZON := Color(0.74, 0.85, 0.93)
const NIGHT_TOP := Color(0.02, 0.03, 0.08)
const NIGHT_HORIZON := Color(0.07, 0.09, 0.16)
const DUSK := Color(0.96, 0.58, 0.32)
const MOONLIGHT := Color(0.60, 0.70, 1.0)
const SUNLIGHT := Color(1.0, 0.96, 0.90)

var sun: DirectionalLight3D
var environment: Environment
var sky_material: ProceduralSkyMaterial


func _process(_delta: float) -> void:
	var t := GameState.time_of_day()
	var elevation := DayNight.sun_elevation(t)
	var light := DayNight.daylight(t)
	var dusk := (1.0 - clampf(absf(elevation) * 4.0, 0.0, 1.0))

	var arc := DayNight.arc_angle(t)
	var toward_light := Vector3(cos(arc), sin(arc) * 0.85 + 0.05, 0.35).normalized()
	sun.global_transform.basis = Basis.looking_at(-toward_light, Vector3.UP)
	sun.light_energy = lerpf(0.12, 0.95, light)
	sun.light_color = MOONLIGHT.lerp(SUNLIGHT, light).lerp(DUSK, dusk * light * 0.6)

	var horizon := NIGHT_HORIZON.lerp(DAY_HORIZON, light).lerp(DUSK, dusk * 0.5)
	sky_material.sky_top_color = NIGHT_TOP.lerp(DAY_TOP, light)
	sky_material.sky_horizon_color = horizon
	sky_material.ground_horizon_color = horizon
	environment.ambient_light_energy = lerpf(0.10, 0.45, light)
	environment.fog_light_color = horizon
