class_name Sailboat
extends Boat
## The abandoned cruising sailboat moored in the camp island's cove — the crew's
## first real home. Lines to posts on the beach and an anchor hold it in place;
## a companionway leads down to a cabin with a bunk, sea chest, galley stove,
## chart table, crew lockers and a locked compartment.
##
## Boat space: bow toward -Z, stern (with the boarding ladder) toward +Z.

const LENGTH := 11.2
const BEAM := 3.7
const FLOOR_Y := 0.25
const DECK_Y := 1.6
const ROOF_Y := 2.4
const CABIN_FORE := -3.0
const CABIN_AFT := 3.2
const STAIRS_BOTTOM := 1.2
const BUNK_SPAWN := Vector3(0.0, FLOOR_Y + 0.05, -1.4)
const LADDER_LANDING := Vector3(0.0, DECK_Y + 0.05, 4.4)
## °C of shelter below deck, plus more while the galley stove burns.
const CABIN_WARMTH := 6.0
const STOVE_WARMTH := 6.0
const LINE_STIFFNESS := 6000.0
const LINE_DAMPING := 3000.0
const LINE_SLACK := 1.04

const HULL := Color(0.90, 0.90, 0.87)
const STRIPE := Color(0.12, 0.20, 0.36)
const TEAK := Color(0.62, 0.47, 0.30)
const DARK := Color(0.10, 0.11, 0.13)

## part name -> Interactable
var parts := {}
## {"local": boat-space cleat, "anchor": world point, "length": metres}
var mooring: Array[Dictionary] = []
var _ropes: Array[MeshInstance3D] = []
var _stove_glow: OmniLight3D


## Where the boat sits in the cove and where its lines run.
static func mooring_layout(shape: CampIsland) -> Dictionary:
	var out := Vector2.from_angle(shape.cove_bearing)
	var side := out.orthogonal()
	var boat_xz := shape.cove + out * 24.0
	var yaw := atan2(-out.x, -out.y)
	var posts: Array[Vector3] = []
	for s: float in [-5.0, 5.0]:
		var p := shape.cove + side * s - out * 1.5
		posts.append(Vector3(p.x, shape.height_at(p.x, p.y) + 0.9, p.y))
	var anchor_xz := boat_xz + out * 20.0
	var anchor := Vector3(anchor_xz.x, shape.height_at(anchor_xz.x, anchor_xz.y) + 0.3, anchor_xz.y)
	var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(boat_xz.x, -0.7, boat_xz.y))
	var cleats := [Vector3(-1.6, DECK_Y + 0.1, LENGTH * 0.5 - 0.2), Vector3(1.6, DECK_Y + 0.1, LENGTH * 0.5 - 0.2)]
	var lines: Array[Dictionary] = []
	for cleat: Vector3 in cleats:
		var world_cleat := xf * cleat
		var nearest := posts[0] if world_cleat.distance_to(posts[0]) < world_cleat.distance_to(posts[1]) else posts[1]
		lines.append({"local": cleat, "anchor": nearest})
	lines.append({"local": Vector3(0.0, DECK_Y + 0.1, -LENGTH * 0.5 - 0.3), "anchor": anchor})
	return {"transform": xf, "lines": lines, "posts": posts, "anchor": anchor}


