class_name Props
extends RefCounted
## Island props built in code with organic shapes and textured materials:
## curved palms with drooping fronds, branching trees with leafy canopies,
## lumpy stones, bleached driftwood, grass tufts and berry bushes.
##
## Palms, trees and berry bushes come from the CC0 model packs (assets/models/nature)
## when they're there; the code-built versions below are the fallback.
##
## build(kind, variant) returns:
##   root: Node3D visual · harvest: nodes hidden while depleted
##   shape + shape_position: collision · blocks: stops players walking through
##   hide_when_depleted: the whole prop disappears when picked (stones, fiber)
##   charred: meshes turned to char when fire takes the prop · leaves: hidden then
##   burnt_keep: harvest nodes that stay standing when it burns (a tree's trunk)
##   felled: shown only once it's cut down (a stump)

## [file, part, height in metres]
const PALM_MODELS := [
	["nature/palm_trees.glb", 0, 6.4], ["nature/palm_trees.glb", 2, 5.6], ["nature/palm_trees.glb", 3, 6.8],
	["nature/palm_trees.glb", 4, 7.2], ["nature/palm_curved.glb", 0, 6.2],
]
const TREE_MODELS := [
	["nature/trees.glb", 0, 7.0], ["nature/trees.glb", 1, 6.6], ["nature/trees.glb", 2, 6.0],
	["nature/trees.glb", 3, 5.8], ["nature/tree_leafy.glb", 0, 7.4],
]
## The leafy bush (not the pack's own berry bush, whose stacked lumps look like a pile of cushions).
const BUSH_MODEL := ["nature/bushes.glb", 1, 1.1]
const TRUNK_WORDS := ["trunk", "bark", "wood"]
const LEAF_WORDS := ["leaves", "green"]

static var _materials := {}


## A plain coloured material, cached by key (used by structures, boats and landmarks).
static func material(key: String, color: Color) -> StandardMaterial3D:
	# Named surfaces get the real (photo) materials; anything else stays a flat colour.
	for word: String in ["wood", "mast", "handle", "log"]:
		if key.contains(word):
			return Materials.wood(color)
	for word: String in ["stone", "rock", "boulder", "charcoal"]:
		if key.contains(word):
			return Materials.stone(color)
	if key.contains("tarp"):
		return Materials.cloth(color)
	if key == "bag":
		return Materials.burlap(color)
	if key.contains("strap") or key.contains("cover"):
		return Materials.leather(color)
	if key == "blade" or key == "brass":
		return Materials.metal(color, 0.3)
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 1.0
		_materials[key] = m
	return _materials[key]


static func build(kind: String, variant: int = 0) -> Dictionary:
	var pick := absi(variant)
	variant = pick % 4
	match kind:
		"palm":
			return _palm_model(pick) if ModelLib.exists(PALM_MODELS[0][0]) else _palm(variant)
		"tree":
			return _tree_model(pick) if ModelLib.exists(TREE_MODELS[0][0]) else _tree(variant)
		"berry_bush":
			return _bush_model(pick, Color(0.30, 0.20, 0.62)) if ModelLib.exists(BUSH_MODEL[0]) else _bush(variant, Color(0.30, 0.20, 0.62))
		"red_berry_bush":
			return _bush_model(pick, Color(0.86, 0.10, 0.12)) if ModelLib.exists(BUSH_MODEL[0]) else _bush(variant, Color(0.86, 0.10, 0.12))
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
	return {"root": root, "harvest": harvest, "shape": shape, "shape_position": shape_position, "blocks": blocks, "hide_when_depleted": hide_all,
		"charred": [], "leaves": [], "burnt_keep": [], "felled": []}


## A palm from the pack, with coconuts hung under the crown where the trunk ends.
static func _palm_model(pick: int) -> Dictionary:
	var spec: Array = PALM_MODELS[pick % PALM_MODELS.size()]
	var height: float = spec[2]
	var root := Node3D.new()
	var model := ModelLib.part(spec[0], spec[1], height)
	root.add_child(model)
	var top := ModelLib.surface_top(spec[0], spec[1], height, TRUNK_WORDS)
	var coconuts := Node3D.new()
	coconuts.position = top + Vector3.DOWN * 0.22
	root.add_child(coconuts)
	var nut := MeshKit.rock(9, 0.06, 1.0)
	var husk := Materials.bark(Color(0.40, 0.27, 0.14))
	var rng := RandomNumberGenerator.new()
	rng.seed = 8400 + pick
	for i in 3 + pick % 3:
		var a := i * TAU / 4.0 + rng.randf_range(-0.4, 0.4)
		_instance(coconuts, nut, husk, Vector3(cos(a) * 0.16, rng.randf_range(-0.08, 0.04), sin(a) * 0.16), Vector3(rng.randf(), rng.randf(), 0.0), Vector3.ONE * 0.27)
	var shape := CylinderShape3D.new()
	shape.radius = maxf(0.22, ModelLib.base_radius(spec[0], spec[1], height, TRUNK_WORDS))
	shape.height = height * 0.8
	var built := _result(root, [coconuts], shape, Vector3(top.x * 0.35, height * 0.4, top.z * 0.35), true, false, 500.0)
	built.charred = ModelLib.surfaces_named(model, TRUNK_WORDS)
	built.leaves = ModelLib.surfaces_named(model, LEAF_WORDS)
	return built


## A tree from the pack. Felling it leaves a stump sized to its trunk; fire leaves
## the trunk standing, black and bare.
static func _tree_model(pick: int) -> Dictionary:
	var spec: Array = TREE_MODELS[pick % TREE_MODELS.size()]
	var height: float = spec[2]
	var root := Node3D.new()
	var radius := ModelLib.base_radius(spec[0], spec[1], height, TRUNK_WORDS, 0.9, 0.4)
	var bark := Materials.bark(Color(0.40, 0.31, 0.22))
	# The stump only shows once the tree is felled: the trunk cut 45 cm up, rings on top.
	var stump := Node3D.new()
	root.add_child(stump)
	_instance(stump, _cylinder_mesh(snappedf(radius, 0.01), snappedf(radius * 1.25, 0.01), 0.45), bark, Vector3(0.0, 0.225, 0.0))
	_instance(stump, _cylinder_mesh(snappedf(radius * 0.96, 0.01), snappedf(radius * 0.96, 0.01), 0.02), Materials.tree_rings(Color(0.70, 0.55, 0.36)), Vector3(0.0, 0.45, 0.0))
	var standing := ModelLib.part(spec[0], spec[1], height)
	root.add_child(standing)
	var shape := CylinderShape3D.new()
	shape.radius = radius + 0.08
	shape.height = 4.5
	var built := _result(root, [standing], shape, Vector3(0.0, 2.25, 0.0), true, false, 500.0)
	built.charred = ModelLib.surfaces_named(standing, TRUNK_WORDS)
	built.leaves = ModelLib.surfaces_named(standing, LEAF_WORDS)
	built.burnt_keep = [standing]
	built.felled = [stump]
	return built


