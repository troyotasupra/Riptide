class_name Sailboat
extends Boat
## The abandoned sloop moored in the camp island's cove — the crew's first real
## home. A round-bellied wooden hull with a raised quarterdeck and ship's wheel,
## one mast with a crow's nest and a square sail on its yard (torn), a bowsprit,
## capstan and cannons. A hatch amidships leads below to the cabin: bunk, sea
## chest, galley stove, chart table, crew lockers and a locked compartment.
## Lines to posts on the beach and an anchor hold her in place.
##
## Boat space: bow toward -Z, stern (with the quarterdeck) toward +Z. The hull is
## drawn as a smooth lofted shell; walking and standing use simple boxes inside it.

const LENGTH := 12.0
const BEAM := 4.2
const KEEL_Y := -1.1
const FLOOR_Y := -0.3
const DECK_Y := 1.8
const QUARTER_Y := 2.7
const BULWARK := 0.55
## Bottom of the section is flatter the lower this is (0.5 = round, 0.3 = full).
const FULLNESS := 0.3
const CABIN_FORE := -2.6
const CABIN_AFT := 4.0
const CABIN_HALF := 1.2
const HATCH_FORE := 0.2
const HATCH_AFT := 3.0
const HATCH_HALF := 0.45
const MAST_Z := -1.0
const MAST_TOP := DECK_Y + 13.0
const YARD_Y := DECK_Y + 8.9
const HELM := Vector3(0.0, QUARTER_Y, 4.3)
const LADDER_Z := -3.3
const BUNK_SPAWN := Vector3(0.0, FLOOR_Y + 0.05, -0.2)
const LADDER_LANDING := Vector3(0.85, DECK_Y + 0.05, LADDER_Z)
const LADDER_LANDING_PORT := Vector3(-0.85, DECK_Y + 0.05, LADDER_Z)
## °C of shelter below deck, plus more while the galley stove burns.
const CABIN_WARMTH := 6.0
const STOVE_WARMTH := 6.0
const LINE_STIFFNESS := 6000.0
const LINE_DAMPING := 3000.0
const LINE_SLACK := 1.04

const HULL_WOOD := Color(0.55, 0.36, 0.22)
const TAR := Color(0.10, 0.08, 0.07)
const DECK_WOOD := Color(0.66, 0.51, 0.34)
const PANEL_WOOD := Color(0.56, 0.40, 0.25)
const GOLD := Color(0.80, 0.62, 0.26)
const IRON := Color(0.16, 0.16, 0.17)
const ROPE := Color(0.70, 0.60, 0.44)
const SAIL := Color(0.88, 0.84, 0.74)

## part name -> Interactable
var parts := {}
## {"local": boat-space cleat, "anchor": world point, "length": metres}
var mooring: Array[Dictionary] = []
var _ropes: Array[MeshInstance3D] = []
var _stove_glow: OmniLight3D
var _flag: Node3D

static var _mats := {}
static var _unit_cylinder: CylinderMesh


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
	var cleats := [Vector3(-1.3, QUARTER_Y + 0.35, LENGTH * 0.5 - 0.3), Vector3(1.3, QUARTER_Y + 0.35, LENGTH * 0.5 - 0.3)]
	var lines: Array[Dictionary] = []
	for cleat: Vector3 in cleats:
		var world_cleat := xf * cleat
		var nearest := posts[0] if world_cleat.distance_to(posts[0]) < world_cleat.distance_to(posts[1]) else posts[1]
		lines.append({"local": cleat, "anchor": nearest})
	lines.append({"local": Vector3(-0.55, DECK_Y + 0.35, -LENGTH * 0.5 + 0.35), "anchor": anchor})
	return {"transform": xf, "lines": lines, "posts": posts, "anchor": anchor}


## Where the n-th crew member wakes aboard: the cabin first, then the main deck.
static func crew_spawn(index: int) -> Vector3:
	var spots := [BUNK_SPAWN, Vector3(0.0, DECK_Y + 0.05, -2.4), Vector3(-0.9, DECK_Y + 0.05, -0.2),
		Vector3(0.9, DECK_Y + 0.05, -0.2), Vector3(0.0, DECK_Y + 0.05, -4.9), Vector3(0.0, QUARTER_Y + 0.05, 5.3)]
	return spots[index % spots.size()]


static func create(index: int) -> Sailboat:
	var boat := Sailboat.new()
	boat.name = "Sailboat"
	boat.proxy_index = index
	boat.mass = 3800.0
	boat.can_paddle = false
	boat.float_depth = 0.7
	boat.water_drag = 0.6
	boat.water_angular_drag = 1.5
	boat.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	boat.center_of_mass = Vector3(0.0, 0.2, 0.0)
	boat.deck_top = DECK_Y
	boat.hull_aabb = AABB(Vector3(-BEAM * 0.5, FLOOR_Y - 0.1, -LENGTH * 0.5), Vector3(BEAM, QUARTER_Y + 1.6 - FLOOR_Y, LENGTH))
	# The cabin sits below the waterline: keep the sea out of it. The hull shell
	# and the cabin panelling hide the gap between this box and the planking.
	boat.water_mask = AABB(Vector3(-CABIN_HALF, FLOOR_Y - 0.3, CABIN_FORE), Vector3(CABIN_HALF * 2.0, DECK_Y - FLOOR_Y + 0.5, CABIN_AFT - CABIN_FORE))
	boat._build_hull()
	boat._build_decks()
	boat._build_cabin()
	boat._build_fittings()
	boat._build_rig()
	for x: float in [-1.35, 1.35]:
		for z: float in [-4.0, -2.0, 0.0, 2.0, 4.0]:
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
	for line: Dictionary in lines:
		var cleat: Vector3 = line.local
		var anchor: Vector3 = line.anchor
		var length := (transform * cleat).distance_to(anchor) * LINE_SLACK
		mooring.append({"local": cleat, "anchor": anchor, "length": length})
		var rope := MeshInstance3D.new()
		rope.mesh = _cylinder()
		rope.material_override = _mat("rope")
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
		_ropes[i].global_transform = _rope_transform(from, mooring[i].anchor, 0.03)


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


## Where a boarding ladder part puts you on deck.
static func ladder_landing(part_name: String) -> Vector3:
	return LADDER_LANDING_PORT if part_name == "ladder_port" else LADDER_LANDING


func _part_prompt(part_name: String, player: Node) -> String:
	if GameState.world == null or GameState.world.camp == null:
		return ""
	if part_name.begins_with("ladder"):
		return "" if player != null and player.platform == self else "Climb aboard"
	return GameState.world.camp.part_prompt(self, part_name, player)


# --- hull shape ------------------------------------------------------------------

## 0 at the bow tip, 1 at the transom.
static func _u(z: float) -> float:
	return clampf((z + LENGTH * 0.5) / LENGTH, 0.0, 1.0)


## Half the hull's width at the top of its side, at boat-space `z`.
static func hull_half_width(z: float) -> float:
	var u := _u(z)
	var f := 0.0
	if u < 0.45:
		var k := (0.45 - u) / 0.45
		f = sqrt(maxf(0.0, 1.0 - k * k))
	else:
		var k := (u - 0.45) / 0.55
		f = 1.0 - 0.25 * k * k
	return BEAM * 0.5 * f


## Height of the top of the bulwark: sweeping up to the bow and over the quarterdeck.
static func sheer_y(z: float) -> float:
	var u := _u(z)
	var bow := maxf(0.0, 1.0 - u / 0.25)
	return DECK_Y + BULWARK + 0.7 * bow * bow + (QUARTER_Y - DECK_Y) * smoothstep(0.70, 0.76, u)


## Bottom of the keel: rising into the stem at the bow and up to the transom.
static func keel_y(z: float) -> float:
	var u := _u(z)
	if u < 0.3:
		var k := 1.0 - u / 0.3
		return KEEL_Y + (1.0 - KEEL_Y) * k * k
	if u > 0.85:
		var k := (u - 0.85) / 0.15
		return KEEL_Y + 0.6 * k * k
	return KEEL_Y


## Distance of the outer planking from the centreline at (`z`, height `y`).
static func hull_x(z: float, y: float) -> float:
	var ky := keel_y(z)
	var t := clampf((y - ky) / maxf(sheer_y(z) - ky, 0.01), 0.0, 1.0)
	return hull_half_width(z) * pow(sin(t * PI * 0.5), FULLNESS)


static func _section_point(z: float, t: float, side: float, inset: float = 0.0) -> Vector3:
	var ky := keel_y(z)
	var y := lerpf(ky, sheer_y(z), t)
	var x := maxf(0.0, hull_half_width(z) * pow(sin(t * PI * 0.5), FULLNESS) - inset)
	return Vector3(side * x, y, z)


# --- building helpers -----------------------------------------------------------

static func _mat(key: String) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m: StandardMaterial3D
	match key:
		"hull", "hull_inner":
			# Strakes: plank seams run the length of the hull, following its curve.
			m = StandardMaterial3D.new()
			m.albedo_color = HULL_WOOD if key == "hull" else HULL_WOOD.lightened(0.12)
			m.albedo_texture = _plank_texture()
			m.uv1_scale = Vector3(1.0, 3.0, 1.0)
			m.roughness = 0.85
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"tar":
			m = Materials.wood(TAR).duplicate()
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"deck", "panel":
			m = StandardMaterial3D.new()
			m.albedo_color = DECK_WOOD if key == "deck" else PANEL_WOOD
			m.albedo_texture = _plank_texture()
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(0.55, 0.55, 0.55)
			m.roughness = 0.85
		"dark_wood":
			m = Materials.wood(Color(0.30, 0.19, 0.11))
		"gold":
			m = Materials.metal(GOLD, 0.3)
		"iron":
			m = Materials.metal(IRON, 0.5)
		"rope":
			m = Materials.cloth(ROPE)
		"sail":
			# The torn mainsail: rips and a ragged hem cut out by an alpha mask, so the
			# edges are frayed rather than blocky and the corners still hold their lines.
			m = StandardMaterial3D.new()
			m.albedo_color = SAIL
			m.albedo_texture = _sail_texture()
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.5
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
			m.roughness = 1.0
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"jib":
			m = Materials.cloth(SAIL.darkened(0.04)).duplicate()
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"blanket":
			m = Materials.cloth(Color(0.24, 0.32, 0.50))
		"linen":
			m = Materials.cloth(Color(0.86, 0.83, 0.76))
		"paper":
			m = Materials.plain(Color(0.86, 0.80, 0.64))
		"window":
			m = Materials.glow(Color(1.0, 0.72, 0.36), 0.6)
		"lantern":
			m = Materials.glow(Color(1.0, 0.75, 0.40), 3.0)
		_:
			m = Materials.plain(Color.MAGENTA)
	_mats[key] = m
	return m


static var _planks: ImageTexture
static var _sail: ImageTexture


## Light wood grain with dark seams between planks (across u) and staggered butt joints.
static func _plank_texture() -> ImageTexture:
	if _planks != null:
		return _planks
	var width := 128
	var height := 512
	var planks := 8
	var noise := FastNoiseLite.new()
	noise.seed = 31
	noise.frequency = 0.05
	var image := Image.create(width, height, false, Image.FORMAT_RGB8)
	for x in width:
		var plank := x * planks / width
		var along := x - plank * width / planks
		var shade := 0.9 + 0.08 * sin(plank * 12.9898)
		var joint := int(fposmod(plank * 173.0, float(height)))
		for y in height:
			var grain := noise.get_noise_2d(x * 1.5, y * 0.12)
			var v := shade + grain * 0.12
			if along < 2:
				v *= 0.45
			elif along == 2:
				v *= 0.8
			if absi(y - joint) < 2:
				v *= 0.55
			image.set_pixel(x, y, Color(v, v * 0.97, v * 0.93))
	image.generate_mipmaps()
	_planks = ImageTexture.create_from_image(image)
	return _planks


## Canvas with a ragged hem, a long rip and a hole; the corners stay whole.
static func _sail_texture() -> ImageTexture:
	if _sail != null:
		return _sail
	var size := 256
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.3
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for py in size:
		var yn := (py + 0.5) / size
		for px in size:
			var xn := (px + 0.5) / size
			# Smooth, large-scale fraying only: fine noise turns into speckled pinholes.
			var fray := noise.get_noise_1d(xn * 14.0) * 0.5 + noise.get_noise_1d(xn * 45.0 + 9.0) * 0.18
			var keep := true
			if yn > 0.7 + fray * 0.18:
				keep = false
			if yn > 0.25 and yn < 0.72 and absf(xn - 0.3 - yn * 0.14) < 0.008 + 0.008 * sin(yn * 9.0):
				keep = false
			if Vector2(xn - 0.66, (yn - 0.42) * 1.3).length() < 0.07 + noise.get_noise_1d(atan2(yn - 0.42, xn - 0.66) * 3.0) * 0.02:
				keep = false
			var tone := 0.93 + noise.get_noise_2d(xn * 8.0, yn * 3.0) * 0.05
			image.set_pixel(px, py, Color(tone, tone, tone * 0.97, 1.0 if keep else 0.0))
	_sail = ImageTexture.create_from_image(image)
	return _sail


static func _cylinder() -> CylinderMesh:
	if _unit_cylinder == null:
		_unit_cylinder = CylinderMesh.new()
		_unit_cylinder.top_radius = 1.0
		_unit_cylinder.bottom_radius = 1.0
		_unit_cylinder.height = 1.0
		_unit_cylinder.radial_segments = 6
		_unit_cylinder.rings = 1
	return _unit_cylinder


## A unit cylinder stretched from `a` to `b` with the given radius.
static func _rope_transform(a: Vector3, b: Vector3, radius: float) -> Transform3D:
	var along := b - a
	var length := along.length()
	if length < 0.001:
		return Transform3D(Basis.from_scale(Vector3.ONE * 0.001), a)
	var y := along / length
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	return Transform3D(Basis(x * radius, y * length, z * radius), (a + b) * 0.5)


func _rope(a: Vector3, b: Vector3, radius: float = 0.022, key: String = "rope") -> MeshInstance3D:
	var rope := MeshInstance3D.new()
	rope.mesh = _cylinder()
	rope.material_override = _mat(key)
	rope.transform = _rope_transform(a, b, radius)
	add_child(rope)
	return rope


func _mesh(mesh: Mesh, key: String, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _mat(key)
	visual.position = pos
	visual.rotation = rot
	visual.scale = scl
	add_child(visual)
	return visual


func _solid(shape: Shape3D, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = pos
	collider.rotation = rot
	add_child(collider)


func _box(size: Vector3, pos: Vector3, key: String, rot: Vector3 = Vector3.ZERO, solid: bool = true) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := _mesh(mesh, key, pos, rot)
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		_solid(shape, pos, rot)
	return visual


## An invisible wall or floor.
func _block(size: Vector3, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	_solid(shape, pos, rot)


func _round(radius: float, height: float, pos: Vector3, key: String, solid: bool = true, sides: int = 16) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	var visual := _mesh(mesh, key, pos)
	if solid:
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		_solid(shape, pos)
	return visual


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


## A smooth surface through rows of points (rows × columns), normals generated.
static func _sheet(rows: Array, flip: bool) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var columns: int = (rows[0] as PackedVector3Array).size()
	for r in rows.size():
		var row: PackedVector3Array = rows[r]
		for c in columns:
			vertices.append(row[c])
			uvs.append(Vector2(float(c) / (columns - 1), float(r) / (rows.size() - 1)))
	for r in rows.size() - 1:
		for c in columns - 1:
			var a := r * columns + c
			var b := a + columns
			if flip:
				indices.append_array([a, a + 1, b, a + 1, b + 1, b])
			else:
				indices.append_array([a, b, a + 1, a + 1, b, b + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	return MeshKit._with_normals(arrays)


# --- construction ---------------------------------------------------------------

## The lofted hull: tarred below the waterline, planked above, a lighter inner
## face on the bulwarks, a cap rail, gilded wales and a windowed transom.
func _build_hull() -> void:
	var stations := 40
	var rings := 10
	for side: float in [-1.0, 1.0]:
		var lower := []
		var upper := []
		var inner := []
		var cap := []
		var wale := PackedVector3Array()
		var wale_r := PackedFloat32Array()
		for i in stations + 1:
			var z := lerpf(-LENGTH * 0.5, LENGTH * 0.5, float(i) / stations)
			var ky := keel_y(z)
			var sy := sheer_y(z)
			var t_wl := clampf((0.62 - ky) / (sy - ky), 0.02, 0.98)
			var deck := lerpf(DECK_Y, QUARTER_Y, smoothstep(HATCH_AFT - 0.1, HATCH_AFT + 0.1, z))
			var t_deck := clampf((deck - 0.2 - ky) / (sy - ky), 0.0, 0.97)
			var low := PackedVector3Array()
			var high := PackedVector3Array()
			var face := PackedVector3Array()
			for j in rings + 1:
				var k := float(j) / rings
				low.append(_section_point(z, t_wl * k, side))
				high.append(_section_point(z, lerpf(t_wl, 1.0, k), side))
				face.append(_section_point(z, lerpf(t_deck, 1.0, k), side, 0.1))
			lower.append(low)
			upper.append(high)
			inner.append(face)
			cap.append(PackedVector3Array([_section_point(z, 1.0, side) + Vector3.UP * 0.03, _section_point(z, 1.0, side, 0.1) + Vector3.UP * 0.03]))
			if z > -5.3 and z < LENGTH * 0.5 - 0.05:
				var wy := DECK_Y - 0.2
				wale.append(Vector3(side * (hull_x(z, wy) + 0.02), wy, z))
				wale_r.append(0.045)
		var flip := side < 0.0
		_mesh(_sheet(lower, flip), "tar")
		_mesh(_sheet(upper, flip), "hull")
		_mesh(_sheet(inner, not flip), "hull_inner")
		_mesh(_sheet(cap, flip), "hull_inner")
		_mesh(MeshKit.tube(wale, wale_r, 6), "gold")

	# Transom: close the stern section, with a gilded frame and warm windows.
	var zs := LENGTH * 0.5
	var outline := PackedVector3Array()
	for j in range(rings, -1, -1):
		outline.append(_section_point(zs, float(j) / rings, -1.0))
	for j in range(1, rings + 1):
		outline.append(_section_point(zs, float(j) / rings, 1.0))
	var vertices := PackedVector3Array([Vector3(0.0, (keel_y(zs) + sheer_y(zs)) * 0.5, zs)])
	vertices.append_array(outline)
	var indices := PackedInt32Array()
	for j in outline.size() - 1:
		indices.append_array([0, j + 1, j + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	_mesh(MeshKit._with_normals(arrays), "hull")
	var trim := PackedVector3Array()
	var trim_r := PackedFloat32Array()
	for p in outline:
		if p.y > 0.9:
			trim.append(p + Vector3(0.0, 0.0, 0.03))
			trim_r.append(0.05)
	_mesh(MeshKit.tube(trim, trim_r, 6), "gold")
	for x: float in [-0.75, 0.0, 0.75]:
		_box(Vector3(0.46, 0.56, 0.04), Vector3(x, DECK_Y + 0.35, zs + 0.03), "gold", Vector3.ZERO, false)
		_box(Vector3(0.36, 0.44, 0.04), Vector3(x, DECK_Y + 0.35, zs + 0.05), "window", Vector3.ZERO, false)
	# Rudder and a keel fin below the waterline.
	_box(Vector3(0.14, 2.0, 0.8), Vector3(0.0, -0.1, zs + 0.3), "tar", Vector3.ZERO, false)
	_box(Vector3(0.18, 0.35, 7.5), Vector3(0.0, KEEL_Y - 0.1, 0.4), "tar", Vector3.ZERO, false)


## Walkable decks, invisible bulwark walls, companionway and quarterdeck stairs.
func _build_decks() -> void:
	# [fore z, aft z, half width, deck height]
	var segments := [[-5.6, -4.4, 0.65, DECK_Y], [-4.4, -2.8, 1.35, DECK_Y], [-2.8, HATCH_AFT, 1.8, DECK_Y],
		[HATCH_AFT, 4.8, 1.6, QUARTER_Y], [4.8, 5.95, 1.4, QUARTER_Y]]
	for seg: Array in segments:
		var z0: float = seg[0]
		var z1: float = seg[1]
		var half: float = seg[2]
		var top: float = seg[3]
		var mid := (z0 + z1) * 0.5
		if z0 < HATCH_FORE and z1 > HATCH_FORE:
			# Split around the companionway hatch.
			_box(Vector3(half * 2.0, 0.12, HATCH_FORE - z0), Vector3(0.0, top - 0.06, (z0 + HATCH_FORE) * 0.5), "deck")
			for s: float in [-1.0, 1.0]:
				var strip := half - HATCH_HALF
				_box(Vector3(strip, 0.12, z1 - HATCH_FORE), Vector3(s * (HATCH_HALF + strip * 0.5), top - 0.06, (HATCH_FORE + z1) * 0.5), "deck")
		else:
			_box(Vector3(half * 2.0, 0.12, z1 - z0), Vector3(0.0, top - 0.06, mid), "deck")
		for s: float in [-1.0, 1.0]:
			_block(Vector3(0.12, 0.7, z1 - z0 + 0.1), Vector3(s * (half + 0.1), top + 0.35, mid))
	_block(Vector3(1.4, 0.7, 0.12), Vector3(0.0, DECK_Y + 0.35, -5.66))
	_block(Vector3(3.0, 0.7, 0.12), Vector3(0.0, QUARTER_Y + 0.35, 6.02))
	# Under the quarterdeck: the cabin ceiling, and the quarterdeck's face.
	_box(Vector3(3.2, 0.12, 5.95 - HATCH_AFT), Vector3(0.0, DECK_Y - 0.06, (HATCH_AFT + 5.95) * 0.5), "panel")
	_box(Vector3(3.3, QUARTER_Y - DECK_Y, 0.12), Vector3(0.0, (DECK_Y + QUARTER_Y) * 0.5, HATCH_AFT + 0.06), "dark_wood")

	# Quarterdeck rail with balusters, open at both sides for the stairs.
	_box(Vector3(1.9, 0.07, 0.1), Vector3(0.0, QUARTER_Y + 0.8, HATCH_AFT + 0.05), "dark_wood", Vector3.ZERO, false)
	_block(Vector3(1.9, 0.85, 0.1), Vector3(0.0, QUARTER_Y + 0.42, HATCH_AFT + 0.05))
	for i in 7:
		_round(0.03, 0.78, Vector3(-0.9 + i * 0.3, QUARTER_Y + 0.39, HATCH_AFT + 0.05), "dark_wood", false, 6)
	for s: float in [-1.0, 1.0]:
		_ramp(Vector3(s * 1.25, DECK_Y, 1.8), Vector3(s * 1.25, QUARTER_Y, HATCH_AFT), 0.6, 4)

	# Companionway: a hatch amidships and steep stairs down to the cabin.
	_ramp(Vector3(0.0, DECK_Y, HATCH_FORE), Vector3(0.0, FLOOR_Y, HATCH_AFT), 0.8, 7)
	for s: float in [-1.0, 1.0]:
		_box(Vector3(0.08, 0.16, HATCH_AFT - HATCH_FORE), Vector3(s * (HATCH_HALF + 0.04), DECK_Y + 0.08, (HATCH_FORE + HATCH_AFT) * 0.5), "dark_wood", Vector3.ZERO, false)


## A stair ramp from `top` down (or up) to `bottom`: a solid slope with step treads on it.
func _ramp(a: Vector3, b: Vector3, width: float, steps: int) -> void:
	var run := b.z - a.z
	var rise := b.y - a.y
	var length := sqrt(run * run + rise * rise)
	var angle := atan2(rise, run)
	var mid := (a + b) * 0.5
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 0.08, length)
	_solid(shape, mid - Vector3(0.0, 0.04, 0.0), Vector3(-angle, 0.0, 0.0))
	for s: float in [-1.0, 1.0]:
		_box(Vector3(0.06, 0.2, length), mid + Vector3(s * width * 0.5, -0.06, 0.0), "dark_wood", Vector3(-angle, 0.0, 0.0), false)
	for i in steps:
		var t := (i + 0.5) / steps
		var p := a.lerp(b, t)
		_box(Vector3(width - 0.04, 0.05, absf(run) / steps + 0.04), Vector3(p.x, p.y - 0.02, p.z), "deck", Vector3.ZERO, false)


## Below deck: panelled cabin with ribs and beams, the bunk forward, chest, stove
## and locked compartment amidships, chart table and lockers aft under the helm.
func _build_cabin() -> void:
	var length := CABIN_AFT - CABIN_FORE
	var mid := (CABIN_AFT + CABIN_FORE) * 0.5
	var height := DECK_Y - FLOOR_Y
	_box(Vector3(CABIN_HALF * 2.0 + 0.1, 0.15, length), Vector3(0.0, FLOOR_Y - 0.075, mid), "deck")
	for s: float in [-1.0, 1.0]:
		_box(Vector3(0.08, height, length), Vector3(s * (CABIN_HALF + 0.04), FLOOR_Y + height * 0.5, mid), "panel")
		for z: float in [-2.0, -0.9, 1.0, 2.2, 3.4]:
			_box(Vector3(0.08, height, 0.12), Vector3(s * (CABIN_HALF - 0.02), FLOOR_Y + height * 0.5, z), "dark_wood", Vector3.ZERO, false)
	for z: float in [CABIN_FORE - 0.04, CABIN_AFT + 0.04]:
		_box(Vector3(CABIN_HALF * 2.0 + 0.16, height, 0.08), Vector3(0.0, FLOOR_Y + height * 0.5, z), "panel")
	for z: float in [-2.0, -0.4, 3.4]:
		_box(Vector3(CABIN_HALF * 2.0, 0.12, 0.14), Vector3(0.0, DECK_Y - 0.18, z), "dark_wood", Vector3.ZERO, false)

	# Bunk.
	_box(Vector3(2.3, 0.45, 1.0), Vector3(0.0, FLOOR_Y + 0.225, -2.1), "dark_wood")
	_box(Vector3(2.1, 0.12, 0.85), Vector3(0.0, FLOOR_Y + 0.51, -2.12), "blanket", Vector3.ZERO, false)
	_box(Vector3(0.5, 0.1, 0.36), Vector3(-0.78, FLOOR_Y + 0.61, -2.15), "linen", Vector3.ZERO, false)
	_part("bunk", Vector3(2.3, 0.9, 1.1), Vector3(0.0, FLOOR_Y + 0.5, -2.05))
	# Sea chest (the stash), iron-banded.
	_box(Vector3(0.48, 0.45, 0.85), Vector3(-0.95, FLOOR_Y + 0.225, -0.2), "dark_wood")
	_box(Vector3(0.5, 0.1, 0.87), Vector3(-0.95, FLOOR_Y + 0.5, -0.2), "panel", Vector3.ZERO, false)
	for z: float in [-0.5, 0.1]:
		_box(Vector3(0.51, 0.56, 0.05), Vector3(-0.95, FLOOR_Y + 0.28, z), "gold", Vector3.ZERO, false)
	_part("chest", Vector3(0.7, 0.8, 1.0), Vector3(-0.9, FLOOR_Y + 0.35, -0.2))
	# Galley stove with its flue up through the deck.
	_box(Vector3(0.5, 0.8, 0.6), Vector3(0.95, FLOOR_Y + 0.4, -0.3), "iron")
	_box(Vector3(0.02, 0.2, 0.28), Vector3(0.69, FLOOR_Y + 0.35, -0.3), "dark_wood", Vector3.ZERO, false)
	_round(0.06, DECK_Y - FLOOR_Y - 0.8, Vector3(1.0, (FLOOR_Y + 0.8 + DECK_Y) * 0.5, -0.45), "iron", false, 8)
	_part("stove", Vector3(0.7, 1.0, 0.8), Vector3(0.95, FLOOR_Y + 0.5, -0.3))
	_stove_glow = OmniLight3D.new()
	_stove_glow.light_color = Color(1.0, 0.55, 0.2)
	_stove_glow.light_energy = 1.2
	_stove_glow.omni_range = 3.0
	_stove_glow.position = Vector3(0.6, FLOOR_Y + 0.6, -0.3)
	_stove_glow.visible = false
	add_child(_stove_glow)
	# The locked compartment, low against the hull.
	_box(Vector3(0.45, 0.4, 0.45), Vector3(-0.97, FLOOR_Y + 0.2, -1.1), "dark_wood")
	_box(Vector3(0.02, 0.09, 0.07), Vector3(-0.735, FLOOR_Y + 0.26, -1.1), "gold", Vector3.ZERO, false)
	_part("compartment", Vector3(0.6, 0.6, 0.6), Vector3(-0.9, FLOOR_Y + 0.3, -1.1))
	# Chart table and crew lockers aft, under the helm.
	_box(Vector3(0.8, 0.78, 0.7), Vector3(0.75, FLOOR_Y + 0.39, 3.6), "dark_wood")
	_box(Vector3(0.62, 0.01, 0.5), Vector3(0.75, FLOOR_Y + 0.785, 3.6), "paper", Vector3(0.0, 0.1, 0.0), false)
	_part("chart", Vector3(0.9, 1.0, 0.9), Vector3(0.75, FLOOR_Y + 0.5, 3.6))
	_box(Vector3(0.8, 1.4, 0.45), Vector3(-0.75, FLOOR_Y + 0.7, 3.77), "panel")
	for x: float in [-0.95, -0.55]:
		_box(Vector3(0.36, 1.3, 0.02), Vector3(x, FLOOR_Y + 0.7, 3.54), "dark_wood", Vector3.ZERO, false)
	_part("lockers", Vector3(0.9, 1.4, 0.6), Vector3(-0.75, FLOOR_Y + 0.7, 3.6))
	# Hanging lanterns.
	for spot: Vector3 in [Vector3(0.0, DECK_Y - 0.5, -1.7), Vector3(0.0, DECK_Y - 0.5, 3.6)]:
		_box(Vector3(0.14, 0.2, 0.14), spot, "lantern", Vector3.ZERO, false)
		_box(Vector3(0.18, 0.05, 0.18), spot + Vector3(0.0, 0.12, 0.0), "iron", Vector3.ZERO, false)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.8, 0.52)
		light.light_energy = 1.0
		light.omni_range = 4.5
		light.position = spot - Vector3(0.0, 0.15, 0.0)
		add_child(light)


## On deck: mast and crow's nest, bowsprit, capstan, anchor, cannons, the helm,
## barrels, stern lanterns and boarding ladders on both sides.
func _build_fittings() -> void:
	_mesh(MeshKit.tube(PackedVector3Array([Vector3(0.0, FLOOR_Y, MAST_Z), Vector3(0.0, MAST_TOP, MAST_Z)]), PackedFloat32Array([0.19, 0.09]), 12), "panel")
	var mast_shape := CylinderShape3D.new()
	mast_shape.radius = 0.17
	mast_shape.height = MAST_TOP - FLOOR_Y
	_solid(mast_shape, Vector3(0.0, (MAST_TOP + FLOOR_Y) * 0.5, MAST_Z))
	for y: float in [DECK_Y + 0.25, DECK_Y + 4.0, YARD_Y + 0.3]:
		_round(0.2 - (y - DECK_Y) * 0.006, 0.08, Vector3(0.0, y, MAST_Z), "iron", false, 12)
	# Crow's nest.
	var nest_y := DECK_Y + 10.4
	_round(0.85, 0.08, Vector3(0.0, nest_y, MAST_Z), "dark_wood", false, 20)
	var wall := CylinderMesh.new()
	wall.top_radius = 0.92
	wall.bottom_radius = 0.82
	wall.height = 0.65
	wall.radial_segments = 20
	wall.rings = 1
	wall.cap_top = false
	wall.cap_bottom = false
	_mesh(wall, "hull", Vector3(0.0, nest_y + 0.32, MAST_Z))
	_round(0.95, 0.06, Vector3(0.0, nest_y + 0.66, MAST_Z), "gold", false, 20)
	# Bowsprit.
	_mesh(MeshKit.tube(PackedVector3Array([Vector3(0.0, DECK_Y + 0.3, -4.8), Vector3(0.0, DECK_Y + 0.95, -6.8), Vector3(0.0, DECK_Y + 1.5, -8.6)]),
		PackedFloat32Array([0.16, 0.12, 0.06]), 10), "panel")
	# Capstan.
	_round(0.3, 0.7, Vector3(0.0, DECK_Y + 0.35, -4.0), "dark_wood", true, 12)
	_round(0.4, 0.12, Vector3(0.0, DECK_Y + 0.72, -4.0), "dark_wood", false, 12)
	for i in 4:
		_box(Vector3(1.4, 0.05, 0.07), Vector3(0.0, DECK_Y + 0.6, -4.0), "panel", Vector3(0.0, i * PI / 4.0, 0.0), false)
	# Anchor hung on the port bow.
	var ax := -(hull_x(-4.7, 1.4) + 0.12)
	_box(Vector3(0.08, 1.2, 0.08), Vector3(ax, 1.35, -4.7), "iron", Vector3.ZERO, false)
	_box(Vector3(0.07, 0.07, 0.75), Vector3(ax, 1.85, -4.7), "iron", Vector3.ZERO, false)
	for s: float in [-1.0, 1.0]:
		_box(Vector3(0.07, 0.5, 0.08), Vector3(ax, 0.88, -4.7 + s * 0.17), "iron", Vector3(s * 0.9, 0.0, 0.0), false)
	# Cannons.
	for z: float in [-2.0, 0.9]:
		for s: float in [-1.0, 1.0]:
			_box(Vector3(0.55, 0.28, 0.7), Vector3(s * 1.3, DECK_Y + 0.14, z), "dark_wood")
			for dz: float in [-0.25, 0.25]:
				for dx: float in [-0.29, 0.29]:
					_mesh(_wheel_mesh(), "dark_wood", Vector3(s * 1.3 + dx, DECK_Y + 0.12, z + dz), Vector3(0.0, 0.0, PI / 2.0))
			_mesh(MeshKit.tube(PackedVector3Array([Vector3(s * 0.95, DECK_Y + 0.4, z), Vector3(s * 1.4, DECK_Y + 0.42, z), Vector3(s * 1.86, DECK_Y + 0.44, z)]),
				PackedFloat32Array([0.17, 0.13, 0.1]), 12), "iron")
			# A gunport lid on the outside of the hull where each gun would run out.
			var port_y := DECK_Y + 0.44
			_box(Vector3(0.05, 0.36, 0.38), Vector3(s * (hull_x(z, port_y) + 0.025), port_y, z), "dark_wood", Vector3.ZERO, false)
			_box(Vector3(0.06, 0.04, 0.42), Vector3(s * (hull_x(z, port_y + 0.2) + 0.03), port_y + 0.2, z), "iron", Vector3.ZERO, false)
	# Helm on the quarterdeck.
	_box(Vector3(0.22, 1.12, 0.22), Vector3(0.0, QUARTER_Y + 0.56, HELM.z + 0.1), "dark_wood")
	var wheel := Node3D.new()
	wheel.position = Vector3(0.0, QUARTER_Y + 1.12, HELM.z - 0.06)
	add_child(wheel)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.5
	rim.outer_radius = 0.58
	rim.rings = 24
	rim.ring_segments = 8
	_child_mesh(wheel, rim, "dark_wood", Vector3.ZERO, Vector3(PI / 2.0, 0.0, 0.0))
	var hub := CylinderMesh.new()
	hub.top_radius = 0.1
	hub.bottom_radius = 0.1
	hub.height = 0.16
	_child_mesh(wheel, hub, "iron", Vector3.ZERO, Vector3(PI / 2.0, 0.0, 0.0))
	var spoke := BoxMesh.new()
	spoke.size = Vector3(0.045, 1.5, 0.045)
	for i in 4:
		_child_mesh(wheel, spoke, "dark_wood", Vector3.ZERO, Vector3(0.0, 0.0, i * PI / 4.0))
	_part("helm", Vector3(1.4, 1.6, 0.9), Vector3(0.0, QUARTER_Y + 0.9, HELM.z))
	# Barrels on the quarterdeck.
	for s: float in [-1.0, 1.0]:
		var barrel := MeshKit.tube(PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0.42, 0), Vector3(0, 0.84, 0)]), PackedFloat32Array([0.25, 0.3, 0.25]), 14, "sloop_barrel")
		_mesh(barrel, "panel", Vector3(s * 1.05, QUARTER_Y, 5.35))
		for y: float in [0.15, 0.69]:
			_round(0.29, 0.05, Vector3(s * 1.05, QUARTER_Y + y, 5.35), "iron", false, 14)
		var barrel_shape := CylinderShape3D.new()
		barrel_shape.radius = 0.3
		barrel_shape.height = 0.84
		_solid(barrel_shape, Vector3(s * 1.05, QUARTER_Y + 0.42, 5.35))
	# Stern lanterns.
	for s: float in [-1.0, 1.0]:
		_box(Vector3(0.06, 0.7, 0.06), Vector3(s * 1.35, QUARTER_Y + 0.9, 5.85), "iron", Vector3.ZERO, false)
		_box(Vector3(0.18, 0.26, 0.18), Vector3(s * 1.35, QUARTER_Y + 1.35, 5.85), "lantern", Vector3.ZERO, false)
		_box(Vector3(0.22, 0.06, 0.22), Vector3(s * 1.35, QUARTER_Y + 1.5, 5.85), "iron", Vector3.ZERO, false)
	var stern_light := OmniLight3D.new()
	stern_light.light_color = Color(1.0, 0.78, 0.45)
	stern_light.light_energy = 0.8
	stern_light.omni_range = 6.0
	stern_light.position = Vector3(0.0, QUARTER_Y + 1.4, 5.6)
	add_child(stern_light)
	# Boarding ladders down both sides, following the curve of the hull.
	for s: float in [-1.0, 1.0]:
		var rails := [PackedVector3Array(), PackedVector3Array()]
		var radii := PackedFloat32Array()
		for k in 8:
			var y := 0.0 + k * 0.32
			var x := s * (hull_x(LADDER_Z, y) + 0.07)
			_box(Vector3(0.06, 0.05, 0.56), Vector3(x, y, LADDER_Z), "dark_wood", Vector3.ZERO, false)
			rails[0].append(Vector3(x, y, LADDER_Z - 0.3))
			rails[1].append(Vector3(x, y, LADDER_Z + 0.3))
			radii.append(0.035)
		for rail: PackedVector3Array in rails:
			_mesh(MeshKit.tube(rail, radii, 6), "dark_wood")
		_part("ladder" if s > 0.0 else "ladder_port", Vector3(0.9, 2.6, 1.0), Vector3(s * (hull_x(LADDER_Z, 1.0) + 0.4), 1.0, LADDER_Z))


static var _wheel: CylinderMesh


static func _wheel_mesh() -> CylinderMesh:
	if _wheel == null:
		_wheel = CylinderMesh.new()
		_wheel.top_radius = 0.13
		_wheel.bottom_radius = 0.13
		_wheel.height = 0.06
		_wheel.radial_segments = 10
		_wheel.rings = 1
	return _wheel


func _child_mesh(parent: Node3D, mesh: Mesh, key: String, pos: Vector3, rot: Vector3) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _mat(key)
	visual.position = pos
	visual.rotation = rot
	parent.add_child(visual)
	return visual


## The yard and its square sail — billowing, torn and holed until it's repaired —
## with shrouds, ratlines, stays and sheets.
func _build_rig() -> void:
	var yard_z := MAST_Z - 0.22
	_mesh(MeshKit.tube(PackedVector3Array([Vector3(-3.5, YARD_Y, yard_z), Vector3(0.0, YARD_Y, yard_z), Vector3(3.5, YARD_Y, yard_z)]),
		PackedFloat32Array([0.06, 0.12, 0.06]), 10), "panel")
	var masthead := Vector3(0.0, MAST_TOP - 1.2, MAST_Z)
	for s: float in [-1.0, 1.0]:
		_rope(masthead, Vector3(s * 3.3, YARD_Y, yard_z), 0.018)
	_build_sail(yard_z)

	var shroud_top := DECK_Y + 10.3
	for s: float in [-1.0, 1.0]:
		var feet := [Vector3(s * 1.95, DECK_Y + 0.55, MAST_Z - 0.6), Vector3(s * 1.98, DECK_Y + 0.55, MAST_Z + 0.1), Vector3(s * 1.95, DECK_Y + 0.55, MAST_Z + 0.8)]
		var top := Vector3(s * 0.2, shroud_top, MAST_Z)
		for foot: Vector3 in feet:
			_rope(foot, top, 0.022)
			_box(Vector3(0.1, 0.18, 0.1), foot, "iron", Vector3.ZERO, false)
		for k in range(1, 15):
			var f := k * 0.6 / (shroud_top - DECK_Y - 0.55)
			if f >= 0.97:
				break
			_rope(feet[0].lerp(top, f), feet[2].lerp(top, f), 0.013)
	_rope(Vector3(0.0, MAST_TOP - 0.8, MAST_Z), Vector3(0.0, DECK_Y + 1.45, -8.5), 0.025)
	_rope(Vector3(0.0, DECK_Y + 1.45, -8.5), Vector3(0.0, 0.9, -6.1), 0.02)
	for s: float in [-1.0, 1.0]:
		_rope(Vector3(s * 0.1, MAST_TOP - 0.8, MAST_Z), Vector3(s * 1.3, QUARTER_Y + 0.6, 5.6), 0.022)


func _build_sail(yard_z: float) -> void:
	var columns := 44
	var rows := 34
	var top := YARD_Y - 0.1
	var bottom := DECK_Y + 3.4
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.3
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	for r in rows + 1:
		var yn := float(r) / rows
		var half := lerpf(3.3, 2.9, yn)
		for c in columns + 1:
			var xn := float(c) / columns
			var billow := 0.95 * sin(PI * xn) * sin(PI * 0.6 * yn) + 0.08 * noise.get_noise_2d(c * 0.7, r * 0.7)
			var y := lerpf(top, bottom, yn)
			vertices.append(Vector3(lerpf(-half, half, xn), y, yard_z - 0.1 - billow))
			uvs.append(Vector2(xn, yn))
	var indices := PackedInt32Array()
	for r in rows:
		for c in columns:
			var a := r * (columns + 1) + c
			var b := a + columns + 1
			indices.append_array([a, b, a + 1, a + 1, b, b + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	_mesh(MeshKit._with_normals(arrays), "sail")
	_build_jib()
	# Sheets from what's left of the lower corners down to the rail.
	var torn_y := lerpf(top, bottom, 0.6)
	for s: float in [-1.0, 1.0]:
		_rope(Vector3(s * 3.0, torn_y, yard_z - 0.1), Vector3(s * 1.8, DECK_Y + 0.6, 1.6), 0.016)


## A triangular jib on the forestay between the bowsprit and the mast.
func _build_jib() -> void:
	var top := Vector3(0.0, MAST_TOP - 0.8, MAST_Z)
	var tip := Vector3(0.0, DECK_Y + 1.45, -8.5)
	var tack := tip.lerp(top, 0.06)
	var head := tip.lerp(top, 0.6)
	var clew := Vector3(0.55, DECK_Y + 1.0, -4.3)
	var out := (head - tack).cross(clew - tack).normalized()
	if out.x < 0.0:
		out = -out
	var steps := 10
	var vertices := PackedVector3Array()
	var index_of := {}
	for i in steps + 1:
		for j in steps + 1 - i:
			var u := float(i) / steps
			var v := float(j) / steps
			var belly := 27.0 * u * v * (1.0 - u - v)
			index_of[Vector2i(i, j)] = vertices.size()
			vertices.append(tack + (head - tack) * u + (clew - tack) * v + out * 0.4 * belly)
	var indices := PackedInt32Array()
	for i in steps:
		for j in steps - i:
			indices.append_array([index_of[Vector2i(i, j)], index_of[Vector2i(i + 1, j)], index_of[Vector2i(i, j + 1)]])
			if j < steps - i - 1:
				indices.append_array([index_of[Vector2i(i + 1, j)], index_of[Vector2i(i + 1, j + 1)], index_of[Vector2i(i, j + 1)]])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	_mesh(MeshKit._with_normals(arrays), "jib")
	_rope(clew, Vector3(1.55, DECK_Y + 0.6, -3.6), 0.016)


## Flies the crew's colour and emblem from the masthead.
func set_crew_flag(crew_color: int, emblem: int) -> void:
	if _flag != null:
		_flag.queue_free()
	_flag = Node3D.new()
	_flag.position = Vector3(0.0, MAST_TOP - 0.35, MAST_Z + 0.5)
	add_child(_flag)
	var color := AppearanceTable.crew_color(crew_color)
	var cloth := QuadMesh.new()
	cloth.size = Vector2(0.9, 0.6)
	var cloth_material := StandardMaterial3D.new()
	cloth_material.albedo_color = color
	cloth_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var flag := MeshInstance3D.new()
	flag.mesh = cloth
	flag.material_override = cloth_material
	flag.rotation.y = PI / 2.0
	_flag.add_child(flag)
	if emblem <= 0:
		return
	var badge := QuadMesh.new()
	badge.size = Vector2(0.45, 0.45)
	var badge_material := StandardMaterial3D.new()
	badge_material.albedo_texture = Emblem.texture(emblem, Emblem.contrast(color))
	badge_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	badge_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for side: float in [-1.0, 1.0]:
		var mark := MeshInstance3D.new()
		mark.mesh = badge
		mark.material_override = badge_material
		mark.position.x = side * 0.004
		mark.rotation.y = PI / 2.0
		_flag.add_child(mark)
