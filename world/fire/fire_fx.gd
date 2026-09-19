class_name FireFx
extends Node3D
## A fire: crossed sheets of flame whose tongues lick up from white-hot at the
## root to red at the tips (FlameSheets), one solid body with no gaps, a few rising embers, smoke and a flickering light. `size` is roughly
## the radius of the burning area in metres; `intensity` (0..1) scales how hard it
## burns, and 0 puts it out. Used for campfires, the castaway's pit and wildfire.

@export var size := 0.5
@export var intensity := 1.0
## Wildfire cells skip the light's shadow; only a few fires can afford one.
@export var shadows := true
@export var smoke := true

var _tongues: FlameSheets
var _bed: MeshInstance3D
var _embers: GPUParticles3D
var _smoke: GPUParticles3D
var _light: OmniLight3D
var _time := 0.0

static var _flame_texture: Texture2D
static var _puff_texture: Texture2D


func _ready() -> void:
	_bed = _ember_bed()
	add_child(_bed)
	_tongues = FlameSheets.new()
	add_child(_tongues)
	_tongues.set_sheets(_campfire_sheets())
	var embers := FireChips.ember_process()
	embers.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	embers.emission_sphere_radius = size * 0.5
	_embers = _particles(embers, FireChips.ember_mesh(), int(clampf(10.0 * size + 4.0, 4.0, 24.0)), 2.2)
	if smoke:
		_smoke = _particles(_smoke_material(), _smoke_draw(), int(clampf(8.0 * size + 5.0, 5.0, 24.0)), 5.0)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.58, 0.24)
	_light.omni_range = 5.0 + size * 6.0
	_light.shadow_enabled = shadows
	_light.position.y = 0.35 + size * 0.5
	add_child(_light)
	set_intensity(intensity)


func set_intensity(value: float) -> void:
	intensity = clampf(value, 0.0, 1.0)
	if _tongues == null:
		return
	var on := intensity > 0.01
	_tongues.visible = on
	if _bed != null:
		# The coals outlive the flames and fade as the fire dies.
		_bed.visible = on
		var coals: StandardMaterial3D = _bed.material_override
		coals.emission_energy_multiplier = lerpf(0.3, 1.0, intensity)
	# A fire burning low is a smaller fire, not a thinner one.
	_tongues.scale = Vector3.ONE * lerpf(0.45, 1.0, intensity)
	for particles: GPUParticles3D in [_embers, _smoke]:
		if particles != null:
			particles.emitting = on
			particles.amount_ratio = maxf(0.05, intensity)
	_light.visible = on
	set_process(on)


## Sheets stood through the fire at every angle and offset — never a neat star,
## which reads as an X from above — with a lower ring round the edge, so from
## any side and any height it is one body of fire with the ground hidden.
func _campfire_sheets() -> Array:
	var list: Array = []
	var tall := 0.4 + size * 0.95
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	for i in 7:
		# Each sheet is offset off the middle and turned freely, so the sheets
		# cross all over the fire rather than all through one line.
		var offset := Vector2.from_angle(rng.randf() * TAU) * size * rng.randf_range(0.0, 0.42)
		list.append({"pos": Vector3(offset.x, 0.0, offset.y), "yaw": rng.randf() * TAU,
			"width": size * rng.randf_range(1.25, 1.8), "height": tall * rng.randf_range(0.78, 1.0),
			"seed": 5150 + i, "heat": 1.0})
	for i in 8:
		var a := i * TAU / 8.0 + rng.randf_range(-0.2, 0.2)
		list.append({"pos": Vector3(cos(a), 0.0, sin(a)) * size * rng.randf_range(0.4, 0.6),
			"yaw": -a + PI / 2.0 + rng.randf_range(-0.4, 0.4), "width": size * 0.95,
			"height": tall * rng.randf_range(0.42, 0.62), "seed": 5170 + i, "heat": 0.6})
	return list


## The ember bed: the fire is sitting on coals, so you never see bare ground
## through the flames, and it glows on after the flames drop.
func _ember_bed() -> MeshInstance3D:
	var bed := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = size * 0.62
	disc.bottom_radius = size * 0.78
	disc.height = 0.06
	disc.radial_segments = 11
	bed.mesh = disc
	var coals := StandardMaterial3D.new()
	coals.albedo_color = Color(0.14, 0.07, 0.05)
	coals.emission_enabled = true
	coals.emission = Color(1.0, 0.30, 0.04)
	coals.emission_energy_multiplier = 0.9
	coals.roughness = 0.95
	bed.material_override = coals
	bed.position.y = 0.02
	return bed


func _process(delta: float) -> void:
	_time += delta
	var flicker := 1.0 + 0.22 * sin(_time * 13.0) + 0.12 * sin(_time * 31.0 + 1.3) + 0.08 * sin(_time * 7.1)
	_light.light_energy = (1.1 + size * 1.4) * intensity * flicker


func _particles(process: ParticleProcessMaterial, draw: Mesh, amount: int, lifetime: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.preprocess = lifetime
	particles.randomness = 0.5
	particles.process_material = process
	particles.draw_pass_1 = draw
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(Vector3(-2.0, -0.5, -2.0) * maxf(1.0, size * 2.0), Vector3(4.0, 12.0, 4.0) * maxf(1.0, size * 2.0))
	add_child(particles)
	return particles


func _smoke_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = size * 0.4
	m.direction = Vector3.UP
	m.spread = 10.0
	m.initial_velocity_min = 0.6
	m.initial_velocity_max = 1.2 + size * 0.5
	m.gravity = Vector3(0.25, 0.35, 0.1)
	m.damping_min = 0.1
	m.damping_max = 0.3
	m.scale_min = 0.8 + size
	m.scale_max = 1.4 + size * 1.5
	m.scale_curve = _curve([Vector2(0.0, 0.4), Vector2(1.0, 2.4)])
	m.angle_min = -180.0
	m.angle_max = 180.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.12, 0.6, 1.0])
	ramp.colors = PackedColorArray([Color(0.25, 0.22, 0.2, 0.0), Color(0.3, 0.28, 0.26, 0.4), Color(0.45, 0.44, 0.43, 0.22), Color(0.55, 0.55, 0.55, 0.0)])
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	m.color_ramp = ramp_texture
	return m


func _smoke_draw() -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _puff()
	m.roughness = 1.0
	m.disable_receive_shadows = true
	quad.material = m
	return quad


static func _curve(points: Array) -> CurveTexture:
	var curve := Curve.new()
	for point: Vector2 in points:
		curve.add_point(point)
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture


## A soft tongue of flame: an elongated glow, widest low down and tapering up,
## with no hard edge anywhere, so overlapping flames melt into each other.
static func _flame_tex() -> Texture2D:
	if _flame_texture != null:
		return _flame_texture
	var w := 64
	var h := 128
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var u := (x + 0.5) / w * 2.0 - 1.0
			var v := 1.0 - (y + 0.5) / h  # 0 at the bottom, 1 at the top
			# The half-width narrows toward the tip; the core sits a third of the way up.
			var half := lerpf(0.85, 0.12, pow(v, 0.8))
			var across := u / half
			var along := (v - 0.32) / (0.32 if v < 0.32 else 0.68)
			var r := sqrt(across * across + along * along)
			var a := clampf(1.0 - r, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	image.generate_mipmaps()
	_flame_texture = ImageTexture.create_from_image(image)
	return _flame_texture


static func _puff() -> Texture2D:
	if _puff_texture != null:
		return _puff_texture
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	_puff_texture = texture
	return texture