static func create(index: int) -> Sailboat:
	var boat := Sailboat.new()
	boat.name = "Sailboat"
	boat.proxy_index = index
	boat.mass = 3500.0
	boat.can_paddle = false
	boat.float_depth = 0.7
	boat.water_drag = 0.6
	boat.water_angular_drag = 1.5
	boat.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	boat.center_of_mass = Vector3(0.0, 0.35, 0.0)
	boat.deck_top = DECK_Y
	boat.hull_aabb = AABB(Vector3(-BEAM * 0.5, 0.0, -LENGTH * 0.5 - 1.2), Vector3(BEAM, ROOF_Y, LENGTH + 1.4))
	# Cover the hull's full outer footprint: the walls hide any water inside their
	# thickness, and a mask even a few centimetres short shows strips of sea indoors.
	boat.water_mask = AABB(Vector3(-BEAM * 0.5, FLOOR_Y - 0.3, -LENGTH * 0.5), Vector3(BEAM, DECK_Y - FLOOR_Y + 0.6, LENGTH))
	boat._build_hull()
	boat._build_cabin()
	boat._build_rig()
	for x: float in [-1.55, 1.55]:
		for z: float in [-4.8, -2.4, 0.0, 2.4, 4.8]:
			boat.probes.append(Vector3(x, 0.0, z))
	return boat


func _ready() -> void:
	super._ready()
	for part_name: String in parts:
		var node: Interactable = parts[part_name]
		node.text_provider = func(player: Node) -> String: return _part_prompt(part_name, player)


func moor(lines: Array) -> void:
	for rope in _ropes:
		rope.queue_free()
	_ropes.clear()
	mooring.clear()
	var rope_mesh := CylinderMesh.new()
	rope_mesh.top_radius = 0.025
	rope_mesh.bottom_radius = 0.025
	rope_mesh.height = 1.0
	rope_mesh.radial_segments = 5
	rope_mesh.rings = 1
	for line: Dictionary in lines:
		var cleat: Vector3 = line.local
		var anchor: Vector3 = line.anchor
		var length := (transform * cleat).distance_to(anchor) * LINE_SLACK
		mooring.append({"local": cleat, "anchor": anchor, "length": length})
		var rope := MeshInstance3D.new()
		rope.mesh = rope_mesh
		rope.material_override = Props.material("rope", Color(0.72, 0.64, 0.48))
		rope.top_level = true
		rope.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(rope)
		_ropes.append(rope)


func set_stove_lit(lit: bool) -> void:
	if _stove_glow != null:
		_stove_glow.visible = lit


func _process(_delta: float) -> void:
	var xf := get_global_transform_interpolated()
	for i in mini(_ropes.size(), mooring.size()):
		var from: Vector3 = xf * Vector3(mooring[i].local)
		var to: Vector3 = mooring[i].anchor
		var along := to - from
		var length := along.length()
		if length < 0.01:
			continue
		var y := along / length
		var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var z := x.cross(y)
		_ropes[i].global_transform = Transform3D(Basis(x, y * length, z), (from + to) * 0.5)


func _simulate() -> void:
	super._simulate()
	for line in mooring:
		var p := global_transform * Vector3(line.local)
		var to_anchor: Vector3 = Vector3(line.anchor) - p
		var distance := to_anchor.length()
		if distance <= float(line.length) or distance < 0.001:
			continue
		var dir := to_anchor / distance
		var closing := point_velocity(p).dot(dir)
		var tension := maxf(0.0, (distance - float(line.length)) * LINE_STIFFNESS - closing * LINE_DAMPING)
		apply_force(dir * tension, p - global_position)


func _part_prompt(part_name: String, player: Node) -> String:
	if GameState.world == null or GameState.world.camp == null:
		return ""
	if part_name == "ladder":
		return "" if player != null and player.platform == self else "Climb aboard"
	return GameState.world.camp.part_prompt(self, part_name, player)


# --- construction -----------------------------------------------------------

func _block(size: Vector3, pos: Vector3, color_key: String, color: Color, rot: Vector3 = Vector3.ZERO, solid: bool = true) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = Props.material(color_key, color)
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


func _part(part_name: String, size: Vector3, pos: Vector3) -> void:
	var part := Interactable.new()
	part.name = "Part_" + part_name
	part.interact_id = "boat:%s:%s" % [name, part_name]
	part.collision_layer = Layers.INTERACT
	part.collision_mask = 0
	part.position = pos
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	part.add_child(collider)
	add_child(part)
	parts[part_name] = part


