class_name CharacterModel
extends Node3D
## A crew member's visible body, built in code: a jointed figure with a smooth
## lofted torso, rounded limbs, and a single smooth head mesh. Hair, beards and
## hats are shells generated from that same head surface (cut along a hairline
## or beard line), and armour is a shell of the torso surface — so nothing can
## leave gaps or float. Animated procedurally (walk, run, crouch, swim, swings).
##
## Faces -Z. Origin at the feet.

const HIP_Y := 0.92
const THIGH := 0.42
const SHIN := 0.42
const TORSO := 0.46
const UPPER_ARM := 0.3
const FOREARM := 0.28
const SEGMENTS := 18
const RINGS := 10
const TORSO_SEGMENTS := 28
const HEAD_RINGS := 40
const HEAD_SEGMENTS := 64
## Where trousers end and the shirt begins, in pelvis space.
const WAIST_SPLIT := 0.11

const CLOTHING_COLORS := {
	"rain_jacket": Color(0.93, 0.72, 0.14),
	"wool_sweater": Color(0.52, 0.40, 0.29),
	"shorts": Color(0.20, 0.34, 0.55),
	"cargo_pants": Color(0.50, 0.46, 0.34),
	"sandals": Color(0.36, 0.24, 0.15),
	"hiking_boots": Color(0.30, 0.22, 0.15),
	"wool_beanie": Color(0.24, 0.27, 0.31),
	"sun_hat": Color(0.84, 0.77, 0.58),
	"combat_helmet": Color(0.33, 0.36, 0.27),
	"daypack": Color(0.22, 0.25, 0.30),
}
const UNDERWEAR := Color(0.18, 0.18, 0.20)

static var _sphere: SphereMesh
static var _mesh_cache := {}
static var _material_cache := {}

var look := AppearanceTable.DEFAULT_LOOK.duplicate()
var worn := {}
var crew_color_index := 4
var emblem_index := 1
var held_id := ""

var _pelvis: Node3D
var _spine: Node3D
var _head: Node3D
var _arms := {}
var _legs := {}
var _held_root: Node3D
var _phase := 0.0
var _swing_t := 0.0
var _breath := 0.0
## Head shape parameters for the current look: size, chin push, jaw narrowing.
var _head_shape := {"size": Vector3(0.21, 0.26, 0.24), "chin": 0.02, "jaw": 0.1}


func setup(p_look: Variant, p_worn: Dictionary, crew_color: int, emblem: int) -> void:
	look = AppearanceTable.sanitize(p_look)
	worn = p_worn.duplicate()
	crew_color_index = crew_color
	emblem_index = emblem
	rebuild()


func set_worn(ids: Dictionary) -> void:
	if ids != worn:
		worn = ids.duplicate()
		rebuild()


func set_held(id: String) -> void:
	if id == held_id:
		return
	held_id = id
	_rebuild_held()


## Plays one tool swing (chop, cut, use).
func swing() -> void:
	_swing_t = 1.0


func crew_color() -> Color:
	return AppearanceTable.crew_color(crew_color_index)


func clothing_color(id: String) -> Color:
	if ItemTable.get_item(id).get("tint", "") == "crew":
		var crew := crew_color()
		return crew.lerp(Color(0.30, 0.32, 0.26), 0.55) if id == "plate_carrier" else crew
	return CLOTHING_COLORS.get(id, Color(0.5, 0.5, 0.5))


# --- building ------------------------------------------------------------------

