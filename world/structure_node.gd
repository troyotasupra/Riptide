class_name StructureNode
extends Interactable
## A placed camp structure: campfire, lean-to, tent, drying rack or storage crate.
## Its state (fuel, cooking, contents) lives in CampSystems; this is the prop,
## built from the same organic meshes and textured materials as the island props.

var structure_id := ""
var type := ""
var _fire: FireFx
var _lit := false
var _build_parts: Node3D
var _progress := {}
var _part_colliders: Array[CollisionShape3D] = []


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
		"compost_bin":
			_compost_bin()
		"storage_crate":
			_crate()
		"raft_site":
			_raft_site()
	if StructureTable.is_build_site(type) and type != "raft_site":
		set_progress({})
	text_provider = func(player: Node) -> String:
		if GameState.world == null or GameState.world.camp == null:
			return ""
		return GameState.world.camp.structure_prompt(structure_id, player)
	if type == "tent":
		_tent_inside()
	set_lit(false)


## The inside of the tent, for the crosshair only: look in through the open door
## and it's the tent you're looking at (to sleep in it), though you walk straight in.
func _tent_inside() -> void:
	var inside := Interactable.new()
	inside.name = "Inside"
	inside.interact_id = interact_id
	inside.text_provider = text_provider
	inside.collision_layer = Layers.INTERACT
	inside.collision_mask = 0
	var box := BoxShape3D.new()
	box.size = Vector3(TENT_HALF_WIDTH * 1.4, TENT_RIDGE * 0.8, TENT_HALF_LENGTH * 2.0)
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = Vector3(0.0, TENT_RIDGE * 0.4, 0.0)
	inside.add_child(shape)
	add_child(inside)


## Flames over the whole thing while it burns down.
func set_burning(on: bool) -> void:
	var blaze: FireFx = get_node_or_null("Blaze")
	if on and blaze == null:
		blaze = FireFx.new()
		blaze.name = "Blaze"
		blaze.size = clampf(float(StructureTable.get_type(type).get("footprint", 1.0)) * 0.7, 0.6, 1.6)
		blaze.shadows = false
		blaze.position.y = 0.2
		add_child(blaze)
	elif not on and blaze != null:
		blaze.queue_free()


func set_lit(lit: bool) -> void:
	_lit = lit
	if _fire != null:
		_fire.set_intensity(1.0 if lit else 0.0)


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
	_mesh(MeshKit.tube(points, PackedFloat32Array([radius, radius, radius]), 5), Materials.rope(Color(0.72, 0.62, 0.45)), Vector3.ZERO)


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


