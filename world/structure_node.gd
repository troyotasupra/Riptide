class_name StructureNode
extends Interactable
## A placed camp structure: campfire, lean-to, tent, drying rack or storage crate.
## Its state (fuel, cooking, contents) lives in CampSystems; this is the prop.

var structure_id := ""
var type := ""
var _fire_parts: Array[Node3D] = []


func setup(id: String, p_type: String, pos: Vector3, yaw: float) -> void:
	structure_id = id
	type = p_type
	name = "Structure_" + id
	interact_id = "struct:" + id
	position = pos
	rotation.y = yaw
	collision_layer = Layers.WORLD | Layers.INTERACT
	collision_mask = 0
	match type:
		"campfire":
			_campfire()
		"lean_to":
			_lean_to()
		"tent":
			_tent()
		"drying_rack":
			_drying_rack()
		"storage_crate":
			_crate()
	text_provider = func(player: Node) -> String:
		if GameState.world == null or GameState.world.camp == null:
			return ""
		return GameState.world.camp.structure_prompt(structure_id, player)
	set_lit(false)


func set_lit(lit: bool) -> void:
	for part in _fire_parts:
		part.visible = lit


func _box(size: Vector3, pos: Vector3, key: String, color: Color, rot: Vector3 = Vector3.ZERO, solid: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = Props.material(key, color)
	visual.position = pos
	visual.rotation = rot
	add_child(visual)
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position = pos
		collider.rotation = rot
		add_child(collider)
	return visual


func _campfire() -> void:
	for i in 8:
		var a := i * TAU / 8.0
		_box(Vector3(0.28, 0.2, 0.22), Vector3(cos(a) * 0.6, 0.1, sin(a) * 0.6), "ring_stone", Color(0.45, 0.44, 0.42), Vector3(0.0, a, 0.0))
	for i in 3:
		_box(Vector3(0.9, 0.12, 0.12), Vector3(0.0, 0.1, 0.0), "fire_log", Color(0.30, 0.22, 0.14), Vector3(0.0, i * PI / 3.0, 0.2))
	var shape := CylinderShape3D.new()
	shape.radius = 0.75
	shape.height = 0.5
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.25
	add_child(collider)
	var flame_material := StandardMaterial3D.new()
	flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_material.albedo_color = Color(1.0, 0.55, 0.15)
	for i in 3:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.22 - i * 0.04
		cone.height = 0.7 - i * 0.12
		cone.radial_segments = 5
		cone.rings = 1
		var flame := MeshInstance3D.new()
		flame.mesh = cone
		flame.material_override = flame_material
		flame.position = Vector3(sin(i * 2.1) * 0.12, 0.35, cos(i * 2.1) * 0.12)
		add_child(flame)
		_fire_parts.append(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 1.6
	light.omni_range = 8.0
	light.position.y = 0.8
	add_child(light)
	_fire_parts.append(light)


func _lean_to() -> void:
	for x: float in [-1.1, 1.1]:
		_box(Vector3(0.1, 1.9, 0.1), Vector3(x, 0.95, -0.9), "post", Color(0.45, 0.34, 0.22))
	_box(Vector3(2.5, 0.05, 2.3), Vector3(0.0, 1.05, 0.0), "tarp_blue", Color(0.20, 0.35, 0.55), Vector3(-0.75, 0.0, 0.0), true)


func _tent() -> void:
	var cloth := Color(0.36, 0.45, 0.30)
	for s: float in [-1.0, 1.0]:
		_box(Vector3(0.05, 1.7, 2.4), Vector3(s * 0.55, 0.7, 0.0), "tent_cloth", cloth, Vector3(0.0, 0.0, s * 0.6))
	_box(Vector3(0.08, 0.08, 2.5), Vector3(0.0, 1.35, 0.0), "post", Color(0.45, 0.34, 0.22))
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 1.3, 2.4)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.65
	add_child(collider)


func _drying_rack() -> void:
	for x: float in [-0.7, 0.7]:
		_box(Vector3(0.08, 1.4, 0.08), Vector3(x, 0.7, 0.0), "post", Color(0.45, 0.34, 0.22), Vector3.ZERO, true)
	for y: float in [0.6, 0.9, 1.2]:
		_box(Vector3(1.6, 0.05, 0.05), Vector3(0.0, y, 0.0), "post", Color(0.45, 0.34, 0.22))


func _crate() -> void:
	_box(Vector3(1.0, 0.7, 0.7), Vector3(0.0, 0.35, 0.0), "crate", Color(0.55, 0.40, 0.24), Vector3.ZERO, true)
	_box(Vector3(1.04, 0.08, 0.74), Vector3(0.0, 0.62, 0.0), "crate_band", Color(0.35, 0.25, 0.15))
