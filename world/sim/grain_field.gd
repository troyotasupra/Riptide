class_name GrainField
extends Node3D
## Draws and feeds a GrainSim: the fire, smoke, embers, spray and running water
## in one place are all grains of the same simulation, stepped every frame and
## drawn in a single MultiMesh.
##
## Add sources with `add_source` (a fire, a spout of water); the field keeps the
## ground under itself so grains land on it, and it never draws more grains than
## its capacity. Everything here is local to the peer looking at it — the host
## decides what burns (FireService), this decides what it looks like.

## Fire is coloured by where a grain is in the flame, not by its age: white
## hot in the middle of the body, yellow around that, orange at the edge, and
## the specks thrown clear are the darkest.
const FIRE_CORE := Color(1.0, 0.99, 0.86)
const FIRE_BODY := Color(1.0, 0.79, 0.28)
const FIRE_EDGE := Color(0.98, 0.58, 0.13)
const FIRE_RIM := Color(0.82, 0.36, 0.06)
## Smoke off a hot fire is pale, not grey.
const SMOKE_COLOUR := Color(0.90, 0.89, 0.93)
const WATER_COLOUR := Color(0.62, 0.86, 0.92)
const FOAM_COLOUR := Color(0.97, 0.99, 1.0)
const EMBER_COLOUR := Color(0.95, 0.51, 0.12)
const STEAM_COLOUR := Color(0.95, 0.96, 0.98)

## How big one grain is drawn, by kind. Fire and its smoke are the same size,
## so the whole thing reads as one grid of pixels.
const SIZE := [0.02, 0.055, 0.06, 0.04, 0.05]

var sim: GrainSim
## Each source: {"kind", "at": local Vector3, "radius", "rate" per second,
## "speed", "spread", "strength", "_owed"}.
var sources: Array[Dictionary] = []
## Grains stop at this height (the sea, a pool); -INF for none.
var water_level := -INF
## The middle of the fire and how wide its body is, for colouring the flame
## from its core outward. Set by whatever owns the field.
var fire_origin := Vector3.ZERO
var fire_width := 0.5

var _mesh: MultiMeshInstance3D
## The whole instance buffer, refilled each frame (Godot wants it all at once).
var _buffer := PackedFloat32Array()
var _ground_ready := false
var _reground_in := 0.0
static var _material: ShaderMaterial
static var _grain_mesh: ArrayMesh


func _init(capacity: int = 1200) -> void:
	sim = GrainSim.new(capacity)


func _ready() -> void:
	_mesh = MultiMeshInstance3D.new()
	_mesh.top_level = true  # grains live in world space, not under a moving node
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = _grain()
	multi.instance_count = sim.capacity
	multi.visible_instance_count = 0
	_buffer.resize(sim.capacity * 16)
	_mesh.multimesh = multi
	_mesh.material_override = _grain_material()
	add_child(_mesh)
	_take_ground()


## A source of grains: kind is one of GrainSim's, `at` is in this node's space.
func add_source(kind: int, at: Vector3, rate: float, speed: float, spread: float,
		radius: float = 0.0, strength: float = 1.0) -> Dictionary:
	var source := {"kind": kind, "at": at, "rate": rate, "speed": speed, "spread": spread,
		"radius": radius, "strength": strength, "_owed": 0.0}
	sources.append(source)
	return source


## Throws a handful of grains out at once — a splash, a gust of sparks.
func burst(kind: int, at: Vector3, grains: int, speed: float, spread: float, strength: float = 1.0) -> void:
	var here := global_transform * at
	for i in grains:
		sim.spawn(kind, here, _random_velocity(speed, spread), strength)


func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	_reground_in -= delta
	if _reground_in <= 0.0:
		_take_ground()
	for source: Dictionary in sources:
		_feed(source, delta)
	sim.water_level = water_level
	sim.wind = _wind()
	sim.step(delta)
	_draw()


## Ground under the field, sampled once into a small grid the sim can read fast.
func _take_ground() -> void:
	_reground_in = 3.0
	var world := GameState.world
	if world == null or not world.has_method("ground_height"):
		return
	const CELLS := 25
	const STEP := 0.75
	var origin := Vector2(global_position.x, global_position.z) - Vector2.ONE * (CELLS - 1) * STEP * 0.5
	var heights := PackedFloat32Array()
	heights.resize(CELLS * CELLS)
	for z in CELLS:
		for x in CELLS:
			var at := origin + Vector2(x, z) * STEP
			var h: float = world.ground_height(at.x, at.y)
			heights[z * CELLS + x] = h if h != -INF else -9999.0
	sim.set_ground(heights, origin, STEP, CELLS)
	_ground_ready = true


func _feed(source: Dictionary, delta: float) -> void:
	source._owed = float(source._owed) + float(source.rate) * delta
	var owed := int(source._owed)
	if owed <= 0:
		return
	source._owed = float(source._owed) - owed
	var middle: Vector3 = global_transform * Vector3(source.at)
	var radius := float(source.radius)
	for i in owed:
		var at := middle
		if radius > 0.0:
			var angle := randf() * TAU
			var reach := sqrt(randf()) * radius
			at += Vector3(cos(angle) * reach, randf() * radius * 0.3, sin(angle) * reach)
		sim.spawn(int(source.kind), at, _random_velocity(float(source.speed), float(source.spread)), float(source.strength))


