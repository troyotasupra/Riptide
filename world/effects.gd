class_name Effects
extends RefCounted
## Short-lived things you see for a moment and then don't: muzzle flashes,
## tracers, and the puff where a bullet lands. Every peer makes its own — none
## of it is worth sending over the network.

const TRACER_SECONDS := 0.055
const FLASH_SECONDS := 0.045
const IMPACT_SECONDS := 0.5

const IMPACT_COLORS := {
	"flesh": Color(0.62, 0.12, 0.10),
	"water": Color(0.80, 0.90, 0.95),
	"dirt": Color(0.58, 0.52, 0.44),
}


## A streak of light along the bullet's path.
static func tracer(from: Vector3, to: Vector3) -> void:
	var world := _world()
	if world == null or from.distance_to(to) < 0.01:
		return
	var streak := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.035, 0.035, from.distance_to(to))
	streak.mesh = mesh
	streak.material_override = _glow(Color(1.0, 0.86, 0.55), 3.0)
	streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(streak)
	streak.global_transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), (from + to) * 0.5)
	_forget(streak, TRACER_SECONDS)


## The flash at the muzzle. `strength` fades with a suppressor fitted.
## A hot core with a few flame spikes thrown forward down the barrel's line,
## a different star every shot, and a quick light.
static func muzzle_flash(at: Vector3, direction: Vector3, strength: float) -> void:
	var world := _world()
	if world == null or strength <= 0.05:
		return
	var forward := direction.normalized()
	var flash := Node3D.new()
	world.add_child(flash)
	var up := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	flash.global_transform = Transform3D(Basis.looking_at(forward, up), at)
	var hot := _glow(Color(1.0, 0.9, 0.62), 5.0)
	var core := MeshInstance3D.new()
	core.mesh = _flash_core()
	core.material_override = hot
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.scale = Vector3(1.0, 1.0, 1.6) * strength
	core.position = Vector3(0.0, 0.0, -0.03 * strength)
	flash.add_child(core)
	var spin := randf() * TAU
	for i in 5:
		var spike := MeshInstance3D.new()
		spike.mesh = _flash_spike()
		spike.material_override = hot
		spike.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The spike's cone points along its +Y; lay it forward (-Z) and splay it out.
		var around := spin + i * TAU / 5.0 + randf_range(-0.3, 0.3)
		var splay := 0.35 if i > 0 else 0.0
		spike.transform = Transform3D(Basis(Vector3.FORWARD, around) * Basis(Vector3.RIGHT, -PI / 2.0 + splay), Vector3.ZERO)
		spike.scale = Vector3.ONE * strength * randf_range(0.7, 1.15) * (1.4 if i == 0 else 1.0)
		# The cone is centred on its middle: slide it out so its base sits at the muzzle.
		spike.position = spike.basis * Vector3(0.0, 0.055, 0.0)
		flash.add_child(spike)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.55)
	light.light_energy = 2.2 * strength
	light.omni_range = 5.0
	light.position = Vector3(0.0, 0.0, -0.1)
	flash.add_child(light)
	_forget(flash, FLASH_SECONDS)


static var _core_mesh: SphereMesh
static var _spike_mesh: CylinderMesh


static func _flash_core() -> SphereMesh:
	if _core_mesh == null:
		_core_mesh = SphereMesh.new()
		_core_mesh.radius = 0.028
		_core_mesh.height = 0.056
		_core_mesh.radial_segments = 8
		_core_mesh.rings = 4
	return _core_mesh


## A thin cone, 11 cm long, centred on its middle.
static func _flash_spike() -> CylinderMesh:
	if _spike_mesh == null:
		_spike_mesh = CylinderMesh.new()
		_spike_mesh.top_radius = 0.0
		_spike_mesh.bottom_radius = 0.016
		_spike_mesh.height = 0.11
		_spike_mesh.radial_segments = 5
		_spike_mesh.rings = 1
	return _spike_mesh


## Where the round landed: blood, a splash, or a puff of dirt.
static func impact(at: Vector3, kind: String) -> void:
	var world := _world()
	if world == null:
		return
	var burst := GPUParticles3D.new()
	burst.amount = 14
	burst.lifetime = IMPACT_SECONDS
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var speck := QuadMesh.new()
	speck.size = Vector2(0.06, 0.06)
	burst.draw_pass_1 = speck
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 60.0
	process.initial_velocity_min = 1.5
	process.initial_velocity_max = 4.0
	process.gravity = Vector3(0.0, -9.0, 0.0)
	process.scale_min = 0.5
	process.scale_max = 1.4
	burst.process_material = process
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = IMPACT_COLORS.get(kind, IMPACT_COLORS.dirt)
	burst.material_override = material
	world.add_child(burst)
	burst.global_position = at
	burst.emitting = true
	_forget(burst, IMPACT_SECONDS * 2.0)


static func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


static func _world() -> Node3D:
	if GameState.world == null or DisplayServer.get_name() == "headless":
		return null
	return GameState.world


static func _forget(node: Node, seconds: float) -> void:
	node.get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if is_instance_valid(node):
			node.queue_free())
