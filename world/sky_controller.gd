class_name SkyController
extends Node
## Moves the sun (and the moon at night) and recolours sky, fog and ambient
## light through the day — greyed and dimmed by clouds and rain, lit up by
## lightning in a storm.

const DAY_TOP := Color(0.30, 0.54, 0.86)
const DAY_HORIZON := Color(0.74, 0.85, 0.93)
const NIGHT_TOP := Color(0.02, 0.03, 0.08)
const NIGHT_HORIZON := Color(0.07, 0.09, 0.16)
const DUSK := Color(0.96, 0.58, 0.32)
const MOONLIGHT := Color(0.60, 0.70, 1.0)
const SUNLIGHT := Color(1.0, 0.96, 0.90)
const OVERCAST_TOP := Color(0.40, 0.44, 0.49)
const OVERCAST_HORIZON := Color(0.58, 0.61, 0.64)
const BASE_FOG := 0.0015

var sun: DirectionalLight3D
var environment: Environment
var sky_material: ProceduralSkyMaterial


func _process(_delta: float) -> void:
	var t := GameState.time_of_day()
	var elevation := DayNight.sun_elevation(t)
	var light := DayNight.daylight(t)
	var dusk := (1.0 - clampf(absf(elevation) * 4.0, 0.0, 1.0))

	var clouds := 0.0
	var rain := 0.0
	var dim := 1.0
	var flash := 0.0
	var weather: Weather = GameState.world.weather if GameState.world != null else null
	if weather != null:
		clouds = float(weather.current.clouds)
		rain = float(weather.current.rain)
		dim = float(weather.current.light)
		flash = weather.flash_amount()

	var arc := DayNight.arc_angle(t)
	var toward_light := Vector3(cos(arc), sin(arc) * 0.85 + 0.05, 0.35).normalized()
	sun.global_transform.basis = Basis.looking_at(-toward_light, Vector3.UP)
	sun.light_energy = lerpf(0.12, 0.95, light) * dim + flash * 1.6
	sun.light_color = MOONLIGHT.lerp(SUNLIGHT, light).lerp(DUSK, dusk * light * 0.6 * (1.0 - clouds))
	sun.shadow_opacity = lerpf(1.0, 0.35, clouds)

	var overcast := clouds * 0.75
	var top := NIGHT_TOP.lerp(DAY_TOP.lerp(OVERCAST_TOP, overcast), light)
	var horizon := NIGHT_HORIZON.lerp(DAY_HORIZON.lerp(OVERCAST_HORIZON, overcast), light).lerp(DUSK, dusk * 0.5 * (1.0 - clouds))
	top = top.lerp(Color(0.85, 0.88, 1.0), flash * 0.6)
	sky_material.sky_top_color = top
	sky_material.sky_horizon_color = horizon
	sky_material.ground_horizon_color = horizon
	environment.ambient_light_energy = lerpf(0.10, 0.45, light) * lerpf(1.0, 0.8, clouds) + flash * 0.8
	environment.fog_light_color = horizon
	environment.fog_density = BASE_FOG + 0.006 * rain