func _build_hull() -> void:
	var half_l := LENGTH * 0.5
	var half_b := BEAM * 0.5
	_block(Vector3(BEAM, FLOOR_Y, LENGTH), Vector3(0.0, FLOOR_Y * 0.5, 0.0), "hull", HULL)
	_block(Vector3(BEAM, 0.02, LENGTH - 0.3), Vector3(0.0, FLOOR_Y + 0.01, 0.0), "teak", TEAK, Vector3.ZERO, false)
	for s: float in [-1.0, 1.0]:
		_block(Vector3(0.15, DECK_Y, LENGTH), Vector3(s * (half_b - 0.075), DECK_Y * 0.5, 0.0), "hull", HULL)
		_block(Vector3(0.02, 0.18, LENGTH), Vector3(s * (half_b + 0.01), DECK_Y - 0.35, 0.0), "stripe", STRIPE, Vector3.ZERO, false)
	_block(Vector3(BEAM, DECK_Y, 0.15), Vector3(0.0, DECK_Y * 0.5, half_l - 0.075), "hull", HULL)
	_block(Vector3(BEAM, DECK_Y, 0.15), Vector3(0.0, DECK_Y * 0.5, -half_l + 0.075), "hull", HULL)
	# A pointed bow: a turned block you can also stand on.
	_block(Vector3(BEAM * 0.7, DECK_Y, BEAM * 0.7), Vector3(0.0, DECK_Y * 0.5, -half_l), "hull", HULL, Vector3(0.0, PI / 4.0, 0.0))

	# Decks: foredeck, aft deck, and side walkways beside the deckhouse.
	var fore_length := CABIN_FORE + half_l
	_block(Vector3(BEAM, 0.12, fore_length), Vector3(0.0, DECK_Y - 0.06, -half_l + fore_length * 0.5), "teak", TEAK)
	var aft_length := half_l - CABIN_AFT
	_block(Vector3(BEAM, 0.12, aft_length), Vector3(0.0, DECK_Y - 0.06, CABIN_AFT + aft_length * 0.5), "teak", TEAK)
	var cabin_length := CABIN_AFT - CABIN_FORE
	var cabin_mid := (CABIN_AFT + CABIN_FORE) * 0.5
	for s: float in [-1.0, 1.0]:
		_block(Vector3(0.55, 0.12, cabin_length), Vector3(s * (half_b - 0.275), DECK_Y - 0.06, cabin_mid), "teak", TEAK)
		# Deckhouse side walls with dark windows.
		_block(Vector3(0.1, ROOF_Y - DECK_Y, cabin_length), Vector3(s * 1.25, (DECK_Y + ROOF_Y) * 0.5, cabin_mid), "hull", HULL)
		_block(Vector3(0.02, 0.28, 3.2), Vector3(s * 1.31, DECK_Y + 0.45, cabin_mid - 0.4), "window", DARK, Vector3.ZERO, false)
		# Rails.
		_block(Vector3(0.05, 0.55, LENGTH - 0.6), Vector3(s * (half_b - 0.03), DECK_Y + 0.3, -0.2), "rail", Color(0.75, 0.76, 0.78))
		_block(Vector3(half_b - 0.6, 0.55, 0.05), Vector3(s * (0.6 + (half_b - 0.6) * 0.5), DECK_Y + 0.3, half_l - 0.03), "rail", Color(0.75, 0.76, 0.78))
	_block(Vector3(2.5, ROOF_Y - DECK_Y, 0.1), Vector3(0.0, (DECK_Y + ROOF_Y) * 0.5, CABIN_FORE), "hull", HULL)
	for s: float in [-1.0, 1.0]:
		_block(Vector3(0.75, ROOF_Y - DECK_Y, 0.1), Vector3(s * 0.875, (DECK_Y + ROOF_Y) * 0.5, CABIN_AFT), "hull", HULL)
	# Deckhouse roof, open over the companionway stairs.
	var roof_length := STAIRS_BOTTOM - CABIN_FORE
	_block(Vector3(2.6, 0.1, roof_length), Vector3(0.0, ROOF_Y + 0.05, CABIN_FORE + roof_length * 0.5), "hull", HULL)
	var hatch_length := CABIN_AFT - STAIRS_BOTTOM
	for s: float in [-1.0, 1.0]:
		_block(Vector3(0.8, 0.1, hatch_length), Vector3(s * 0.9, ROOF_Y + 0.05, STAIRS_BOTTOM + hatch_length * 0.5), "hull", HULL)
	# Companionway stairs, down from the aft deck into the cabin.
	var rise := DECK_Y - FLOOR_Y
	var run := CABIN_AFT - STAIRS_BOTTOM
	_block(Vector3(1.0, 0.08, sqrt(rise * rise + run * run)), Vector3(0.0, (DECK_Y + FLOOR_Y) * 0.5 - 0.04, (CABIN_AFT + STAIRS_BOTTOM) * 0.5), "teak", TEAK, Vector3(-atan2(rise, run), 0.0, 0.0))
	# Boarding ladder on the transom.
	for s: float in [-0.3, 0.3]:
		_block(Vector3(0.05, DECK_Y, 0.05), Vector3(s, DECK_Y * 0.5, half_l + 0.1), "rail", Color(0.75, 0.76, 0.78), Vector3.ZERO, false)
	for step in 4:
		_block(Vector3(0.6, 0.04, 0.12), Vector3(0.0, 0.3 + step * 0.35, half_l + 0.12), "rail", Color(0.75, 0.76, 0.78), Vector3.ZERO, false)
	_part("ladder", Vector3(1.0, 2.0, 0.6), Vector3(0.0, 0.8, half_l + 0.2))


