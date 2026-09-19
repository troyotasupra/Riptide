class_name ShackDoor
extends Interactable
## The fishing shack's door: a plank door on a hinge at the left of the doorway,
## swinging in against the wall. From inside it can be bolted, and then nobody
## outside can open it. The host decides (CampSystems.shack_door); every peer
## swings its own copy to match.

const WIDTH := 1.1
const HEIGHT := 2.0
## Swings in, into the room, away from whoever is on the step outside.
const OPEN_ANGLE := -1.6

var is_open := false
var locked := false
var _hinge: Node3D
var _bolt: MeshInstance3D


## Builds the door in `parent` (the hut, in shack space) at the doorway, `front` being
## the wall's middle z.
static func make(parent: Node3D, front: float, planks: Material, dark: Material, iron: Material) -> ShackDoor:
	var hinge := Node3D.new()
	hinge.name = "DoorHinge"
	hinge.position = Vector3(-WIDTH * 0.5, 0.0, front)
	parent.add_child(hinge)
	var door := ShackDoor.new()
	door.name = "Door"
	door.interact_id = "shack:door"
	door.collision_layer = Layers.WORLD | Layers.INTERACT
	door.collision_mask = 0
	door.position = Vector3(WIDTH * 0.5, HEIGHT * 0.5 + 0.01, 0.0)
	door._hinge = hinge
	hinge.add_child(door)
	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDTH, HEIGHT, 0.06)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	door.add_child(collider)
	# Vertical boards, two ledges and a brace, a pull handle and the bolt.
	for i in 5:
		var board := BoxMesh.new()
		board.size = Vector3(WIDTH / 5.0 + 0.004, HEIGHT, 0.05)
		var visual := MeshInstance3D.new()
		visual.mesh = board
		visual.material_override = planks
		visual.position = Vector3(-WIDTH * 0.5 + (i + 0.5) * WIDTH / 5.0, 0.0, 0.0)
		door.add_child(visual)
	for y: float in [-0.6, 0.6]:
		for face: float in [-1.0, 1.0]:
			var ledge := BoxMesh.new()
			ledge.size = Vector3(WIDTH - 0.08, 0.12, 0.03)
			var visual := MeshInstance3D.new()
			visual.mesh = ledge
			visual.material_override = dark
			visual.position = Vector3(0.0, y, face * 0.04)
			door.add_child(visual)
	var brace := BoxMesh.new()
	brace.size = Vector3(0.1, 1.45, 0.03)
	var brace_visual := MeshInstance3D.new()
	brace_visual.mesh = brace
	brace_visual.material_override = dark
	brace_visual.position = Vector3(0.0, 0.0, -0.04)
	brace_visual.rotation.z = 0.62
	door.add_child(brace_visual)
	for face: float in [-1.0, 1.0]:
		var handle := BoxMesh.new()
		handle.size = Vector3(0.04, 0.2, 0.04)
		var grip := MeshInstance3D.new()
		grip.mesh = handle
		grip.material_override = iron
		grip.position = Vector3(WIDTH * 0.5 - 0.14, 0.0, face * 0.07)
		door.add_child(grip)
	var bolt_mesh := BoxMesh.new()
	bolt_mesh.size = Vector3(0.22, 0.04, 0.04)
	door._bolt = MeshInstance3D.new()
	door._bolt.mesh = bolt_mesh
	door._bolt.material_override = iron
	door._bolt.position = Vector3(WIDTH * 0.5 - 0.1, 0.12, 0.07)
	door.add_child(door._bolt)
	door.add_to_group("shack_door")
	return door


func set_state(p_open: bool, p_locked: bool) -> void:
	is_open = p_open
	locked = p_locked
	# The bolt slides across into the frame when it's locked.
	if _bolt != null:
		_bolt.position.x = WIDTH * 0.5 + (0.02 if locked else -0.1)


func _process(delta: float) -> void:
	if _hinge == null:
		return
	var target := OPEN_ANGLE if is_open else 0.0
	_hinge.rotation.y = move_toward(_hinge.rotation.y, target, delta * 3.2)
