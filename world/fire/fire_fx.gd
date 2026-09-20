class_name FireFx
extends Node3D
## A fire, simulated grain by grain (GrainSim): hot grains born in the fuel bed
## climb, wander, cool from white through orange to red, and go up as smoke;
## sparks are thrown clear and fall back. Nothing here is a painted sheet.
##
## `size` is roughly the radius of the burning area in metres; `intensity`
## (0..1) is how hard it burns, and 0 puts it out. Used for campfires, the
## castaway's pit and every burning cell of a wildfire.

@export var size := 0.5
@export var intensity := 1.0
## Wildfire cells skip the light's shadow; only a few fires can afford one.
@export var shadows := true
@export var smoke := true

var _grains: GrainField
var _flames: Dictionary
var _sparks: Dictionary
var _bed: MeshInstance3D
var _light: OmniLight3D
var _time := 0.0

static var _flame_texture: Texture2D
static var _puff_texture: Texture2D


func _ready() -> void:
	_bed = _ember_bed()
	add_child(_bed)
	# Room for the flames, their smoke and a few sparks at once.
	_grains = GrainField.new(int(clampf(2000.0 * (0.6 + size), 1200.0, 4000.0)))
	add_child(_grains)
	# Born across the fuel bed, not from one point, so the fire has width.
	_flames = _grains.add_source(GrainSim.FIRE, Vector3(0.0, 0.04, 0.0),
		_flame_rate(), 0.7 + size * 0.6, 0.3 + size * 0.35, size * 0.75)
	_sparks = _grains.add_source(GrainSim.EMBER, Vector3(0.0, 0.12, 0.0),
		clampf(24.0 * size, 8.0, 40.0), 2.6 + size, 1.1, size * 0.5)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.58, 0.24)
	_light.omni_range = 5.0 + size * 6.0
	_light.shadow_enabled = shadows
	_light.position.y = 0.35 + size * 0.5
	add_child(_light)
	set_intensity(intensity)


## Grains of flame a second: enough at once that the fire is a body, not sparks.
func _flame_rate() -> float:
	return clampf(2600.0 * (0.4 + size), 900.0, 5200.0)


func set_intensity(value: float) -> void:
	intensity = clampf(value, 0.0, 1.0)
	if _grains == null:
		return
	var on := intensity > 0.01
	if _bed != null:
		# The coals outlive the flames and fade as the fire dies.
		_bed.visible = on
		var coals: StandardMaterial3D = _bed.material_override
		coals.emission_energy_multiplier = lerpf(0.3, 1.0, intensity)
	# A fire burning low throws fewer, weaker flames — not thinner ones.
	_flames.rate = _flame_rate() * intensity
	_flames.strength = lerpf(0.5, 1.0, intensity)
	_sparks.rate = clampf(24.0 * size, 8.0, 40.0) * intensity * (0.0 if not smoke else 1.0)
	_grains.visible = on
	_grains.set_process(on)
	if not on:
		_grains.sim.clear()
	_light.visible = on
	set_process(on)


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