func _build_cabin() -> void:
	# Warm wood panelling below deck, so the cabin reads as a cosy interior rather
	# than bare white hull lit blue by the sky.
	var panel := Color(0.70, 0.55, 0.38)
	var panel_height := DECK_Y - FLOOR_Y - 0.06
	var panel_y := FLOOR_Y + panel_height * 0.5
	for s: float in [-1.0, 1.0]:
		_block(Vector3(0.02, panel_height, LENGTH - 0.5), Vector3(s * (BEAM * 0.5 - 0.17), panel_y, 0.0), "cabin_panel", panel, Vector3.ZERO, false)
	_block(Vector3(BEAM - 0.4, panel_height, 0.02), Vector3(0.0, panel_y, LENGTH * 0.5 - 0.17), "cabin_panel", panel, Vector3.ZERO, false)
	# V-berth under the foredeck.
	_block(Vector3(2.6, 0.5, 2.0), Vector3(0.0, FLOOR_Y + 0.25, -3.9), "bunk", Color(0.30, 0.38, 0.52))
	_block(Vector3(2.2, 0.08, 1.6), Vector3(0.0, FLOOR_Y + 0.54, -3.9), "sheet", Color(0.86, 0.84, 0.78), Vector3.ZERO, false)
	_part("bunk", Vector3(2.6, 0.9, 2.0), Vector3(0.0, FLOOR_Y + 0.5, -3.7))
	# Sea chest (the stash).
	_block(Vector3(0.9, 0.55, 0.55), Vector3(-1.2, FLOOR_Y + 0.275, -1.9), "chest", Color(0.45, 0.30, 0.16))
	_part("chest", Vector3(1.0, 0.8, 0.7), Vector3(-1.2, FLOOR_Y + 0.35, -1.9))
	# Galley stove.
	_block(Vector3(0.7, 0.9, 0.6), Vector3(1.3, FLOOR_Y + 0.45, -1.8), "stove", Color(0.35, 0.36, 0.38))
	_block(Vector3(0.5, 0.02, 0.4), Vector3(1.3, FLOOR_Y + 0.91, -1.8), "burner", DARK, Vector3.ZERO, false)
	_part("stove", Vector3(0.8, 1.1, 0.7), Vector3(1.3, FLOOR_Y + 0.55, -1.8))
	_stove_glow = OmniLight3D.new()
	_stove_glow.light_color = Color(1.0, 0.55, 0.2)
	_stove_glow.light_energy = 1.0
	_stove_glow.omni_range = 3.0
	_stove_glow.position = Vector3(1.3, FLOOR_Y + 1.1, -1.8)
	_stove_glow.visible = false
	add_child(_stove_glow)
	# Chart table.
	_block(Vector3(0.8, 0.75, 0.9), Vector3(1.3, FLOOR_Y + 0.375, 0.4), "chart_table", TEAK)
	_block(Vector3(0.6, 0.01, 0.7), Vector3(1.3, FLOOR_Y + 0.76, 0.4), "chart_paper", Color(0.85, 0.82, 0.70), Vector3.ZERO, false)
	_part("chart", Vector3(0.9, 1.0, 1.0), Vector3(1.3, FLOOR_Y + 0.5, 0.4))
	# Crew lockers.
	_block(Vector3(0.5, 1.25, 1.2), Vector3(-1.4, FLOOR_Y + 0.625, 0.4), "lockers", Color(0.55, 0.42, 0.28))
	_part("lockers", Vector3(0.7, 1.3, 1.3), Vector3(-1.3, FLOOR_Y + 0.65, 0.4))
	# The locked compartment, low under the side deck.
	_block(Vector3(0.5, 0.4, 0.5), Vector3(-1.35, FLOOR_Y + 0.2, -0.8), "compartment", Color(0.32, 0.24, 0.15))
	_block(Vector3(0.06, 0.08, 0.02), Vector3(-1.1, FLOOR_Y + 0.25, -0.8), "brass", Color(0.8, 0.65, 0.25), Vector3.ZERO, false)
	_part("compartment", Vector3(0.7, 0.6, 0.7), Vector3(-1.3, FLOOR_Y + 0.3, -0.8))
	# Cabin lantern.
	var lantern := OmniLight3D.new()
	lantern.light_color = Color(1.0, 0.82, 0.55)
	lantern.light_energy = 1.1
	lantern.omni_range = 6.0
	lantern.position = Vector3(0.0, ROOF_Y - 0.35, -0.6)
	add_child(lantern)


