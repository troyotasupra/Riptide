class_name ViewModel
extends Node3D
## What you see of yourself in first person: your forearms in your sleeves, your
## hands, and whatever you're holding. Bobs as you move and swings when you use a
## tool. Lives under the camera.
##
## Tools hang from the right forearm. Guns are different: they sit in their own rig
## in camera space (barrel forward, sights up), and the hands are placed on the gun
## at its grip and handguard, each arm bending at the elbow back to a shoulder off screen.
## That rig moves between a hip pose and a sighted pose, where the sights sit on
## the middle of the screen, and it kicks, draws and reloads as a whole.

## Elbow position below and right of the eye; the forearm points forward and up from it.
const REST := Vector3(0.34, -0.37, -0.12)
const REST_PITCH := 1.85

## ItemModels lays guns out barrel +Y, sights +Z; in camera space that is -Z and +Y.
const GUN_BASIS := Basis(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, -1.0), Vector3(0.0, 1.0, 0.0))
## Where the grip sits from the hip: right of centre, below the eye.
const HIP_LONG := Vector3(0.15, -0.19, -0.36)
const HIP_PISTOL := Vector3(0.13, -0.16, -0.4)
## How far out the grip sits once sighted in: a long gun is pulled into the
## shoulder, a pistol pushed out at arm's length.
const AIM_DEPTH_LONG := -0.2
const AIM_DEPTH_PISTOL := -0.38
## From the hip the gun toes in a little toward the crosshair and cants.
const HIP_TURN := Vector3(0.03, 0.05, -0.05)
## Shoulders, just off the bottom of the screen; each arm reaches from one to its hand.
const RIGHT_SHOULDER := Vector3(0.22, -0.36, 0.02)
const LEFT_SHOULDER := Vector3(-0.2, -0.36, -0.06)
## Elbows bend down and out, away from the body's middle.
const RIGHT_POLE := Vector3(0.6, -1.0, 0.1)
const LEFT_POLE := Vector3(-0.6, -1.0, 0.1)
const UPPER_ARM := 0.3
const FOREARM := 0.27
const UPPER_RADIUS := 0.05
const FOREARM_RADIUS := 0.04
## A sight's top edge sits this far above the line you look along.
const SIGHT_DROP := 0.006
## A scope's axis is this far under the top of the tube.
const SCOPE_DROP := 0.022

## 0 from the hip, 1 fully sighted in (Gun.aim).
var aim := 0.0
## How far through a reload (0..1), or -1 when not reloading; `clearing` for a jam.
var reload := -1.0
var clearing := false
## 0..1 while rowing: the arm pulls the oar through its stroke.
var rowing := 0.0
## A round (an arrow, for the bow) is ready: the bow shows it nocked.
var loaded := true

var _arm: Node3D
var _hand: Node3D
var _held: Node3D
var _held_id := "?"
var _sleeve_key := "?"
var _skin := Color.WHITE
var _sleeve := Color.WHITE
var _phase := 0.0
var _swing_t := 0.0
## Swings alternate: forehand (down to the left), then backhand (down to the right).
var _swing_side := 1.0
var _recoil := 0.0
var _row_phase := 0.0

var _rig: Node3D
var _gun: Node3D
var _pistol := false
var _hip := HIP_LONG
var _aimed := Vector3.ZERO
var _draw := 0.0
var _right_hand: Node3D
var _left_hand: Node3D
var _right_arm: MeshInstance3D
var _left_arm: MeshInstance3D
var _right_upper: MeshInstance3D
var _left_upper: MeshInstance3D
# The bow: its string drawn as two lengths meeting at the nock, and the nocked arrow.
var _bow := false
var _bow_tips: Array = []
var _bow_string: Array[MeshInstance3D] = []
var _bow_arrow: Node3D
## Brace height and full draw, along the bow's own +Y (arrow direction).
const BOW_BRACED := -0.14
const BOW_DRAWN := -0.66


func _ready() -> void:
	_arm = Node3D.new()
	_arm.position = REST
	_arm.rotation.x = REST_PITCH
	add_child(_arm)
	_rig = Node3D.new()
	_rig.name = "GunRig"
	add_child(_rig)
	_right_arm = _limb()
	_left_arm = _limb()
	_right_upper = _limb()
	_left_upper = _limb()