func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_arms.clear()
	_legs.clear()
	scale = Vector3.ONE * AppearanceTable.height_scale(look)

	var feminine := int(look.body) == 1
	var build: float = [0.88, 1.0, 1.16][int(look.build)]
	var skin: Color = AppearanceTable.SKIN[int(look.skin)]
	var shoulder_w := (0.37 if feminine else 0.43) * build
	var hip_w := (0.37 if feminine else 0.33) * build
	var depth := 0.23 * build
	var arm_r := (0.047 if feminine else 0.055) * build
	var leg_r := (0.08 if feminine else 0.077) * build

	var torso_item: String = worn.get("torso", "")
	var legs_item: String = worn.get("legs", "")
	var feet_item: String = worn.get("feet", "")
	var shirt := clothing_color(torso_item) if not torso_item.is_empty() else skin
	var long_sleeves := torso_item in ["rain_jacket", "wool_sweater"]
	var pants := clothing_color(legs_item) if not legs_item.is_empty() else UNDERWEAR
	var long_legs := legs_item == "cargo_pants"
	var bulk := 1.05 if long_sleeves else 1.0

	_pelvis = Node3D.new()
	_pelvis.name = "Pelvis"
	_pelvis.position.y = HIP_Y
	add_child(_pelvis)
	var profile := _torso_profile(hip_w, shoulder_w, depth, bulk, feminine)
	var torso := MeshInstance3D.new()
	torso.name = "Torso"
	torso.mesh = _torso_mesh(profile, WAIST_SPLIT, pants, shirt)
	torso.material_override = _vertex_color_material()
	_pelvis.add_child(torso)

	for side: float in [-1.0, 1.0]:
		var key := "l" if side < 0.0 else "r"
		var hip := _joint(_pelvis, "Hip_" + key, Vector3(side * (hip_w * 0.5 - leg_r * 0.85), -0.04, 0.0))
		var thigh_color := pants if long_legs else skin
		_capsule(hip, leg_r, THIGH, Vector3(0.0, -THIGH * 0.5, 0.0), thigh_color)
		if legs_item == "shorts":
			_capsule(hip, leg_r * 1.14, THIGH * 0.5, Vector3(0.0, -THIGH * 0.2, 0.0), pants)
		var knee := _joint(hip, "Knee_" + key, Vector3(0.0, -THIGH, 0.0))
		var shin_color := pants if long_legs else skin
		_ellipsoid(knee, Vector3.ONE * leg_r * 1.8, Vector3.ZERO, shin_color)
		_capsule(knee, leg_r * 0.8, SHIN, Vector3(0.0, -SHIN * 0.5, 0.0), shin_color)
		var foot_color := skin
		var foot_size := Vector3(0.1, 0.075, 0.25) * Vector3(build, 1.0, 1.0)
		if feet_item == "hiking_boots":
			foot_color = clothing_color(feet_item)
			foot_size *= Vector3(1.2, 1.35, 1.1)
			_capsule(knee, leg_r * 0.95, 0.16, Vector3(0.0, -SHIN + 0.06, 0.0), foot_color)
		_ellipsoid(knee, foot_size, Vector3(0.0, -SHIN - 0.035, -0.05), foot_color)
		if feet_item == "sandals":
			_cylinder(knee, 0.07 * build, 0.02, Vector3(0.0, -SHIN - 0.07, -0.05), clothing_color(feet_item), Vector3(1.0, 1.0, 2.1))
		_legs[key] = {"hip": hip, "knee": knee}

	# The spine carries the arms and neck; the torso shape and anything worn on
	# it live on the pelvis so they bend together as one surface.
	_spine = _joint(_pelvis, "Spine", Vector3(0.0, 0.08, 0.0))
	if torso_item == "tshirt" and emblem_index > 0 and not worn.has("vest"):
		var badge := Vector2(-shoulder_w * 0.2, 0.45)
		_decal(_pelvis, Emblem.texture(emblem_index, Emblem.contrast(shirt)), 0.1, Vector3(badge.x, badge.y, _front_z(profile, badge.x, badge.y) - 0.005))

	for side: float in [-1.0, 1.0]:
		var key := "l" if side < 0.0 else "r"
		var shoulder := _joint(_spine, "Shoulder_" + key, Vector3(side * (shoulder_w * 0.43 + arm_r * 0.35), TORSO - 0.08, 0.0))
		var sleeve := shirt if (long_sleeves or torso_item == "tshirt") else skin
		_ellipsoid(shoulder, Vector3(arm_r * 2.6, arm_r * 2.4, arm_r * 2.5), Vector3(0.0, -0.005, 0.0), sleeve)
		_capsule(shoulder, arm_r, UPPER_ARM, Vector3(0.0, -UPPER_ARM * 0.5, 0.0), shirt if long_sleeves else skin)
		if torso_item == "tshirt":
			_capsule(shoulder, arm_r * 1.22, UPPER_ARM * 0.45, Vector3(0.0, -UPPER_ARM * 0.2, 0.0), shirt)
		var elbow := _joint(shoulder, "Elbow_" + key, Vector3(0.0, -UPPER_ARM, 0.0))
		var forearm_color := shirt if long_sleeves else skin
		_ellipsoid(elbow, Vector3.ONE * arm_r * 1.8, Vector3.ZERO, forearm_color)
		_capsule(elbow, arm_r * 0.9, FOREARM, Vector3(0.0, -FOREARM * 0.5, 0.0), forearm_color)
		var hand := _joint(elbow, "Hand_" + key, Vector3(0.0, -FOREARM - 0.03, 0.0))
		_ellipsoid(hand, Vector3(0.075, 0.105, 0.048) * build, Vector3(0.0, -0.03, 0.0), skin)
		_ellipsoid(hand, Vector3(0.024, 0.052, 0.024) * build, Vector3(-side * 0.032, -0.01, -0.02), skin, Vector3(0.0, 0.0, -side * 0.5))
		_arms[key] = {"shoulder": shoulder, "elbow": elbow, "hand": hand}

	_build_gear(profile, shoulder_w, feminine)

	var neck := _joint(_spine, "Neck", Vector3(0.0, TORSO, 0.0))
	_capsule(neck, (0.052 if feminine else 0.06) * build, 0.12, Vector3(0.0, 0.01, 0.0), skin)
	_head = _joint(neck, "Head", Vector3(0.0, 0.16, 0.0))
	_build_head(skin, feminine)
	_rebuild_held()


# --- torso ----------------------------------------------------------------------

## Rings of [height, half-width, half-depth] up the torso, in pelvis space.
static func _torso_profile(hip_w: float, shoulder_w: float, depth: float, bulk: float, feminine: bool) -> Array:
	var waist := lerpf(hip_w, shoulder_w, 0.2) * (0.9 if feminine else 1.0)
	var chest := lerpf(waist, shoulder_w, 0.65)
	return [
		[-0.14, 0.0, 0.0],
		[-0.13, hip_w * 0.3, depth * 0.28],
		[-0.08, hip_w * 0.5, depth * 0.43],
		[0.01, hip_w * 0.56, depth * 0.47],
		[0.1, hip_w * 0.51, depth * 0.45],
		[0.2, waist * 0.47 * bulk, depth * 0.42 * bulk],
		[0.3, chest * 0.5 * bulk, depth * (0.5 if feminine else 0.47) * bulk],
		[0.4, shoulder_w * 0.5 * bulk, depth * (0.57 if feminine else 0.52) * bulk],
		[0.47, shoulder_w * 0.5 * bulk, depth * 0.5 * bulk],
		[0.52, shoulder_w * 0.43 * bulk, depth * 0.42 * bulk],
		[0.555, shoulder_w * 0.22, depth * 0.26],
		[0.565, 0.0, 0.0],
	]


## Half-width and half-depth of the torso at height `y` (pelvis space).
static func _ring_at(profile: Array, y: float) -> Vector2:
	for i in range(1, profile.size()):
		var a: Array = profile[i - 1]
		var b: Array = profile[i]
		if y <= float(b[0]):
			var t := clampf((y - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001), 0.0, 1.0)
			return Vector2(lerpf(a[1], b[1], t), lerpf(a[2], b[2], t))
	return Vector2.ZERO


## Front surface (-Z) of the torso at pelvis-space (x, y).
static func _front_z(profile: Array, x: float, y: float) -> float:
	var ring := _ring_at(profile, y)
	var nx := x / maxf(ring.x, 0.0001)
	return -ring.y * sqrt(maxf(0.0, 1.0 - nx * nx))


## A smooth, closed torso lofted through the profile rings, coloured below and above the waist.
static func _torso_mesh(profile: Array, split_y: float, lower: Color, upper: Color) -> ArrayMesh:
	var key := "torso|%s|%.3f|%s|%s" % [str(profile), split_y, lower.to_html(false), upper.to_html(false)]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var rings: Array = []
	for i in profile.size():
		var row: Array = profile[i]
		if i > 0:
			var prev: Array = profile[i - 1]
			if float(prev[0]) < split_y and float(row[0]) >= split_y:
				var ring := _ring_at(profile, split_y)
				rings.append([split_y, ring.x, ring.y, lower])
				rings.append([split_y, ring.x, ring.y, upper])
		rings.append([row[0], row[1], row[2], lower if float(row[0]) < split_y else upper])
	var mesh := _loft(rings, 0.0, func(_a: float, _y: float) -> bool: return true, true)
	_mesh_cache[key] = mesh
	return mesh


## A shell hugging the torso between two heights, `inflate` metres off the
## surface, keeping only the parts where `keep(angle, y)` is true. Used for armour.
static func _torso_shell(profile: Array, y_min: float, y_max: float, inflate: float, keep: Callable, cache_key: String) -> ArrayMesh:
	var key := "shell|%s|%s" % [str(profile), cache_key]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var rings: Array = []
	var steps := 18
	for i in steps + 1:
		var y := lerpf(y_min, y_max, float(i) / steps)
		var ring := _ring_at(profile, y)
		rings.append([y, ring.x, ring.y, Color.WHITE])
	var mesh := _loft(rings, inflate, keep, false)
	_mesh_cache[key] = mesh
	return mesh


