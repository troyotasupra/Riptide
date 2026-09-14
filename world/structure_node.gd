class_name StructureNode
extends Interactable
## A placed camp structure: campfire, lean-to, tent, drying rack or storage crate.
## Its state (fuel, cooking, contents) lives in CampSystems; this is the prop,
## built from the same organic meshes and textured materials as the island props.

var structure_id := ""
var type := ""
var _fire_parts: Array[Node3D] = []
var _flames: Array[MeshInstance3D] = []
var _fire_light: OmniLight3D
var _lit := false
var _build_parts: Node3D


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
		"raft_site":
			_raft_site()
	text_provider = func(player: Node) -> String:
		if GameState.world == null or GameState.world.camp == null:
			return ""
		return GameState.world.camp.structure_prompt(structure_id, player)
	set_lit(false)


func set_lit(lit: bool) -> void:
	_lit = lit
	for part in _fire_parts:
		part.visible = lit
	set_process(lit and not _flames.is_empty())


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for i in _flames.size():
		var flicker := 1.0 + 0.18 * sin(t * (9.0 + i * 2.3) + i) + 0.08 * sin(t * 23.0 + i * 4.0)
		_flames[i].scale = Vector3(1.0 / sqrt(flicker), flicker, 1.0 / sqrt(flicker))
		_flames[i].rotation.y = t * (0.6 + i * 0.3)
	if _fire_light != null:
		_fire_light.light_energy = 1.7 + 0.35 * sin(t * 13.0) + 0.2 * sin(t * 31.0)


# --- helpers --------------------------------------------------------------------

