class_name Boat
extends RigidBody3D
## A floating, crewable vessel.
##
## The host simulates it as a rigid body pushed up by buoyancy probes sampling
## the shared wave function. Clients freeze it and follow the host's snapshots,
## interpolated at the (slightly delayed) ocean clock.
##
## Crew don't physically stand on this body. Each boat keeps a still copy of
## its hull collision — the deck proxy — far below the world. Players aboard
## walk on that proxy with ordinary character physics and are drawn relative
## to the real hull. A pitching, drifting deck therefore never makes anyone
## slide or jitter, locally or over the network. Real hulls live on their own
## physics layer, which players never treat as a moving platform.

const SEND_EVERY_TICKS := 3
const PROXY_BASE := Vector3(0.0, -5000.0, 0.0)
const PROXY_SPACING := 250.0
const MAX_SNAPSHOTS := 32
const RAFT_SIZE := HullSpecs.RAFT_SIZE
## Paddle force multiplier while a paddler sprints (costs them stamina).
const SPRINT_PADDLE := 1.8

@export var float_depth := Buoyancy.DEFAULT_FLOAT_DEPTH
@export var heave_damping := Buoyancy.DEFAULT_DAMPING_RATIO
@export var water_drag := 1.0
@export var water_angular_drag := 2.0
@export var paddle_force := 900.0
@export var paddle_torque := 700.0

var proxy_index := 0
var probes := PackedVector3Array()
var can_paddle := true
## Everything walkable, in boat space. Leaving it (plus a margin) means you've left the boat.
var hull_aabb := AABB()
## Height of the main deck above the boat origin.
var deck_top := 0.0
## Boat-space box the ocean must not draw inside (cabins below the waterline).
var water_mask := AABB()
var proxy: StaticBody3D
var proxy_xf := Transform3D.IDENTITY
## Velocity of the hull; on clients this comes from the host's snapshots.
var net_velocity := Vector3.ZERO
## peer_id -> {"input": Vector2 (x turn, y throttle), "sprint": bool}
var paddlers := {}

var _snapshots: Array[Dictionary] = []
var _tick := 0


static func create_raft(index: int) -> Boat:
	var boat := Boat.new()
	boat.name = "Raft"
	boat.proxy_index = index
	boat.mass = HullSpecs.RAFT_MASS
	var size := RAFT_SIZE
	boat.deck_top = size.y
	boat.hull_aabb = AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), size)

	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = size.y * 0.5
	boat.add_child(collider)

	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.60, 0.42, 0.24)
	var dark_wood := StandardMaterial3D.new()
	dark_wood.albedo_color = Color(0.44, 0.30, 0.17)

	# Floating logs along the length...
	var log_count := 6
	var log_radius := size.x / (log_count * 2.0)
	for i in log_count:
		var log_mesh := CylinderMesh.new()
		log_mesh.top_radius = log_radius
		log_mesh.bottom_radius = log_radius
		log_mesh.height = size.z * (0.92 + 0.04 * (i % 3))
		log_mesh.radial_segments = 7
		log_mesh.rings = 1
		var log_instance := MeshInstance3D.new()
		log_instance.mesh = log_mesh
		log_instance.material_override = wood if i % 2 == 0 else dark_wood
		log_instance.rotation.x = PI / 2.0
		log_instance.position = Vector3(-size.x * 0.5 + log_radius * (2 * i + 1), log_radius, 0.0)
		boat.add_child(log_instance)

	# ...with a plank deck lashed across the top.
	var plank_depth := 0.06
	var plank_count := int(size.z / 0.36)
	for i in plank_count:
		var plank_mesh := BoxMesh.new()
		plank_mesh.size = Vector3(size.x + 0.1, plank_depth, 0.3)
		var plank := MeshInstance3D.new()
		plank.mesh = plank_mesh
		plank.material_override = dark_wood if i % 2 == 0 else wood
		plank.position = Vector3(0.0, size.y - plank_depth * 0.5, -size.z * 0.5 + (i + 0.5) * size.z / plank_count)
		boat.add_child(plank)

	for x: float in [-0.45, 0.45]:
		for z: float in [-0.45, 0.45]:
			boat.probes.append(Vector3(size.x * x, 0.0, size.z * z))
	boat.probes.append(Vector3.ZERO)
	return boat


func _ready() -> void:
	add_to_group("boats")
	collision_layer = Layers.BOATS
	collision_mask = Layers.WORLD | Layers.BOATS
	can_sleep = false
	if not multiplayer.is_server():
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		freeze = true
	_build_proxy()