## Lofts elliptical rings into a smooth surface. Quads failing `keep(angle, y)` are left out.
static func _loft(rings: Array, inflate: float, keep: Callable, coloured: bool) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var last := rings.size() - 1
	for r in rings.size():
		var ring: Array = rings[r]
		var below := r
		while below > 0 and is_equal_approx(float(rings[below][0]), float(ring[0])):
			below -= 1
		var above := r
		while above < last and is_equal_approx(float(rings[above][0]), float(ring[0])):
			above += 1
		var d_y := float(rings[above][0]) - float(rings[below][0])
		var d_rx := float(rings[above][1]) - float(rings[below][1])
		var d_rz := float(rings[above][2]) - float(rings[below][2])
		var rx := float(ring[1]) + (inflate if float(ring[1]) > 0.0 else 0.0)
		var rz := float(ring[2]) + (inflate if float(ring[2]) > 0.0 else 0.0)
		for j in TORSO_SEGMENTS + 1:
			var a := TAU * j / TORSO_SEGMENTS
			vertices.append(Vector3(rx * cos(a), ring[0], rz * sin(a)))
			var along_a := Vector3(-rx * sin(a), 0.0, rz * cos(a))
			var along_y := Vector3(d_rx * cos(a), d_y, d_rz * sin(a))
			var normal := along_y.cross(along_a)
			if normal.length_squared() < 0.0000001:
				normal = Vector3.DOWN if r == 0 else Vector3.UP
			normals.append(normal.normalized())
			colors.append(ring[3])
	var row := TORSO_SEGMENTS + 1
	for r in last:
		for j in TORSO_SEGMENTS:
			var a_mid := TAU * (j + 0.5) / TORSO_SEGMENTS
			var y_mid := (float(rings[r][0]) + float(rings[r + 1][0])) * 0.5
			if not keep.call(a_mid, y_mid):
				continue
			var v00 := r * row + j
			var v01 := v00 + 1
			var v10 := v00 + row
			var v11 := v10 + 1
			indices.append_array([v00, v01, v10, v01, v11, v10])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	if coloured:
		arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	if not indices.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_gear(profile: Array, shoulder_w: float, feminine: bool) -> void:
	var vest: String = worn.get("vest", "")
	var plate_depth := 0.028
	if vest == "plate_carrier":
		var color := clothing_color(vest)
		# Front and back plates over the chest, a wrap-around cummerbund at the
		# waist, and straps over the tops of the shoulders — all one surface.
		var keep := func(a: float, y: float) -> bool:
			var facing := absf(sin(a))
			if y < 0.25:
				return true
			if y > 0.5:
				var across := absf(cos(a))
				return across > 0.35 and across < 0.75
			return facing > 0.5
		var carrier := MeshInstance3D.new()
		carrier.mesh = _torso_shell(profile, 0.13, 0.555, plate_depth, keep, "carrier")
		carrier.material_override = _two_sided(Materials.cloth(color))
		_pelvis.add_child(carrier)
		var rim := MeshInstance3D.new()
		rim.mesh = _torso_shell(profile, 0.12, 0.15, plate_depth + 0.006, func(_a: float, _y: float) -> bool: return true, "carrier_rim")
		rim.material_override = _two_sided(Materials.cloth(color.darkened(0.3)))
		_pelvis.add_child(rim)
		for x: float in [-0.085, 0.0, 0.085]:
			var px := x * shoulder_w / 0.43
			var py := 0.21
			var size := Vector3(0.075, 0.085, 0.05)
			_ellipsoid(_pelvis, size, Vector3(px, py, _front_z(profile, px, py) - plate_depth - size.z * 0.35), color.darkened(0.22))
		if emblem_index > 0:
			var bx := -shoulder_w * 0.2
			var by := 0.44
			_decal(_pelvis, Emblem.texture(emblem_index, Emblem.contrast(color)), 0.08, Vector3(bx, by, _front_z(profile, bx, by) - plate_depth - 0.005))
	if worn.get("back", "") in ["daypack", "satchel"]:
		var big: bool = worn.back == "daypack"
		var pack := clothing_color("daypack") if big else Color(0.55, 0.47, 0.32)
		var size := Vector3(shoulder_w * (0.72 if big else 0.6), 0.38 if big else 0.24, 0.16 if big else 0.09)
		var py := 0.34 if big else 0.2
		var back_z := -_front_z(profile, 0.0, py) + (plate_depth if vest == "plate_carrier" else 0.0)
		_ellipsoid(_pelvis, size, Vector3(0.0, py, back_z + size.z * 0.42), pack)
		_ellipsoid(_pelvis, Vector3(size.x * 0.82, size.y * 0.3, size.z * 0.6), Vector3(0.0, py + size.y * 0.28, back_z + size.z * 0.75), pack.darkened(0.2))
		var straps := MeshInstance3D.new()
		var strap_keep := func(a: float, y: float) -> bool:
			var across := absf(cos(a))
			return across > 0.25 and across < 0.5 and (y > 0.3 or sin(a) > 0.0)
		straps.mesh = _torso_shell(profile, 0.22, 0.555, (plate_depth if vest == "plate_carrier" else 0.0) + 0.012, strap_keep, "straps_%s" % vest)
		straps.material_override = _two_sided(Materials.leather(pack.darkened(0.35)))
		_pelvis.add_child(straps)
	if not feminine:
		return


# --- head ------------------------------------------------------------------------

