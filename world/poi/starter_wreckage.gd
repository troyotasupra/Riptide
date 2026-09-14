class_name StarterWreckage
extends RefCounted
## What washed up with the crew on the starter island's landing beach: a split
## crate, a life ring, a torn tarp and a tangle of driftwood. Scenery only — it
## says "you washed up here" and marks the beach where the goal is in sight.

static func build(island: IslandGenerator, toward: Vector2) -> Node3D:
	var root := Node3D.new()
	root.name = "StarterWreckage"
	var shore := island.find_shore_point(toward)
	var side := toward.orthogonal()
	var base := Vector2(shore.x, shore.z) - toward * 3.0
	var yaw := atan2(-toward.x, -toward.y)
	var wood := Materials.wood(Color(0.58, 0.46, 0.32))
	var dark := Materials.wood(Color(0.36, 0.28, 0.2))

	# A split crate, lid knocked aside.
	var crate := _place(root, island, base + side * 3.5, yaw + 0.4)
	for i in 3:
		_box(crate, Vector3(0.9, 0.2, 0.04), Vector3(0.0, 0.12 + i * 0.21, 0.33), wood if i % 2 == 0 else dark)
		_box(crate, Vector3(0.04, 0.2, 0.62), Vector3(0.46, 0.12 + i * 0.21, 0.0), dark)
	_box(crate, Vector3(0.9, 0.2, 0.04), Vector3(0.0, 0.12, -0.33), wood)
	_box(crate, Vector3(0.95, 0.05, 0.66), Vector3(-0.4, 0.05, -0.8), wood, Vector3(0.1, 0.5, 0.2))

	# A life ring half buried in the sand.
	var ring := _place(root, island, base - side * 2.5 + toward * 1.2, yaw - 0.8)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.2
	torus.outer_radius = 0.34
	torus.rings = 20
	torus.ring_segments = 10
	var ring_mesh := MeshInstance3D.new()
	ring_mesh.mesh = torus
	ring_mesh.material_override = Materials.plain(Color(0.94, 0.4, 0.14), 0.55)
	ring_mesh.rotation = Vector3(0.15, 0.0, 0.1)
	ring_mesh.position.y = 0.03
	ring.add_child(ring_mesh)
	for i in 4:
		_box(ring, Vector3(0.1, 0.075, 0.075), Vector3(cos(i * TAU / 4.0) * 0.27, 0.06, sin(i * TAU / 4.0) * 0.27), Materials.plain(Color(0.93, 0.92, 0.88)), Vector3(0.0, -i * TAU / 4.0, 0.0))

	# A torn tarp snagged on the sand.
	var tarp := _place(root, island, base + side * 0.8 - toward * 2.0, yaw + 1.9)
	for i in 3:
		_box(tarp, Vector3(1.1 - i * 0.25, 0.02, 0.8 - i * 0.15), Vector3(i * 0.2, 0.02 + i * 0.03, i * 0.1), Materials.cloth(Color(0.2, 0.35, 0.55)), Vector3(0.05 * i, i * 0.4, 0.08 * i))

	# A tangle of driftwood.
	var pile := _place(root, island, base - side * 5.0 - toward * 1.0, yaw)
	var bleached := Materials.wood(Color(0.74, 0.7, 0.62))
	for i in 4:
		var branch := MeshInstance3D.new()
		branch.mesh = MeshKit.branch(150 + i, 1.6 - i * 0.2, 0.08, 0.03, 0.25, 6)
		branch.material_override = bleached
		branch.position = Vector3(-0.7, 0.08 + i * 0.05, (i - 1.5) * 0.18)
		branch.rotation = Vector3(0.0, i * 0.5, -PI / 2.0 + 0.1)
		pile.add_child(branch)
	return root


static func _place(root: Node3D, island: IslandGenerator, at: Vector2, yaw: float) -> Node3D:
	var node := Node3D.new()
	node.position = Vector3(at.x, island.height_at(at.x, at.y), at.y)
	node.rotation.y = yaw
	root.add_child(node)
	return node


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = mat
	visual.position = pos
	visual.rotation = rot
	parent.add_child(visual)
