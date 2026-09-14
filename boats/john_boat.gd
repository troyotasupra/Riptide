class_name JohnBoat
extends Boat
## A dented aluminium john boat with no motor, tied up at the fishing shack's
## dock on the camp island. Flat floor, three bench seats, oarlocks on the
## gunwales, a dry box under the bow bench and a cleat on the bow. Rowed with
## oars like the raft — lighter, drier and a good deal quicker.
##
## Boat space: bow toward -Z, the square transom toward +Z.

const LENGTH := 4.3
const BEAM := 1.7
const FLOOR_Y := 0.16
const SIDE_TOP := 0.64
const BOW_CLEAT := Vector3(0.0, SIDE_TOP + 0.05, -2.02)
const STERN_CLEAT := Vector3(0.0, SIDE_TOP + 0.02, 2.1)
const SEATS := [
	Vector3(0.0, FLOOR_Y + 0.05, 0.7), Vector3(-0.45, FLOOR_Y + 0.05, -0.55), Vector3(0.45, FLOOR_Y + 0.05, -0.55),
	Vector3(-0.45, FLOOR_Y + 0.05, 0.7), Vector3(0.45, FLOOR_Y + 0.05, 0.7), Vector3(0.0, FLOOR_Y + 0.05, 1.75),
]
const PAINT := Color(0.29, 0.36, 0.27)
const ALUMINIUM := Color(0.66, 0.68, 0.67)
const BENCH_WOOD := Color(0.56, 0.43, 0.28)


static func crew_spawn(index: int) -> Vector3:
	return SEATS[index % SEATS.size()]


static func create(index: int) -> JohnBoat:
	var boat := JohnBoat.new()
	boat.name = "JohnBoat"
	boat.kind = "john_boat"
	boat.proxy_index = index
	boat.mass = 230.0
	boat.float_depth = 0.1
	boat.water_drag = 0.6
	boat.water_angular_drag = 1.8
	boat.row_force = 450.0
	boat.row_torque = 320.0
	boat.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	boat.center_of_mass = Vector3(0.0, 0.12, 0.0)
	boat.deck_top = FLOOR_Y
	boat.hull_aabb = AABB(Vector3(-BEAM * 0.5, 0.0, -LENGTH * 0.5), Vector3(BEAM, SIDE_TOP, LENGTH))
	# The floor sits just above the waterline; keep waves from drawing inside the hull.
	boat.water_mask = AABB(Vector3(-BEAM * 0.5 + 0.06, -0.3, -LENGTH * 0.5 + 0.08), Vector3(BEAM - 0.12, SIDE_TOP + 0.3, LENGTH - 0.16))
	boat._build()
	for x: float in [-0.6, 0.6]:
		for z: float in [-1.7, -0.6, 0.6, 1.7]:
			boat.probes.append(Vector3(x, 0.0, z))
	return boat


