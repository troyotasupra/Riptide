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

## Colour of a grain by what it is and how much life is left in it.
const FIRE_HOT := Color(1.0, 0.96, 0.75)
const FIRE_MID := Color(1.0, 0.55, 0.11)
const FIRE_COLD := Color(0.72, 0.13, 0.03)
const SMOKE_COLOUR := Color(0.32, 0.30, 0.29)
const WATER_COLOUR := Color(0.62, 0.86, 0.92)
const FOAM_COLOUR := Color(0.97, 0.99, 1.0)
const EMBER_COLOUR := Color(1.0, 0.62, 0.18)
const STEAM_COLOUR := Color(0.92, 0.95, 0.97)

## How big one grain is drawn, by kind.
const SIZE := [0.07, 0.055, 0.17, 0.035, 0.15]

var sim: GrainSim
## Each source: {"kind", "at": local Vector3, "radius", "rate" per second,
## "speed", "spread", "strength", "_owed"}.
var sources: Array[Dictionary] = []
## Grains stop at this height (the sea, a pool); -INF for none.
var water_level := -INF

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
		var colour := _colour_for(k, life)
		buffer[b + 12] = colour.r
		buffer[b + 13] = colour.g
		buffer[b + 14] = colour.b
		buffer[b + 15] = colour.a
	multi.visible_instance_count = shown
	multi.buffer = buffer


static func _scale_for(kind: int, life: float) -> float:
	match kind:
		GrainSim.SMOKE, GrainSim.STEAM:
			return lerpf(1.9, 0.6, life)  # puffs swell as they thin out
		GrainSim.FIRE:
			return lerpf(0.55, 1.15, life)
		_:
			return 1.0


static func _colour_for(kind: int, life: float) -> Color:
	match kind:
		GrainSim.FIRE:
			var hot: Color = FIRE_MID.lerp(FIRE_HOT, clampf((life - 0.55) / 0.45, 0.0, 1.0))
			var cool: Color = FIRE_COLD.lerp(FIRE_MID, clampf(life / 0.55, 0.0, 1.0))
			var colour: Color = cool if life < 0.55 else hot
			colour.a = clampf(life * 2.2, 0.0, 1.0)
			return colour
		GrainSim.SMOKE:
			return Color(SMOKE_COLOUR.r, SMOKE_COLOUR.g, SMOKE_COLOUR.b, life * 0.5)
		GrainSim.WATER:
			# Fast water is white with air, slow water is clear blue.
			var colour2: Color = WATER_COLOUR.lerp(FOAM_COLOUR, clampf(1.0 - life, 0.0, 1.0))
			colour2.a = clampf(0.35 + life * 0.5, 0.0, 1.0)
			return colour2
		GrainSim.EMBER:
			return Color(EMBER_COLOUR.r, EMBER_COLOUR.g, EMBER_COLOUR.b, clampf(life * 1.6, 0.0, 1.0))
		_:
			return Color(STEAM_COLOUR.r, STEAM_COLOUR.g, STEAM_COLOUR.b, life * 0.4)


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