## Rebuilds the arm when the sleeve changes and the item when the held item changes.
func refresh(held_id: String, torso_item: String, skin: Color, crew_color_index: int) -> void:
	var sleeve_key := "%s_%s_%d" % [torso_item, skin.to_html(false), crew_color_index]
	if sleeve_key != _sleeve_key:
		_sleeve_key = sleeve_key
		for child in _arm.get_children():
			child.queue_free()
		var long_sleeve := torso_item in ["rain_jacket", "wool_sweater"]
		_skin = skin
		_sleeve = CharacterModel.CLOTHING_COLORS.get(torso_item, skin) if long_sleeve else skin
		var forearm := CapsuleMesh.new()
		forearm.radius = 0.036
		forearm.height = 0.32
		forearm.radial_segments = 8
		forearm.rings = 1
		_part(_arm, forearm, Vector3(0.0, -0.13, 0.0), _sleeve)
		_hand = Node3D.new()
		_hand.position = Vector3(0.0, -0.32, 0.0)
		_arm.add_child(_hand)
		_part(_hand, _unit_sphere(), Vector3.ZERO, skin).scale = Vector3(0.075, 0.1, 0.055)
		for arm: MeshInstance3D in [_right_arm, _left_arm, _right_upper, _left_upper]:
			arm.material_override = _skin_material(_sleeve)
		_held_id = "?"
	visible = not held_id.is_empty()
	if held_id == _held_id:
		return
	_held_id = held_id
	for node: Node3D in [_held, _gun]:
		if node != null and is_instance_valid(node):
			node.queue_free()
	_held = null
	_gun = null
	var is_gun := ItemTable.get_item(held_id).has("weapon")
	_arm.visible = not is_gun
	_rig.visible = is_gun
	if not is_gun:
		for limb: MeshInstance3D in [_right_arm, _left_arm, _right_upper, _left_upper]:
			limb.visible = false
	if held_id.is_empty():
		return
	if is_gun:
		_build_gun(held_id)
		return
	_held = ItemModels.build(held_id)
	_held.rotation.x = PI + 0.5  # blade tilts up from the forearm, about 45° above the horizon
	_hand.add_child(_held)


## The gun in the rig, a hand on its grip and one on its handguard.
func _build_gun(id: String) -> void:
	_gun = ItemModels.build(id)
	_gun.transform.basis = GUN_BASIS
	_rig.add_child(_gun)
	_held = _gun
	var weapon: String = ItemTable.get_item(id).get("weapon", "")
	_pistol = weapon == "m1911"
	_hip = HIP_PISTOL if _pistol else HIP_LONG
	# Sighted in: the top of the sights sits just under the middle of the screen.
	var rail := ItemModels.anchor(_gun, "rail", Vector3(0.0, 0.1, 0.03))
	var scoped := float(WeaponTable.WEAPONS.get(weapon, {}).get("zoom", 1.0)) > 1.0
	var sight_height := rail.z - (SCOPE_DROP if scoped else SIGHT_DROP)
	_aimed = Vector3(0.0, -sight_height, AIM_DEPTH_PISTOL if _pistol else AIM_DEPTH_LONG)
	_bow = WeaponTable.WEAPONS.get(weapon, {}).get("kind", "") == "bow"
	if _bow:
		_build_bow()
		return
	# The right hand wraps the grip: back of the hand to the right, thumb over the top.
	_right_hand = _hand_mesh(_gun, Vector3(0.012, -0.005, -0.012), Vector3(0.0, 0.0, 0.25))
	if _pistol:
		# Support hand cups the shooting hand from the left.
		_left_hand = _hand_mesh(_gun, Vector3(-0.02, 0.0, -0.03), Vector3(0.0, 0.0, -0.35))
	else:
		var fore := ItemModels.anchor(_gun, "fore", Vector3(0.0, 0.3, -0.03))
		# Palm up under the handguard, fingers curling round the left side.
		_left_hand = _hand_mesh(_gun, fore + Vector3(-0.006, 0.0, -0.022), Vector3(PI / 2.0, 0.0, -0.3))
	_draw = 1.0


## A hand: a palm with the fingers closed round something, and a thumb.
func _hand_mesh(parent: Node3D, pos: Vector3, rot: Vector3) -> Node3D:
	var hand := Node3D.new()
	hand.position = pos
	hand.rotation = rot
	parent.add_child(hand)
	# In the hand's own space the fingers wrap round the Y axis (the grip's line).
	_part(hand, _unit_sphere(), Vector3.ZERO, _skin).scale = Vector3(0.044, 0.1, 0.05)
	for i in 4:
		var finger := _part(hand, _unit_sphere(), Vector3(-0.018, 0.03 - i * 0.021, 0.021), _skin)
		finger.scale = Vector3(0.024, 0.019, 0.034)
	var thumb := _part(hand, _unit_sphere(), Vector3(-0.02, 0.045, -0.012), _skin)
	thumb.scale = Vector3(0.02, 0.05, 0.02)
	thumb.rotation = Vector3(0.0, 0.0, 0.5)
	return hand


func swing() -> void:
	_swing_t = 1.0
	_swing_side = -_swing_side


## Where the arm is `p` of the way through a swing (0..1): a quick wind-up that
## cocks the blade up and back over the shoulder, a fast diagonal cut across the
## body with the wrist turning over, a follow-through low on the far side, and an
## easy recovery. Returns [offset, turn (x pitch, y yaw, z roll)].
func _swing_pose(p: float) -> Array:
	var side := _swing_side
	# Cocked high by the shoulder with the blade still in view, tip back.
	# The arm rests right of centre, so a backhand winds up across the body to the
	# left and cuts back out only a little way: both stay on screen.
	var wind := Vector3(0.1 if side > 0.0 else -0.3, 0.24, 0.1)
	var wind_turn := Vector3(-0.3, 0.2 * side, 0.45 * side)
	# Across the middle of the view, low but not out of it, so even a knife is seen.
	var cut := Vector3(-0.2 if side > 0.0 else 0.02, 0.02, -0.18)
	var cut_turn := Vector3(0.95, -0.35 * side, -0.95 * side)
	var pos: Vector3
	var turn: Vector3
	if p < 0.28:
		var k := smoothstep(0.0, 0.28, p)
		pos = wind * k
		turn = wind_turn * k
	elif p < 0.5:
		# The cut is fast: most of the travel in the first part.
		var k := pow((p - 0.28) / 0.22, 0.6)
		pos = wind.lerp(cut, k)
		turn = wind_turn.lerp(cut_turn, k)
	else:
		var k := smoothstep(0.5, 1.0, p)
		pos = cut.lerp(Vector3.ZERO, k)
		turn = cut_turn.lerp(Vector3.ZERO, k)
	return [pos, turn]


## The gun goes off: the hand snaps back and up, then settles.
func recoil(strength: float) -> void:
	_recoil = clampf(strength, 0.0, 1.5)


## Where a point on the held item's model (its own coordinates) is in the world
## right now, or Vector3.INF when nothing is held — e.g. the fishing rod's tip.
func held_point(local: Vector3) -> Vector3:
	if not visible or _held == null or not is_instance_valid(_held) or not _held.is_inside_tree():
		return Vector3.INF
	return _held.global_transform * local


## Where the muzzle of the gun in hand is in the world, or Vector3.INF.
func muzzle_point() -> Vector3:
	if _gun == null or not is_instance_valid(_gun):
		return Vector3.INF
	return held_point(ItemModels.anchor(_gun, "muzzle", Vector3(0.0, 0.3, 0.02)))


func animate(delta: float, speed: float) -> void:
	var moving := clampf(speed / 6.0, 0.0, 1.0)
	_phase = fmod(_phase + delta * (5.0 + speed), TAU)
	_swing_t = maxf(0.0, _swing_t - delta / Player.SWING_SECONDS)
	_recoil = maxf(0.0, _recoil - delta * 5.0)
	if _gun != null and is_instance_valid(_gun):
		_animate_gun(delta, moving)
		return
	var swing := _swing_pose(1.0 - _swing_t) if _swing_t > 0.0 else [Vector3.ZERO, Vector3.ZERO]
	var bob := Vector3(cos(_phase) * 0.012, absf(sin(_phase)) * 0.018, 0.0) * moving
	_arm.position = REST + bob + Vector3(swing[0])
	_arm.rotation = Vector3(REST_PITCH, 0.0, 0.0) + Vector3(swing[1])
	if _recoil > 0.001:
		_arm.position += Vector3(0.0, 0.02, 0.06) * _recoil
		_arm.rotation.x -= 0.16 * _recoil
	if rowing > 0.01:
		_row_phase = fmod(_row_phase + delta * (3.2 + rowing * 2.0), TAU)
		var pull := sin(_row_phase)
		_arm.position += Vector3(-0.06, 0.03 * cos(_row_phase), 0.12 * pull) * rowing
		_arm.rotation.x += 0.35 * pull * rowing


## The bow in the rig: held upright in the left hand; the right hand on the string
## at the nock. The rig's hip pose holds it low and forward; aiming draws it to
## the cheek with the arrow on the crosshair.
func _build_bow() -> void:
	_bow_tips = _gun.get_meta("tips", [])
	var model_string := _gun.find_child("String", true, false)
	if model_string != null:
		model_string.visible = false
	_bow_string.clear()
	var cord := Materials.plain(Color(0.85, 0.82, 0.72))
	for i in 2:
		var length := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 1.0
		cylinder.bottom_radius = 1.0
		cylinder.height = 1.0
		cylinder.radial_segments = 4
		cylinder.rings = 1
		length.mesh = cylinder
		length.material_override = cord
		length.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_gun.add_child(length)
		_bow_string.append(length)
	_bow_arrow = ItemModels.build("arrow")
	_gun.add_child(_bow_arrow)
	_left_hand = _hand_mesh(_gun, Vector3(-0.02, 0.0, 0.0), Vector3(0.0, 0.0, -PI / 2.0))
	_right_hand = _hand_mesh(_gun, Vector3(0.0, BOW_BRACED, 0.0), Vector3(PI / 2.0, 0.0, 0.3))
	_pistol = false
	# Carried low across the body, canted well over.
	_hip = Vector3(0.04, -0.3, -0.62)
	# Drawn, the nock is at the jaw (below and just in front of the eye, where you
	# don't see your own hand) and you look along the arrow over the bow hand.
	_aimed = Vector3(0.0, -0.085, BOW_DRAWN - 0.1)
	_draw = 1.0


## String and arrow for how far the bow is drawn (0 braced .. 1 full draw).
func _update_bow(draw: float) -> void:
	if _bow_tips.size() < 2:
		return
	var nock := Vector3(0.0, lerpf(BOW_BRACED, BOW_DRAWN, draw), 0.0)
	for i in 2:
		var a: Vector3 = _bow_tips[i]
		var along := nock - a
		var up := along.normalized()
		var side := up.cross(Vector3.RIGHT).normalized()
		_bow_string[i].transform = Transform3D(Basis(side * 0.0016, up * along.length(), side.cross(up) * 0.0016), a + along * 0.5)
	_bow_arrow.visible = loaded
	_bow_arrow.position = nock
	_right_hand.position = nock + Vector3(0.012, -0.015, 0.0)


func _animate_gun(delta: float, moving: float) -> void:
	_draw = maxf(0.0, _draw - delta * 3.0)
	var t := smoothstep(0.0, 1.0, aim)
	var loose := 1.0 - t * 0.85
	var pos := _hip.lerp(_aimed, t)
	var turn := HIP_TURN * (1.0 - t)
	if _bow:
		# Only a nocked arrow can be drawn; the bow cants a little, as archers hold it.
		var drawn := t if loaded else 0.0
		_update_bow(drawn)
		turn = Vector3(0.0, 0.0, -0.95 * (1.0 - t) - 0.1)
		# At full draw the string hand is at your jaw, out of sight.
		_right_hand.visible = drawn < 0.6
	# Walking bob, much smaller on the sights.
	pos += Vector3(cos(_phase) * 0.008, absf(sin(_phase)) * 0.012, 0.0) * moving * loose
	# Coming up from below when drawn.
	var draw := _draw * _draw
	pos += Vector3(0.02, -0.2, 0.06) * draw
	turn += Vector3(-0.9, 0.0, 0.3) * draw
	# The kick: straight back into the shoulder and the muzzle up.
	pos += Vector3(0.0, 0.004, 0.035) * _recoil
	turn.x += 0.09 * _recoil
	if reload >= 0.0:
		var r := _reload_pose(reload)
		pos += r[0]
		turn += r[1]
	_rig.position = pos
	_rig.rotation = turn
	# The shoulders follow the gun a little: a kick or a reload moves the whole arm.
	_place_arm(_right_upper, _right_arm, _right_hand, RIGHT_SHOULDER + (pos - _hip) * 0.3, RIGHT_POLE)
	_place_arm(_left_upper, _left_arm, _left_hand, LEFT_SHOULDER + (pos - _hip) * 0.3, LEFT_POLE)


