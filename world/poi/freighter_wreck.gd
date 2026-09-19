class_name FreighterWreck
extends RefCounted
## A small coastal freighter that ran aground on the sandbar in the middle of the
## reef, on the far side of the camp island: bow driven up onto the bar, stern
## settled, listing to port. Her deck is out of the water; a fallen gangway on
## the low side lets a swimmer or someone in a boat climb aboard. On the aft
## deck, by the wheelhouse, are the fuel drums the john boat's outboard needs
## (pickups, CampSystems.WRECK_DRUMS). Salvaging the ship itself comes later.
##
## Ship space: bow toward -Z, the wheelhouse aft (+Z); y = 0 at the keel.

const LENGTH := 28.0
const BEAM := 7.0
const DEPTH := 4.6
## How she lies: bow up, stern down, rolled onto her port side.
const PITCH := -0.06
const ROLL := 0.2
const STATIONS := 24
const SECTION := 10

const HULL := Color(0.12, 0.16, 0.22)
const BOOT := Color(0.42, 0.12, 0.09)
const RUST := Color(0.36, 0.2, 0.12)
const DECK := Color(0.3, 0.29, 0.27)
const WHITE := Color(0.78, 0.77, 0.72)


static func transform(shape: CampIsland) -> Transform3D:
	var p := shape.shipwreck
	var yaw := CampIslandPois.yaw_toward(p, shape.center) + 1.2
	var keel := shape.height_at(p.x, p.y) - 0.6
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PITCH) * Basis(Vector3.FORWARD, ROLL)
	return Transform3D(basis, Vector3(p.x, keel, p.y))


## Where the drums stand on the aft deck (ship space).
static func drum_spots() -> Array[Vector3]:
	var spots: Array[Vector3] = []
	for i in 5:
		spots.append(Vector3(-1.6 + (i % 3) * 0.75, DEPTH + 0.02, 5.2 + int(i / 3) * 0.75))
	return spots


static func build(shape: CampIsland) -> Node3D:
	var node := Node3D.new()
	node.name = "FreighterWreck"
	node.transform = transform(shape)
	var hull_paint := Materials.metal(HULL, 0.7)
	var boot := Materials.metal(BOOT, 0.8)
	var rust := Materials.metal(RUST, 0.9)
	var deck := Materials.metal(DECK, 0.85)
	var white := Materials.metal(WHITE, 0.7)
	_hull(node, hull_paint, boot)
	_deck(node, deck)
	_wheelhouse(node, white, rust)
	_rigging(node, rust, white)
	_gangway(node, rust)
	# Streaks of rust down her side, and a gash in the bow where she struck.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("wreck:%d" % shape.island_seed)
	for i in 14:
		var z := rng.randf_range(-LENGTH * 0.4, LENGTH * 0.4)
		var side := -1.0 if i % 2 == 0 else 1.0
		var streak := BoxMesh.new()
		streak.size = Vector3(0.02, rng.randf_range(0.8, 2.4), rng.randf_range(0.15, 0.4))
		var visual := MeshInstance3D.new()
		visual.mesh = streak
		visual.material_override = rust
		visual.position = Vector3(side * (_half_width(z) + 0.012), DEPTH - streak.size.y * 0.5 - 0.1, z)
		node.add_child(visual)
	var gash := MeshInstance3D.new()
	gash.mesh = MeshKit.rock(170, 0.3, 0.5)
	gash.material_override = Materials.plain(Color(0.03, 0.03, 0.03))
	gash.position = Vector3(-_half_width(-LENGTH * 0.38) + 0.1, 1.2, -LENGTH * 0.38)
	gash.scale = Vector3(0.4, 1.2, 2.4)
	node.add_child(gash)
	return node


## Half the beam at `z`: full amidships, drawn in to a sharp stem at the bow and
## a little at the stern.
static func _half_width(z: float) -> float:
	var t := (z + LENGTH * 0.5) / LENGTH  # 0 bow .. 1 stern
	var bow := smoothstep(0.0, 0.3, t)
	var stern := 1.0 - 0.12 * smoothstep(0.85, 1.0, t)
	return BEAM * 0.5 * maxf(0.04, sqrt(bow)) * stern


## The hull: sections from bow to stern, flat-bottomed with rounded bilges; dark
## paint above the waterline, red anti-fouling below. Solid for walking into.
static func _hull(node: Node3D, paint: Material, boot: Material) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var rows: Array = []
	for i in STATIONS + 1:
		var z := -LENGTH * 0.5 + LENGTH * i / STATIONS
		var w := _half_width(z)
		# The bow's forefoot rises: less hull under the waterline forward.
		var bottom := 0.9 * (1.0 - smoothstep(0.0, 0.25, (z + LENGTH * 0.5) / LENGTH))
		var row: Array[Vector3] = []
		for k in SECTION + 1:
			# Round from the port deck edge, down and across the bottom, up to starboard.
			var a := PI * float(k) / SECTION
			var x := -cos(a) * w
			var bilge := sin(a)
			var y := DEPTH - (DEPTH - bottom) * pow(bilge, 0.25)
			row.append(Vector3(x, y, z))
		rows.append(row)
	var colors := [paint, boot]
	for part in 2:
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in STATIONS:
			for k in SECTION:
				var quad: Array[Vector3] = [rows[i][k], rows[i][k + 1], rows[i + 1][k + 1], rows[i + 1][k]]
				var low := (quad[0].y + quad[2].y) * 0.5 < 1.7
				if low != (part == 1):
					continue
				for index: int in [0, 2, 1, 0, 3, 2]:
					tool.add_vertex(quad[index])
					if part == 0 or true:
						faces.append(quad[index])
		tool.generate_normals()
		var visual := MeshInstance3D.new()
		visual.mesh = tool.commit()
		visual.material_override = colors[part]
		node.add_child(visual)
	# The transom closing the stern.
	var stern: Array = rows[STATIONS]
	var cap := SurfaceTool.new()
	cap.begin(Mesh.PRIMITIVE_TRIANGLES)
	var middle := Vector3(0.0, DEPTH * 0.6, LENGTH * 0.5)
	for k in SECTION:
		for v: Vector3 in [middle, stern[k + 1], stern[k]]:
			cap.add_vertex(v)
			faces.append(v)
	cap.generate_normals()
	var transom := MeshInstance3D.new()
	transom.mesh = cap.commit()
	transom.material_override = paint
	node.add_child(transom)
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var hull_shape := ConcavePolygonShape3D.new()
	hull_shape.backface_collision = true
	hull_shape.set_faces(faces)
	var collider := CollisionShape3D.new()
	collider.shape = hull_shape
	body.add_child(collider)
	node.add_child(body)


## The main deck, a low bulwark round it, and the cargo hatch forward.
static func _deck(node: Node3D, deck: Material) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	for i in STATIONS:
		var z0 := -LENGTH * 0.5 + LENGTH * i / STATIONS
		var z1 := -LENGTH * 0.5 + LENGTH * (i + 1) / STATIONS
		var quad := [Vector3(-_half_width(z0), DEPTH, z0), Vector3(_half_width(z0), DEPTH, z0), Vector3(_half_width(z1), DEPTH, z1), Vector3(-_half_width(z1), DEPTH, z1)]
		for index: int in [0, 1, 2, 0, 2, 3]:
			tool.add_vertex(quad[index])
			faces.append(quad[index])
	tool.generate_normals()
	var visual := MeshInstance3D.new()
	visual.mesh = tool.commit()
	visual.material_override = deck
	node.add_child(visual)
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	node.add_child(body)
	# Bulwarks: a knee-high steel lip along both sides.
	for i in STATIONS:
		var z0 := -LENGTH * 0.5 + LENGTH * i / STATIONS
		var z1 := -LENGTH * 0.5 + LENGTH * (i + 1) / STATIONS
		for side: float in [-1.0, 1.0]:
			var a := Vector3(side * _half_width(z0), DEPTH, z0)
			var b := Vector3(side * _half_width(z1), DEPTH, z1)
			var box := BoxMesh.new()
			box.size = Vector3(0.06, 0.45, a.distance_to(b) + 0.02)
			var lip := MeshInstance3D.new()
			lip.mesh = box
			lip.material_override = Materials.metal(HULL, 0.7)
			lip.transform = Transform3D(Basis.looking_at((b - a).normalized(), Vector3.UP), (a + b) * 0.5 + Vector3.UP * 0.22)
			node.add_child(lip)
	# The cargo hatch: a raised coaming with its lid askew.
	_box(node, Vector3(3.6, 0.5, 6.0), Vector3(0.0, DEPTH + 0.25, -4.0), Materials.metal(RUST, 0.9), true)
	_box(node, Vector3(3.3, 0.12, 2.8), Vector3(0.4, DEPTH + 0.56, -5.3), Materials.metal(DECK.darkened(0.2), 0.8), true, Vector3(0.0, 0.15, 0.08))


## The wheelhouse aft: two decks of white steel, dark windows, a funnel behind.
static func _wheelhouse(node: Node3D, white: Material, rust: Material) -> void:
	var glass := Materials.plain(Color(0.05, 0.07, 0.08), 0.1)
	_box(node, Vector3(5.2, 2.4, 4.0), Vector3(0.0, DEPTH + 1.2, 10.6), white, true)
	_box(node, Vector3(4.2, 1.8, 3.0), Vector3(0.0, DEPTH + 3.3, 10.8), white, true)
	for x in 5:
		_box(node, Vector3(0.6, 0.7, 0.03), Vector3(-1.6 + x * 0.8, DEPTH + 3.5, 9.29), glass)
	for side: float in [-1.0, 1.0]:
		_box(node, Vector3(0.03, 0.6, 0.8), Vector3(side * 2.61, DEPTH + 1.5, 10.0), glass)
		_box(node, Vector3(0.03, 0.6, 0.8), Vector3(side * 2.61, DEPTH + 1.5, 11.3), glass)
	# A doorway into the lower deckhouse (dark), facing forward onto the drums.
	_box(node, Vector3(0.9, 1.9, 0.04), Vector3(1.4, DEPTH + 0.95, 8.59), glass)
	_box(node, Vector3(5.6, 0.12, 4.4), Vector3(0.0, DEPTH + 2.46, 10.6), white)
	var funnel := CylinderMesh.new()
	funnel.top_radius = 0.55
	funnel.bottom_radius = 0.6
	funnel.height = 2.4
	var stack := MeshInstance3D.new()
	stack.mesh = funnel
	stack.material_override = rust
	stack.position = Vector3(0.0, DEPTH + 4.6, 12.3)
	node.add_child(stack)


## A mast forward with a derrick boom, stays, and railings on the wheelhouse top.
static func _rigging(node: Node3D, rust: Material, white: Material) -> void:
	var mast := MeshInstance3D.new()
	mast.mesh = MeshKit.tube(PackedVector3Array([Vector3(0.0, DEPTH, -8.0), Vector3(0.0, DEPTH + 8.0, -8.0)]), PackedFloat32Array([0.16, 0.11]), 8, "wreck_mast")
	mast.material_override = rust
	node.add_child(mast)
	var boom := MeshInstance3D.new()
	boom.mesh = MeshKit.tube(PackedVector3Array([Vector3(0.0, DEPTH + 1.2, -7.6), Vector3(1.4, DEPTH + 3.0, -3.0)]), PackedFloat32Array([0.1, 0.07]), 6, "wreck_boom")
	boom.material_override = rust
	node.add_child(boom)
	for end: Vector3 in [Vector3(-3.0, DEPTH + 0.4, -12.0), Vector3(0.0, DEPTH + 2.5, 9.0), Vector3(3.2, DEPTH + 0.4, -6.0)]:
		var stay := MeshInstance3D.new()
		stay.mesh = MeshKit.tube(PackedVector3Array([Vector3(0.0, DEPTH + 7.8, -8.0), end]), PackedFloat32Array([0.02, 0.02]), 4)
		stay.material_override = Materials.plain(Color(0.2, 0.2, 0.2))
		node.add_child(stay)
	for side: float in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		rail.mesh = MeshKit.tube(PackedVector3Array([Vector3(side * 2.1, DEPTH + 5.2, 9.3), Vector3(side * 2.1, DEPTH + 5.2, 12.3)]), PackedFloat32Array([0.025, 0.025]), 4)
		rail.material_override = white
		node.add_child(rail)


## A gangway fallen against her low (port) side, from the water up to the deck:
## the way aboard. A ramp that can't fail, under the slats you see.
static func _gangway(node: Node3D, rust: Material) -> void:
	var z := 6.0
	var top := Vector3(-_half_width(z) + 0.2, DEPTH + 0.05, z)
	var foot := Vector3(-_half_width(z) - 4.2, DEPTH - 3.6, z + 1.5)
	var along := (top - foot)
	var length := along.length()
	var right := along.normalized().cross(Vector3.UP).normalized()
	var up := right.cross(along.normalized())
	var basis := Basis(right, up, -along.normalized())
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var slab := BoxShape3D.new()
	slab.size = Vector3(1.0, 0.1, length)
	var collider := CollisionShape3D.new()
	collider.shape = slab
	collider.transform = Transform3D(basis, (top + foot) * 0.5)
	body.add_child(collider)
	node.add_child(body)
	var plank := BoxMesh.new()
	plank.size = Vector3(1.0, 0.06, length)
	var visual := MeshInstance3D.new()
	visual.mesh = plank
	visual.material_override = Materials.wood(Color(0.42, 0.34, 0.26))
	visual.transform = Transform3D(basis, (top + foot) * 0.5)
	node.add_child(visual)
	var steps := int(length / 0.4)
	for i in steps:
		var cleat := BoxMesh.new()
		cleat.size = Vector3(0.9, 0.05, 0.05)
		var bar := MeshInstance3D.new()
		bar.mesh = cleat
		bar.material_override = rust
		bar.transform = Transform3D(basis, foot.lerp(top, (i + 0.5) / steps) + up * 0.05)
		node.add_child(bar)


static func _box(node: Node3D, size: Vector3, pos: Vector3, mat: Material, solid: bool = false, rot: Vector3 = Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = mat
	visual.position = pos
	visual.rotation = rot
	node.add_child(visual)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = Layers.WORLD
		body.collision_mask = 0
		body.position = pos
		body.rotation = rot
		var shape := BoxShape3D.new()
		shape.size = size
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		node.add_child(body)
