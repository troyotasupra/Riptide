class_name Weather
extends Node
## The weather over the sea, owned by the host: clear skies cloud over, rain
## sets in, storms roll through and blow out again, each change blending in over
## WeatherMath.CHANGE_SECONDS. A wind wanders and gusts. Every peer draws the
## same sky from the synced state — rain around the camera, darker skies and fog,
## lightning in storms — and the sea roughens through Waves.storm.

const SYNC_SECONDS := 1.0
const FLASH_SECONDS := 0.22

var from_state := "clear"
var to_state := "clear"
## 0..1 progress from `from_state` to `to_state`.
var blend_t := 1.0
## Direction the wind blows toward (radians, world x/z) and its speed in m/s.
var wind_angle := 0.8
var wind_speed := 4.0
## The blended values right now (WeatherMath.STATES keys).
var current: Dictionary = WeatherMath.STATES.clear.duplicate()

var _time_left := 240.0
var _sync_accum := 0.0
var _gust := 0.0
var _rain: GPUParticles3D
var _rain_process: ParticleProcessMaterial
var _flash := 0.0
var _next_flash := 6.0


func _ready() -> void:
	_time_left = WeatherMath.duration(randf())
	wind_angle = randf() * TAU
	if DisplayServer.get_name() != "headless":
		_build_rain()


func _exit_tree() -> void:
	Waves.storm = 0.0


func _process(delta: float) -> void:
	blend_t = minf(1.0, blend_t + delta / WeatherMath.CHANGE_SECONDS)
	if multiplayer.is_server():
		_host_tick(delta)
	current = WeatherMath.blend(from_state, to_state, blend_t)
	Waves.storm = float(current.storm)
	_update_rain()
	_update_lightning(delta)


