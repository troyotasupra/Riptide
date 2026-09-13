class_name CharacterModel
extends Node3D
## A crew member's visible body, built in code: a jointed figure with a smooth
## lofted torso (hips → waist → chest → sloped shoulders), rounded limbs,
## natural proportions, a face, hair and facial hair from the player's look,
## and every worn clothing and gear piece shown on it. Animated procedurally
## (walk, run, crouch, swim, tool swings) so no animation files are needed.
##
## Faces -Z. Origin at the feet.

const HIP_Y := 0.92
const THIGH := 0.42
const SHIN := 0.42
const TORSO := 0.46
const UPPER_ARM := 0.3
const FOREARM := 0.28
## Smoothness of the rounded shapes.
const SEGMENTS := 18
const RINGS := 10
const TORSO_SEGMENTS := 24
## Where trousers end and the shirt begins, in pelvis space.
const WAIST_SPLIT := 0.11
## Beards are the lower half of an ellipsoid around the jaw, tipped back by this
## much so their front edge sits just under the nose and the back tucks under the ears.
const BEARD_TILT := -0.25

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
static var _hemisphere: SphereMesh
static var _torso_cache := {}
static var _vertex_material: StandardMaterial3D

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

	# The spine carries the arms, neck and chest gear; the torso shape itself
	# lives on the pelvis so it bends with the body as one smooth piece.
	_spine = _joint(_pelvis, "Spine", Vector3(0.0, 0.08, 0.0))
	if torso_item == "tshirt" and emblem_index > 0:
		var badge := Vector2(-shoulder_w * 0.2, 0.37)
		var z := _front_z(profile, badge.x, badge.y + 0.08) - 0.006
		_decal(_spine, Emblem.texture(emblem_index, Emblem.contrast(shirt)), 0.1, Vector3(badge.x, badge.y, z))

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

	_build_gear(profile, shoulder_w, depth, feminine)

	var neck := _joint(_spine, "Neck", Vector3(0.0, TORSO, 0.0))
	_capsule(neck, (0.052 if feminine else 0.06) * build, 0.12, Vector3(0.0, 0.01, 0.0), skin)
	_head = _joint(neck, "Head", Vector3(0.0, 0.16, 0.0))
	_build_head(skin, feminine)
	_rebuild_held()


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


## Front surface (-Z) of the torso at pelvis-space (x, y).
static func _front_z(profile: Array, x: float, y: float) -> float:
	for i in range(1, profile.size()):
		var a: Array = profile[i - 1]
		var b: Array = profile[i]
		if y <= float(b[0]):
			var t := clampf((y - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001), 0.0, 1.0)
			var rx := lerpf(a[1], b[1], t)
			var rz := lerpf(a[2], b[2], t)
			var nx := x / maxf(rx, 0.0001)
			return -rz * sqrt(maxf(0.0, 1.0 - nx * nx))
	return 0.0


## A smooth, closed torso lofted through the profile rings, coloured below and
## above the waist. Cached, since crews share builds and outfits.
static func _torso_mesh(profile: Array, split_y: float, lower: Color, upper: Color) -> ArrayMesh:
	var key := "%s|%.3f|%s|%s" % [str(profile), split_y, lower.to_html(false), upper.to_html(false)]
	if _torso_cache.has(key):
		return _torso_cache[key]
	var rings: Array = []
	for i in profile.size():
		var row: Array = profile[i]
		if i > 0:
			var prev: Array = profile[i - 1]
			if float(prev[0]) < split_y and float(row[0]) >= split_y:
				var t := (split_y - float(prev[0])) / (float(row[0]) - float(prev[0]))
				var rx := lerpf(prev[1], row[1], t)
				var rz := lerpf(prev[2], row[2], t)
				rings.append([split_y, rx, rz, lower])
				rings.append([split_y, rx, rz, upper])
		rings.append([row[0], row[1], row[2], lower if float(row[0]) < split_y else upper])

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
		for j in TORSO_SEGMENTS + 1:
			var a := TAU * j / TORSO_SEGMENTS
			var rx := float(ring[1])
			var rz := float(ring[2])
			vertices.append(Vector3(rx * cos(a), ring[0], rz * sin(a)))
			var along_a := Vector3(-rx * sin(a), 0.0, rz * cos(a))
			var along_y := Vector3(d_rx * cos(a), d_y, d_rz * sin(a))
			var normal := along_y.cross(along_a)
			if normal.length_squared() < 0.0000001:
				normal = Vector3.DOWN if r == 0 else Vector3.UP
			normals.append(normal.normalized())
			colors.append(ring[3])
	var row_size := TORSO_SEGMENTS + 1
	for r in last:
		for j in TORSO_SEGMENTS:
			var v00 := r * row_size + j
			var v01 := v00 + 1
			var v10 := v00 + row_size
			var v11 := v10 + 1
			indices.append_array([v00, v01, v10, v01, v11, v10])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_torso_cache[key] = mesh
	return mesh


