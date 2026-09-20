class_name GpuFire
extends Node3D
## A fire made of GPU particles: thousands of fine specks rising, cooling and
## going out, with a slower column of smoke over them and a flickering light.
## Everything is built in code — no scene file — so it can be dropped anywhere:
##
##     var fire := GpuFire.new()
##     fire.size = 0.6          # radius of the burning area, metres
##     add_child(fire)
##     fire.set_intensity(0.5)  # burning low
##
## Godot 4 throughout: GPUParticles3D with a ParticleProcessMaterial, and
## `shader_type spatial` materials on the draw passes.

## Radius of the burning area, in metres.
@export var size := 0.5
## 0 out, 1 burning hard.
@export var intensity := 1.0
@export var smoke := true
## Only a few fires can afford a shadow-casting light.
@export var shadows := false

## Specks alive at once for a fire of `size` 1. They are tiny — millimetres —
## so it takes tens of thousands of them to make a body of fire.
const FLAMES_PER_METRE := 270000
const SMOKE_PER_METRE := 42000
const FLAME_LIFE := 0.9
const SMOKE_LIFE := 3.5
## How big one speck is, in metres, for a fire of `size` 1.
const SPECK := 0.006
const SMOKE_SPECK := 0.012

var flames: GPUParticles3D
var smoke_puffs: GPUParticles3D
var light: OmniLight3D
var _time := 0.0


func _ready() -> void:
	flames = _build_flames()
	add_child(flames)
	if smoke:
		smoke_puffs = _build_smoke()
		add_child(smoke_puffs)
	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.56, 0.22)
	light.omni_range = 4.5 + size * 7.0
	light.shadow_enabled = shadows
	light.position.y = 0.3 + size * 0.5
	add_child(light)
	set_intensity(intensity)


## 0 puts it out; anything above burns that hard.
func set_intensity(value: float) -> void:
	intensity = clampf(value, 0.0, 1.0)
	var on := intensity > 0.01
	if flames != null:
		flames.emitting = on
		flames.amount_ratio = maxf(0.08, intensity)
	if smoke_puffs != null:
		smoke_puffs.emitting = on
		smoke_puffs.amount_ratio = maxf(0.08, intensity * 0.9)
	if light != null:
		light.visible = on
	set_process(on)


func _process(delta: float) -> void:
	# The specks are coloured by where they are relative to the fire's heart.
	var heart := global_position + Vector3(0.0, size * 0.35, 0.0)
	var flame_material: ShaderMaterial = (flames.draw_pass_1 as QuadMesh).material
	flame_material.set_shader_parameter("fire_origin", heart)
	flame_material.set_shader_parameter("fire_width", size * lerpf(0.6, 1.0, intensity))
	# A fire never burns steadily: the light jumps about.
	_time += delta
	var flicker := 1.0 + 0.2 * sin(_time * 12.0) + 0.11 * sin(_time * 29.0 + 1.3) + 0.07 * sin(_time * 6.7)
	light.light_energy = (1.0 + size * 1.5) * intensity * flicker


# --- the flames ---------------------------------------------------------------

func _build_flames() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "Flames"
	particles.amount = int(clampf(FLAMES_PER_METRE * size, 36000, 260000))
	particles.lifetime = FLAME_LIFE * (0.8 + size * 0.4)
	particles.randomness = 0.45
	particles.preprocess = particles.lifetime
	particles.fixed_fps = 0  # follow the frame rate, so it never steps visibly
	particles.interpolate = true
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(Vector3(-size * 3.0, -0.2, -size * 3.0),
		Vector3(size * 6.0, 3.0 + size * 5.0, size * 6.0))

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = size * 0.6
	process.direction = Vector3.UP
	process.spread = 22.0
	process.initial_velocity_min = 0.2 + size * 0.2
	process.initial_velocity_max = 0.6 + size * 0.5
	# Hot gas rises: gravity points up for flames.
	process.gravity = Vector3(0.0, 0.8 + size * 0.7, 0.0)
	process.damping_min = 0.4
	process.damping_max = 1.2
	process.scale_min = 0.5
	process.scale_max = 1.0
	# A speck is full size almost all its life and then gone, so it never fades
	# into a smear — it simply stops being there.
	process.scale_curve = _curve([Vector2(0.0, 0.9), Vector2(0.75, 1.0), Vector2(1.0, 0.0)])
	# Turbulence is what makes it curl instead of going straight up.
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 1.6
	process.turbulence_noise_scale = 2.4
	process.turbulence_noise_speed = Vector3(0.0, 1.2, 0.0)
	process.turbulence_influence_min = 0.06
	process.turbulence_influence_max = 0.18
	# White through the ramp: the draw-pass shader decides the colour from where
	# a speck is in the flame. Alpha carries how much life it has left.
	process.color_ramp = _ramp([0.0, 0.75, 1.0], [
		Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 0.45), Color(1.0, 1.0, 1.0, 0.0),
	])
	particles.process_material = process
	particles.draw_pass_1 = _speck(SPECK * (0.6 + size * 0.8), "res://world/fire/fire_particle.gdshader")
	return particles


# --- the smoke ----------------------------------------------------------------

func _build_smoke() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "Smoke"
	particles.amount = int(clampf(SMOKE_PER_METRE * size, 6000, 60000))
	particles.lifetime = SMOKE_LIFE
	particles.randomness = 0.6
	particles.preprocess = SMOKE_LIFE * 0.5
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(Vector3(-size * 8.0, -0.2, -size * 8.0),
		Vector3(size * 16.0, 14.0, size * 16.0))

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = size * 0.5
	process.direction = Vector3.UP
	process.spread = 8.0
	process.initial_velocity_min = 0.8
	process.initial_velocity_max = 1.6 + size
	process.gravity = Vector3(0.0, 0.45, 0.0)
	process.damping_min = 0.2
	process.damping_max = 0.5
	process.scale_min = 0.6 + size
	process.scale_max = 1.2 + size * 1.6
	process.scale_curve = _curve([Vector2(0.0, 0.35), Vector2(1.0, 2.6)])
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.9
	process.turbulence_noise_scale = 1.4
	process.turbulence_influence_min = 0.05
	process.turbulence_influence_max = 0.14
	process.color_ramp = _ramp([0.0, 0.12, 0.55, 1.0], [
		Color(0.22, 0.20, 0.19, 0.0),
		Color(0.26, 0.24, 0.23, 0.5),
		Color(0.45, 0.44, 0.43, 0.22),
		Color(0.6, 0.6, 0.6, 0.0),
	])
	particles.process_material = process
	particles.draw_pass_1 = _speck(SMOKE_SPECK * (0.6 + size * 0.8), "res://world/fire/smoke_particle.gdshader")
	return particles


# --- odds and ends -------------------------------------------------------------

## One particle's mesh: a quad with the given shader on it.
static func _speck(across: float, shader_path: String) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(across, across)
	var material := ShaderMaterial.new()
	material.shader = load(shader_path)
	quad.material = material
	return quad


static func _curve(points: Array) -> CurveTexture:
	var curve := Curve.new()
	for point: Vector2 in points:
		curve.add_point(point)
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture


static func _ramp(offsets: Array, colors: Array) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(offsets)
	gradient.colors = PackedColorArray(colors)
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture
