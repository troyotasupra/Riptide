class_name ShackWindow
extends Interactable
## One of the fishing shack's side windows: a real hole through the wall with a
## frame on both faces, and a glazed sash hinged along its top that pushes out and
## up to let air in. The host decides whether it's open (CampSystems.shack_windows);
## every peer swings its own copy to match.

const WIDTH := 0.8
const HEIGHT := 0.6
## Middle of the opening in shack space (per side).
const CENTER := Vector3(0.0, 1.5, -0.6)
const OPEN_ANGLE := 1.0

var index := 0
var is_open := false
var _hinge: Node3D


## Builds the window in the hut (shack space) on the wall at x = `wall_x`, facing
## out along `side` (-1 left, +1 right). The wall itself leaves the opening.
static func make(parent: Node3D, p_index: int, side: float, wall_x: float, wall: float, dark: Material) -> ShackWindow:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.62, 0.72, 0.76, 0.28)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic_specular = 0.9
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var middle := Vector3(wall_x, CENTER.y, CENTER.z)
	# The frame round the opening, inside and out.
	for face: float in [-1.0, 1.0]:
		var x := wall_x + face * (wall * 0.5 + 0.012)
		for piece: Array in [[Vector3(0.03, 0.06, WIDTH + 0.12), Vector3(x, CENTER.y + HEIGHT * 0.5 + 0.03, CENTER.z)],
				[Vector3(0.05, 0.06, WIDTH + 0.16), Vector3(x + face * 0.01, CENTER.y - HEIGHT * 0.5 - 0.03, CENTER.z)],
				[Vector3(0.03, HEIGHT, 0.06), Vector3(x, CENTER.y, CENTER.z - WIDTH * 0.5 - 0.03)],
				[Vector3(0.03, HEIGHT, 0.06), Vector3(x, CENTER.y, CENTER.z + WIDTH * 0.5 + 0.03)]]:
			var box := BoxMesh.new()
			box.size = piece[0]
			var frame := MeshInstance3D.new()
			frame.mesh = box
			frame.material_override = dark
			frame.position = piece[1]
			parent.add_child(frame)
	# The sash hangs from a hinge along the top of the opening, on the outer face.
	var hinge := Node3D.new()
	hinge.name = "WindowHinge%d" % p_index
	hinge.position = Vector3(wall_x + side * (wall * 0.5), CENTER.y + HEIGHT * 0.5, CENTER.z)
	parent.add_child(hinge)
	var sash := ShackWindow.new()
	sash.name = "Window%d" % p_index
	sash.index = p_index
	sash.interact_id = "shack:window%d" % p_index
	sash.collision_layer = Layers.WORLD | Layers.INTERACT
	sash.collision_mask = 0
	sash.position = Vector3(0.0, -HEIGHT * 0.5, 0.0)
	sash._hinge = hinge
	sash.set_meta("side", side)
	hinge.add_child(sash)
	var pane := BoxMesh.new()
	pane.size = Vector3(0.012, HEIGHT - 0.06, WIDTH - 0.06)
	var pane_visual := MeshInstance3D.new()
	pane_visual.mesh = pane
	pane_visual.material_override = glass
	sash.add_child(pane_visual)
	# Sash frame and a glazing bar across the middle.
	for piece: Array in [[Vector3(0.035, 0.04, WIDTH), Vector3(0.0, HEIGHT * 0.5 - 0.02, 0.0)],
			[Vector3(0.035, 0.04, WIDTH), Vector3(0.0, -HEIGHT * 0.5 + 0.02, 0.0)],
			[Vector3(0.035, HEIGHT, 0.04), Vector3(0.0, 0.0, -WIDTH * 0.5 + 0.02)],
			[Vector3(0.035, HEIGHT, 0.04), Vector3(0.0, 0.0, WIDTH * 0.5 - 0.02)],
			[Vector3(0.03, HEIGHT, 0.025), Vector3(0.0, 0.0, 0.0)]]:
		var box := BoxMesh.new()
		box.size = piece[0]
		var bar := MeshInstance3D.new()
		bar.mesh = box
		bar.material_override = dark
		bar.position = piece[1]
		sash.add_child(bar)
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.05, HEIGHT, WIDTH)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	sash.add_child(collider)
	sash.add_to_group("shack_window")
	return sash


func set_open(p_open: bool) -> void:
	is_open = p_open


func _process(delta: float) -> void:
	if _hinge == null:
		return
	# Pushed out and up about its top edge.
	var side := float(get_meta("side", 1.0))
	var target := OPEN_ANGLE * side if is_open else 0.0
	_hinge.rotation.z = move_toward(_hinge.rotation.z, target, delta * 2.4)
