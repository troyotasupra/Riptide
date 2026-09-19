class_name WildfireFx
extends Node3D
## The whole wildfire drawn in a few batches rather than a node per cell: every
## burning cell stands a crossed pair of flame sheets (FlameSheets), wider than the
## cell so they overlap their neighbours into one connected fire with no gaps, taller
## where there was more to burn. Rebuilt twice a second from the burning cells. Embers and smoke rise from points across
## the burning ground, and a handful of lights sit at the fire's hottest spots.

const POINTS_PER_CELL := 24
const MAX_POINTS := 14000
## At most this many sheets in all (two per burning cell).
const MAX_SHEETS := 1600
## A sheet is this much wider than its cell, so neighbours overlap.
const OVERLAP := 1.45
const SMOKE := 900
const EMBERS := 1200
const LIGHTS := 6

var _tongues: FlameSheets
var _smoke: GPUParticles3D
var _embers: GPUParticles3D
var _points: ImageTexture
var _normals: ImageTexture
var _lights: Array[OmniLight3D] = []
var _time := 0.0
var _count := 0


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_tongues = FlameSheets.new()
	_tongues.top_level = true
	add_child(_tongues)
	_smoke = _particles(SMOKE, 7.0, _smoke_process(), _smoke_draw())
	_embers = _particles(EMBERS, 2.8, _points_shape(FireChips.ember_process()), FireChips.ember_mesh())
	for i in LIGHTS:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.55, 0.22)
		light.omni_range = 14.0
		light.shadow_enabled = i < 2
		light.visible = false
		add_child(light)
		_lights.append(light)
	set_cells([], Callable())


## `cells` burning (Vector2i); `ground` maps a world xz to its height; `fuel`
## maps a cell to how much there was to burn (0..1), which sets the flames' height.
func set_cells(cells: Array, ground: Callable, fuel: Callable = Callable()) -> void:
	var points := PackedVector3Array()
	var rng := RandomNumberGenerator.new()
	var sheets: Array = []
	var width := FireGrid.CELL * OVERLAP
	for cell: Vector2i in cells:
		if sheets.size() >= MAX_SHEETS:
			break
		rng.seed = hash(cell) + 17
		var f: float = fuel.call(cell) if fuel.is_valid() else 0.8
		var middle := FireGrid.center_of(cell)
		var h := (0.45 + f * 1.0) * rng.randf_range(0.85, 1.15)
		for yaw: float in [0.0, PI / 2.0]:
			# Sit the base at the lowest ground under the sheet, so it never floats.
			var along := Vector2(cos(yaw), -sin(yaw)) * width * 0.5
			var y := INF
			for xz: Vector2 in [middle, middle + along, middle - along]:
				y = minf(y, ground.call(xz) if ground.is_valid() else 0.0)
			sheets.append({"pos": Vector3(middle.x, y, middle.y), "yaw": yaw + rng.randf_range(-0.12, 0.12), "width": width, "height": h, "seed": rng.randi(), "heat": f})
	_tongues.set_sheets(sheets)
	for cell: Vector2i in cells:
		if points.size() >= MAX_POINTS:
			break
		rng.seed = hash(cell)
		var corner := Vector2(cell) * FireGrid.CELL
		for k in POINTS_PER_CELL:
			var xz := corner + Vector2(rng.randf(), rng.randf()) * FireGrid.CELL
			var y: float = ground.call(xz) if ground.is_valid() else 0.0
			points.append(Vector3(xz.x, y + 0.05, xz.y))
	_count = points.size()
	var on := _count > 0
	_tongues.visible = on
	for particles: GPUParticles3D in [_smoke, _embers]:
		particles.emitting = on
	if not on:
		for light in _lights:
			light.visible = false
		return
	var image := Image.create(_count, 1, false, Image.FORMAT_RGBF)
	for i in _count:
		var p := points[i]
		image.set_pixel(i, 0, Color(p.x, p.y, p.z))
	if _points == null or _points.get_width() != _count:
		_points = ImageTexture.create_from_image(image)
	else:
		_points.update(image)
	for particles: GPUParticles3D in [_smoke, _embers]:
		var process := particles.process_material as ParticleProcessMaterial
		process.emission_point_texture = _points
		process.emission_point_count = _count
	var cells_burning := float(_count) / POINTS_PER_CELL
	_smoke.amount_ratio = clampf(cells_burning * 8.0 / SMOKE, 0.05, 1.0)
	_embers.amount_ratio = clampf(cells_burning * 2.0 / EMBERS, 0.02, 1.0)
	_place_lights(points)


## Lights at the fire's hot spots: spread-out points, farthest-first.
func _place_lights(points: PackedVector3Array) -> void:
	var chosen: Array[Vector3] = []
	if not points.is_empty():
		chosen.append(points[0])
	while chosen.size() < LIGHTS and chosen.size() < points.size():
		var best := Vector3.ZERO
		var best_d := -1.0
		for i in range(0, points.size(), 5):
			var d := INF
			for c in chosen:
				d = minf(d, points[i].distance_squared_to(c))
			if d > best_d:
				best_d = d
				best = points[i]
		if best_d < 16.0:
			break
		chosen.append(best)
	for i in _lights.size():
		_lights[i].visible = i < chosen.size()
		if i < chosen.size():
			_lights[i].position = chosen[i] + Vector3.UP * 1.2


func _process(delta: float) -> void:
	_time += delta
	for i in _lights.size():
		var flicker := 1.0 + 0.25 * sin(_time * (11.0 + i) + i * 2.0) + 0.12 * sin(_time * 29.0 + i)
		_lights[i].light_energy = 2.2 * flicker


func _particles(amount: int, lifetime: float, process: ParticleProcessMaterial, draw: Mesh) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.randomness = 0.6
	particles.process_material = process
	particles.draw_pass_1 = draw
	particles.local_coords = false
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(Vector3(-2000.0, -50.0, -2000.0), Vector3(4000.0, 200.0, 4000.0))
	particles.emitting = false
	add_child(particles)
	return particles


static func _ramp(offsets: Array, colors: Array) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(offsets)
	gradient.colors = PackedColorArray(colors)
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


static func _points_shape(m: ParticleProcessMaterial) -> ParticleProcessMaterial:
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
	return m


func _smoke_process() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
	m.emission_shape_offset = Vector3(0.0, 1.6, 0.0)
	m.direction = Vector3.UP
	m.spread = 12.0
	m.initial_velocity_min = 1.2
	m.initial_velocity_max = 2.4
	m.gravity = Vector3(0.4, 0.5, 0.2)
	m.damping_min = 0.1
	m.damping_max = 0.3
	m.scale_min = 2.0
	m.scale_max = 3.6
	m.scale_curve = FireFx._curve([Vector2(0.0, 0.5), Vector2(1.0, 3.0)])
	m.angle_min = -180.0
	m.angle_max = 180.0
	m.color_ramp = _ramp([0.0, 0.1, 0.5, 1.0], [Color(0.12, 0.1, 0.09, 0.0), Color(0.16, 0.14, 0.13, 0.55), Color(0.32, 0.31, 0.3, 0.32), Color(0.5, 0.5, 0.5, 0.0)])
	return m


func _smoke_draw() -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 1.6)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = FireFx._puff()
	m.roughness = 1.0
	m.disable_receive_shadows = true
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 1.5
	quad.material = m
	return quad
