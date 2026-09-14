class_name FishingShack
extends RefCounted
## The fishing shack on the camp island's cove: a weathered plank hut on short
## stilts with a tin roof, a dock running out into the cove, and the john boat
## tied alongside. Inside: a bunk (respawn), the sea chest (the stash), a gear
## locker, a locked footlocker (the pistol), a wood stove and a chart table.
##
## layout() is pure math from the island's seed, so the host and every client
## agree on where everything is. Shack space: -Z is the door, facing the sea.

const SIZE := Vector3(5.0, 2.5, 4.0)
const PART_SPOTS := {
	"bunk": Vector3(-1.35, 0.45, 1.45),
	"chest": Vector3(1.7, 0.3, 1.55),
	"lockers": Vector3(2.15, 0.85, 0.3),
	"footlocker": Vector3(-1.35, 0.22, 0.7),
	"stove": Vector3(-1.95, 0.5, -1.2),
	"chart": Vector3(1.5, 0.85, -1.2),
}
const PART_SIZES := {
	"bunk": Vector3(1.9, 0.8, 0.95), "chest": Vector3(0.95, 0.6, 0.6), "lockers": Vector3(0.55, 1.7, 0.95),
	"footlocker": Vector3(0.85, 0.5, 0.5), "stove": Vector3(0.7, 1.0, 0.7), "chart": Vector3(1.05, 0.4, 0.75),
}
const SPAWN := Vector3(0.0, 0.05, 0.35)
const DOCK_SIDE := 4.0
const DOCK_WIDTH := 1.5
const DOCK_Y := 1.35
const ROOF_TILT := 0.18

const PLANKS := Color(0.64, 0.60, 0.53)
const DARK_WOOD := Color(0.33, 0.26, 0.19)
const TIN := Color(0.52, 0.53, 0.5)


static func layout(shape: CampIsland) -> Dictionary:
	var out := Vector2.from_angle(shape.cove_bearing)
	var side := out.orthogonal()
	var yaw := atan2(-out.x, -out.y)
	var basis := Basis(Vector3.UP, yaw)
	var hut := shape.cove - out * 11.0
	# The floor sits level, just above the highest ground under the hut.
	var ground := shape.height_at(hut.x, hut.y)
	var top := ground
	for cx: float in [-1.0, 1.0]:
		for cz: float in [-1.0, 1.0]:
			var corner := Vector3(hut.x, 0.0, hut.y) + basis * Vector3(cx * SIZE.x * 0.5, 0.0, cz * SIZE.z * 0.5)
			top = maxf(top, shape.height_at(corner.x, corner.z))
	var xf := Transform3D(basis, Vector3(hut.x, maxf(top, 1.2) + 0.35, hut.y))
	var parts := {}
	for part: String in PART_SPOTS:
		parts[part] = xf * Vector3(PART_SPOTS[part])

	var dock_start := shape.cove - out * 2.5 + side * DOCK_SIDE
	var dock_end := shape.cove + out * 14.0 + side * DOCK_SIDE
	# Alongside the dock with room to bob without grinding against the pilings.
	var boat_xz := shape.cove + out * 10.5 + side * (DOCK_SIDE + DOCK_WIDTH * 0.5 + JohnBoat.BEAM * 0.5 + 0.8)
	var boat_xf := Transform3D(basis, Vector3(boat_xz.x, 0.0, boat_xz.y))
	var posts: Array[Vector3] = []
	for along: float in [7.5, 13.5]:
		var p := shape.cove + out * along + side * (DOCK_SIDE + DOCK_WIDTH * 0.5 + 0.1)
		posts.append(Vector3(p.x, DOCK_Y + 0.35, p.y))
	var lines: Array[Dictionary] = []
	for cleat: Vector3 in [JohnBoat.BOW_CLEAT, JohnBoat.STERN_CLEAT]:
		var world_cleat := boat_xf * cleat
		var nearest := posts[0] if world_cleat.distance_to(posts[0]) < world_cleat.distance_to(posts[1]) else posts[1]
		lines.append({"local": cleat, "anchor": nearest})
	return {
		"xf": xf, "ground": ground, "parts": parts, "spawn": xf * SPAWN,
		"dock_start": Vector3(dock_start.x, DOCK_Y, dock_start.y), "dock_end": Vector3(dock_end.x, DOCK_Y, dock_end.y),
		"boat_xf": boat_xf, "lines": lines, "posts": posts,
	}


## Is world point `p` inside the shack's walls?
static func contains(shack: Dictionary, p: Vector3) -> bool:
	if shack.is_empty():
		return false
	var local: Vector3 = Transform3D(shack.xf).affine_inverse() * p
	return absf(local.x) < SIZE.x * 0.5 - 0.05 and absf(local.z) < SIZE.z * 0.5 - 0.05 and local.y > -0.6 and local.y < SIZE.y + 0.2


static func build(shape: CampIsland) -> Node3D:
	var shack := layout(shape)
	var root := Node3D.new()
	root.name = "FishingShack"
	root.add_child(_hut(shack))
	root.add_child(_dock(shape, shack))
	return root


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, solid: bool = false, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = mat
	visual.position = pos
	visual.rotation = rot
	parent.add_child(visual)
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
		parent.add_child(body)
	return visual


static func _post(parent: Node3D, from: Vector3, to: Vector3, radius: float, mat: Material) -> void:
	var visual := MeshInstance3D.new()
	visual.mesh = MeshKit.tube(PackedVector3Array([from, from.lerp(to, 0.5) + Vector3(0.015, 0.0, 0.01), to]), PackedFloat32Array([radius, radius * 0.95, radius * 0.9]), 8)
	visual.material_override = mat
	parent.add_child(visual)


