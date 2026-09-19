class_name FireChips
extends RefCounted
## The look of fire, shared by campfires and wildfire: a swarm of tiny faceted
## chips (a centimetre or two across, about half an inch next to a person),
## glowing white-yellow at the base, going orange then deep red as they rise,
## tumbling in the heat and shrinking away to nothing. Thousands of them make
## the shape of the flames; no soft sprites.

## Metres across one chip at scale 1.
const CHIP := 0.012

static var _chip_mesh: ArrayMesh
static var _ember_mesh: ArrayMesh
static var _shard_mesh: ArrayMesh


## A small tetrahedron, lit by nothing but its own glow.
static func chip_mesh() -> ArrayMesh:
	if _chip_mesh == null:
		_chip_mesh = _tetra(CHIP, _glow_material(Color(1.8, 1.4, 1.2)))
	return _chip_mesh


## Embers: the same chips, smaller and brighter, drifting high on the heat.
static func ember_mesh() -> ArrayMesh:
	if _ember_mesh == null:
		_ember_mesh = _tetra(CHIP * 0.6, _glow_material(Color(3.0, 2.2, 1.5)))
	return _ember_mesh


## The body of the flames: tall faceted shards, from a hand's width to most of a
## metre, stretched along their rise and overlapping into connected tongues of
## fire. The small chips flicker around and above them.
static func shard_mesh() -> ArrayMesh:
	if _shard_mesh == null:
		_shard_mesh = _shard(_glow_material(Color(1.35, 1.1, 1.0), 1000.0))
	return _shard_mesh


static func body_process(height: float) -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 10.0
	var rise := height / 0.8
	m.initial_velocity_min = rise * 0.35
	m.initial_velocity_max = rise * 0.7
	m.gravity = Vector3(0.0, rise * 0.8, 0.0)
	m.damping_min = rise * 0.3
	m.damping_max = rise * 0.6
	m.scale_min = 0.25 * height
	m.scale_max = 0.7 * height
	m.scale_curve = FireFx._curve([Vector2(0.0, 0.35), Vector2(0.25, 1.0), Vector2(0.65, 0.7), Vector2(1.0, 0.0)])
	# Pointing along their rise, so they read as licks of flame, not confetti.
	m.particle_flag_align_y = true
	m.color_ramp = _ramp([0.0, 0.15, 0.45, 0.75, 1.0], [Color(1.0, 0.9, 0.55), Color(1.0, 0.62, 0.1), Color(0.95, 0.3, 0.02), Color(0.7, 0.1, 0.01), Color(0.28, 0.03, 0.01)])
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.8
	m.turbulence_noise_scale = 1.6
	m.turbulence_influence_min = 0.05
	m.turbulence_influence_max = 0.2
	return m


## Flames rising from the emitter. `height` is roughly how tall they stand (m).
static func flame_process(height: float) -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 22.0
	var rise := height / 0.9
	m.initial_velocity_min = rise * 0.45
	m.initial_velocity_max = rise * 0.95
	m.gravity = Vector3(0.0, rise * 0.9, 0.0)
	m.damping_min = rise * 0.4
	m.damping_max = rise * 0.9
	m.scale_min = 1.0
	m.scale_max = 2.4
	m.scale_curve = FireFx._curve([Vector2(0.0, 0.8), Vector2(0.15, 1.0), Vector2(0.7, 0.55), Vector2(1.0, 0.0)])
	m.angular_velocity_min = -540.0
	m.angular_velocity_max = 540.0
	m.particle_flag_rotate_y = true
	m.color_ramp = _ramp([0.0, 0.12, 0.35, 0.65, 1.0], [Color(1.0, 0.92, 0.6), Color(1.0, 0.7, 0.15), Color(1.0, 0.38, 0.03), Color(0.75, 0.12, 0.02), Color(0.25, 0.03, 0.01)])
	# Licks and gutters: the heat shimmers the swarm into tongues.
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 1.6
	m.turbulence_noise_scale = 1.2
	m.turbulence_noise_speed_random = 0.6
	m.turbulence_influence_min = 0.12
	m.turbulence_influence_max = 0.35
	return m


static func ember_process() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 35.0
	m.initial_velocity_min = 1.2
	m.initial_velocity_max = 3.6
	m.gravity = Vector3(0.3, 0.7, 0.1)
	m.scale_min = 0.8
	m.scale_max = 1.6
	m.scale_curve = FireFx._curve([Vector2(0.0, 1.0), Vector2(1.0, 0.0)])
	m.angular_velocity_min = -360.0
	m.angular_velocity_max = 360.0
	m.particle_flag_rotate_y = true
	m.color_ramp = _ramp([0.0, 0.5, 1.0], [Color(1.0, 0.85, 0.45), Color(1.0, 0.4, 0.07), Color(0.35, 0.05, 0.0)])
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 3.0
	m.turbulence_noise_scale = 2.5
	return m


static func _ramp(offsets: Array, colors: Array) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(offsets)
	gradient.colors = PackedColorArray(colors)
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


static func _glow_material(boost: Color, true_size_within: float = 4.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://world/fire/fire_chip.gdshader")
	# Brighter than white, so the chips bloom.
	m.set_shader_parameter("boost", Vector3(boost.r, boost.g, boost.b))
	m.set_shader_parameter("true_size_within", true_size_within)
	return m


## A tall, slightly twisted three-sided spike, 1 unit high, base at the origin.
static func _shard(material: Material) -> ArrayMesh:
	var w := 0.2
	var tip := Vector3(0.03, 1.0, -0.02)
	var mid := [Vector3(w, 0.3, 0.0), Vector3(-w * 0.5, 0.3, w * 0.87), Vector3(-w * 0.5, 0.3, -w * 0.87)]
	var foot := Vector3(0.0, 0.0, 0.0)
	var vertices := PackedVector3Array()
	for i in 3:
		var a: Vector3 = mid[i]
		var b: Vector3 = mid[(i + 1) % 3]
		vertices.append_array([tip, a, b, foot, b, a])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh


static func _tetra(size: float, material: Material) -> ArrayMesh:
	var r := size * 0.5
	var a := Vector3(0.0, r * 1.2, 0.0)
	var b := Vector3(r, -r * 0.5, r * 0.6)
	var c := Vector3(-r, -r * 0.5, r * 0.6)
	var d := Vector3(0.0, -r * 0.5, -r)
	var vertices := PackedVector3Array([a, b, c, a, c, d, a, d, b, b, d, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh
