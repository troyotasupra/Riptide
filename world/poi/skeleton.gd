class_name Remains
extends RefCounted
## Human remains, built bone by bone: what's left of someone who died here a
## long while back. A skull with its jaw, a spine of stacked vertebrae, a rib
## cage, pelvis, and arms and legs with the right two bones in the forearm and
## shin. Every bone is a tapered tube, so nothing reads as a box.
##
## build() returns a Node3D standing at the origin, feet on the ground, facing
## -Z. Lay it down by rotating the node it goes under.

const BONE := Color(0.83, 0.80, 0.71)
const BONE_DARK := Color(0.63, 0.58, 0.48)


static func build(seed_value: int = 0) -> Node3D:
	var root := Node3D.new()
	root.name = "Remains"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var bone := Materials.plain(BONE, 0.9)
	var stained := Materials.plain(BONE.lerp(BONE_DARK, 0.5), 0.95)

	# --- spine and pelvis ---------------------------------------------------
	var hip_y := 0.92
	var shoulder_y := 1.42
	for i in 17:
		var t := i / 16.0
		var y: float = lerpf(hip_y, shoulder_y + 0.09, t)
		# The spine curves: hollow at the small of the back, forward at the neck.
		var z := 0.035 * sin(t * PI * 1.6) - 0.02
		var width: float = lerpf(0.035, 0.022, t)
		_bone(root, Vector3(0.0, y - 0.012, z), Vector3(0.0, y + 0.012, z), width, width * 0.95, stained if i % 2 == 0 else bone, 7)

	# The pelvis: two blades off a short sacrum.
	_bone(root, Vector3(0.0, hip_y - 0.12, -0.02), Vector3(0.0, hip_y, -0.01), 0.04, 0.035, stained, 7)
	for s: float in [-1.0, 1.0]:
		_bone(root, Vector3(0.0, hip_y - 0.02, -0.02), Vector3(s * 0.11, hip_y + 0.02, 0.01), 0.022, 0.05, bone, 7)
		_bone(root, Vector3(s * 0.11, hip_y + 0.02, 0.01), Vector3(s * 0.09, hip_y - 0.11, 0.0), 0.05, 0.03, bone, 7)

	# --- rib cage -----------------------------------------------------------
	var sternum_z := -0.11
	_bone(root, Vector3(0.0, shoulder_y - 0.02, sternum_z), Vector3(0.0, shoulder_y - 0.3, sternum_z + 0.02), 0.03, 0.022, bone, 6)
	for i in 8:
		var t := i / 7.0
		var y: float = lerpf(shoulder_y - 0.03, hip_y + 0.12, t)
		var reach: float = lerpf(0.11, 0.16, sin(t * PI))
		var front: float = lerpf(sternum_z + 0.01, -0.04, t)
		# Built once on the right and mirrored, so both sides share one mesh.
		var points := PackedVector3Array([
			Vector3(0.0, 0.0, -0.01),
			Vector3(reach * 0.7, -0.012, 0.03),
			Vector3(reach, -0.03, -0.03),
			Vector3(reach * 0.75, -0.05, front + 0.03),
			Vector3(0.03 if i < 6 else 0.06, -0.06, front)])
		for s: float in [-1.0, 1.0]:
			var radii := PackedFloat32Array([0.012, 0.011, 0.011, 0.010, 0.009])
			var rib := MeshInstance3D.new()
			rib.mesh = MeshKit.tube(points, radii, 6, "rib_%d_%.3f_%.3f" % [i, reach, front])
			rib.material_override = bone if i % 3 else stained
			rib.scale.x = s
			rib.position.y = y
			root.add_child(rib)

	# --- skull --------------------------------------------------------------
	var skull_y := shoulder_y + 0.22
	var cranium := MeshInstance3D.new()
	cranium.mesh = MeshKit.rock(203, 0.12, 0.92)
	cranium.material_override = bone
	cranium.scale = Vector3(0.17, 0.19, 0.21)
	cranium.position = Vector3(0.0, skull_y, -0.01)
	root.add_child(cranium)
	# The face: brow, cheeks and the jaw hanging open.
	_bone(root, Vector3(-0.07, skull_y - 0.01, -0.08), Vector3(0.07, skull_y - 0.01, -0.08), 0.022, 0.022, bone, 6)
	for s: float in [-1.0, 1.0]:
		_bone(root, Vector3(s * 0.06, skull_y - 0.02, -0.08), Vector3(s * 0.045, skull_y - 0.08, -0.07), 0.018, 0.014, bone, 6)
		# Eye sockets: dark hollows set into the face.
		var socket := MeshInstance3D.new()
		var socket_mesh := SphereMesh.new()
		socket_mesh.radius = 0.028
		socket_mesh.height = 0.056
		socket_mesh.radial_segments = 8
		socket_mesh.rings = 5
		socket.mesh = socket_mesh
		socket.material_override = Materials.plain(Color(0.09, 0.08, 0.07), 1.0)
		socket.position = Vector3(s * 0.045, skull_y + 0.005, -0.085)
		root.add_child(socket)
	var jaw_drop := rng.randf_range(0.02, 0.05)
	for s: float in [-1.0, 1.0]:
		_bone(root, Vector3(s * 0.058, skull_y - 0.05, -0.0), Vector3(s * 0.05, skull_y - 0.09 - jaw_drop, -0.085), 0.014, 0.012, stained, 6)
	_bone(root, Vector3(-0.05, skull_y - 0.09 - jaw_drop, -0.085), Vector3(0.05, skull_y - 0.09 - jaw_drop, -0.085), 0.013, 0.013, stained, 6)

	# --- arms and legs ------------------------------------------------------
	for s: float in [-1.0, 1.0]:
		var shoulder := Vector3(s * 0.17, shoulder_y - 0.02, -0.02)
		# The collar bone and the shoulder blade behind it.
		_bone(root, Vector3(0.0, shoulder_y - 0.02, -0.07), shoulder, 0.014, 0.016, bone, 6)
		_bone(root, Vector3(s * 0.05, shoulder_y - 0.02, 0.03), Vector3(s * 0.15, shoulder_y - 0.16, 0.02), 0.03, 0.02, stained, 6)
		# Upper arm, then the pair of forearm bones, then a spray of finger bones.
		var elbow := shoulder + Vector3(s * 0.05, -0.29, 0.02)
		var wrist := elbow + Vector3(s * 0.03, -0.26, -0.03)
		_bone(root, shoulder, elbow, 0.028, 0.021, bone, 7)
		_bone(root, elbow + Vector3(s * 0.015, 0.0, 0.0), wrist, 0.016, 0.012, bone, 6)
		_bone(root, elbow - Vector3(s * 0.015, 0.0, 0.0), wrist + Vector3(0.0, 0.0, 0.01), 0.014, 0.011, bone, 6)
		for f in 4:
			var spread := (f - 1.5) * 0.022
			_bone(root, wrist, wrist + Vector3(s * 0.02 + spread, -0.09, -0.02 - absf(spread)), 0.009, 0.006, bone, 5)
		# Thigh, the shin pair, and a foot of small bones.
		var hip := Vector3(s * 0.09, hip_y - 0.11, 0.0)
		var knee := hip + Vector3(s * 0.005, -0.42, -0.01)
		var ankle := knee + Vector3(0.0, -0.4, 0.01)
		_bone(root, hip, knee, 0.036, 0.026, bone, 8)
		_bone(root, knee + Vector3(0.0, -0.01, -0.01), ankle, 0.026, 0.018, bone, 7)
		_bone(root, knee + Vector3(s * 0.022, -0.02, 0.01), ankle + Vector3(s * 0.012, 0.0, 0.0), 0.013, 0.010, bone, 6)
		for f in 3:
			_bone(root, ankle, ankle + Vector3(s * 0.02 + (f - 1) * 0.02, -0.06, -0.12), 0.011, 0.007, stained, 5)
	return root


## One tapered bone from `a` to `b`, with knuckle ends so joints don't look cut.
## The mesh is built along +Y and placed, so bones of a size share one mesh.
static func _bone(parent: Node3D, a: Vector3, b: Vector3, r_a: float, r_b: float, material: Material, sides: int) -> void:
	var along := b - a
	var length := along.length()
	if length < 0.001:
		return
	var waist := minf(r_a, r_b) * 0.72
	var piece := MeshInstance3D.new()
	piece.mesh = MeshKit.tube(
		PackedVector3Array([Vector3.ZERO, Vector3(0.0, length * 0.18, 0.0), Vector3(0.0, length * 0.5, 0.0),
			Vector3(0.0, length * 0.82, 0.0), Vector3(0.0, length, 0.0)]),
		PackedFloat32Array([r_a, waist, waist * 1.05, waist, r_b]), sides,
		"bone_%.3f_%.3f_%.3f_%d" % [length, r_a, r_b, sides])
	piece.material_override = material
	var up := along / length
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	piece.transform = Transform3D(Basis(side, up, side.cross(up)), a)
	parent.add_child(piece)