static func _random_velocity(speed: float, spread: float) -> Vector3:
	var out := Vector3(randf_range(-spread, spread), speed, randf_range(-spread, spread))
	return out


func _wind() -> Vector2:
	var world := GameState.world
	if world == null or world.weather == null:
		return Vector2.ZERO
	var weather: Weather = world.weather
	return WeatherMath.wind_vector(weather.wind_angle, weather.wind_speed) * 0.25


## Fills the MultiMesh in one pass: 12 floats of transform and 4 of colour each.
func _draw() -> void:
	var multi := _mesh.multimesh
	var shown := sim.count
	if shown == 0:
		multi.visible_instance_count = 0
		return
	var buffer := _buffer
	for i in shown:
		var k := sim.kind[i]
		var life: float = clampf(sim.heat[i], 0.0, 1.0)
		var at := Vector3(sim.px[i], sim.py[i], sim.pz[i])
		var size: float = SIZE[k] * _scale_for(k, life)
		var b := i * 16
		# A box, turned a little by where it is so the grains don't line up.
		var turn := sin(sim.px[i] * 3.7 + sim.pz[i] * 2.3) * 0.6
		var c := cos(turn) * size
		var s := sin(turn) * size
		buffer[b + 0] = c
		buffer[b + 1] = 0.0
		buffer[b + 2] = s
		buffer[b + 3] = sim.px[i]
		buffer[b + 4] = 0.0
		buffer[b + 5] = size
		buffer[b + 6] = 0.0
		buffer[b + 7] = sim.py[i]
		buffer[b + 8] = -s
		buffer[b + 9] = 0.0
		buffer[b + 10] = c
		buffer[b + 11] = sim.pz[i]
		var colour := _colour_for(k, life) if k != GrainSim.FIRE else _flame_colour(at, life)
		buffer[b + 12] = colour.r
		buffer[b + 13] = colour.g
		buffer[b + 14] = colour.b
		buffer[b + 15] = colour.a
	multi.visible_instance_count = shown
	multi.buffer = buffer


## Nothing fades — a grain shrinks to nothing instead, so every block stays
## hard-edged right to the end.
static func _scale_for(kind: int, life: float) -> float:
	match kind:
		GrainSim.SMOKE, GrainSim.STEAM:
			# Smoke swells as it climbs, then goes out like everything else.
			return lerpf(1.6, 1.0, life) * clampf(life * 4.0, 0.0, 1.0)
		GrainSim.FIRE:
			return clampf(life * 2.2, 0.0, 1.0)
		_:
			return clampf(life * 3.0, 0.0, 1.0)


## Where a grain sits in the flame decides its colour: the middle of the body is
## white hot, it goes yellow then orange outward and upward, and a grain thrown
## clear of the body is the dull orange of a speck flying off.
func _flame_colour(at: Vector3, life: float) -> Color:
	var out := Vector2(at.x - fire_origin.x, at.z - fire_origin.z).length() / maxf(fire_width, 0.05)
	var up := clampf((at.y - fire_origin.y) / maxf(fire_width * 2.4, 0.2), 0.0, 1.4)
	# Distance from the hot heart of it, counting height as well as spread.
	var from_core := clampf(out * 0.8 + up * 0.7 + (1.0 - life) * 0.3, 0.0, 1.0)
	if from_core < 0.18:
		return FIRE_CORE
	if from_core < 0.42:
		return FIRE_CORE.lerp(FIRE_BODY, (from_core - 0.18) / 0.24)
	if from_core < 0.7:
		return FIRE_BODY.lerp(FIRE_EDGE, (from_core - 0.42) / 0.28)
	return FIRE_EDGE.lerp(FIRE_RIM, (from_core - 0.7) / 0.3)


static func _colour_for(kind: int, life: float) -> Color:
	match kind:
		GrainSim.SMOKE:
			# Pale and solid, darkening a little as it cools and spreads.
			return SMOKE_COLOUR.lerp(Color(0.72, 0.71, 0.75), 1.0 - life)
		GrainSim.WATER:
			# Fast water is white with air, slow water is clear blue.
			return WATER_COLOUR.lerp(FOAM_COLOUR, clampf(1.0 - life, 0.0, 1.0))
		GrainSim.EMBER:
			return EMBER_COLOUR
		_:
			return STEAM_COLOUR


static func _grain_material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load("res://world/sim/grain.gdshader")
	return _material


## One grain: a box, so a grain has faces that catch the light differently.
static func _grain() -> ArrayMesh:
	if _grain_mesh != null:
		return _grain_mesh
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var tool := SurfaceTool.new()
	tool.create_from(box, 0)
	_grain_mesh = tool.commit()
	return _grain_mesh