## The head surface point in direction `dir` from its centre (head space).
func _head_point(dir: Vector3) -> Vector3:
	var n := dir.normalized()
	var size: Vector3 = _head_shape.size
	var p := Vector3(n.x * size.x * 0.5, n.y * size.y * 0.5, n.z * size.z * 0.5)
	var front := maxf(0.0, -n.z)
	var lower := maxf(0.0, -n.y)
	p.x *= 1.0 - lower * float(_head_shape.jaw)
	p.z -= front * lower * float(_head_shape.chin)
	p.y -= front * lower * 0.012
	return p


## Outward normal of the head surface near `dir` (ellipsoid approximation).
func _head_normal(dir: Vector3) -> Vector3:
	var size: Vector3 = _head_shape.size
	var p := _head_point(dir)
	return Vector3(p.x / (size.x * size.x), p.y / (size.y * size.y), p.z / (size.z * size.z)).normalized()


## A mesh over the head surface, `inflate` (+ `bulge(dir)`) metres out, over the
## region where `keep(dir)` holds. Triangles touching the region are kept and
## their outside corners are pulled down onto the skin, so every shell's edge
## meets the head instead of hovering over it. The skin itself is keep-everything at 0.
func _head_surface(inflate: float, keep: Callable, cache_key: String, bulge: Callable = Callable()) -> ArrayMesh:
	var key := "head|%s|%s|%.3f" % [str(_head_shape), cache_key, inflate]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var inside: Array[bool] = []
	for i in HEAD_RINGS + 1:
		var theta := PI * i / HEAD_RINGS
		for j in HEAD_SEGMENTS + 1:
			var phi := TAU * j / HEAD_SEGMENTS
			var dir := Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))
			var normal := _head_normal(dir)
			var kept: bool = keep.call(dir)
			var out := inflate + (float(bulge.call(dir)) if bulge.is_valid() else 0.0)
			if not kept:
				out = minf(inflate, 0.0015)
			vertices.append(_head_point(dir) + normal * out)
			normals.append(normal)
			inside.append(kept)
	var indices := PackedInt32Array()
	var row := HEAD_SEGMENTS + 1
	for i in HEAD_RINGS:
		for j in HEAD_SEGMENTS:
			var a := i * row + j
			var b := a + 1
			var c := a + row
			var d := c + 1
			for tri: Array in [[a, b, c], [b, d, c]]:
				if not (inside[tri[0]] or inside[tri[1]] or inside[tri[2]]):
					continue
				var p0 := vertices[tri[0]]
				var p1 := vertices[tri[1]]
				var p2 := vertices[tri[2]]
				var outward := (normals[tri[0]] + normals[tri[1]] + normals[tri[2]])
				# Godot draws front faces whose (b - a) × (c - a) points away from the viewer.
				if (p1 - p0).cross(p2 - p0).dot(outward) > 0.0:
					indices.append_array([tri[0], tri[2], tri[1]])
				else:
					indices.append_array([tri[0], tri[1], tri[2]])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	if not indices.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_cache[key] = mesh
	return mesh


## True above a hairline that sits `front` up the forehead and `back` down the
## nape, rising over the ears when `ears` is set.
static func _above_hairline(dir: Vector3, front: float, back: float, ears: bool) -> bool:
	var facing := -dir.z
	var threshold := facing * front if facing > 0.0 else facing * back
	if ears:
		threshold += 0.35 * clampf((absf(dir.x) - 0.7) / 0.3, 0.0, 1.0) * clampf(1.0 - absf(dir.z) * 2.0, 0.0, 1.0)
	return dir.y > threshold


## True over the jaw below a beard line `top` at the front, rising to the ears
## at the sides, and never behind the ears.
static func _in_beard(dir: Vector3, top: float) -> bool:
	var facing := -dir.z
	if facing < -0.15:
		return false
	var line := lerpf(0.05, top, clampf(facing, 0.0, 1.0))
	return dir.y < line and not (facing > 0.3 and dir.y < -0.97)


func _head_part(mesh: Mesh, material: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	_head.add_child(instance)
	return instance


func _build_head(skin: Color, feminine: bool) -> void:
	var face := int(look.face)
	_head_shape = {
		"size": Vector3([0.21, 0.225, 0.19][face] * (0.95 if feminine else 1.0), [0.26, 0.26, 0.28][face], 0.24),
		"chin": [0.018, 0.024, 0.03][face],
		"jaw": [0.12, 0.02, 0.2][face] + (0.06 if feminine else 0.0),
	}
	var hair_color: Color = AppearanceTable.HAIR_COLORS[int(look.hair_color)]
	if hair_color.v < 0.12:
		hair_color.v = 0.12  # pure black hair reads as a hole in the head
	var beard := int(look.beard)
	var all := func(_d: Vector3) -> bool: return true

	_head_part(_head_surface(0.0, all, "skin"), _material(skin))
	for side: float in [-1.0, 1.0]:
		var ear_dir := Vector3(side, -0.08, 0.06)
		_ellipsoid(_head, Vector3(0.022, 0.058, 0.04), _head_point(ear_dir) + Vector3(side * 0.004, 0.0, 0.0), skin.darkened(0.06))
		var eye_dir := Vector3(side * 0.42, 0.13, -0.9)
		var eye := _head_point(eye_dir)
		var eye_out := _head_normal(eye_dir)
		_ellipsoid(_head, Vector3(0.042, 0.03, 0.02), eye - eye_out * 0.002, Color(0.95, 0.95, 0.93), _facing(eye_out))
		_ellipsoid(_head, Vector3(0.02, 0.022, 0.012), eye + eye_out * 0.005, AppearanceTable.EYE_COLORS[int(look.eyes)], _facing(eye_out))
		var brow_dir := Vector3(side * 0.42, 0.34, -0.86)
		var brow_out := _head_normal(brow_dir)
		_ellipsoid(_head, Vector3(0.056, 0.014, 0.018), _head_point(brow_dir) + brow_out * 0.002, hair_color, _facing(brow_out, side * -0.12))
	var nose_dir := Vector3(0.0, -0.1, -1.0)
	_ellipsoid(_head, Vector3(0.034, 0.058, 0.05), _head_point(nose_dir) + Vector3(0.0, 0.0, -0.008), skin.darkened(0.05))

	var beard_inflate := 0.0
	match beard:
		1:
			beard_inflate = 0.006
			_head_part(_head_surface(beard_inflate, func(d: Vector3) -> bool: return _in_beard(d, -0.25), "stubble"), _two_sided(_material(skin.darkened(0.25).lerp(hair_color, 0.35))))
		2:
			_head_part(_head_surface(0.02, func(d: Vector3) -> bool: return -d.z > 0.72 and d.y < -0.55, "goatee"), _two_sided(_material(hair_color)))
		3:
			beard_inflate = 0.022
			# Fuller under the chin, tapering up the cheeks.
			var fullness := func(d: Vector3) -> float: return 0.045 * maxf(0.0, -d.y) * maxf(0.0, -d.z)
			_head_part(_head_surface(beard_inflate, func(d: Vector3) -> bool: return _in_beard(d, -0.18), "full_beard", fullness), _two_sided(_material(hair_color)))
	var mouth_dir := Vector3(0.0, -0.52, -0.86)
	var mouth_out := _head_normal(mouth_dir)
	var mouth_lift := beard_inflate + (0.045 * 0.52 * 0.86 if beard == 3 else 0.0)
	_ellipsoid(_head, Vector3(0.046, 0.013, 0.012), _head_point(mouth_dir) + mouth_out * (mouth_lift + 0.001), Color(0.50, 0.26, 0.24), _facing(mouth_out))
	if beard == 4:
		var lip_dir := Vector3(0.0, -0.38, -0.92)
		var lip_out := _head_normal(lip_dir)
		_ellipsoid(_head, Vector3(0.08, 0.022, 0.024), _head_point(lip_dir) + lip_out * 0.006, hair_color, _facing(lip_out))

	var head_item: String = worn.get("head", "")
	var hatted := head_item in ["wool_beanie", "combat_helmet"]
	var style := int(look.hair)
	var hair_material := _two_sided(_material(hair_color))
	var hair_inflate: float = [0.0, 0.006, 0.018, 0.022, 0.016, 0.016, 0.0, 0.016][style]
	if style != 0 and style != 6 and not hatted:
		# With a full beard the sideburns come down to meet it instead of clearing the ears.
		var ears := beard != 3
		_head_part(_head_surface(hair_inflate, func(d: Vector3) -> bool: return _above_hairline(d, 0.42, 0.55, ears), "hair_%d_%s" % [style, ears]), hair_material)
	var back_dir := Vector3(0.0, -0.2, 1.0)
	var back := _head_point(back_dir)
	match style:
		3:
			if not hatted:
				var quiff_dir := Vector3(0.0, 0.72, -0.7)
				_ellipsoid(_head, Vector3(0.14, 0.06, 0.1), _head_point(quiff_dir) + _head_normal(quiff_dir) * 0.03, hair_color, Vector3(-0.4, 0.0, 0.0))
		4:
			_ellipsoid(_head, Vector3(_head_shape.size.x * 1.05, 0.34, 0.07), back + Vector3(0.0, -0.1, 0.02), hair_color)
			for side: float in [-1.0, 1.0]:
				var side_dir := Vector3(side, -0.2, 0.25)
				_ellipsoid(_head, Vector3(0.04, 0.24, 0.13), _head_point(side_dir) + Vector3(side * 0.015, -0.08, 0.0), hair_color)
		5:
			_ellipsoid(_head, Vector3(0.065, 0.22, 0.065), back + Vector3(0.0, -0.06, 0.04), hair_color, Vector3(0.3, 0.0, 0.0))
		6:
			if not hatted:
				_head_part(_head_surface(0.045, func(d: Vector3) -> bool: return absf(d.x) < 0.16 and d.y > -0.25 and _above_hairline(d, 0.42, 0.55, false), "mohawk"), hair_material)
		7:
			if not hatted:
				var bun_dir := Vector3(0.0, 0.55, 0.83)
				_ellipsoid(_head, Vector3.ONE * 0.1, _head_point(bun_dir) + _head_normal(bun_dir) * 0.04, hair_color)

	match head_item:
		"wool_beanie":
			var beanie := clothing_color(head_item)
			var top := func(d: Vector3) -> bool: return _above_hairline(d, 0.52, 0.3, false)
			_head_part(_head_surface(0.03, top, "beanie"), _two_sided(Materials.cloth(beanie)))
			var cuff := func(d: Vector3) -> bool:
				return _above_hairline(d, 0.52, 0.3, false) and not _above_hairline(d + Vector3(0.0, -0.2, 0.0), 0.52, 0.3, false)
			_head_part(_head_surface(0.042, cuff, "beanie_cuff"), _two_sided(Materials.cloth(beanie.darkened(0.2))))
		"sun_hat":
			var hat := clothing_color(head_item)
			_head_part(_head_surface(0.035, func(d: Vector3) -> bool: return d.y > 0.42, "sun_hat"), _two_sided(Materials.cloth(hat)))
			var brim_y := _head_point(Vector3(0.0, 0.42, -0.9)).y + 0.01
			_cylinder(_head, 0.25, 0.012, Vector3(0.0, brim_y, 0.0), hat)
		"combat_helmet":
			var helmet := clothing_color(head_item)
			# One smooth edge: at the brow in front, over the ears, down to the nape.
			var edge := func(d: Vector3) -> float: return maxf(-0.15, 0.1 + 0.25 * -d.z)
			var shell := func(d: Vector3) -> bool: return d.y > float(edge.call(d))
			_head_part(_head_surface(0.03, shell, "helmet"), _two_sided(Materials.cloth(helmet)))
			_head_part(_head_surface(0.004, shell, "helmet_liner"), _two_sided(_material(helmet.darkened(0.55))))
			var rim := func(d: Vector3) -> bool:
				var e: float = edge.call(d)
				return d.y > e and d.y < e + 0.09
			_head_part(_head_surface(0.04, rim, "helmet_rim"), _two_sided(_material(helmet.darkened(0.25))))
			var mount_dir := Vector3(0.0, 0.62, -0.78)
			var mount_out := _head_normal(mount_dir)
			_ellipsoid(_head, Vector3(0.05, 0.03, 0.012), _head_point(mount_dir) + mount_out * 0.036, helmet.darkened(0.35), _facing(mount_out))


func _rebuild_held() -> void:
	if _held_root != null and is_instance_valid(_held_root):
		_held_root.queue_free()
	_held_root = null
	if held_id.is_empty() or not _arms.has("r"):
		return
	_held_root = ItemModels.build(held_id)
	_held_root.rotation.x = -PI / 2.0
	_held_root.position = Vector3(0.0, -0.05, 0.0)
	(_arms.r.hand as Node3D).add_child(_held_root)


# --- animation --------------------------------------------------------------------

## speed: horizontal m/s · head_pitch: radians, + looks up.
func animate(delta: float, speed: float, swimming: bool, crouching: bool, head_pitch: float) -> void:
	if _pelvis == null:
		return
	var moving := clampf(speed / 6.0, 0.0, 1.0)
	if moving > 0.05 or swimming:
		_phase = fmod(_phase + delta * (4.0 + speed * 1.2), TAU)
	_swing_t = maxf(0.0, _swing_t - delta * 2.6)
	_breath = fmod(_breath + delta * 1.6, TAU)
	var swing := sin(_phase) * moving
	var t := 1.0 - exp(-12.0 * delta)

	var pelvis_y := HIP_Y + absf(sin(_phase)) * 0.035 * moving
	var body_pitch := 0.0
	var legs := [swing * 0.7, -swing * 0.7]
	var knees := [-maxf(0.0, -sin(_phase)) * moving, -maxf(0.0, sin(_phase)) * moving]
	var arms := [-swing * 0.6, swing * 0.6]
	var elbows := [0.2 + 0.35 * moving, 0.2 + 0.35 * moving]

	if swimming:
		var stroke := sin(_phase * 0.7)
		pelvis_y = HIP_Y - 0.15
		body_pitch = -1.15
		arms = [2.4 + stroke * 0.8, 2.4 - stroke * 0.8]
		elbows = [0.3, 0.3]
		legs = [sin(_phase * 2.0) * 0.3, -sin(_phase * 2.0) * 0.3]
		knees = [-0.2, -0.2]
	elif crouching:
		pelvis_y = HIP_Y - 0.36
		body_pitch = -0.3
		legs = [1.15 + swing * 0.3, 1.15 - swing * 0.3]
		knees = [-1.9, -1.9]

	if not held_id.is_empty() and not swimming:
		arms[1] = maxf(arms[1], 0.35)
		elbows[1] = 0.95
	# The swing arcs the right arm up and out to the side, clear of the face.
	var arm_out := 0.0
	if _swing_t > 0.0:
		var arc := sin(_swing_t * PI)
		arms[1] += arc * 2.0
		elbows[1] = minf(elbows[1] + arc * 0.4, 0.7)
		arm_out = 0.4 * arc

	_pelvis.position.y = lerpf(_pelvis.position.y, pelvis_y, t)
	_pelvis.rotation.x = lerp_angle(_pelvis.rotation.x, body_pitch, t)
	_spine.rotation.x = sin(_breath) * 0.01
	for i in 2:
		var key := "l" if i == 0 else "r"
		_legs[key].hip.rotation.x = lerp_angle(_legs[key].hip.rotation.x, legs[i], t)
		_legs[key].knee.rotation.x = lerp_angle(_legs[key].knee.rotation.x, knees[i], t)
		_arms[key].shoulder.rotation.x = lerp_angle(_arms[key].shoulder.rotation.x, arms[i], t)
		_arms[key].elbow.rotation.x = lerp_angle(_arms[key].elbow.rotation.x, elbows[i], t)
		_arms[key].shoulder.rotation.z = lerp_angle(_arms[key].shoulder.rotation.z, arm_out if i == 1 else 0.0, t)
	_head.rotation.x = lerp_angle(_head.rotation.x, clampf(head_pitch, -0.9, 0.9) - body_pitch * (0.7 if swimming else 0.0), t)


# --- mesh helpers -------------------------------------------------------------------

func _joint(parent: Node3D, joint_name: String, pos: Vector3) -> Node3D:
	var joint := Node3D.new()
	joint.name = joint_name
	joint.position = pos
	parent.add_child(joint)
	return joint


static func _material(color: Color) -> StandardMaterial3D:
	var key := "body_" + color.to_html(false)
	if not _material_cache.has(key):
		# Soft, slightly satin skin and hair with a rim of light, rather than flat clay.
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.68
		m.rim_enabled = true
		m.rim = 0.22
		m.rim_tint = 0.5
		_material_cache[key] = m
	return _material_cache[key]


## Euler rotation that lays a face feature flat on the surface with normal `out`.
static func _facing(out: Vector3, roll: float = 0.0) -> Vector3:
	var basis := Basis.looking_at(-out, Vector3.UP)
	return (basis * Basis(Vector3.BACK, roll)).get_euler()


static func _two_sided(source: StandardMaterial3D) -> StandardMaterial3D:
	var key := source.get_instance_id()
	if not _material_cache.has(key):
		var copy := source.duplicate() as StandardMaterial3D
		copy.cull_mode = BaseMaterial3D.CULL_DISABLED
		_material_cache[key] = copy
	return _material_cache[key]


static func _vertex_color_material() -> StandardMaterial3D:
	if not _material_cache.has("vertex"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		_material_cache["vertex"] = m
	return _material_cache["vertex"]


static func _unit_sphere() -> SphereMesh:
	if _sphere == null:
		_sphere = SphereMesh.new()
		_sphere.radius = 0.5
		_sphere.height = 1.0
		_sphere.radial_segments = SEGMENTS
		_sphere.rings = RINGS
	return _sphere


## A smooth ellipsoid `size` across.
func _ellipsoid(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> void:
	var instance := _mesh(parent, _unit_sphere(), pos, color, rot)
	instance.scale = size


func _capsule(parent: Node3D, radius: float, length: float, pos: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(length + radius, radius * 2.0)
	mesh.radial_segments = 14
	mesh.rings = 4
	_mesh(parent, mesh, pos, color, rot)


func _cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color, stretch: Vector3 = Vector3.ONE) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 1
	var instance := _mesh(parent, mesh, pos, color)
	instance.scale = stretch


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color)
	instance.position = pos
	instance.rotation = rot
	parent.add_child(instance)
	return instance


## A small picture (emblem) facing forward (-Z).
func _decal(parent: Node3D, texture: Texture2D, size: float, pos: Vector3) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.4
	material.roughness = 1.0
	var instance := MeshInstance3D.new()
	instance.mesh = quad
	instance.material_override = material
	instance.position = pos
	instance.rotation.y = PI
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