## Pieces that come and go with build progress live under _build_parts.
func _part(mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var visual := _mesh(mesh, mat, pos, rot, scl)
	visual.reparent(_build_parts, false)
	return visual


func _part_node(node: Node3D) -> void:
	node.reparent(_build_parts, false)


func _part_pole(a: Vector3, b: Vector3, radius: float, variant: int, mat: Material) -> void:
	_pole(a, b, radius, variant, mat)
	get_child(get_child_count() - 1).reparent(_build_parts, false)


func _part_cord(a: Vector3, b: Vector3) -> void:
	_cord(a, b)
	get_child(get_child_count() - 1).reparent(_build_parts, false)


## Colliders have to sit directly under the body, so the ones that come with
## build progress are tracked and cleared along with the parts.
func _part_collider(shape: Shape3D, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = pos
	collider.rotation = rot
	add_child(collider)
	_part_colliders.append(collider)


func _triangle(a: Vector3, b: Vector3, c: Vector3, mat: Material) -> MeshInstance3D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([a, b, c])
	var normal := (c - a).cross(b - a).normalized()
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([normal, normal, normal])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _mesh(mesh, mat, Vector3.ZERO)


# --- structures -------------------------------------------------------------------

## The fire ring: the kit is a few stones on a bed of ash; the rest of the ring
## and the wood go on as they're added, and it burns with particle flames.
func _campfire() -> void:
	var ash := MeshKit.rock(70, 0.1, 0.25)
	_mesh(ash, Materials.stone(Color(0.16, 0.14, 0.13)), Vector3(0.0, 0.0, 0.0), Vector3.ZERO, Vector3(1.0, 0.25, 1.0))
	var shape := CylinderShape3D.new()
	shape.radius = 0.75
	shape.height = 0.5
	_collider(shape, Vector3(0.0, 0.25, 0.0))
	_fire = FireFx.new()
	_fire.size = 0.45
	_fire.position.y = 0.1
	_fire.intensity = 0.0
	add_child(_fire)


func _campfire_progress(progress: Dictionary) -> void:
	var stone := Materials.stone(Color(0.52, 0.50, 0.47))
	var stones := 3 + int(round(6.0 * mini(int(progress.get("stone", 0)), 4) / 4.0))
	for i in stones:
		var a := i * TAU / 9.0
		var size := Vector3(0.3, 0.2, 0.26) * (0.85 + 0.3 * absf(sin(i * 3.7)))
		_part(MeshKit.rock(60 + i % 6, 0.3, 0.7), stone, Vector3(cos(a) * 0.62, 0.07, sin(a) * 0.62), Vector3(0.0, a * 1.7, 0.1), size)
	var bark := Materials.bark(Color(0.34, 0.25, 0.17))
	var logs := int(round(5.0 * mini(int(progress.get("wood", 0)), 3) / 3.0))
	for i in logs:
		var a := i * TAU / 5.0 + 0.3
		var foot := Vector3(cos(a) * 0.42, 0.02, sin(a) * 0.42)
		_part_pole(foot, Vector3(cos(a + 0.5) * 0.05, 0.42, sin(a + 0.5) * 0.05), 0.05, 80 + i, bark)


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


## A ridge tent. The frame (the kit) is two A-frames and a ridge pole; the canvas
## goes over it (two sagging sides, a closed back, door flaps tied open and a
## groundsheet), then the guy lines and stakes that hold it taut.
const TENT_RIDGE := 1.45
const TENT_HALF_WIDTH := 1.05
const TENT_HALF_LENGTH := 1.2


func _tent() -> void:
	var wood := Materials.wood(Color(0.55, 0.42, 0.28))
	for z: float in [-TENT_HALF_LENGTH - 0.03, TENT_HALF_LENGTH + 0.03]:
		for side: float in [-1.0, 1.0]:
			# The poles are footed a little into the ground, not sat on top of it.
			_pole(Vector3(side * (TENT_HALF_WIDTH + 0.02), -0.12, z), Vector3(0.0, TENT_RIDGE + 0.1, z), 0.028, 96 + int(side), wood)
	_pole(Vector3(0.0, TENT_RIDGE + 0.04, -TENT_HALF_LENGTH - 0.15), Vector3(0.0, TENT_RIDGE + 0.04, TENT_HALF_LENGTH + 0.15), 0.03, 97, wood)


func _tent_progress(progress: Dictionary) -> void:
	var worn := structure_id.begins_with("castaway")
	var canvas_color := Color(0.5, 0.47, 0.34) if worn else Color(0.44, 0.45, 0.27)
	var canvas := _double_sided(Materials.cloth(canvas_color))
	var r := TENT_RIDGE
	var w := TENT_HALF_WIDTH
	var l := TENT_HALF_LENGTH
	# The canvas carries on below the ground line, so on uneven ground the tent
	# never stands on stilts with daylight under its walls.
	var skirt := -0.28
	if int(progress.get("tarp", 0)) >= 1:
		for side: float in [-1.0, 1.0]:
			_part_node(_sheet(Vector3(0.0, r, -l), Vector3(0.0, r, l), Vector3(side * w, skirt, l), Vector3(side * w, skirt, -l), 0.05 * side, canvas))
		# Closed back wall.
		_part_node(_triangle(Vector3(-w, skirt, -l), Vector3(0.0, r, -l), Vector3(w, skirt, -l), canvas))
		# Door flaps, rolled back and tied either side of the opening.
		for side: float in [-1.0, 1.0]:
			_part_node(_triangle(Vector3(0.0, r, l), Vector3(side * w, skirt, l), Vector3(side * w * 0.55, skirt, l + 0.02), canvas))
			var roll := MeshKit.tube(PackedVector3Array([Vector3(side * w * 0.57, 0.05, l + 0.05), Vector3(side * w * 0.3, r * 0.52, l + 0.05), Vector3(side * 0.06, r - 0.05, l + 0.05)]),
				PackedFloat32Array([0.05, 0.045, 0.03]), 6)
			_part(roll, canvas, Vector3.ZERO)
		# The groundsheet is laid a touch under the sod and reaches the walls, so
		# no strip of bare ground shows inside.
		var ground := BoxMesh.new()
		ground.size = Vector3(w * 2.0, 0.05, l * 2.0 + 0.04)
		_part(ground, Materials.cloth(Color(0.22, 0.24, 0.2)), Vector3(0.0, -0.012, 0.0))
		if worn:
			# Faded, and patched with whatever the castaway had.
			var patch := _double_sided(Materials.cloth(Color(0.55, 0.44, 0.30)))
			_part_node(_sheet(Vector3(0.5, r * 0.53 + 0.012, -0.35), Vector3(0.5, r * 0.53 + 0.012, 0.15), Vector3(0.78, r * 0.26 + 0.012, 0.15), Vector3(0.78, r * 0.26 + 0.012, -0.35), 0.0, patch))
		# Canvas walls to bump into; the door stays open so you can crawl in.
		for side: float in [-1.0, 1.0]:
			var slab := BoxShape3D.new()
			slab.size = Vector3(0.06, sqrt(w * w + r * r), l * 2.0)
			_part_collider(slab, Vector3(side * w * 0.5, r * 0.5, 0.0), Vector3(0.0, 0.0, side * atan2(w, r)))
		var back := BoxShape3D.new()
		back.size = Vector3(w * 2.0, r, 0.06)
		_part_collider(back, Vector3(0.0, r * 0.5, -l))
	var ropes := int(progress.get("rope", 0))
	var lines: Array = [[Vector3(0.0, r + 0.08, -l - 0.15), Vector3(0.0, 0.0, -l - 1.0)],
		[Vector3(0.0, r + 0.08, l + 0.15), Vector3(0.0, 0.0, l + 1.0)]]
	for side: float in [-1.0, 1.0]:
		for z: float in [-0.9, 0.9]:
			lines.append([Vector3(side * w * 0.55, r * 0.45, z), Vector3(side * (w + 0.8), 0.0, z * 1.15)])
	var shown := int(round(lines.size() * mini(ropes, 3) / 3.0))
	var wood := Materials.wood(Color(0.55, 0.42, 0.28))
	for i in shown:
		var line: Array = lines[i]
		_part_cord(line[0], line[1] + Vector3.UP * 0.1)
		_part_pole(line[1] - Vector3(0.0, 0.08, 0.0), line[1] + Vector3(0.0, 0.14, 0.0), 0.018, 98, wood)


## A slatted wooden bin with a heap of dark compost showing over the top.
func _compost_bin() -> void:
	var wood := Materials.wood(Color(0.5, 0.39, 0.27))
	for side: float in [-1.0, 1.0]:
		for i in 4:
			_mesh(_box_mesh(Vector3(0.9, 0.12, 0.04)), wood, Vector3(0.0, 0.1 + i * 0.16, side * 0.45))
			_mesh(_box_mesh(Vector3(0.04, 0.12, 0.9)), wood, Vector3(side * 0.45, 0.1 + i * 0.16, 0.0))
	for x: float in [-0.45, 0.45]:
		for z: float in [-0.45, 0.45]:
			_pole(Vector3(x, -0.05, z), Vector3(x, 0.72, z), 0.035, 130 + int(x * 10 + z * 5), wood)
	_mesh(MeshKit.rock(131, 0.25, 0.8), Materials.stone(Color(0.16, 0.12, 0.09)), Vector3(0.0, 0.5, 0.0), Vector3.ZERO, Vector3(0.82, 0.35, 0.82))
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.95, 0.7, 0.95)
	_collider(shape, Vector3(0.0, 0.35, 0.0))


static func _box_mesh(size: Vector3) -> BoxMesh:
	var box := BoxMesh.new()
	box.size = size
	return box


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
	if StructureTable.get_type(type).has("launches") and GameState.world != null:
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
	_progress = progress
	for collider in _part_colliders:
		collider.queue_free()
	_part_colliders.clear()
	if _build_parts != null:
		_build_parts.queue_free()
	_build_parts = Node3D.new()
	add_child(_build_parts)
	match type:
		"campfire":
			_campfire_progress(progress)
			return
		"tent":
			_tent_progress(progress)
			return
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
	# Each rope added is another lashing wrapped round every log.
	var lashings := mini(int(progress.get("rope", 0)), 3)
	var xs := PackedFloat32Array()
	for i in logs:
		xs.append(-1.1 + i * 0.44)
	for k in (lashings if logs > 0 else 0):
		_build_parts.add_child(MeshKit.lash(xs, 0.21, 0.5, -1.2 + k * 1.2, Materials.rope(Color(0.72, 0.62, 0.45))))


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