func _mesh(mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = mat
	visual.position = pos
	visual.rotation = rot
	visual.scale = scl
	add_child(visual)
	return visual


func _collider(shape: Shape3D, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = pos
	collider.rotation = rot
	add_child(collider)


## A straight-ish pole from `a` to `b` (a crooked branch, not a dowel).
func _pole(a: Vector3, b: Vector3, radius: float, variant: int, mat: Material) -> void:
	var along := b - a
	var length := along.length()
	var branch := MeshKit.branch(variant, length, radius, radius * 0.7, 0.04, 6)
	var y := along / length
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var visual := MeshInstance3D.new()
	visual.mesh = branch
	visual.material_override = mat
	visual.transform = Transform3D(Basis(x, y, x.cross(y)), a)
	add_child(visual)


## A cord from `a` to `b`.
func _cord(a: Vector3, b: Vector3, radius: float = 0.012) -> void:
	var points := PackedVector3Array([a, a.lerp(b, 0.5) + Vector3.DOWN * a.distance_to(b) * 0.04, b])
	_mesh(MeshKit.tube(points, PackedFloat32Array([radius, radius, radius]), 5), Materials.cloth(Color(0.72, 0.62, 0.45)), Vector3.ZERO)


## A sagging cloth sheet through four corners (a b along the top, d c along the bottom).
func _sheet(a: Vector3, b: Vector3, c: Vector3, d: Vector3, sag: float, mat: Material) -> MeshInstance3D:
	var columns := 10
	var rows := 8
	var vertices := PackedVector3Array()
	var normal := (b - a).cross(d - a).normalized()
	for r in rows + 1:
		var v := float(r) / rows
		for col in columns + 1:
			var u := float(col) / columns
			var p := a.lerp(b, u).lerp(d.lerp(c, u), v)
			vertices.append(p - normal * sag * sin(PI * u) * sin(PI * v))
	var indices := PackedInt32Array()
	for r in rows:
		for col in columns:
			var i := r * (columns + 1) + col
			var j := i + columns + 1
			indices.append_array([i, j, i + 1, i + 1, j, j + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	return _mesh(MeshKit._with_normals(arrays), mat, Vector3.ZERO)


static func _double_sided(mat: StandardMaterial3D) -> StandardMaterial3D:
	var copy: StandardMaterial3D = mat.duplicate()
	copy.cull_mode = BaseMaterial3D.CULL_DISABLED
	return copy


# --- structures -------------------------------------------------------------------

func _campfire() -> void:
	var stone := Materials.stone(Color(0.52, 0.50, 0.47))
	for i in 9:
		var a := i * TAU / 9.0
		var size := Vector3(0.3, 0.2, 0.26) * (0.85 + 0.3 * absf(sin(i * 3.7)))
		_mesh(MeshKit.rock(60 + i % 6, 0.3, 0.7), stone, Vector3(cos(a) * 0.62, 0.07, sin(a) * 0.62), Vector3(0.0, a * 1.7, 0.1), size)
	var ash := MeshKit.rock(70, 0.1, 0.25)
	_mesh(ash, Materials.stone(Color(0.16, 0.14, 0.13)), Vector3(0.0, 0.0, 0.0), Vector3.ZERO, Vector3(1.0, 0.25, 1.0))
	var bark := Materials.bark(Color(0.34, 0.25, 0.17))
	for i in 5:
		var a := i * TAU / 5.0 + 0.3
		var foot := Vector3(cos(a) * 0.42, 0.02, sin(a) * 0.42)
		_pole(foot, Vector3(cos(a + 0.5) * 0.05, 0.42, sin(a + 0.5) * 0.05), 0.05, 80 + i, bark)
	var shape := CylinderShape3D.new()
	shape.radius = 0.75
	shape.height = 0.5
	_collider(shape, Vector3(0.0, 0.25, 0.0))
	# Flames: layered glowing tongues that flicker, embers, and a warm light.
	var colors := [Color(1.0, 0.35, 0.08), Color(1.0, 0.6, 0.15), Color(1.0, 0.85, 0.45)]
	for i in 3:
		var tongue := MeshKit.leaf(0.75 - i * 0.18, 0.5 - i * 0.12, -0.05, 6, 1.4)
		for k in 3:
			var flame := _mesh(tongue, _double_sided(Materials.glow(colors[i], 3.0 + i)), Vector3(0.0, 0.08 + i * 0.02, 0.0), Vector3(-PI / 2.0, k * TAU / 3.0 + i, 0.0))
			_fire_parts.append(flame)
			_flames.append(flame)
	var embers := _mesh(MeshKit.rock(71, 0.4, 0.4), Materials.glow(Color(1.0, 0.3, 0.05), 2.5), Vector3(0.0, 0.05, 0.0), Vector3.ZERO, Vector3(0.45, 0.2, 0.45))
	_fire_parts.append(embers)
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color(1.0, 0.6, 0.25)
	_fire_light.light_energy = 1.8
	_fire_light.omni_range = 8.0
	_fire_light.shadow_enabled = true
	_fire_light.position.y = 0.8
	add_child(_fire_light)
	_fire_parts.append(_fire_light)


func _lean_to() -> void:
	var bark := Materials.bark(Color(0.40, 0.30, 0.20))
	for x: float in [-1.1, 1.1]:
		_pole(Vector3(x, -0.05, -0.9), Vector3(x * 1.02, 1.95, -0.92), 0.05, 90 + int(x), bark)
		_pole(Vector3(x, -0.05, 0.95), Vector3(x, 0.25, 0.9), 0.03, 92 + int(x), bark)
	_pole(Vector3(-1.3, 1.9, -0.9), Vector3(1.3, 1.9, -0.9), 0.045, 94, bark)
	var tarp := _double_sided(Materials.cloth(Color(0.20, 0.36, 0.56)))
	_sheet(Vector3(-1.25, 1.92, -0.95), Vector3(1.25, 1.92, -0.95), Vector3(1.25, 0.2, 1.0), Vector3(-1.25, 0.2, 1.0), 0.12, tarp)
	for x: float in [-1.2, 1.2]:
		_cord(Vector3(x, 0.2, 1.0), Vector3(x * 1.05, 0.0, 1.25))
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.5, 0.05, 2.5)
	_collider(shape, Vector3(0.0, 1.05, 0.0), Vector3(-0.75, 0.0, 0.0))


func _tent() -> void:
	var canvas := _double_sided(Materials.cloth(Color(0.36, 0.45, 0.30)))
	var ridge := 1.4
	for s: float in [-1.0, 1.0]:
		_sheet(Vector3(0.0, ridge, -1.2), Vector3(0.0, ridge, 1.2), Vector3(s * 1.0, 0.02, 1.2), Vector3(s * 1.0, 0.02, -1.2), 0.06, canvas)
	var back := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-1.0, 0.02, -1.2), Vector3(0.0, ridge, -1.2), Vector3(1.0, 0.02, -1.2)])
	back.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh(back, canvas, Vector3.ZERO)
	var wood := Materials.wood(Color(0.55, 0.42, 0.28))
	for z: float in [-1.25, 1.25]:
		_pole(Vector3(0.0, 0.0, z), Vector3(0.0, ridge + 0.12, z), 0.03, 96, wood)
		_cord(Vector3(0.0, ridge + 0.08, z), Vector3(0.0, 0.0, z + signf(z) * 0.9))
	for s: float in [-1.0, 1.0]:
		for z: float in [-1.1, 0.0, 1.1]:
			_pole(Vector3(s * 1.08, -0.1, z), Vector3(s * 1.1, 0.12, z), 0.015, 98, wood)
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 1.3, 2.4)
	_collider(shape, Vector3(0.0, 0.65, 0.0))