## A leafy bush from the pack with clusters of berries tucked just inside its
## outer leaves, all the way round, so they peek out between them.
static func _bush_model(pick: int, berry_color: Color) -> Dictionary:
	var root := Node3D.new()
	var height: float = BUSH_MODEL[2] * (0.9 + (pick % 5) * 0.06)
	var model := ModelLib.part(BUSH_MODEL[0], BUSH_MODEL[1], height)
	model.rotation.y = (pick % 7) * 0.9
	root.add_child(model)
	var size := ModelLib.part_size(BUSH_MODEL[0], BUSH_MODEL[1]) * (height / maxf(ModelLib.part_size(BUSH_MODEL[0], BUSH_MODEL[1]).y, 0.01))
	var berries := Node3D.new()
	root.add_child(berries)
	var berry := SphereMesh.new()
	berry.radius = 0.03
	berry.height = 0.06
	berry.radial_segments = 8
	berry.rings = 4
	var shiny := Materials.plain(berry_color, 0.25)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8100 + pick % 16
	const CLUSTERS := 14
	for i in CLUSTERS:
		# One cluster per slice round the bush, at a random height on the dome.
		var around := (i + rng.randf_range(0.1, 0.9)) * TAU / CLUSTERS
		var up := rng.randf_range(0.15, 0.85)
		var dir := Vector3(cos(around) * sqrt(1.0 - up * up), up, sin(around) * sqrt(1.0 - up * up))
		var at := Vector3(dir.x * size.x * 0.5, height * 0.42 + dir.y * height * 0.52, dir.z * size.z * 0.5) * 0.97
		for k in 3:
			_instance(berries, berry, shiny, at + Vector3(rng.randf_range(-0.035, 0.035), rng.randf_range(-0.03, 0.02), rng.randf_range(-0.035, 0.035)))
	var shape := SphereShape3D.new()
	shape.radius = 0.8
	var built := _result(root, [berries], shape, Vector3(0.0, 0.5, 0.0), false, false, 180.0)
	built.charred = ModelLib.surfaces_named(model, LEAF_WORDS)
	return built


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
	_instance(root, trunk, Materials.palm_bark(Color(0.56, 0.45, 0.32)), Vector3.ZERO)
	var top := points[segments]
	var crown := Node3D.new()
	crown.position = top
	root.add_child(crown)
	var frond_material := Materials.foliage(Color(0.28, 0.52, 0.2))
	var rng := RandomNumberGenerator.new()
	rng.seed = 8300 + variant
	# Eleven fronds: most spread and droop, every third is a younger one standing up.
	for i in 11:
		var yaw := i * TAU / 11.0 + variant * 0.3 + rng.randf_range(-0.2, 0.2)
		var young := i % 3 == 0
		var length := rng.randf_range(2.6, 3.3) * (0.7 if young else 1.0)
		var frond := MeshKit.frond(snappedf(length, 0.1), snappedf(rng.randf_range(0.95, 1.15), 0.05), snappedf(rng.randf_range(0.2, 0.3) if young else rng.randf_range(0.45, 0.7), 0.05))
		var pitch := rng.randf_range(-0.95, -0.7) if young else rng.randf_range(-0.5, -0.15)
		_instance(crown, frond, frond_material, Vector3.ZERO, Vector3(pitch, yaw, rng.randf_range(-0.12, 0.12)))
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
	var bark := Materials.bark(Color(0.40, 0.31, 0.22))
	# The stump flares at the roots and tucks inside the trunk, so it only shows once felled.
	_instance(root, _cylinder_mesh(0.31, 0.46, 0.5), bark, Vector3(0.0, 0.25, 0.0))
	_instance(root, _cylinder_mesh(0.30, 0.30, 0.02), Materials.tree_rings(Color(0.70, 0.55, 0.36)), Vector3(0.0, 0.5, 0.0))
	var standing := Node3D.new()
	root.add_child(standing)
	const TRUNK := 4.4
	const TRUNK_BEND := 0.12
	var base := Vector3(0.0, 0.3, 0.0)
	_instance(standing, MeshKit.branch(variant, TRUNK, 0.38, 0.14, TRUNK_BEND, 9), bark, base)
	var top := base + MeshKit.branch_point(variant, TRUNK, TRUNK_BEND, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7000 + variant
	# Branches leave the upper trunk and end inside the crown, each tip hidden in a clump.
	var tips: Array[Vector3] = []
	for i in 4:
		var start := base + MeshKit.branch_point(variant, TRUNK, TRUNK_BEND, rng.randf_range(0.6, 0.85))
		var length := snappedf(rng.randf_range(1.4, 1.9), 0.05)
		var rot := Vector3(0.0, i * TAU / 4.0 + rng.randf_range(-0.4, 0.4), -rng.randf_range(0.7, 0.95))
		var id := 20 + variant * 10 + i
		_instance(standing, MeshKit.branch(id, length, 0.12, 0.05, 0.5, 5), bark, start, rot)
		tips.append(start + Basis.from_euler(rot) * MeshKit.branch_point(id, length, 0.5, 1.0))
	var center := top
	for tip in tips:
		center += tip
	center /= tips.size() + 1
	# The crown: a big clump over the trunk top, one on every branch tip, and filler
	# scattered between so it reads as one leafy mass — lighter on top, darker below.
	var clumps: Array = [[top + Vector3.UP * 0.3, 1.9]]
	for tip in tips:
		clumps.append([tip + Vector3.UP * 0.15, rng.randf_range(1.3, 1.6)])
	for i in 12:
		var angle := rng.randf() * TAU
		var ring := sqrt(rng.randf()) * 1.6
		var pos := center + Vector3(cos(angle) * ring, rng.randf_range(-0.3, 0.9) + (1.6 - ring) * 0.35, sin(angle) * ring)
		clumps.append([pos, lerpf(1.5, 1.0, ring / 1.6) * rng.randf_range(0.85, 1.1)])
	var leaves := Materials.foliage(Color(0.17, 0.40, 0.15))
	var sunlit := Materials.foliage(Color(0.24, 0.48, 0.18))
	for clump: Array in clumps:
		var pos: Vector3 = clump[0]
		var size: float = clump[1]
		_instance(standing, MeshKit.rock(30 + rng.randi() % 8, 0.32, 0.72), sunlit if pos.y > center.y + 0.6 else leaves, pos,
			Vector3(rng.randf() * 0.4, rng.randf() * TAU, rng.randf() * 0.4), Vector3(size, size * rng.randf_range(0.75, 0.95), size))
	var shape := CylinderShape3D.new()
	shape.radius = 0.45
	shape.height = 4.5
	return _result(root, [standing], shape, Vector3(0.0, 2.25, 0.0), true, false, 500.0)


## A leafy bush dotted with berries.
static func _bush(variant: int, berry_color: Color) -> Dictionary:
	var root := Node3D.new()
	var leaves := Materials.foliage(Color(0.22, 0.44, 0.19))
	var clumps: Array[MeshInstance3D] = []
	for i in 5:
		var a := i * TAU / 5.0 + variant
		var offset := Vector3(cos(a) * 0.35, 0.45 + (i % 2) * 0.15, sin(a) * 0.35) if i > 0 else Vector3(0.0, 0.62, 0.0)
		var size := 0.95 if i == 0 else 0.7
		clumps.append(_instance(root, MeshKit.rock(40 + (variant + i) % 5, 0.3, 0.85), leaves, offset, Vector3(0.0, i, 0.0), Vector3.ONE * size))
	var berries := Node3D.new()
	root.add_child(berries)
	var berry := SphereMesh.new()
	berry.radius = 0.045
	berry.height = 0.09
	berry.radial_segments = 8
	berry.rings = 4
	var shiny := Materials.plain(berry_color, 0.25)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8100 + variant
	# Spread all the way round: one berry per slice of the bush, somewhere in that slice.
	const BERRIES := 14
	var sectors: Array = []
	sectors.resize(BERRIES)
	for i in BERRIES:
		sectors[i] = []
	for p in _berry_spots(variant, clumps):
		sectors[int(fposmod(atan2(p.z, p.x), TAU) / TAU * BERRIES) % BERRIES].append(p)
	for sector: Array in sectors:
		if not sector.is_empty():
			_instance(berries, berry, shiny, sector[rng.randi() % sector.size()])
	var shape := SphereShape3D.new()
	shape.radius = 0.8
	return _result(root, [berries], shape, Vector3(0.0, 0.5, 0.0), false, false, 180.0)


static var _berry_spot_cache := {}


## Where berries can hang on a bush: real surface points of its leaf clumps that
## face out from the middle of the bush and aren't buried inside a neighbouring
## clump — so berries neither float nor hide. Cached per variant.
static func _berry_spots(variant: int, clumps: Array[MeshInstance3D]) -> PackedVector3Array:
	if _berry_spot_cache.has(variant):
		return _berry_spot_cache[variant]
	const MIDDLE := Vector3(0.0, 0.5, 0.0)
	var spots := PackedVector3Array()
	for clump in clumps:
		var vertices: PackedVector3Array = clump.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for v in vertices:
			var p := clump.transform * v
			var out := (p - MIDDLE).normalized()
			if p.y < 0.3 or out.dot((p - clump.position).normalized()) < 0.55:
				continue
			var buried := false
			for other in clumps:
				if other != clump and p.distance_to(other.position) < other.scale.x * 0.5 * 0.85:
					buried = true
					break
			if not buried:
				spots.append(p + out * 0.025)
	if spots.is_empty():
		spots.append(MIDDLE + Vector3.UP * 0.5)
	_berry_spot_cache[variant] = spots
	return spots


## A tuft of long, arching grass blades.
static func _fiber(variant: int) -> Dictionary:
	var root := Node3D.new()
	var green := Materials.foliage(Color(0.50, 0.66, 0.28))
	var rng := RandomNumberGenerator.new()
	rng.seed = 8200 + variant
	for i in 14:
		var yaw := rng.randf() * TAU
		var blade := MeshKit.leaf(0.95 + (i % 4) * 0.12, 0.09, 0.45 + (i % 3) * 0.15, 6, 0.0)
		var lean := rng.randf_range(0.2, 0.7)
		_instance(root, blade, green, Vector3(cos(yaw) * rng.randf_range(0.0, 0.12), 0.0, sin(yaw) * rng.randf_range(0.0, 0.12)), Vector3(-PI / 2.0 + lean, yaw, rng.randf_range(-0.2, 0.2)))
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