func _box(size: Vector3, pos: Vector3, mat: Material, solid: bool = true, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = mat
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
	return visual


func _tube(points: PackedVector3Array, radius: float, mat: Material) -> void:
	var radii := PackedFloat32Array()
	for p in points:
		radii.append(radius)
	var visual := MeshInstance3D.new()
	visual.mesh = MeshKit.tube(points, radii, 8)
	visual.material_override = mat
	add_child(visual)


func _build() -> void:
	var paint := Materials.metal(PAINT, 0.62)
	var metal := Materials.metal(ALUMINIUM, 0.5)
	var dark := Materials.metal(ALUMINIUM.darkened(0.35), 0.6)
	var wood := Materials.wood(BENCH_WOOD)
	var half_l := LENGTH * 0.5
	var half_b := BEAM * 0.5

	# Floor, sides, transom and bow wall are the walkable, solid hull.
	_box(Vector3(BEAM - 0.1, FLOOR_Y, LENGTH - 0.12), Vector3(0.0, FLOOR_Y * 0.5, 0.0), metal)
	for s: float in [-1.0, 1.0]:
		_box(Vector3(0.04, SIDE_TOP, LENGTH), Vector3(s * (half_b - 0.02), SIDE_TOP * 0.5, 0.0), paint)
		_box(Vector3(0.012, SIDE_TOP - FLOOR_Y - 0.04, LENGTH - 0.1), Vector3(s * (half_b - 0.047), (SIDE_TOP + FLOOR_Y) * 0.5, 0.0), metal, false)
		_tube(PackedVector3Array([Vector3(s * half_b, SIDE_TOP, -half_l + 0.05), Vector3(s * half_b, SIDE_TOP, half_l - 0.02)]), 0.025, metal)
		# Oarlocks.
		_box(Vector3(0.04, 0.1, 0.04), Vector3(s * (half_b + 0.01), SIDE_TOP + 0.05, 0.25), dark, false)
		_box(Vector3(0.05, 0.015, 0.12), Vector3(s * (half_b + 0.01), SIDE_TOP + 0.1, 0.25), dark, false)
		# A painted boat number on each bow quarter.
		_box(Vector3(0.005, 0.07, 0.42), Vector3(s * (half_b + 0.002), SIDE_TOP - 0.16, -1.25), Materials.plain(Color(0.92, 0.9, 0.84)), false)
	_box(Vector3(BEAM, SIDE_TOP, 0.05), Vector3(0.0, SIDE_TOP * 0.5, half_l - 0.025), paint)
	_box(Vector3(BEAM - 0.08, 0.1, 0.06), Vector3(0.0, SIDE_TOP - 0.05, half_l - 0.07), wood, false)
	_box(Vector3(BEAM, SIDE_TOP, 0.05), Vector3(0.0, SIDE_TOP * 0.5, -half_l + 0.025), paint)
	# The raked, flat bow and the bow deck with its cleat.
	_box(Vector3(BEAM, 0.04, 0.72), Vector3(0.0, 0.22, -half_l + 0.24), paint, false, Vector3(0.62, 0.0, 0.0))
	_box(Vector3(BEAM - 0.02, 0.035, 0.36), Vector3(0.0, SIDE_TOP - 0.02, -half_l + 0.19), metal, false)
	_box(Vector3(0.16, 0.03, 0.04), BOW_CLEAT, dark, false)
	_box(Vector3(0.04, 0.05, 0.04), BOW_CLEAT - Vector3(0.0, 0.035, 0.0), dark, false)
	# The flat bottom seen from the water.
	_box(Vector3(BEAM - 0.04, 0.03, LENGTH - 0.5), Vector3(0.0, -0.015, 0.25), paint, false)

	# Ribs across the floor and three bench seats.
	for i in 6:
		_box(Vector3(BEAM - 0.14, 0.02, 0.05), Vector3(0.0, FLOOR_Y + 0.01, -1.7 + i * 0.68), dark, false)
	for z: float in [-1.35, 0.15, 1.55]:
		_box(Vector3(BEAM - 0.1, 0.045, 0.3), Vector3(0.0, 0.44, z), wood, false)
		for s: float in [-1.0, 1.0]:
			_box(Vector3(0.06, 0.26, 0.26), Vector3(s * (half_b - 0.1), 0.3, z), metal, false)

	# The dry box under the bow bench.
	_box(Vector3(0.8, 0.26, 0.26), Vector3(0.0, FLOOR_Y + 0.13, -1.35), metal, false)
	_box(Vector3(0.82, 0.03, 0.28), Vector3(0.0, FLOOR_Y + 0.27, -1.35), dark, false)
	_add_part("drybox", Vector3(0.9, 0.4, 0.45), Vector3(0.0, FLOOR_Y + 0.2, -1.35))
	_add_part("cleat", Vector3(0.5, 0.3, 0.4), BOW_CLEAT + Vector3(0.0, 0.05, 0.08))