func _drying_rack() -> void:
	var bark := Materials.bark(Color(0.42, 0.32, 0.22))
	for x: float in [-0.75, 0.75]:
		_pole(Vector3(x - 0.2, -0.05, -0.25), Vector3(x + 0.05, 1.45, 0.0), 0.04, 100 + int(x * 10), bark)
		_pole(Vector3(x + 0.2, -0.05, 0.25), Vector3(x - 0.05, 1.45, 0.0), 0.04, 104 + int(x * 10), bark)
		var post := CylinderShape3D.new()
		post.radius = 0.08
		post.height = 1.4
		_collider(post, Vector3(x, 0.7, 0.0))
	for y: float in [0.65, 0.95, 1.25]:
		_pole(Vector3(-0.95, y, 0.0), Vector3(0.95, y + 0.02, 0.0), 0.025, 110 + int(y * 10), bark)
	for x: float in [-0.75, 0.75]:
		for y: float in [0.65, 0.95, 1.25]:
			_mesh(MeshKit.rock(120, 0.05, 1.0), Materials.cloth(Color(0.7, 0.6, 0.42)), Vector3(x, y, 0.0), Vector3.ZERO, Vector3.ONE * 0.07)


## A finished raft is pushed into the water by holding E.
func hold_seconds(_player: Node) -> float:
	if StructureTable.is_build_site(type) and GameState.world != null:
		var entry: Dictionary = GameState.world.camp.structures.get(structure_id, {})
		if StructureTable.next_stage(type, entry.get("progress", {})).is_empty():
			return 2.0
	return 0.0


## The raft build site: log rollers and a pole frame on the sand. Logs appear as
## they're added, then the rope lashings.
func _raft_site() -> void:
	var bark := Materials.bark(Color(0.42, 0.32, 0.22))
	for z: float in [-1.2, 1.2]:
		_pole(Vector3(-1.6, 0.1, z), Vector3(1.6, 0.1, z + 0.05), 0.11, 130 + int(z), bark)
	for x: float in [-1.35, 1.35]:
		_pole(Vector3(x, 0.24, -1.75), Vector3(x + 0.03, 0.24, 1.75), 0.05, 134 + int(x), bark)
	for corner: Vector3 in [Vector3(-1.7, 0.0, -1.5), Vector3(1.7, 0.0, -1.5), Vector3(-1.7, 0.0, 1.5), Vector3(1.7, 0.0, 1.5)]:
		_pole(corner - Vector3(0.0, 0.15, 0.0), corner + Vector3(0.0, 0.45, 0.0), 0.03, 140, bark)
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 0.5, 3.6)
	_collider(shape, Vector3(0.0, 0.25, 0.0))
	set_progress({})


func set_progress(progress: Dictionary) -> void:
	if not StructureTable.is_build_site(type):
		return
	if _build_parts != null:
		_build_parts.queue_free()
	_build_parts = Node3D.new()
	add_child(_build_parts)
	var bark := Materials.bark(Color(0.46, 0.34, 0.22))
	var logs := mini(int(progress.get("log", 0)), 6)
	for i in logs:
		var points := PackedVector3Array()
		var radii := PackedFloat32Array()
		for k in 7:
			var t := k / 6.0
			points.append(Vector3(0.02 * sin(t * PI + i), 0.0, (t - 0.5) * 3.3))
			radii.append(0.21 * (0.96 + 0.05 * sin(t * 17.0 + i)))
		var log_visual := MeshInstance3D.new()
		log_visual.mesh = MeshKit.tube(points, radii, 10, "site_log_%d" % (i % 3))
		log_visual.material_override = bark
		log_visual.position = Vector3(-1.1 + i * 0.44, 0.5, 0.0)
		_build_parts.add_child(log_visual)
	var lashings := mini(int(progress.get("rope", 0)), 3)
	for k in lashings:
		var band := BoxMesh.new()
		band.size = Vector3(2.75, 0.05, 0.09)
		var lashing := MeshInstance3D.new()
		lashing.mesh = band
		lashing.material_override = Materials.cloth(Color(0.72, 0.62, 0.45))
		lashing.position = Vector3(0.0, 0.72, -1.2 + k * 1.2)
		_build_parts.add_child(lashing)


func _crate() -> void:
	var wood := Materials.wood(Color(0.58, 0.43, 0.27))
	var dark := Materials.wood(Color(0.36, 0.26, 0.16))
	var iron := Materials.metal(Color(0.2, 0.2, 0.21), 0.5)
	for y: int in 3:
		for side: float in [-1.0, 1.0]:
			var plank := BoxMesh.new()
			plank.size = Vector3(1.0, 0.21, 0.04)
			_mesh(plank, wood if (y + int(side)) % 2 == 0 else dark, Vector3(0.0, 0.12 + y * 0.225, side * 0.33))
			var end := BoxMesh.new()
			end.size = Vector3(0.04, 0.21, 0.62)
			_mesh(end, dark if y % 2 == 0 else wood, Vector3(side * 0.48, 0.12 + y * 0.225, 0.0))
	var lid := BoxMesh.new()
	lid.size = Vector3(1.04, 0.07, 0.72)
	_mesh(lid, wood, Vector3(0.0, 0.7, 0.0))
	for x: float in [-0.44, 0.44]:
		var band := BoxMesh.new()
		band.size = Vector3(0.06, 0.74, 0.74)
		_mesh(band, iron, Vector3(x, 0.36, 0.0))
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 0.7, 0.7)
	_collider(shape, Vector3(0.0, 0.35, 0.0))