func _build_proxy() -> void:
	proxy = StaticBody3D.new()
	proxy.name = "DeckProxy"
	proxy.top_level = true
	proxy.collision_layer = Layers.WORLD
	proxy.collision_mask = 0
	for child in get_children():
		if child is CollisionShape3D:
			var copy := CollisionShape3D.new()
			copy.shape = child.shape
			copy.transform = child.transform
			proxy.add_child(copy)
	add_child(proxy)
	proxy_xf = Transform3D(Basis.IDENTITY, PROXY_BASE + Vector3(PROXY_SPACING * proxy_index, 0.0, 0.0))
	proxy.global_transform = proxy_xf


func _physics_process(_delta: float) -> void:
	if multiplayer.is_server():
		_simulate()
		net_velocity = linear_velocity
		_tick += 1
		if _tick % SEND_EVERY_TICKS == 0:
			Net.send_to_ready(self, "_net_state", [Ocean.time, global_transform, linear_velocity])
	else:
		_follow_host()


## Is boat-space point `p` still on (or just beside) this boat?
func contains_local_point(p: Vector3, margin: float, drop: float) -> bool:
	return p.x > hull_aabb.position.x - margin and p.x < hull_aabb.end.x + margin \
		and p.z > hull_aabb.position.z - margin and p.z < hull_aabb.end.z + margin \
		and p.y > hull_aabb.position.y - drop


## World-space velocity of the hull at `world_point`.
func point_velocity(world_point: Vector3) -> Vector3:
	if multiplayer.is_server():
		return linear_velocity + angular_velocity.cross(world_point - global_position)
	return net_velocity


func _simulate() -> void:
	var support := mass * Buoyancy.GRAVITY / probes.size()
	var t: float = Ocean.time
	var submerged := 0
	for probe in probes:
		var wp := global_transform * probe
		var xz := Vector2(wp.x, wp.z)
		var depth := Waves.height_at(xz, t) - wp.y
		if depth <= 0.0:
			continue
		submerged += 1
		var lift := Buoyancy.probe_force(depth, Buoyancy.water_vertical_velocity(xz, t),
			point_velocity(wp).y, support, float_depth, heave_damping)
		apply_force(Vector3.UP * lift, wp - global_position)
	if submerged == 0:
		return
	var wet := float(submerged) / probes.size()
	var v := linear_velocity
	apply_central_force(Vector3(-v.x, 0.0, -v.z) * water_drag * mass * wet)
	apply_torque(-angular_velocity * mass * water_angular_drag * wet)

	if paddlers.is_empty():
		return
	var paddle := Vector2.ZERO
	for entry: Dictionary in paddlers.values():
		paddle += Vector2(entry.input) * (SPRINT_PADDLE if entry.sprint else 1.0)
	paddle = paddle.clampf(-2.5, 2.5)  # a second paddler helps, a sixth doesn't
	var forward := -global_basis.z
	forward.y = 0.0
	if forward.length_squared() > 0.001:
		apply_central_force(forward.normalized() * -paddle.y * paddle_force * wet)
	apply_torque(Vector3.UP * -paddle.x * paddle_torque * wet)


func _follow_host() -> void:
	if _snapshots.is_empty():
		return
	var render_time: float = Ocean.time
	while _snapshots.size() > 2 and _snapshots[1].t <= render_time:
		_snapshots.pop_front()
	var a: Dictionary = _snapshots[0]
	var xf: Transform3D = a.xf
	net_velocity = a.lv
	if _snapshots.size() > 1 and render_time > a.t:
		var b: Dictionary = _snapshots[1]
		var span: float = maxf(b.t - a.t, 0.001)
		xf = xf.interpolate_with(b.xf, clampf((render_time - a.t) / span, 0.0, 1.0))
		net_velocity = b.lv
	global_transform = xf


@rpc("authority", "call_remote", "unreliable_ordered")
func _net_state(t: float, xf: Transform3D, lv: Vector3) -> void:
	if not _snapshots.is_empty() and t <= _snapshots.back().t:
		return
	_snapshots.append({"t": t, "xf": xf, "lv": lv})
	if _snapshots.size() > MAX_SNAPSHOTS:
		_snapshots.pop_front()


@rpc("any_peer", "call_local", "reliable")
func set_paddle_input(input: Vector2, sprint: bool) -> void:
	if not multiplayer.is_server() or not can_paddle:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	if input == Vector2.ZERO:
		paddlers.erase(sender)
	else:
		paddlers[sender] = {"input": input.limit_length(1.0), "sprint": sprint}