func _build_rig() -> void:
	var mast_mesh := CylinderMesh.new()
	mast_mesh.top_radius = 0.08
	mast_mesh.bottom_radius = 0.11
	mast_mesh.height = 11.0
	mast_mesh.radial_segments = 6
	var mast := MeshInstance3D.new()
	mast.mesh = mast_mesh
	mast.material_override = Props.material("mast", Color(0.78, 0.78, 0.76))
	mast.position = Vector3(0.0, DECK_Y + 5.5, -3.7)
	add_child(mast)
	var mast_shape := CylinderShape3D.new()
	mast_shape.radius = 0.12
	mast_shape.height = 11.0
	var mast_collider := CollisionShape3D.new()
	mast_collider.shape = mast_shape
	mast_collider.position = mast.position
	add_child(mast_collider)
	_block(Vector3(0.1, 0.1, 4.2), Vector3(0.0, DECK_Y + 1.9, -1.5), "mast", Color(0.78, 0.78, 0.76), Vector3.ZERO, false)
	# What's left of the mainsail: a torn scrap flapping from the mast.
	_block(Vector3(0.02, 4.0, 1.6), Vector3(0.05, DECK_Y + 5.0, -2.8), "torn_sail", Color(0.82, 0.80, 0.74), Vector3(0.0, 0.25, 0.08), false)
	_block(Vector3(0.02, 1.8, 0.9), Vector3(0.05, DECK_Y + 2.6, -2.2), "torn_sail", Color(0.82, 0.80, 0.74), Vector3(0.1, -0.35, -0.2), false)