## The gun's offset and turn at `p` of the way through a reload: it rolls over and
## drops to bring the magazine well into view, pauses while the old mag comes out
## and the new one goes in, then comes back up and gets a sharp rack at the end.
## Clearing a jam is a quicker roll with a harder rack.
func _reload_pose(p: float) -> Array:
	var down := smoothstep(0.0, 0.18, p) * (1.0 - smoothstep(0.78, 0.95, p))
	var seat := exp(-pow((p - 0.55) / 0.05, 2.0))  # the new mag is slapped home
	var rack := exp(-pow((p - 0.88) / 0.04, 2.0))
	if clearing:
		down = smoothstep(0.0, 0.25, p) * (1.0 - smoothstep(0.6, 0.9, p))
		seat = 0.0
		rack = exp(-pow((p - 0.5) / 0.08, 2.0)) * 1.5
	var pos := Vector3(-0.04, -0.07, 0.03) * down + Vector3(0.0, 0.012, 0.0) * seat + Vector3(0.0, 0.0, 0.02) * rack
	var turn := Vector3(0.35, 0.1, 0.7) * down + Vector3(-0.05, 0.0, 0.0) * seat + Vector3(0.06, -0.05, 0.0) * rack
	return [pos, turn]


## Places an arm from `shoulder` to the wrist just behind `hand` (camera space):
## two segments that bend at an elbow toward `pole`, lengths fixed, as a real arm.
func _place_arm(upper: MeshInstance3D, fore: MeshInstance3D, hand: Node3D, shoulder: Vector3, pole: Vector3) -> void:
	if hand == null or not is_instance_valid(hand) or not hand.is_inside_tree() or not hand.visible:
		upper.visible = false
		fore.visible = false
		return
	var wrist := global_transform.affine_inverse() * hand.global_position
	var reach := wrist - shoulder
	var d := clampf(reach.length(), absf(UPPER_ARM - FOREARM) + 0.01, UPPER_ARM + FOREARM - 0.001)
	var along := reach.normalized()
	# How far along the shoulder-to-wrist line the elbow sits, and how far off it.
	var x := (UPPER_ARM * UPPER_ARM - FOREARM * FOREARM + d * d) / (2.0 * d)
	var out := sqrt(maxf(UPPER_ARM * UPPER_ARM - x * x, 0.0))
	var bend := (pole - along * pole.dot(along)).normalized()
	var elbow := shoulder + along * x + bend * out
	_segment(upper, shoulder, elbow, UPPER_RADIUS)
	_segment(fore, elbow, wrist, FOREARM_RADIUS)


## Stretches a unit capsule from `a` to `b`.
func _segment(limb: MeshInstance3D, a: Vector3, b: Vector3, radius: float) -> void:
	var along := b - a
	var length := along.length()
	limb.visible = length > 0.01
	if not limb.visible:
		return
	var up := along / length
	var side := up.cross(Vector3.FORWARD)
	if side.length() < 0.01:
		side = up.cross(Vector3.RIGHT)
	side = side.normalized()
	# Columns scaled one by one: the capsule is a unit one, stretched to reach.
	var basis := Basis(side * radius, up * (length * 0.5 + radius), side.cross(up) * radius)
	limb.transform = Transform3D(basis, a + along * 0.5)


func _limb() -> MeshInstance3D:
	var limb := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 1.0
	capsule.height = 2.0
	capsule.radial_segments = 10
	capsule.rings = 2
	limb.mesh = capsule
	limb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	limb.visible = false
	add_child(limb)
	return limb


static var _sphere: SphereMesh


static func _unit_sphere() -> SphereMesh:
	if _sphere == null:
		_sphere = SphereMesh.new()
		_sphere.radius = 0.5
		_sphere.height = 1.0
		_sphere.radial_segments = 16
		_sphere.rings = 8
	return _sphere


func _skin_material(color: Color) -> Material:
	return Props.material("body_" + color.to_html(false), color)


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _skin_material(color)
	instance.position = pos
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance
