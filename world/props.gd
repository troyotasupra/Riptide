class_name Props
extends RefCounted
## Low-poly props generated in code. Meshes and materials are cached and shared,
## so a thousand bushes reuse one mesh instead of creating a thousand.
##
## build(kind) returns:
##   root: Node3D visual · harvest: nodes hidden while depleted
##   shape + shape_position: collision · blocks: stops players walking through
##   hide_when_depleted: the whole prop disappears when picked (stones, fiber)

static var _meshes := {}
static var _materials := {}


static func material(key: String, color: Color) -> StandardMaterial3D:
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 1.0
		_materials[key] = m
	return _materials[key]


static func build(kind: String) -> Dictionary:
	match kind:
		"palm":
			return _palm()
		"tree":
			return _tree()
		"berry_bush":
			return _bush(Color(0.30, 0.22, 0.62))
		"red_berry_bush":
			return _bush(Color(0.86, 0.10, 0.12))
		"fiber":
			return _fiber()
		"stone":
			return _small("stone", _sphere_mesh("stone", 0.3, 5, 2), material("stone", Color(0.56, 0.54, 0.51)), Vector3(1.1, 0.6, 0.9))
		"flint":
			return _small("flint", _box_mesh("flint", Vector3(0.26, 0.12, 0.18)), material("flint", Color(0.22, 0.22, 0.25)), Vector3.ONE)
		"driftwood":
			return _driftwood()
		_:
			return _rock()


static func _result(root: Node3D, harvest: Array, shape: Shape3D, shape_position: Vector3, blocks: bool, hide_all: bool, view_distance: float) -> Dictionary:
	for child in root.find_children("*", "GeometryInstance3D", true, false):
		(child as GeometryInstance3D).visibility_range_end = view_distance
	return {"root": root, "harvest": harvest, "shape": shape, "shape_position": shape_position, "blocks": blocks, "hide_when_depleted": hide_all}


static func _instance(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = pos
	instance.rotation = rot
	instance.scale = scl
	parent.add_child(instance)
	return instance


static func _palm() -> Dictionary:
	var root := Node3D.new()
	var trunk_mesh: Mesh = _cached("palm_trunk", func() -> Mesh:
		var m := CylinderMesh.new()
		m.top_radius = 0.12
		m.bottom_radius = 0.2
		m.height = 6.0
		m.radial_segments = 6
		m.rings = 2
		return m)
	_instance(root, trunk_mesh, material("palm_trunk", Color(0.55, 0.43, 0.30)), Vector3(0.15, 3.0, 0.0), Vector3(0.0, 0.0, -0.05))
	var frond := _box_mesh("palm_frond", Vector3(0.55, 0.05, 2.6))
	var leaf := material("palm_leaf", Color(0.30, 0.55, 0.20))
	for i in 6:
		var a := i * TAU / 6.0
		_instance(root, frond, leaf, Vector3(0.3 + sin(a) * 1.1, 5.8, cos(a) * 1.1), Vector3(0.35, a, 0.0))
	var coconuts := Node3D.new()
	root.add_child(coconuts)
	var nut := _sphere_mesh("coconut", 0.16, 6, 3)
	for offset: Vector3 in [Vector3(0.45, 5.7, 0.15), Vector3(0.1, 5.65, -0.2), Vector3(0.2, 5.6, 0.3)]:
		_instance(coconuts, nut, material("coconut", Color(0.38, 0.26, 0.14)), offset)
	var shape := CylinderShape3D.new()
	shape.radius = 0.3
	shape.height = 6.0
	return _result(root, [coconuts], shape, Vector3(0.15, 3.0, 0.0), true, false, 450.0)


static func _tree() -> Dictionary:
	var root := Node3D.new()
	var trunk_mesh: Mesh = _cached("tree_trunk", func() -> Mesh:
		var m := CylinderMesh.new()
		m.top_radius = 0.28
		m.bottom_radius = 0.4
		m.height = 4.5
		m.radial_segments = 6
		m.rings = 1
		return m)
	var bark := material("tree_trunk", Color(0.36, 0.26, 0.17))
	_instance(root, trunk_mesh, bark, Vector3(0.0, 0.25, 0.0), Vector3.ZERO, Vector3(1.05, 0.11, 1.05))
	var standing := Node3D.new()
	root.add_child(standing)
	_instance(standing, trunk_mesh, bark, Vector3(0.0, 2.25, 0.0))
	_instance(standing, _sphere_mesh("tree_canopy", 2.3, 7, 4), material("tree_canopy", Color(0.16, 0.38, 0.14)), Vector3(0.0, 5.6, 0.0), Vector3.ZERO, Vector3(1.0, 0.85, 1.0))
	var shape := CylinderShape3D.new()
	shape.radius = 0.45
	shape.height = 4.5
	return _result(root, [standing], shape, Vector3(0.0, 2.25, 0.0), true, false, 450.0)


static func _bush(berry_color: Color) -> Dictionary:
	var root := Node3D.new()
	_instance(root, _sphere_mesh("bush", 0.8, 6, 3), material("bush", Color(0.24, 0.45, 0.20)), Vector3(0.0, 0.45, 0.0), Vector3.ZERO, Vector3(1.0, 0.75, 1.0))
	var berries := Node3D.new()
	root.add_child(berries)
	var berry := _sphere_mesh("berry", 0.08, 5, 2)
	var berry_material := material("berry_%s" % berry_color.to_html(), berry_color)
	for i in 9:
		var a := i * 2.4
		var y := 0.35 + 0.12 * ((i * 7) % 4)
		_instance(berries, berry, berry_material, Vector3(cos(a) * 0.72, y, sin(a) * 0.72))
	var shape := SphereShape3D.new()
	shape.radius = 0.8
	return _result(root, [berries], shape, Vector3(0.0, 0.5, 0.0), false, false, 160.0)


static func _fiber() -> Dictionary:
	var root := Node3D.new()
	var blade := _box_mesh("fiber_blade", Vector3(0.05, 1.0, 0.16))
	var green := material("fiber", Color(0.56, 0.70, 0.30))
	for i in 5:
		var a := i * TAU / 5.0
		_instance(root, blade, green, Vector3(cos(a) * 0.15, 0.5, sin(a) * 0.15), Vector3(0.25 * cos(a), a, 0.25 * sin(a)))
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.8, 1.0, 0.8)
	return _result(root, [root], shape, Vector3(0.0, 0.5, 0.0), false, true, 110.0)


static func _small(key: String, mesh: Mesh, mat: Material, scl: Vector3) -> Dictionary:
	var root := Node3D.new()
	_instance(root, mesh, mat, Vector3(0.0, 0.08, 0.0), Vector3(0.2, 0.7, 0.1), scl)
	var shape := SphereShape3D.new()
	shape.radius = 0.35
	return _result(root, [root], shape, Vector3(0.0, 0.15, 0.0), false, true, 90.0)


static func _driftwood() -> Dictionary:
	var root := Node3D.new()
	var log_mesh: Mesh = _cached("driftwood", func() -> Mesh:
		var m := CylinderMesh.new()
		m.top_radius = 0.1
		m.bottom_radius = 0.14
		m.height = 1.8
		m.radial_segments = 5
		m.rings = 1
		return m)
	_instance(root, log_mesh, material("driftwood", Color(0.68, 0.62, 0.54)), Vector3(0.0, 0.12, 0.0), Vector3(0.0, 0.0, PI / 2.0))
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 0.35, 0.4)
	return _result(root, [root], shape, Vector3(0.0, 0.15, 0.0), false, true, 110.0)


static func _rock() -> Dictionary:
	var root := Node3D.new()
	_instance(root, _sphere_mesh("boulder", 1.0, 6, 3), material("boulder", Color(0.47, 0.45, 0.43)), Vector3(0.0, 0.4, 0.0), Vector3(0.3, 0.8, 0.0), Vector3(1.6, 1.1, 1.3))
	var shape := SphereShape3D.new()
	shape.radius = 1.2
	return _result(root, [], shape, Vector3(0.0, 0.4, 0.0), true, false, 400.0)


static func _cached(key: String, maker: Callable) -> Mesh:
	if not _meshes.has(key):
		_meshes[key] = maker.call()
	return _meshes[key]


static func _sphere_mesh(key: String, radius: float, segments: int, rings: int) -> Mesh:
	return _cached(key, func() -> Mesh:
		var m := SphereMesh.new()
		m.radius = radius
		m.height = radius * 2.0
		m.radial_segments = segments
		m.rings = rings
		return m)


static func _box_mesh(key: String, size: Vector3) -> Mesh:
	return _cached(key, func() -> Mesh:
		var m := BoxMesh.new()
		m.size = size
		return m)
