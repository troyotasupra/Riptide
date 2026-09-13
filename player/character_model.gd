class_name CharacterModel
extends Node3D
## A crew member's visible body, built in code to match the low-poly world:
## a jointed figure with a face, hair and facial hair from the player's look,
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
	var shoulder_w := (0.35 if feminine else 0.40) * build
	var hip_w := (0.35 if feminine else 0.32) * build
	var depth := 0.22 * build
	var arm_r := (0.04 if feminine else 0.046) * build
	var leg_r := 0.064 * build

	var torso_item: String = worn.get("torso", "")
	var legs_item: String = worn.get("legs", "")
	var feet_item: String = worn.get("feet", "")
	var shirt := clothing_color(torso_item) if not torso_item.is_empty() else skin
	var long_sleeves := torso_item in ["rain_jacket", "wool_sweater"]
	var pants := clothing_color(legs_item) if not legs_item.is_empty() else UNDERWEAR
	var long_legs := legs_item == "cargo_pants"

	_pelvis = Node3D.new()
	_pelvis.name = "Pelvis"
	_pelvis.position.y = HIP_Y
	add_child(_pelvis)
	_box(_pelvis, Vector3(hip_w, 0.18, depth * 0.95), Vector3(0.0, 0.02, 0.0), pants)

	for side: float in [-1.0, 1.0]:
		var key := "l" if side < 0.0 else "r"
		var hip := _joint(_pelvis, "Hip_" + key, Vector3(side * (hip_w * 0.5 - leg_r), -0.02, 0.0))
		_capsule(hip, leg_r, THIGH, Vector3(0.0, -THIGH * 0.5, 0.0), skin if legs_item.is_empty() else (pants if long_legs else skin))
		if legs_item == "shorts":
			_capsule(hip, leg_r + 0.012, THIGH * 0.55, Vector3(0.0, -THIGH * 0.26, 0.0), pants)
		var knee := _joint(hip, "Knee_" + key, Vector3(0.0, -THIGH, 0.0))
		_capsule(knee, leg_r * 0.85, SHIN, Vector3(0.0, -SHIN * 0.5, 0.0), pants if long_legs else skin)
		var foot_color := skin
		if feet_item == "hiking_boots":
			foot_color = clothing_color(feet_item)
			_capsule(knee, leg_r * 0.95, 0.14, Vector3(0.0, -SHIN + 0.06, 0.0), foot_color)
		_box(knee, Vector3(0.1 * build, 0.08, 0.25), Vector3(0.0, -SHIN - 0.04, -0.05), foot_color)
		if feet_item == "sandals":
			_box(knee, Vector3(0.11 * build, 0.02, 0.27), Vector3(0.0, -SHIN - 0.075, -0.05), clothing_color(feet_item))
		_legs[key] = {"hip": hip, "knee": knee}

	_spine = _joint(_pelvis, "Spine", Vector3(0.0, 0.08, 0.0))
	var bulk := 1.06 if long_sleeves else 1.0
	var waist_w := lerpf(hip_w, shoulder_w, 0.35)
	_box(_spine, Vector3(waist_w * bulk, 0.22, depth * bulk), Vector3(0.0, 0.11, 0.0), shirt)
	_box(_spine, Vector3(shoulder_w * bulk, 0.26, depth * 1.05 * bulk), Vector3(0.0, 0.33, 0.0), shirt)
	if feminine:
		var top := shirt if not torso_item.is_empty() else UNDERWEAR
		_box(_spine, Vector3(shoulder_w * 0.72, 0.1, 0.07), Vector3(0.0, 0.32, -depth * 0.5 - 0.02), top)
	if torso_item == "tshirt" and emblem_index > 0:
		_decal(_spine, Emblem.texture(emblem_index, Emblem.contrast(shirt)), 0.13, Vector3(0.0, 0.34, -depth * 0.55 - (0.075 if feminine else 0.01)))

	for side: float in [-1.0, 1.0]:
		var key := "l" if side < 0.0 else "r"
		var shoulder := _joint(_spine, "Shoulder_" + key, Vector3(side * (shoulder_w * 0.5 + arm_r * 0.8), TORSO - 0.06, 0.0))
		_capsule(shoulder, arm_r, UPPER_ARM, Vector3(0.0, -UPPER_ARM * 0.5, 0.0), shirt if long_sleeves else skin)
		if torso_item == "tshirt":
			_capsule(shoulder, arm_r + 0.013, UPPER_ARM * 0.5, Vector3(0.0, -UPPER_ARM * 0.2, 0.0), shirt)
		var elbow := _joint(shoulder, "Elbow_" + key, Vector3(0.0, -UPPER_ARM, 0.0))
		_capsule(elbow, arm_r * 0.9, FOREARM, Vector3(0.0, -FOREARM * 0.5, 0.0), shirt if long_sleeves else skin)
		var hand := _joint(elbow, "Hand_" + key, Vector3(0.0, -FOREARM - 0.03, 0.0))
		_box(hand, Vector3(0.07, 0.09, 0.05) * build, Vector3(0.0, -0.03, 0.0), skin)
		_arms[key] = {"shoulder": shoulder, "elbow": elbow, "hand": hand}

	_build_gear(shoulder_w, depth, feminine)

	var neck := _joint(_spine, "Neck", Vector3(0.0, TORSO, 0.0))
	_capsule(neck, 0.05 * build, 0.08, Vector3(0.0, 0.02, 0.0), skin)
	_head = _joint(neck, "Head", Vector3(0.0, 0.16, 0.0))
	_build_head(skin, feminine)
	_rebuild_held()


func _build_gear(shoulder_w: float, depth: float, feminine: bool) -> void:
	var vest: String = worn.get("vest", "")
	if vest == "plate_carrier":
		var color := clothing_color(vest)
		var front_z := -depth * 0.5 - (0.075 if feminine else 0.03)
		_box(_spine, Vector3(shoulder_w * 0.92, 0.32, 0.05), Vector3(0.0, 0.29, front_z), color)
		_box(_spine, Vector3(shoulder_w * 0.92, 0.32, 0.05), Vector3(0.0, 0.29, depth * 0.5 + 0.03), color)
		for side: float in [-1.0, 1.0]:
			_box(_spine, Vector3(0.05, 0.03, depth + 0.12), Vector3(side * shoulder_w * 0.3, 0.46, 0.0), color.darkened(0.15))
			_box(_spine, Vector3(0.04, 0.16, depth + 0.02), Vector3(side * shoulder_w * 0.5, 0.22, 0.0), color.darkened(0.1))
		for x: float in [-0.09, 0.0, 0.09]:
			_box(_spine, Vector3(0.075, 0.09, 0.045), Vector3(x * shoulder_w / 0.4, 0.2, front_z - 0.045), color.darkened(0.25))
		if emblem_index > 0:
			_decal(_spine, Emblem.texture(emblem_index, Emblem.contrast(color)), 0.08, Vector3(-shoulder_w * 0.22, 0.38, front_z - 0.027))
	if worn.get("back", "") == "daypack":
		var pack := clothing_color("daypack")
		_box(_spine, Vector3(shoulder_w * 0.7, 0.34, 0.14), Vector3(0.0, 0.26, depth * 0.5 + (0.13 if vest == "plate_carrier" else 0.08)), pack)
		_box(_spine, Vector3(shoulder_w * 0.72, 0.1, 0.15), Vector3(0.0, 0.4, depth * 0.5 + (0.13 if vest == "plate_carrier" else 0.08)), pack.darkened(0.2))


func _build_head(skin: Color, feminine: bool) -> void:
	var face := int(look.face)
	var w: float = [0.23, 0.25, 0.21][face] * (0.94 if feminine else 1.0)
	var h: float = [0.26, 0.26, 0.28][face]
	var d := 0.245
	var front := -d * 0.5
	var hair_color: Color = AppearanceTable.HAIR_COLORS[int(look.hair_color)]
	_box(_head, Vector3(w, h, d), Vector3.ZERO, skin)
	if face == 1:
		_box(_head, Vector3(w + 0.01, 0.08, d * 0.9), Vector3(0.0, -h * 0.5 + 0.04, 0.0), skin)
	for side: float in [-1.0, 1.0]:
		_box(_head, Vector3(0.02, 0.06, 0.04), Vector3(side * (w * 0.5 + 0.008), -0.01, 0.01), skin.darkened(0.05))
		_box(_head, Vector3(0.046, 0.032, 0.01), Vector3(side * 0.055, 0.02, front - 0.002), Color(0.95, 0.95, 0.93))
		_box(_head, Vector3(0.02, 0.026, 0.01), Vector3(side * 0.055, 0.02, front - 0.006), AppearanceTable.EYE_COLORS[int(look.eyes)])
		_box(_head, Vector3(0.062, 0.015, 0.012), Vector3(side * 0.055, 0.056, front - 0.004), hair_color)
	_box(_head, Vector3(0.034, 0.06, 0.04), Vector3(0.0, -0.02, front - 0.016), skin.darkened(0.08))
	_box(_head, Vector3(0.07, 0.013, 0.01), Vector3(0.0, -0.075, front - 0.003), Color(0.45, 0.22, 0.20))

	match int(look.beard):
		1:
			_box(_head, Vector3(w + 0.004, 0.09, d * 0.9), Vector3(0.0, -h * 0.5 + 0.045, 0.01), skin.lerp(hair_color, 0.4))
		2:
			_box(_head, Vector3(0.06, 0.065, 0.03), Vector3(0.0, -0.11, front - 0.008), hair_color)
		3:
			_box(_head, Vector3(w + 0.02, 0.12, d * 0.88), Vector3(0.0, -h * 0.5 + 0.05, 0.02), hair_color)
			_box(_head, Vector3(w * 0.7, 0.07, 0.06), Vector3(0.0, -h * 0.5 - 0.01, front + 0.02), hair_color)
		4:
			_box(_head, Vector3(0.09, 0.022, 0.016), Vector3(0.0, -0.055, front - 0.008), hair_color)

	var head_item: String = worn.get("head", "")
	var hatted := head_item in ["wool_beanie", "combat_helmet"]
	var top := h * 0.5
	match int(look.hair):
		1:
			if not hatted:
				_box(_head, Vector3(w + 0.01, 0.03, d + 0.01), Vector3(0.0, top - 0.005, 0.0), hair_color)
		2, 5, 7:
			if not hatted:
				_box(_head, Vector3(w + 0.02, 0.06, d + 0.02), Vector3(0.0, top + 0.01, 0.0), hair_color)
			_box(_head, Vector3(w + 0.02, 0.14, 0.03), Vector3(0.0, top - 0.08, d * 0.5 + 0.005), hair_color)
			if int(look.hair) == 5:
				_box(_head, Vector3(0.05, 0.2, 0.05), Vector3(0.0, top - 0.13, d * 0.5 + 0.05), hair_color, Vector3(0.3, 0.0, 0.0))
			elif int(look.hair) == 7 and not hatted:
				_sphere(_head, 0.065, Vector3(0.0, top + 0.02, d * 0.5 - 0.02), hair_color)
		3:
			if not hatted:
				_box(_head, Vector3(w + 0.02, 0.08, d + 0.02), Vector3(0.0, top + 0.02, 0.0), hair_color)
				_box(_head, Vector3(w * 0.8, 0.05, 0.07), Vector3(0.0, top + 0.06, front + 0.04), hair_color)
			_box(_head, Vector3(w + 0.02, 0.12, 0.03), Vector3(0.0, top - 0.07, d * 0.5 + 0.005), hair_color)
		4:
			if not hatted:
				_box(_head, Vector3(w + 0.02, 0.06, d + 0.02), Vector3(0.0, top + 0.01, 0.0), hair_color)
			_box(_head, Vector3(w + 0.03, 0.36, 0.04), Vector3(0.0, top - 0.16, d * 0.5 + 0.01), hair_color)
			for side: float in [-1.0, 1.0]:
				_box(_head, Vector3(0.03, 0.26, d * 0.7), Vector3(side * (w * 0.5 + 0.014), top - 0.12, 0.03), hair_color)
		6:
			if not hatted:
				_box(_head, Vector3(0.05, 0.09, d + 0.02), Vector3(0.0, top + 0.04, 0.0), hair_color)

	match head_item:
		"wool_beanie":
			var beanie := clothing_color(head_item)
			_box(_head, Vector3(w + 0.04, 0.12, d + 0.04), Vector3(0.0, top, 0.0), beanie)
			_box(_head, Vector3(w + 0.05, 0.035, d + 0.05), Vector3(0.0, top - 0.055, 0.0), beanie.darkened(0.2))
		"sun_hat":
			var hat := clothing_color(head_item)
			_cylinder(_head, 0.24, 0.015, Vector3(0.0, top - 0.01, 0.0), hat)
			_cylinder(_head, 0.13, 0.1, Vector3(0.0, top + 0.05, 0.0), hat)
		"combat_helmet":
			var helmet := clothing_color(head_item)
			_box(_head, Vector3(w + 0.06, 0.15, d + 0.07), Vector3(0.0, top + 0.005, 0.005), helmet)
			_box(_head, Vector3(w + 0.08, 0.03, d + 0.09), Vector3(0.0, top - 0.07, 0.005), helmet.darkened(0.15))
			_box(_head, Vector3(0.05, 0.04, 0.03), Vector3(0.0, top - 0.01, front - 0.04), Color(0.12, 0.12, 0.13))


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
	_spine.rotation.x = sin(_breath) * 0.015
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


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_mesh(parent, mesh, pos, color, rot)


func _capsule(parent: Node3D, radius: float, length: float, pos: Vector3, color: Color) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(length + radius, radius * 2.0)
	mesh.radial_segments = 8
	mesh.rings = 1
	_mesh(parent, mesh, pos, color)


func _cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	_mesh(parent, mesh, pos, color)


func _sphere(parent: Node3D, radius: float, pos: Vector3, color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	_mesh(parent, mesh, pos, color)


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color)
	instance.position = pos
	instance.rotation = rot
	parent.add_child(instance)


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
