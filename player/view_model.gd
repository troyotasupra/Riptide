class_name ViewModel
extends Node3D
## What you see of yourself in first person: your right forearm in your sleeve,
## your hand, and whatever you're holding. Bobs as you move and swings when you
## use a tool. Lives under the camera.

## Elbow position below and right of the eye; the forearm points forward and up from it.
const REST := Vector3(0.34, -0.37, -0.12)
const REST_PITCH := 1.85

var _arm: Node3D
var _hand: Node3D
var _held: Node3D
var _held_id := "?"
var _sleeve_key := "?"
var _phase := 0.0
var _swing_t := 0.0


func _ready() -> void:
	_arm = Node3D.new()
	_arm.position = REST
	_arm.rotation.x = REST_PITCH
	add_child(_arm)


## Rebuilds the arm when the sleeve changes and the item when the held item changes.
func refresh(held_id: String, torso_item: String, skin: Color, crew_color_index: int) -> void:
	var sleeve_key := "%s_%s_%d" % [torso_item, skin.to_html(false), crew_color_index]
	if sleeve_key != _sleeve_key:
		_sleeve_key = sleeve_key
		for child in _arm.get_children():
			child.queue_free()
		var long_sleeve := torso_item in ["rain_jacket", "wool_sweater"]
		var sleeve_color := skin
		if long_sleeve:
			sleeve_color = CharacterModel.CLOTHING_COLORS.get(torso_item, skin)
		var forearm := CapsuleMesh.new()
		forearm.radius = 0.036
		forearm.height = 0.32
		forearm.radial_segments = 8
		forearm.rings = 1
		_part(_arm, forearm, Vector3(0.0, -0.13, 0.0), sleeve_color)
		var palm := SphereMesh.new()
		palm.radius = 0.5
		palm.height = 1.0
		palm.radial_segments = 16
		palm.rings = 8
		_hand = Node3D.new()
		_hand.position = Vector3(0.0, -0.32, 0.0)
		_arm.add_child(_hand)
		_part(_hand, palm, Vector3.ZERO, skin).scale = Vector3(0.075, 0.1, 0.055)
		_held_id = "?"
	visible = not held_id.is_empty()
	if held_id == _held_id:
		return
	_held_id = held_id
	if _held != null and is_instance_valid(_held):
		_held.queue_free()
	_held = null
	if held_id.is_empty():
		return
	_held = ItemModels.build(held_id)
	_held.rotation.x = PI + 0.5  # blade tilts up from the forearm, about 45° above the horizon
	_hand.add_child(_held)


func swing() -> void:
	_swing_t = 1.0


func animate(delta: float, speed: float) -> void:
	var moving := clampf(speed / 6.0, 0.0, 1.0)
	_phase = fmod(_phase + delta * (5.0 + speed), TAU)
	_swing_t = maxf(0.0, _swing_t - delta * 2.6)
	var arc := sin(_swing_t * PI)
	_arm.position = REST + Vector3(cos(_phase) * 0.012, absf(sin(_phase)) * 0.018, 0.0) * moving + Vector3(-0.05, 0.08, 0.0) * arc
	_arm.rotation.x = REST_PITCH + arc * 0.7 - (1.0 - _swing_t) * arc * 1.4


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = Props.material("body_" + color.to_html(false), color)
	instance.position = pos
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance
