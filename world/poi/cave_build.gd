class_name CaveBuild
extends RefCounted
## The cave in the hillside rock band. CampIsland cuts a tunnel and a round chamber
## down to the cave floor; this roofs it over and furnishes it:
##   - a lid over the cut that follows the hillside as it was, in the terrain's
##     own material, so from outside it is just the hill (and, over the doorway,
##     the cliff face) with nothing to show a hole was dug;
##   - a low ceiling of rock inside and boulders along the walls, so it reads as
##     a cave rather than a trench with a roof on;
##   - a probe that keeps the inside dark: bring a torch or a lighter;
##   - the chamber where two pirates fought over the john boat's outboard motor
##     and both died of it (their dagger and bow, and the motor, are pickups).

const LID_STEP := 1.0
## The lid only closes over the cut where the hill stands this far over the floor,
## which leaves the doorway open at the foot of the cliff.
const HEADROOM := 3.4
## How far past the cut's wall the lid reaches, to hide the terrain cells it dips.
const LID_OVERLAP := 2.2

const ROCK := Color(0.34, 0.33, 0.31)
const DARK_ROCK := Color(0.2, 0.19, 0.18)


static func build(shape: CampIsland) -> Node3D:
	var root := Node3D.new()
	root.name = "Cave"
	root.set_meta("floor", shape.cave_floor)
	root.add_child(_lid(shape))
	_ceiling_and_walls(shape, root)
	_doorway(shape, root)
	root.add_child(_darkness(shape))
	root.add_child(_chamber(shape))
	return root


## A point `along` metres into the cave and `across` to the right of its middle
## line (which wanders a little, the way CampIsland cuts it), on the floor.
static func point(shape: CampIsland, along: float, across: float, up: float = 0.0) -> Vector3:
	var wander := sin(along * 0.45) * 0.6
	var xz := shape.cave_mouth + shape.cave_dir * along + shape.cave_dir.orthogonal() * (across + wander)
	return Vector3(xz.x, shape.cave_floor + up, xz.y)


## In the chamber: `offset` metres from its middle (x right, z further in).
static func room_point(shape: CampIsland, offset: Vector3) -> Vector3:
	var right := shape.cave_dir.orthogonal()
	var xz := shape.cave + right * offset.x + shape.cave_dir * offset.z
	return Vector3(xz.x, shape.cave_floor + offset.y, xz.y)


static func facing_in(shape: CampIsland) -> float:
	return atan2(-shape.cave_dir.x, -shape.cave_dir.y)


# --- the lid -------------------------------------------------------------------

static func _lid(shape: CampIsland) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "CaveRoof"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var reach := CampIsland.CAVE_TUNNEL + CampIsland.CAVE_ROOM * 2.0 + LID_OVERLAP + 6.0
	var half_width := CampIsland.CAVE_ROOM + CampIsland.CAVE_WALL + LID_OVERLAP + 2.0
	var right := shape.cave_dir.orthogonal()
	var columns := int(half_width * 2.0 / LID_STEP) + 1
	var rows := int((reach + 4.0) / LID_STEP) + 1
	# Sample every grid point once: position, whether it's over the cut, and its look.
	var points := {}
	for r in rows:
		for c in columns:
			var xz := shape.cave_mouth + shape.cave_dir * (-4.0 + r * LID_STEP) + right * (-half_width + c * LID_STEP)
			var over := shape.height_over_cave(xz.x, xz.y)
			var covered := shape.cave_edge(xz) < CampIsland.CAVE_WALL + LID_OVERLAP and over - shape.cave_floor >= HEADROOM
			points[Vector2i(c, r)] = {"xz": xz, "h": over, "covered": covered}
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var faces := PackedVector3Array()
	for r in rows - 1:
		for c in columns - 1:
			var corners := [Vector2i(c, r), Vector2i(c + 1, r), Vector2i(c, r + 1), Vector2i(c + 1, r + 1)]
			var all_covered := true
			for k: Vector2i in corners:
				all_covered = all_covered and points[k].covered
			if not all_covered:
				continue
			var quad: Array[Vector3] = []
			for k: Vector2i in corners:
				var p: Dictionary = points[k]
				quad.append(Vector3(p.xz.x, float(p.h) + 0.05, p.xz.y))
			# Wound so the faces look up (Godot's front faces are clockwise seen
			# from above, like the terrain's), whichever way the grid runs.
			var order := [0, 1, 2, 1, 3, 2]
			if (quad[1] - quad[0]).cross(quad[2] - quad[0]).y > 0.0:
				order = [0, 2, 1, 1, 2, 3]
			for i: int in order:
				var v: Vector3 = quad[i]
				vertices.append(v)
				faces.append(v)
				_terrain_look(shape, v, normals, colors, uv, uv2)
	if vertices.is_empty():
		return body
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = TerrainLayers.material()
	body.add_child(visual)
	var shape3d := ConcavePolygonShape3D.new()
	shape3d.set_faces(faces)
	var collider := CollisionShape3D.new()
	collider.shape = shape3d
	body.add_child(collider)
	return body


## The same layer, tint and normal the terrain would have there without the cave.
static func _terrain_look(shape: CampIsland, v: Vector3, normals: PackedVector3Array, colors: PackedColorArray,
		uv: PackedVector2Array, uv2: PackedVector2Array) -> void:
	const E := 1.0
	var left := shape.height_over_cave(v.x - E, v.z)
	var right := shape.height_over_cave(v.x + E, v.z)
	var back := shape.height_over_cave(v.x, v.z - E)
	var front := shape.height_over_cave(v.x, v.z + E)
	var normal := Vector3(left - right, 2.0 * E, back - front).normalized()
	var biome := shape.biome_at(v.x, v.z, v.y)
	var layer := CampIsland.layer_for(biome, v.y, normal.y)
	var layer_uvs := TerrainLayers.uvs(layer)
	normals.append(normal)
	colors.append(TerrainLayers.tint(CampIsland.color_for(biome, v.y, normal.y), CampIsland.LAYER_BASE[layer]))
	uv.append(layer_uvs[0])
	uv2.append(layer_uvs[1])


# --- inside ------------------------------------------------------------------------

static func _ceiling_and_walls(shape: CampIsland, root: Node3D) -> void:
	var rock := Materials.stone(ROCK)
	var dark := Materials.stone(DARK_ROCK)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("cave:%d" % shape.island_seed)
	# A low, lumpy ceiling down the tunnel: slabs across it, overlapping.
	var along := 0.5
	while along < CampIsland.CAVE_TUNNEL + 2.0:
		for across: float in [-1.7, 0.0, 1.7]:
			var at := point(shape, along, across, rng.randf_range(3.3, 3.8))
			_rock(root, at, Vector3(rng.randf_range(2.4, 3.0), rng.randf_range(1.0, 1.4), rng.randf_range(1.8, 2.3)), dark, rng)
		# Boulders along both walls, half into them, so the walls aren't smooth cuts.
		for side: float in [-1.0, 1.0]:
			var wall := point(shape, along + rng.randf_range(-0.4, 0.4), side * (CampIsland.CAVE_HALF + 0.55), rng.randf_range(0.4, 2.2))
			_rock(root, wall, Vector3.ONE * rng.randf_range(1.3, 2.1), rock, rng)
		along += 1.5
	# The chamber: a dome, lower round the edge, and a ring of boulders at its walls.
	for ring: Array in [[2.2, 6, 5.4], [4.6, 11, 4.4], [6.3, 16, 3.3]]:
		var radius: float = ring[0]
		var count: int = ring[1]
		for i in count:
			var a := TAU * i / count + rng.randf() * 0.3
			var at := room_point(shape, Vector3(cos(a) * radius, float(ring[2]) + rng.randf_range(-0.2, 0.3), sin(a) * radius))
			_rock(root, at, Vector3(rng.randf_range(2.8, 3.6), rng.randf_range(1.3, 1.8), rng.randf_range(2.8, 3.6)), dark, rng)
	_rock(root, room_point(shape, Vector3(0.0, 5.9, 0.0)), Vector3(4.2, 1.6, 4.2), dark, rng)
	for i in 14:
		var a := TAU * i / 14.0
		var at := room_point(shape, Vector3(cos(a) * (CampIsland.CAVE_ROOM + 0.5), rng.randf_range(0.5, 2.6), sin(a) * (CampIsland.CAVE_ROOM + 0.5)))
		_rock(root, at, Vector3.ONE * rng.randf_range(1.6, 2.6), rock, rng)
	# Rubble and a few fallen stones on the floor.
	for i in 18:
		var in_room := i % 2 == 0
		var at := point(shape, rng.randf_range(1.0, CampIsland.CAVE_TUNNEL), rng.randf_range(-1.8, 1.8), 0.05)
		if in_room:
			at = room_point(shape, Vector3(rng.randf_range(-5.0, 5.0), 0.05, rng.randf_range(-5.0, 5.0)))
		if in_room and Vector2(at.x, at.z).distance_to(shape.cave) > CampIsland.CAVE_ROOM - 0.8:
			continue
		_rock(root, at, Vector3.ONE * rng.randf_range(0.15, 0.4), rock, rng, false)


## Big rocks frame the doorway at the foot of the cliff.
static func _doorway(shape: CampIsland, root: Node3D) -> void:
	var rock := Materials.stone(ROCK)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("cave_door:%d" % shape.island_seed)
	for side: float in [-1.0, 1.0]:
		_rock(root, point(shape, -0.3, side * (CampIsland.CAVE_HALF + 0.4), 1.0), Vector3(1.8, 2.6, 1.6), rock, rng)
		_rock(root, point(shape, -0.9, side * (CampIsland.CAVE_HALF + 1.1), 0.4), Vector3(1.4, 1.2, 1.4), rock, rng)
	_rock(root, point(shape, 0.2, 0.0, 3.7), Vector3(6.4, 1.4, 1.8), rock, rng)


static func _rock(root: Node3D, at: Vector3, size: Vector3, mat: Material, rng: RandomNumberGenerator, solid: bool = true) -> void:
	var visual := MeshInstance3D.new()
	visual.mesh = MeshKit.rock(140 + rng.randi() % 10, 0.22, 0.85)
	visual.material_override = mat
	visual.position = at
	visual.rotation = Vector3(rng.randf() * 0.5, rng.randf() * TAU, rng.randf() * 0.5)
	visual.scale = size
	root.add_child(visual)
	if not solid:
		return
	# Only what you could walk into collides: the lower rocks, not the ceiling.
	if at.y - (root.get_meta("floor", -INF) as float) > 3.0:
		return
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	body.position = at
	var sphere := SphereShape3D.new()
	sphere.radius = minf(size.x, size.z) * 0.42
	var collider := CollisionShape3D.new()
	collider.shape = sphere
	body.add_child(collider)
	root.add_child(body)


## Inside, the sky doesn't light anything: an interior probe with near-black
## ambient over the whole cave, so a torch or a lighter is what you see by.
static func _darkness(shape: CampIsland) -> ReflectionProbe:
	var probe := ReflectionProbe.new()
	probe.name = "CaveDark"
	var length := CampIsland.CAVE_TUNNEL + CampIsland.CAVE_ROOM * 2.0 + 1.0
	probe.size = Vector3(CampIsland.CAVE_ROOM * 2.0 + 2.0, 7.0, length)
	probe.interior = true
	probe.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	probe.ambient_color = Color(0.03, 0.03, 0.035)
	probe.ambient_color_energy = 1.0
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.intensity = 0.2
	var middle := point(shape, length * 0.5 - 0.5, 0.0, 3.3)
	probe.transform = Transform3D(Basis(Vector3.UP, facing_in(shape)), middle)
	return probe


# --- the chamber ---------------------------------------------------------------

## Two pirates, dead where they fought: the thief who took the motor, face down by
## it with his dagger, and the one who came after him, on his back by the wall
## with his bow. Their weapons and the motor are pickups (CampSystems.CAVE_PICKUPS).
static func _chamber(shape: CampIsland) -> Node3D:
	var node := Node3D.new()
	node.name = "Chamber"
	var yaw := facing_in(shape)
	# Long dead: picked clean, with the rags of what they wore under the bones.
	var thief := _dead_pirate(node, 11, Color(0.24, 0.3, 0.26))
	thief.transform = Transform3D(Basis(Vector3.UP, yaw + 0.7) * Basis(Vector3.RIGHT, -1.52), room_point(shape, Vector3(-1.1, 0.06, 0.6)))
	var hunter := _dead_pirate(node, 27, Color(0.35, 0.28, 0.2))
	hunter.transform = Transform3D(Basis(Vector3.UP, yaw - 2.2) * Basis(Vector3.RIGHT, 1.5), room_point(shape, Vector3(2.9, 0.06, -1.2)))
	# Where they bled, and the lantern that went out when it fell.
	var blood := Materials.plain(Color(0.22, 0.04, 0.03), 0.4)
	for spot: Vector3 in [Vector3(-1.0, 0.02, 0.9), Vector3(2.6, 0.02, -0.9), Vector3(0.7, 0.02, 0.1)]:
		var stain := MeshInstance3D.new()
		stain.mesh = MeshKit.rock(150, 0.3, 0.15)
		stain.material_override = blood
		stain.position = room_point(shape, spot)
		stain.scale = Vector3(1.1, 0.03, 0.8)
		node.add_child(stain)
	var lantern := MeshInstance3D.new()
	var body := CylinderMesh.new()
	body.top_radius = 0.08
	body.bottom_radius = 0.09
	body.height = 0.26
	lantern.mesh = body
	lantern.material_override = Materials.metal(Color(0.2, 0.2, 0.19), 0.6)
	lantern.position = room_point(shape, Vector3(0.9, 0.09, 1.8))
	lantern.rotation = Vector3(PI / 2.0, 0.4, 0.0)
	node.add_child(lantern)
	# A couple of crates the thief was living off.
	var crate := BoxMesh.new()
	crate.size = Vector3(0.7, 0.5, 0.5)
	for spot: Vector3 in [Vector3(-3.6, 0.25, 2.6), Vector3(-3.0, 0.25, 3.4)]:
		var box := MeshInstance3D.new()
		box.mesh = crate
		box.material_override = Materials.wood(Color(0.45, 0.35, 0.24))
		box.position = room_point(shape, spot)
		box.rotation.y = yaw + spot.x
		node.add_child(box)
	return node


## A skeleton with the rotted remains of clothing caught under the bones.
static func _dead_pirate(parent: Node3D, seed_value: int, cloth: Color) -> Node3D:
	var node := Node3D.new()
	parent.add_child(node)
	var bones := Remains.build(seed_value)
	node.add_child(bones)
	var rag := Materials.cloth(cloth.darkened(0.25))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# Torn cloth over the ribs and hips, sagging into the frame it once filled.
	for spot: Vector3 in [Vector3(0.0, 1.22, -0.03), Vector3(0.0, 1.38, -0.02), Vector3(0.0, 0.86, -0.01), Vector3(0.0, 0.62, 0.0)]:
		var piece := MeshInstance3D.new()
		piece.mesh = MeshKit.rock(300 + seed_value + int(spot.y * 10.0), 0.4, 0.5)
		piece.material_override = rag
		piece.position = spot
		piece.rotation.y = rng.randf_range(-0.6, 0.6)
		piece.scale = Vector3(rng.randf_range(0.3, 0.42), rng.randf_range(0.1, 0.2), rng.randf_range(0.22, 0.34))
		node.add_child(piece)
	return node