static func _vertex_color_material() -> StandardMaterial3D:
	if _vertex_material == null:
		_vertex_material = StandardMaterial3D.new()
		_vertex_material.vertex_color_use_as_albedo = true
		_vertex_material.vertex_color_is_srgb = true
		_vertex_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _vertex_material


func _build_gear(profile: Array, shoulder_w: float, depth: float, feminine: bool) -> void:
	var vest: String = worn.get("vest", "")
	var chest_front := _front_z(profile, 0.0, 0.4)
	var chest_back := -chest_front
	if vest == "plate_carrier":
		var color := clothing_color(vest)
		var front_z := chest_front - 0.015
		_rounded_plate(_spine, Vector3(shoulder_w * 0.84, 0.3, 0.05), Vector3(0.0, 0.26, front_z), color)
		_rounded_plate(_spine, Vector3(shoulder_w * 0.84, 0.3, 0.05), Vector3(0.0, 0.26, chest_back + 0.015), color)
		for side: float in [-1.0, 1.0]:
			_ellipsoid(_spine, Vector3(0.07, 0.035, depth * 1.08), Vector3(side * shoulder_w * 0.27, 0.45, 0.0), color.darkened(0.15))
			_ellipsoid(_spine, Vector3(0.05, 0.17, depth * 0.9), Vector3(side * shoulder_w * 0.45, 0.19, 0.0), color.darkened(0.1))
		for x: float in [-0.09, 0.0, 0.09]:
			_rounded_plate(_spine, Vector3(0.075, 0.09, 0.045), Vector3(x * shoulder_w / 0.43, 0.17, front_z - 0.045), color.darkened(0.25))
		if emblem_index > 0:
			_decal(_spine, Emblem.texture(emblem_index, Emblem.contrast(color)), 0.08, Vector3(-shoulder_w * 0.2, 0.34, front_z - 0.034))
	if worn.get("back", "") == "daypack":
		var pack := clothing_color("daypack")
		var back_z := chest_back + (0.11 if vest == "plate_carrier" else 0.07)
		_ellipsoid(_spine, Vector3(shoulder_w * 0.72, 0.38, 0.16), Vector3(0.0, 0.25, back_z), pack)
		_ellipsoid(_spine, Vector3(shoulder_w * 0.6, 0.12, 0.1), Vector3(0.0, 0.13, back_z + 0.06), pack.darkened(0.2))


func _build_head(skin: Color, feminine: bool) -> void:
	var face := int(look.face)
	var w: float = [0.21, 0.225, 0.19][face] * (0.95 if feminine else 1.0)
	var h: float = [0.26, 0.26, 0.28][face]
	var d := 0.24
	var skull := Vector3(w, h, d)
	var hair_color: Color = AppearanceTable.HAIR_COLORS[int(look.hair_color)]
	var beard := int(look.beard)

	_ellipsoid(_head, skull, Vector3.ZERO, skin)
	var jaw_w: float = [0.78, 0.9, 0.7][face] * (0.9 if feminine else 1.0)
	_ellipsoid(_head, Vector3(w * jaw_w, h * 0.52, d * 0.78), Vector3(0.0, -h * 0.2, -d * 0.06), skin)
	for side: float in [-1.0, 1.0]:
		_ellipsoid(_head, Vector3(0.024, 0.06, 0.042), Vector3(side * w * 0.49, -0.01, 0.01), skin.darkened(0.05))
		var eye := Vector2(side * w * 0.24, 0.018)
		var eye_z := _surface_z(skull, Vector3.ZERO, eye.x, eye.y)
		_ellipsoid(_head, Vector3(0.042, 0.03, 0.02), Vector3(eye.x, eye.y, eye_z + 0.004), Color(0.95, 0.95, 0.93))
		_ellipsoid(_head, Vector3(0.02, 0.022, 0.012), Vector3(eye.x, eye.y, eye_z - 0.004), AppearanceTable.EYE_COLORS[int(look.eyes)])
		var brow_z := _surface_z(skull, Vector3.ZERO, eye.x, 0.05)
		_ellipsoid(_head, Vector3(0.056, 0.014, 0.018), Vector3(eye.x, 0.05, brow_z), hair_color, Vector3(0.0, 0.0, side * -0.12))
	var nose_z := _surface_z(skull, Vector3.ZERO, 0.0, -0.015)
	_ellipsoid(_head, Vector3(0.034, 0.058, 0.05), Vector3(0.0, -0.015, nose_z - 0.006), skin.darkened(0.05))
	var bearded := beard == 1 or beard == 3
	var mouth_z := _surface_z(skull, Vector3.ZERO, 0.0, -0.07) - (0.016 if bearded else 0.002)
	_ellipsoid(_head, Vector3(0.062, 0.014, 0.014), Vector3(0.0, -0.07, mouth_z), Color(0.50, 0.26, 0.24))

	match beard:
		1:
			_hemisphere_part(_head, Vector3(w * 1.03, h * 0.94, d * 1.04), Vector3(0.0, -0.014, 0.0), skin.darkened(0.2).lerp(hair_color, 0.35), Vector3(PI + BEARD_TILT, 0.0, 0.0))
		2:
			_ellipsoid(_head, Vector3(0.055, 0.065, 0.045), Vector3(0.0, -0.11, _surface_z(skull, Vector3.ZERO, 0.0, -0.1) + 0.01), hair_color)
		3:
			_hemisphere_part(_head, Vector3(w * 1.07, h * 0.96, d * 1.07), Vector3(0.0, -0.016, 0.0), hair_color, Vector3(PI + BEARD_TILT, 0.0, 0.0))
			_ellipsoid(_head, Vector3(w * 0.5, 0.08, 0.08), Vector3(0.0, -h * 0.45, -d * 0.3), hair_color)
		4:
			_ellipsoid(_head, Vector3(0.09, 0.024, 0.03), Vector3(0.0, -0.048, mouth_z - 0.004), hair_color)

	var head_item: String = worn.get("head", "")
	var hatted := head_item in ["wool_beanie", "combat_helmet"]
	var style := int(look.hair)
	if style != 0 and style != 6 and not hatted:
		var cap_scale: float = [1.0, 1.04, 1.08, 1.1, 1.08, 1.08, 1.0, 1.08][style]
		_hemisphere_part(_head, skull * cap_scale, Vector3(0.0, -0.004, 0.004), hair_color, Vector3(0.48, 0.0, 0.0))
	match style:
		2, 5:
			_ellipsoid(_head, Vector3(w * 1.02, h * 0.55, d * 0.42), Vector3(0.0, -0.035, d * 0.3), hair_color)
			if style == 5:
				_ellipsoid(_head, Vector3(0.07, 0.24, 0.07), Vector3(0.0, -0.08, d * 0.62), hair_color, Vector3(0.35, 0.0, 0.0))
		3:
			_ellipsoid(_head, Vector3(w * 1.02, h * 0.5, d * 0.42), Vector3(0.0, -0.03, d * 0.3), hair_color)
			if not hatted:
				_ellipsoid(_head, Vector3(w * 0.8, 0.08, 0.13), Vector3(0.0, h * 0.47, -d * 0.24), hair_color, Vector3(-0.35, 0.0, 0.0))
		4:
			_ellipsoid(_head, Vector3(w * 1.08, 0.44, 0.11), Vector3(0.0, -0.11, d * 0.42), hair_color)
			for side: float in [-1.0, 1.0]:
				_ellipsoid(_head, Vector3(0.05, 0.3, d * 0.6), Vector3(side * w * 0.5, -0.09, 0.03), hair_color)
		6:
			if not hatted:
				_ellipsoid(_head, Vector3(0.05, 0.12, d * 1.02), Vector3(0.0, h * 0.44, 0.0), hair_color)
		7:
			if not hatted:
				_ellipsoid(_head, Vector3.ONE * 0.12, Vector3(0.0, h * 0.44, d * 0.36), hair_color)

	match head_item:
		"wool_beanie":
			var beanie := clothing_color(head_item)
			_hemisphere_part(_head, Vector3(w * 1.16, h * 1.35, d * 1.16), Vector3(0.0, 0.02, 0.004), beanie, Vector3(0.45, 0.0, 0.0))
			_torus(_head, Vector3(w * 1.2, 1.5, d * 1.2), Vector3(0.0, 0.03, 0.004), beanie.darkened(0.2), Vector3(0.45, 0.0, 0.0))
		"sun_hat":
			var hat := clothing_color(head_item)
			_cylinder(_head, 0.24, 0.012, Vector3(0.0, h * 0.3, 0.0), hat)
			_hemisphere_part(_head, Vector3(w * 1.12, h * 0.9, d * 1.1), Vector3(0.0, h * 0.28, 0.0), hat)
		"combat_helmet":
			var helmet := clothing_color(head_item)
			_hemisphere_part(_head, Vector3(w * 1.28, h * 1.4, d * 1.26), Vector3(0.0, 0.012, 0.008), helmet, Vector3(0.22, 0.0, 0.0))
			_torus(_head, Vector3(w * 1.3, 1.2, d * 1.28), Vector3(0.0, 0.019, 0.008), helmet.darkened(0.15), Vector3(0.22, 0.0, 0.0))
			_rounded_plate(_head, Vector3(0.05, 0.04, 0.03), Vector3(0.0, h * 0.36, -d * 0.6), Color(0.12, 0.12, 0.13))


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
	if _swing_t > 0.0:
		var arc := sin(_swing_t * PI)
		arms[1] += arc * 2.0
		elbows[1] += arc * 0.4

	_pelvis.position.y = lerpf(_pelvis.position.y, pelvis_y, t)
	_pelvis.rotation.x = lerp_angle(_pelvis.rotation.x, body_pitch, t)
	_spine.rotation.x = sin(_breath) * 0.012
	for i in 2:
		var key := "l" if i == 0 else "r"
		_legs[key].hip.rotation.x = lerp_angle(_legs[key].hip.rotation.x, legs[i], t)
		_legs[key].knee.rotation.x = lerp_angle(_legs[key].knee.rotation.x, knees[i], t)
		_arms[key].shoulder.rotation.x = lerp_angle(_arms[key].shoulder.rotation.x, arms[i], t)
		_arms[key].elbow.rotation.x = lerp_angle(_arms[key].elbow.rotation.x, elbows[i], t)
	_head.rotation.x = lerp_angle(_head.rotation.x, clampf(head_pitch, -0.9, 0.9) - body_pitch * (0.7 if swimming else 0.0), t)


# --- mesh helpers -------------------------------------------------------------------

func _joint(parent: Node3D, joint_name: String, pos: Vector3) -> Node3D:
	var joint := Node3D.new()
	joint.name = joint_name
	joint.position = pos
	parent.add_child(joint)
	return joint


static func _material(color: Color) -> Material:
	return Props.material("body_" + color.to_html(false), color)


## Front surface (-Z) of an ellipsoid of `size` centred at `center`, at (x, y).
static func _surface_z(size: Vector3, center: Vector3, x: float, y: float) -> float:
	var nx := (x - center.x) / (size.x * 0.5)
	var ny := (y - center.y) / (size.y * 0.5)
	return center.z - size.z * 0.5 * sqrt(maxf(0.0, 1.0 - nx * nx - ny * ny))


static func _unit_sphere() -> SphereMesh:
	if _sphere == null:
		_sphere = SphereMesh.new()
		_sphere.radius = 0.5
		_sphere.height = 1.0
		_sphere.radial_segments = SEGMENTS
		_sphere.rings = RINGS
	return _sphere


static func _unit_hemisphere() -> SphereMesh:
	if _hemisphere == null:
		_hemisphere = SphereMesh.new()
		_hemisphere.radius = 0.5
		_hemisphere.height = 0.5
		_hemisphere.is_hemisphere = true
		_hemisphere.radial_segments = SEGMENTS
		_hemisphere.rings = RINGS / 2
	return _hemisphere


## A smooth ellipsoid `size` across.
func _ellipsoid(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> void:
	var instance := _mesh(parent, _unit_sphere(), pos, color, rot)
	instance.scale = size


## The top half of an ellipsoid `size` across (hair, hats); rotate by PI for a lower half (beards).
func _hemisphere_part(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> void:
	var instance := _mesh(parent, _unit_hemisphere(), pos, color, rot)
	instance.scale = size
	instance.material_override = _two_sided(color)


## A soft pad for rigid gear like armour plates and pouches.
func _rounded_plate(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	_ellipsoid(parent, size * Vector3(1.0, 1.0, 1.3), pos, color)


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


## A ring (beanie cuff, helmet rim), scaled to fit around the head.
func _torus(parent: Node3D, stretch: Vector3, pos: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.47
	mesh.outer_radius = 0.53
	mesh.rings = 24
	mesh.ring_segments = 8
	var instance := _mesh(parent, mesh, pos, color, rot)
	instance.scale = stretch


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color)
	instance.position = pos
	instance.rotation = rot
	parent.add_child(instance)
	return instance


static func _two_sided(color: Color) -> Material:
	var key := "body2_" + color.to_html(false)
	var material := Props.material(key, color)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


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