static func _hut(shack: Dictionary) -> Node3D:
	var node := Node3D.new()
	node.name = "Hut"
	node.transform = shack.xf
	var planks := Materials.planks(PLANKS, 0.22)
	var dark := Materials.wood(DARK_WOOD)
	var floor_wood := Materials.planks(Color(0.47, 0.37, 0.27), 0.18)
	var tin := Materials.metal(TIN, 0.72)
	var iron := Materials.metal(Color(0.2, 0.2, 0.21), 0.6)
	var half := SIZE * 0.5
	var lift: float = Transform3D(shack.xf).origin.y - float(shack.ground) + 0.5

	# Floor on stilts, steps up to the door.
	_box(node, Vector3(SIZE.x + 0.2, 0.12, SIZE.z + 0.2), Vector3(0.0, -0.06, 0.0), floor_wood, true)
	for cx: float in [-1.0, 1.0]:
		for cz: float in [-1.0, 1.0]:
			_post(node, Vector3(cx * (half.x - 0.1), -lift - 0.4, cz * (half.z - 0.1)), Vector3(cx * (half.x - 0.1), 0.0, cz * (half.z - 0.1)), 0.09, dark)
	_box(node, Vector3(1.3, 0.1, 0.45), Vector3(0.0, -0.2, -half.z - 0.3), dark, true)
	_box(node, Vector3(1.3, 0.1, 0.45), Vector3(0.0, -0.42, -half.z - 0.7), dark, true, Vector3.ZERO)

	# Walls: plank siding with battens, a doorway facing the sea, a window.
	var wall := 0.1
	_box(node, Vector3(SIZE.x, SIZE.y, wall), Vector3(0.0, half.y, half.z - wall * 0.5), planks, true)
	for sx: float in [-1.0, 1.0]:
		_box(node, Vector3(wall, SIZE.y, SIZE.z), Vector3(sx * (half.x - wall * 0.5), half.y, 0.0), planks, true)
		_box(node, Vector3(half.x - 0.55, SIZE.y, wall), Vector3(sx * (0.55 + (half.x - 0.55) * 0.5), half.y, -half.z + wall * 0.5), planks, true)
	_box(node, Vector3(1.1, 0.45, wall), Vector3(0.0, SIZE.y - 0.225, -half.z + wall * 0.5), planks, true)
	for i in 7:
		var x := -half.x + 0.35 + i * (SIZE.x - 0.7) / 6.0
		if absf(x) > 0.7:
			_box(node, Vector3(0.07, SIZE.y, 0.03), Vector3(x, half.y, -half.z - 0.01), dark)
		_box(node, Vector3(0.07, SIZE.y, 0.03), Vector3(x, half.y, half.z + 0.01), dark)
	_box(node, Vector3(0.14, 2.05, 0.14), Vector3(-0.6, 1.02, -half.z), dark)
	_box(node, Vector3(0.14, 2.05, 0.14), Vector3(0.6, 1.02, -half.z), dark)
	for sx: float in [-1.0, 1.0]:
		_box(node, Vector3(0.03, 0.72, 0.92), Vector3(sx * (half.x + 0.012), 1.5, -0.4), dark)
		_box(node, Vector3(0.035, 0.56, 0.76), Vector3(sx * (half.x + 0.02), 1.5, -0.4), Materials.glow(Color(0.55, 0.62, 0.66), 0.08))
		_box(node, Vector3(0.05, 0.56, 0.05), Vector3(sx * (half.x + 0.03), 1.5, -0.4), dark)
		_box(node, Vector3(0.05, 0.05, 0.76), Vector3(sx * (half.x + 0.03), 1.5, -0.4), dark)

	# A tin shed roof, high over the door and sloping down to the back, with a
	# porch overhang; the walls rise to meet it.
	var ridge := SIZE.y + 0.05 + half.z * ROOF_TILT
	var roof_len := SIZE.z + 1.3
	_box(node, Vector3(SIZE.x + 0.7, 0.1, roof_len), Vector3(0.0, ridge + 0.35 * ROOF_TILT, -0.35), tin, false, Vector3(ROOF_TILT, 0.0, 0.0))
	for i in 10:
		var x := -half.x - 0.3 + i * (SIZE.x + 0.6) / 9.0
		_box(node, Vector3(0.05, 0.045, roof_len), Vector3(x, ridge + 0.35 * ROOF_TILT + 0.07, -0.35), tin, false, Vector3(ROOF_TILT, 0.0, 0.0))
	_box(node, Vector3(SIZE.x + 0.72, 0.16, 0.05), Vector3(0.0, ridge + (roof_len * 0.5 + 0.35) * ROOF_TILT - 0.02, -0.35 - roof_len * 0.5), dark, false, Vector3(ROOF_TILT, 0.0, 0.0))
	var gable := half.z * 2.0 * ROOF_TILT
	_box(node, Vector3(SIZE.x, gable, 0.1), Vector3(0.0, SIZE.y + gable * 0.5, -half.z + 0.05), planks)
	for sx: float in [-1.0, 1.0]:
		_box(node, Vector3(0.08, gable, SIZE.z), Vector3(sx * (half.x - 0.05), SIZE.y + gable * 0.25, 0.0), planks, false, Vector3(ROOF_TILT, 0.0, 0.0))
		_post(node, Vector3(sx * (half.x - 0.1), -0.05, -half.z - 0.55), Vector3(sx * (half.x - 0.1), ridge + 0.9 * ROOF_TILT, -half.z - 0.55), 0.06, dark)
	for z: float in [-1.2, 0.0, 1.2]:
		_box(node, Vector3(SIZE.x - 0.2, 0.12, 0.1), Vector3(0.0, SIZE.y - 0.1, z), dark)

	# Bunk.
	_box(node, Vector3(1.9, 0.42, 0.9), Vector3(-1.35, 0.21, 1.45), dark, true)
	_box(node, Vector3(1.8, 0.12, 0.8), Vector3(-1.35, 0.48, 1.45), Materials.cloth(Color(0.55, 0.28, 0.22)))
	_box(node, Vector3(0.45, 0.1, 0.34), Vector3(-2.0, 0.58, 1.5), Materials.cloth(Color(0.85, 0.82, 0.74)))
	# Sea chest, iron-banded.
	_box(node, Vector3(0.9, 0.46, 0.5), Vector3(1.7, 0.23, 1.6), dark, true)
	_box(node, Vector3(0.92, 0.08, 0.52), Vector3(1.7, 0.47, 1.6), planks)
	for x: float in [1.4, 2.0]:
		_box(node, Vector3(0.05, 0.52, 0.53), Vector3(x, 0.26, 1.6), iron)
	# Gear locker.
	_box(node, Vector3(0.45, 1.7, 0.9), Vector3(2.18, 0.85, 0.3), planks, true)
	for z: float in [0.08, 0.52]:
		_box(node, Vector3(0.02, 1.55, 0.4), Vector3(1.945, 0.85, z), dark)
	# The locked footlocker at the foot of the bunk.
	_box(node, Vector3(0.8, 0.38, 0.42), Vector3(-1.35, 0.19, 0.7), Materials.metal(Color(0.24, 0.31, 0.26), 0.6), true)
	_box(node, Vector3(0.08, 0.1, 0.02), Vector3(-1.35, 0.26, 0.48), Materials.metal(Color(0.8, 0.65, 0.28), 0.35))
	# Wood stove with its flue out through the roof.
	_box(node, Vector3(0.55, 0.75, 0.55), Vector3(-1.95, 0.375, -1.2), iron, true)
	_box(node, Vector3(0.3, 0.2, 0.02), Vector3(-1.95, 0.35, -1.48), Materials.glow(Color(1.0, 0.45, 0.15), 0.4))
	_post(node, Vector3(-1.95, 0.75, -1.2), Vector3(-1.95, SIZE.y + 0.6, -1.2), 0.06, iron)
	var glow := OmniLight3D.new()
	glow.name = "StoveGlow"
	glow.light_color = Color(1.0, 0.55, 0.2)
	glow.light_energy = 1.2
	glow.omni_range = 3.5
	glow.position = Vector3(-1.6, 0.6, -1.2)
	glow.visible = false
	node.add_child(glow)
	# Chart table.
	_box(node, Vector3(1.0, 0.05, 0.7), Vector3(1.5, 0.78, -1.2), planks)
	for lx: float in [1.05, 1.95]:
		for lz: float in [-1.5, -0.9]:
			_box(node, Vector3(0.05, 0.76, 0.05), Vector3(lx, 0.38, lz), dark)
	_box(node, Vector3(0.62, 0.005, 0.46), Vector3(1.5, 0.805, -1.2), Materials.plain(Color(0.86, 0.8, 0.64)), false, Vector3(0.0, 0.12, 0.0))
	# Old buoys hung on a rope by the door.
	var rope := Materials.cloth(Color(0.72, 0.62, 0.45))
	for sx: float in [-1.0, 1.0]:
		var hang := Vector3(sx * 1.35, 1.1, -half.z - 0.16)
		_post(node, hang + Vector3(0.0, 0.18, 0.0), Vector3(sx * 1.35, 2.0, -half.z - 0.06), 0.012, rope)
		var buoy := MeshInstance3D.new()
		buoy.mesh = MeshKit.rock(90, 0.02, 1.0)
		buoy.material_override = Materials.plain(Color(0.92, 0.42, 0.12), 0.5)
		buoy.scale = Vector3(0.22, 0.3, 0.22)
		buoy.position = hang
		node.add_child(buoy)
		_box(node, Vector3(0.23, 0.05, 0.23), hang, Materials.plain(Color(0.92, 0.9, 0.86)))
	# Lights: a lantern inside and one on the porch.
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.8, 0.52)
	lamp.light_energy = 0.9
	lamp.omni_range = 5.5
	lamp.position = Vector3(0.0, 1.95, 0.2)
	node.add_child(lamp)
	_box(node, Vector3(0.16, 0.22, 0.16), Vector3(0.0, 2.05, 0.2), Materials.glow(Color(1.0, 0.78, 0.45), 2.2))
	_box(node, Vector3(0.2, 0.05, 0.2), Vector3(0.0, 2.19, 0.2), iron)
	_post(node, Vector3(0.0, 2.21, 0.2), Vector3(0.0, SIZE.y - 0.04, 0.2), 0.008, iron)
	_box(node, Vector3(0.14, 0.2, 0.14), Vector3(0.95, 2.05, -half.z - 0.2), Materials.glow(Color(1.0, 0.75, 0.4), 2.5))

	for part: String in PART_SPOTS:
		var interactable := Interactable.new()
		interactable.name = "Part_" + part
		interactable.interact_id = "shack:" + part
		interactable.collision_layer = Layers.INTERACT
		interactable.collision_mask = 0
		interactable.position = PART_SPOTS[part]
		var box := BoxShape3D.new()
		box.size = PART_SIZES[part]
		var collider := CollisionShape3D.new()
		collider.shape = box
		interactable.add_child(collider)
		var part_name := part
		interactable.text_provider = func(player: Node) -> String:
			if GameState.world == null or GameState.world.camp == null:
				return ""
			return GameState.world.camp.shack_prompt(part_name, player)
		node.add_child(interactable)
	return node


