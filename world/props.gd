class_name Props
extends RefCounted
## Island props built in code with organic shapes and textured materials:
## curved palms with drooping fronds, branching trees with leafy canopies,
## lumpy stones, bleached driftwood, grass tufts and berry bushes.
##
## build(kind, variant) returns:
##   root: Node3D visual · harvest: nodes hidden while depleted
##   shape + shape_position: collision · blocks: stops players walking through
##   hide_when_depleted: the whole prop disappears when picked (stones, fiber)

static var _materials := {}


## A plain coloured material, cached by key (used by structures, boats and landmarks).
static func material(key: String, color: Color) -> StandardMaterial3D:
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 1.0
		_materials[key] = m
	return _materials[key]


static func build(kind: String, variant: int = 0) -> Dictionary:
	variant = absi(variant) % 4
	match kind:
		"palm":
			return _palm(variant)
		"tree":
			return _tree(variant)
		"berry_bush":
			return _bush(variant, Color(0.30, 0.20, 0.62))
		"red_berry_bush":
			return _bush(variant, Color(0.86, 0.10, 0.12))
		"fiber":
			return _fiber(variant)
		"stone":
			return _small_rock(variant, Vector3(0.55, 0.38, 0.45), Materials.stone(Color(0.58, 0.56, 0.52)), 0.3)
		"flint":
			return _small_rock(variant + 4, Vector3(0.36, 0.2, 0.28), Materials.metal(Color(0.17, 0.17, 0.2), 0.22), 0.55)
		"driftwood":
			return _driftwood(variant)
		_:
			return _boulder(variant)


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


## A palm: a curved, ringed trunk with a crown of long drooping fronds and coconuts.
static func _palm(variant: int) -> Dictionary:
	var root := Node3D.new()
	var height := 5.8 + variant * 0.35
	var lean := 0.9 + variant * 0.25
	var points := PackedVector3Array()
	var radii := PackedFloat32Array()
	var segments := 14
	for i in segments + 1:
		var t := float(i) / segments
		points.append(Vector3(lean * t * t, t * height, 0.0))
		var ring := 1.0 + 0.08 * (1.0 if i % 2 == 0 else -1.0)
		radii.append(lerpf(0.21, 0.13, t) * ring)
	var trunk := MeshKit.tube(points, radii, 10, "palm_trunk_%d" % variant)
	_instance(root, trunk, Materials.bark(Color(0.56, 0.45, 0.32)), Vector3.ZERO)
	var top := points[segments]
	var crown := Node3D.new()
	crown.position = top
	root.add_child(crown)
	var frond_material := Materials.foliage(Color(0.28, 0.52, 0.2))
	for i in 9:
		var yaw := i * TAU / 9.0 + variant * 0.3
		var leaf := MeshKit.leaf(2.7 + (i % 3) * 0.3, 0.75, 0.55 + (i % 2) * 0.2, 10, 0.3)
		_instance(crown, leaf, frond_material, Vector3.ZERO, Vector3(-0.25 - (i % 3) * 0.12, yaw, 0.0))
	var coconuts := Node3D.new()
	crown.add_child(coconuts)
	var nut := MeshKit.rock(9, 0.06, 1.0)
	for i in 4:
		var a := i * TAU / 4.0 + 0.4
		_instance(coconuts, nut, Materials.bark(Color(0.40, 0.27, 0.14)), Vector3(cos(a) * 0.18, -0.2, sin(a) * 0.18), Vector3.ZERO, Vector3.ONE * 0.28)
	var shape := CylinderShape3D.new()
	shape.radius = 0.3
	shape.height = height
	return _result(root, [coconuts], shape, Vector3(lean * 0.3, height * 0.5, 0.0), true, false, 500.0)


## A broadleaf tree: bark trunk, a few branches, and a clumped leafy canopy.
## Chopping leaves a stump with growth rings.
static func _tree(variant: int) -> Dictionary:
	var root := Node3D.new()
	var bark := Materials.bark(Color(0.34, 0.26, 0.18))
	_instance(root, _cylinder_mesh(0.42, 0.46, 0.5), bark, Vector3(0.0, 0.25, 0.0))
	_instance(root, _cylinder_mesh(0.41, 0.41, 0.02), Materials.tree_rings(Color(0.70, 0.55, 0.36)), Vector3(0.0, 0.5, 0.0))
	var standing := Node3D.new()
	root.add_child(standing)
	_instance(standing, MeshKit.branch(variant, 5.2, 0.38, 0.16, 0.15, 9), bark, Vector3(0.0, 0.3, 0.0))
	for i in 3:
		var yaw := i * TAU / 3.0 + variant
		_instance(standing, MeshKit.branch(variant + 20 + i, 2.2, 0.12, 0.04, 0.6, 5), bark, Vector3(0.0, 2.6 + i * 0.6, 0.0), Vector3(0.0, yaw, -0.9))
	# A canopy of many smaller leafy clumps in two tones: rounder and lighter on top,
	# spreading and darker underneath, so the crown has depth instead of a lollipop ball.
	var leaves := Materials.foliage(Color(0.17, 0.40, 0.15))
	var sunlit := Materials.foliage(Color(0.24, 0.48, 0.18))
	for i in 16:
		var angle := i * 2.39996 + variant * 0.9
		var ring := 0.35 + fmod(i * 0.618, 1.0) * 1.6
		var height := 4.3 + (1.6 - ring) * 0.9 + fmod(i * 0.37, 1.0) * 0.5
		var size := lerpf(1.7, 1.05, ring / 1.95)
		var pos := Vector3(cos(angle) * ring, height, sin(angle) * ring)
		_instance(standing, MeshKit.rock(30 + (variant + i) % 8, 0.32, 0.72), sunlit if pos.y > 5.2 else leaves, pos, Vector3(0.0, i * 0.7, 0.0), Vector3.ONE * size)
	var shape := CylinderShape3D.new()
	shape.radius = 0.45
	shape.height = 4.5
	return _result(root, [standing], shape, Vector3(0.0, 2.25, 0.0), true, false, 500.0)


## A leafy bush dotted with berries.
static func _bush(variant: int, berry_color: Color) -> Dictionary:
	var root := Node3D.new()
	var leaves := Materials.foliage(Color(0.22, 0.44, 0.19))
	for i in 5:
		var a := i * TAU / 5.0 + variant
		var offset := Vector3(cos(a) * 0.35, 0.45 + (i % 2) * 0.15, sin(a) * 0.35) if i > 0 else Vector3(0.0, 0.62, 0.0)
		_instance(root, MeshKit.rock(40 + (variant + i) % 5, 0.3, 0.85), leaves, offset, Vector3(0.0, i, 0.0), Vector3.ONE * (0.95 if i == 0 else 0.7))
	var berries := Node3D.new()
	root.add_child(berries)
	var berry := SphereMesh.new()
	berry.radius = 0.045
	berry.height = 0.09
	berry.radial_segments = 8
	berry.rings = 4
	var shiny := Materials.plain(berry_color, 0.25)
	for i in 14:
		var a := i * 2.39
		var r := 0.55 + (i % 3) * 0.08
		_instance(berries, berry, shiny, Vector3(cos(a) * r, 0.35 + (i % 4) * 0.12, sin(a) * r))
	var shape := SphereShape3D.new()
	shape.radius = 0.8
	return _result(root, [berries], shape, Vector3(0.0, 0.5, 0.0), false, false, 180.0)


## A tuft of long, arching grass blades.
static func _fiber(variant: int) -> Dictionary:
	var root := Node3D.new()
	var green := Materials.foliage(Color(0.50, 0.66, 0.28))
	for i in 14:
		var yaw := i * 2.4 + variant
		var blade := MeshKit.leaf(0.95 + (i % 4) * 0.12, 0.09, 0.45 + (i % 3) * 0.15, 6, 0.0)
		_instance(root, blade, green, Vector3(cos(yaw) * 0.05, 0.0, sin(yaw) * 0.05), Vector3(-PI / 2.0 + 0.35 + (i % 3) * 0.12, yaw, 0.0))
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.9, 1.0, 0.9)
	return _result(root, [root], shape, Vector3(0.0, 0.5, 0.0), false, true, 130.0)


static func _small_rock(variant: int, size: Vector3, mat: Material, roughness: float) -> Dictionary:
	var root := Node3D.new()
	_instance(root, MeshKit.rock(variant, roughness, 0.75), mat, Vector3(0.0, size.y * 0.3, 0.0), Vector3(0.2, variant * 1.3, 0.1), size)
	var shape := SphereShape3D.new()
	shape.radius = 0.35
	return _result(root, [root], shape, Vector3(0.0, 0.15, 0.0), false, true, 110.0)


## A bleached, twisting length of driftwood with a stub of a branch.
static func _driftwood(variant: int) -> Dictionary:
	var root := Node3D.new()
	var wood := Materials.wood(Color(0.74, 0.70, 0.62))
	_instance(root, MeshKit.branch(50 + variant, 1.9, 0.13, 0.05, 0.3, 8), wood, Vector3(-0.9, 0.1, 0.0), Vector3(0.0, 0.0, -PI / 2.0 + 0.05))
	_instance(root, MeshKit.branch(60 + variant, 0.6, 0.05, 0.02, 0.4, 4), wood, Vector3(0.1, 0.12, 0.05), Vector3(0.0, 0.8, -1.1))
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.9, 0.35, 0.45)
	return _result(root, [root], shape, Vector3(0.0, 0.15, 0.0), false, true, 130.0)


static func _boulder(variant: int) -> Dictionary:
	var root := Node3D.new()
	_instance(root, MeshKit.rock(20 + variant, 0.35, 0.7), Materials.stone(Color(0.48, 0.46, 0.43)), Vector3(0.0, 0.35, 0.0), Vector3(0.2, variant * 1.7, 0.0), Vector3(2.4, 1.8, 2.0))
	var shape := SphereShape3D.new()
	shape.radius = 1.1
	return _result(root, [], shape, Vector3(0.0, 0.4, 0.0), true, false, 450.0)


static var _cylinders := {}


static func _cylinder_mesh(top: float, bottom: float, height: float) -> CylinderMesh:
	var key := "%.2f_%.2f_%.2f" % [top, bottom, height]
	if not _cylinders.has(key):
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = height
		m.radial_segments = 14
		m.rings = 1
		_cylinders[key] = m
	return _cylinders[key]