func _host_tick(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		set_state(WeatherMath.next_state(to_state, randf()))
	var target: float = current.wind
	_gust = lerpf(_gust, randf_range(-0.3, 0.4) * target, 1.0 - exp(-0.8 * delta))
	wind_speed = maxf(0.0, lerpf(wind_speed, target + _gust, 1.0 - exp(-0.25 * delta)))
	wind_angle = wrapf(wind_angle + sin(Ocean.time * 0.011) * WeatherMath.WIND_WANDER * delta, 0.0, TAU)
	_sync_accum += delta
	if _sync_accum >= SYNC_SECONDS:
		_sync_accum = 0.0
		_broadcast()


## Host: start changing to `state` (or snap to it at once).
func set_state(state: String, instant: bool = false) -> void:
	if not WeatherMath.STATES.has(state):
		return
	from_state = state if instant else (to_state if blend_t > 0.5 else from_state)
	to_state = state
	blend_t = 1.0 if instant else 0.0
	_time_left = WeatherMath.duration(randf())
	current = WeatherMath.blend(from_state, to_state, blend_t)
	Waves.storm = float(current.storm)
	_broadcast()


## Host: set the wind outright.
func set_wind(angle: float, speed: float) -> void:
	wind_angle = wrapf(angle, 0.0, TAU)
	wind_speed = maxf(0.0, speed)
	_gust = 0.0
	_broadcast()


func wind_force_on(area: float) -> Vector3:
	var push := WeatherMath.wind_force(wind_angle, wind_speed, area)
	return Vector3(push.x, 0.0, push.y)


## "Rain · wind from NE 9 m/s"
func describe() -> String:
	var sky := "Clear"
	if float(current.storm) > 0.6:
		sky = "Storm"
	elif float(current.rain) > 0.3:
		sky = "Rain"
	elif float(current.clouds) > 0.5:
		sky = "Cloudy"
	const CARDINALS := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	var from := WeatherMath.wind_from_bearing(wind_angle)
	return "%s · wind %s %d m/s" % [sky, CARDINALS[int(round(from / 45.0)) % 8], roundi(wind_speed)]


## 0..1 brightness of a lightning flash right now.
func flash_amount() -> float:
	if _flash <= 0.0:
		return 0.0
	return clampf(_flash / FLASH_SECONDS, 0.0, 1.0) * (1.0 if fmod(_flash * 40.0, 2.0) > 0.6 else 0.35)


func to_save() -> Dictionary:
	return {"state": to_state, "wind_angle": wind_angle, "wind_speed": wind_speed}


func from_save(data: Dictionary) -> void:
	set_state(data.get("state", "clear"), true)
	set_wind(float(data.get("wind_angle", wind_angle)), float(data.get("wind_speed", wind_speed)))


func sync_to(peer_id: int) -> void:
	_sync.rpc_id(peer_id, from_state, to_state, blend_t, wind_angle, wind_speed)


func _broadcast() -> void:
	Net.send_to_ready(self, "_sync", [from_state, to_state, blend_t, wind_angle, wind_speed])


@rpc("authority", "call_remote", "reliable")
func _sync(p_from: String, p_to: String, t: float, angle: float, speed: float) -> void:
	from_state = p_from
	to_state = p_to
	blend_t = t
	wind_angle = angle
	wind_speed = speed


# --- looks -----------------------------------------------------------------------

func _build_rain() -> void:
	_rain = GPUParticles3D.new()
	_rain.name = "Rain"
	_rain.amount = 3000
	_rain.lifetime = 1.1
	_rain.emitting = false
	_rain.local_coords = false
	_rain.visibility_aabb = AABB(Vector3(-40.0, -40.0, -40.0), Vector3(80.0, 80.0, 80.0))
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rain_process = ParticleProcessMaterial.new()
	_rain_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_rain_process.emission_box_extents = Vector3(22.0, 1.0, 22.0)
	_rain_process.direction = Vector3.DOWN
	_rain_process.spread = 3.0
	_rain_process.initial_velocity_min = 20.0
	_rain_process.initial_velocity_max = 24.0
	_rain_process.gravity = Vector3(0.0, -9.8, 0.0)
	_rain_process.particle_flag_align_y = true
	_rain.process_material = _rain_process
	# Two crossed thin quads per drop, so streaks show from any side.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
		var w := axis * 0.015
		var h := Vector3.UP * 0.4
		for v: Vector3 in [-w - h, w - h, w + h, -w - h, w + h, -w + h]:
			tool.add_vertex(v)
	_rain.draw_pass_1 = tool.commit()
	var streak := StandardMaterial3D.new()
	streak.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak.cull_mode = BaseMaterial3D.CULL_DISABLED
	streak.albedo_color = Color(0.78, 0.82, 0.9, 0.35)
	_rain.material_override = streak
	add_child(_rain)


func _update_rain() -> void:
	if _rain == null:
		return
	var camera := get_viewport().get_camera_3d()
	var rain: float = current.rain
	var indoors: bool = camera != null and GameState.world != null and GameState.world.camp != null and GameState.world.camp.in_shack(camera.global_position)
	_rain.emitting = rain > 0.03 and not indoors
	_rain.amount_ratio = clampf(rain, 0.05, 1.0)
	if camera != null:
		var ahead := -camera.global_basis.z
		ahead.y = 0.0
		_rain.global_position = camera.global_position + Vector3.UP * 14.0 + ahead.normalized() * 6.0
	var wind := WeatherMath.wind_vector(wind_angle, wind_speed)
	_rain_process.gravity = Vector3(wind.x * 1.2, -9.8, wind.y * 1.2)


func _update_lightning(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	if float(current.storm) < 0.6:
		return
	_next_flash -= delta
	if _next_flash <= 0.0:
		_next_flash = randf_range(5.0, 16.0)
		_flash = FLASH_SECONDS
		get_tree().create_timer(randf_range(0.6, 2.5)).timeout.connect(func() -> void: Sound.play("tree_fall", -12.0, 0.3))