static func _dock(shape: CampIsland, shack: Dictionary) -> Node3D:
	var node := Node3D.new()
	node.name = "Dock"
	var start: Vector3 = shack.dock_start
	var end: Vector3 = shack.dock_end
	var along := end - start
	var length := along.length()
	var dir := along / length
	var basis := Basis.looking_at(dir, Vector3.UP)
	var deck := Materials.wood(Color(0.6, 0.52, 0.41))
	var dark := Materials.wood(DARK_WOOD)
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	body.transform = Transform3D(basis, (start + end) * 0.5 - Vector3(0.0, 0.06, 0.0))
	var walk := BoxShape3D.new()
	walk.size = Vector3(DOCK_WIDTH, 0.12, length)
	var collider := CollisionShape3D.new()
	collider.shape = walk
	body.add_child(collider)
	node.add_child(body)
	var plank := BoxMesh.new()
	plank.size = Vector3(DOCK_WIDTH, 0.1, 0.27)
	var count := int(length / 0.3)
	for i in count:
		var visual := MeshInstance3D.new()
		visual.mesh = plank
		visual.material_override = deck if i % 5 != 2 else dark
		visual.transform = Transform3D(basis.rotated(Vector3.UP, 0.015 * sin(i * 2.7)), start + dir * (i + 0.5) * length / count - Vector3(0.0, 0.05, 0.0))
		node.add_child(visual)
	var right := basis * Vector3.RIGHT
	# Stringers under the planks, and a fender along the boat side so a moored
	# boat bumps against the dock instead of sliding under it.
	var stringer := BoxMesh.new()
	stringer.size = Vector3(0.12, 0.16, length)
	for s: float in [-0.5, 0.5]:
		var beam := MeshInstance3D.new()
		beam.mesh = stringer
		beam.material_override = dark
		beam.transform = Transform3D(basis, (start + end) * 0.5 + right * s - Vector3(0.0, 0.18, 0.0))
		node.add_child(beam)
	var boat_side := signf(right.dot(Transform3D(shack.boat_xf).origin - start))
	var fender := StaticBody3D.new()
	fender.collision_layer = Layers.WORLD
	fender.collision_mask = 0
	fender.transform = Transform3D(basis, (start + end) * 0.5 + right * boat_side * (DOCK_WIDTH * 0.5 + 0.08) - Vector3(0.0, 0.75, 0.0))
	var fender_shape := BoxShape3D.new()
	fender_shape.size = Vector3(0.14, 1.7, length)
	var fender_collider := CollisionShape3D.new()
	fender_collider.shape = fender_shape
	fender.add_child(fender_collider)
	node.add_child(fender)
	# A plank path up the beach from the dock to the shack's steps.
	var door: Vector3 = Transform3D(shack.xf) * Vector3(0.0, 0.0, -SIZE.z * 0.5 - 1.0)
	var path_from := Vector3(start.x, 0.0, start.z) - dir * 0.3
	var path_dir := (Vector3(door.x, 0.0, door.z) - path_from).normalized()
	var steps := int(Vector2(door.x - path_from.x, door.z - path_from.z).length() / 0.75)
	for i in steps:
		var p := path_from.lerp(Vector3(door.x, 0.0, door.z), (i + 0.5) / steps)
		p.y = shape.height_at(p.x, p.z) + 0.04
		var board := MeshInstance3D.new()
		board.mesh = plank
		board.material_override = deck
		board.transform = Transform3D(Basis.looking_at(path_dir, Vector3.UP).rotated(Vector3.UP, 0.08 * sin(i * 3.3)), p)
		board.scale = Vector3(0.7, 0.6, 1.0)
		node.add_child(board)
	var spacing := 3.0
	var piles := int(length / spacing) + 1
	for i in piles:
		for s: float in [-1.0, 1.0]:
			var top := start + dir * i * spacing + right * s * (DOCK_WIDTH * 0.5 - 0.05)
			var bed := shape.height_at(top.x, top.z) - 0.6
			_post(node, Vector3(top.x, bed, top.z), top + Vector3(0.0, 0.05, 0.0), 0.09, dark)
	for post: Vector3 in shack.posts:
		var bed := shape.height_at(post.x, post.z) - 0.6
		_post(node, Vector3(post.x, bed, post.z), post + Vector3(0.0, 0.15, 0.0), 0.12, dark)
		var pillar := StaticBody3D.new()
		pillar.collision_layer = Layers.WORLD
		pillar.collision_mask = 0
		pillar.position = post - Vector3(0.0, 0.6, 0.0)
		var column := CylinderShape3D.new()
		column.radius = 0.12
		column.height = 1.6
		var pillar_collider := CollisionShape3D.new()
		pillar_collider.shape = column
		pillar.add_child(pillar_collider)
		node.add_child(pillar)
	return node
