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
##
## Boats are rowed with oars (see RowMath) and can be tied up with mooring lines.
##
## Fittings: the oars sit in the boat's oarlocks, not in anyone's pack. Taking
## them off is the key: nobody rows a boat away without its oars. A boat with a
## transom can carry an outboard motor, driven from the helm on the fuel in its
## tank. Any boat can take another in tow on a line from its stern.

const SEND_EVERY_TICKS := 3
const PROXY_BASE := Vector3(0.0, -5000.0, 0.0)
const PROXY_SPACING := 250.0
const MAX_SNAPSHOTS := 32
const RAFT_SIZE := HullSpecs.RAFT_SIZE
## Mooring lines: spring stiffness and damping per kg of boat, and their slack.
const LINE_STIFFNESS_PER_KG := 9.0
const LINE_DAMPING_PER_KG := 4.0
const LINE_SLACK := 1.04

@export var float_depth := Buoyancy.DEFAULT_FLOAT_DEPTH
@export var heave_damping := Buoyancy.DEFAULT_DAMPING_RATIO
@export var water_drag := 1.0
@export var water_angular_drag := 2.0
@export var row_force := 900.0
@export var row_torque := 700.0
## Side area the wind pushes on (m²).
@export var wind_area := 3.0

## "raft" or "john_boat" — what to rebuild from a save.
var kind := "raft"
var proxy_index := 0
var probes := PackedVector3Array()
var can_paddle := true
## Everything walkable, in boat space. Leaving it (plus a margin) means you've left the boat.
var hull_aabb := AABB()
## Height of the main deck above the boat origin.
var deck_top := 0.0
## Boat-space box the ocean must not draw inside (hulls whose floor is near the waterline).
var water_mask := AABB()
var proxy: StaticBody3D
var proxy_xf := Transform3D.IDENTITY
## Velocity of the hull; on clients this comes from the host's snapshots.
var net_velocity := Vector3.ZERO
## peer_id -> {"left": -1..1, "right": -1..1, "power": bool}
var rowers := {}
## part name -> Interactable (storage, cleats)
var parts := {}
## {"local": boat-space cleat, "anchor": world point, "length": metres}
var mooring: Array[Dictionary] = []

## Fittings (host truth, mirrored on every peer by _fittings).
var oars_fitted := false
var motor_fitted := false
## Litres in the outboard's tank.
var fuel := 0.0
## Motor push and turn (0: this hull takes no motor), and where it clamps on.
var motor_force := 0.0
var motor_torque := 0.0
var motor_mount := Vector3.ZERO
## Where a tow line is made fast on this boat (its stern), boat space.
var tow_local := Vector3.ZERO
## The boat we're towing, and the line's length.
var tow_target: Boat = null
var tow_length := 0.0
const TANK_LITRES := 12.0
## At full throttle a full tank lasts ten minutes.
const FUEL_PER_SECOND := TANK_LITRES / 600.0
const TOW_STIFFNESS_PER_KG := 6.0
const TOW_DAMPING_PER_KG := 3.0

## peer -> {"throttle": -1..1, "steer": -1..1}: who's at the helm.
var _helm := {}
var _fuel_sent := 0.0
var _fuel_accum := 0.0
var _motor_node: Node3D
var _steer_look := 0.0
var _tow_rope: MeshInstance3D
var _cargo_look: Node3D
var _ropes: Array[MeshInstance3D] = []
var _rower_check := 0.0
var _snapshots: Array[Dictionary] = []
var _tick := 0

static var _rope_mesh: CylinderMesh


## Host: shove a boat along, for pushing one off the beach.
func shove(velocity: Vector3) -> void:
	if not multiplayer.is_server():
		return
	freeze = false
	linear_velocity = velocity
	angular_velocity = Vector3.ZERO


static func create_raft(index: int) -> Boat:
	var boat := Boat.new()
	boat.name = "Raft"
	boat.kind = "raft"
	boat.proxy_index = index
	boat.mass = HullSpecs.RAFT_MASS
	# Slippery, so a shove carries it down the sand and into the water.
	var slide := PhysicsMaterial.new()
	slide.friction = 0.05
	slide.rough = false
	boat.physics_material_override = slide
	var size := RAFT_SIZE
	boat.deck_top = size.y
	boat.hull_aabb = AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), size)

	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = size.y * 0.5
	boat.add_child(collider)

	var bark := Materials.bark(Color(0.46, 0.34, 0.22))
	var planks := Materials.wood(Color(0.58, 0.44, 0.28))
	var cord := Materials.rope(Color(0.72, 0.62, 0.45))

	# Lashed logs along the length, each a little crooked...
	var log_count := 6
	var log_radius := size.x / (log_count * 2.0)
	for i in log_count:
		var length := size.z * (0.94 + 0.04 * (i % 3))
		var points := PackedVector3Array()
		var radii := PackedFloat32Array()
		for k in 7:
			var t := k / 6.0
			points.append(Vector3(0.02 * sin(t * PI + i), 0.0, (t - 0.5) * length))
			radii.append(log_radius * (0.96 + 0.05 * sin(t * 17.0 + i)))
		var log_instance := MeshInstance3D.new()
		log_instance.mesh = MeshKit.tube(points, radii, 10, "raft_log_%d" % (i % 3))
		log_instance.material_override = bark
		log_instance.position = Vector3(-size.x * 0.5 + log_radius * (2 * i + 1), log_radius, 0.0)
		boat.add_child(log_instance)

	# ...a plank deck across the top...
	var plank_depth := 0.06
	var plank_count := int(size.z / 0.36)
	for i in plank_count:
		var plank_mesh := BoxMesh.new()
		plank_mesh.size = Vector3(size.x + 0.1, plank_depth, 0.3)
		var plank := MeshInstance3D.new()
		plank.mesh = plank_mesh
		plank.material_override = planks
		plank.position = Vector3(0.0, size.y - plank_depth * 0.5, -size.z * 0.5 + (i + 0.5) * size.z / plank_count)
		plank.rotation.y = 0.02 * sin(i * 3.1)
		boat.add_child(plank)

	# ...and rope lashings at each end.
	for z: float in [-size.z * 0.36, size.z * 0.36]:
		var band := BoxMesh.new()
		band.size = Vector3(size.x + 0.14, 0.03, 0.07)
		var lashing := MeshInstance3D.new()
		lashing.mesh = band
		lashing.material_override = cord
		lashing.position = Vector3(0.0, size.y + 0.005, z)
		boat.add_child(lashing)

	for x: float in [-0.45, 0.45]:
		for z: float in [-0.45, 0.45]:
			boat.probes.append(Vector3(size.x * x, 0.0, size.z * z))
	boat.probes.append(Vector3.ZERO)
	boat.tow_local = Vector3(0.0, size.y, size.z * 0.5)
	# Oarlocks on the right-hand edge, cargo lashed on the deck, a tow post aft.
	boat._add_part("oars", Vector3(0.4, 0.4, 0.8), Vector3(size.x * 0.5, size.y + 0.15, 0.0))
	boat._add_part("cargo", Vector3(1.4, 0.5, 1.4), Vector3(0.0, size.y + 0.25, -0.3))
	boat._add_part("tow", Vector3(0.4, 0.4, 0.3), boat.tow_local + Vector3(0.0, 0.15, -0.1))
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
	for part_name: String in parts:
		var node: Interactable = parts[part_name]
		node.text_provider = func(player: Node) -> String: return _part_prompt(part_name, player)


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


func _process(delta: float) -> void:
	var xf := get_global_transform_interpolated()
	if _tow_rope != null:
		if tow_target != null and is_instance_valid(tow_target):
			_tow_rope.visible = true
			_tow_rope.global_transform = _rope_transform(xf * tow_local, tow_target.get_global_transform_interpolated() * tow_target.bow_point(), 0.02)
		else:
			_tow_rope.visible = false
	if _motor_node != null:
		_motor_node.rotation.y = lerp_angle(_motor_node.rotation.y, -_steer_look * 0.6, 1.0 - exp(-6.0 * delta))
	if _ropes.is_empty():
		return
	for i in mini(_ropes.size(), mooring.size()):
		var from: Vector3 = xf * Vector3(mooring[i].local)
		_ropes[i].global_transform = _rope_transform(from, mooring[i].anchor, 0.025)


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
	_pull_mooring_lines()
	_pull_tow_line()
	if submerged == 0:
		return
	var wet := float(submerged) / probes.size()
	var v := linear_velocity
	apply_central_force(Vector3(-v.x, 0.0, -v.z) * water_drag * mass * wet)
	apply_torque(-angular_velocity * mass * water_angular_drag * wet)
	var weather: Weather = GameState.world.weather if GameState.world != null else null
	if weather != null and wind_area > 0.0:
		apply_central_force(weather.wind_force_on(wind_area) * wet)

	_rower_check += get_physics_process_delta_time()
	if _rower_check >= 0.5:
		_rower_check = 0.0
		_drop_stale_rowers()
	_run_motor(wet)
	if rowers.is_empty():
		return
	# Sitting to one side only matters when someone's there to row the other side.
	var shared := rowers.size() > 1
	var oars := Vector2.ZERO
	for peer: int in rowers:
		var entry: Dictionary = rowers[peer]
		oars += RowMath.oars_for(entry.left, entry.right, _seat_x(peer) if shared else 0.0) \
			* (RowMath.POWER if entry.power else 1.0) * float(entry.get("strength", 1.0))
	var drive := RowMath.thrust(oars)
	var forward := -global_basis.z
	forward.y = 0.0
	if forward.length_squared() > 0.001:
		apply_central_force(forward.normalized() * drive.x * row_force * wet)
	apply_torque(Vector3.UP * drive.y * row_torque * wet)


## Host: forget anyone who has left the boat, lost their oar or gone down.
func _drop_stale_rowers() -> void:
	if GameState.world == null:
		return
	for peer: int in rowers.keys():
		var player := GameState.world.players_root.get_node_or_null(str(peer)) as Player
		if player == null or player.platform != self or player.survivor == null or player.survivor.downed or not oars_fitted:
			rowers.erase(peer)
	for peer: int in _helm.keys():
		var player := GameState.world.players_root.get_node_or_null(str(peer)) as Player
		if player == null or player.platform != self or player.survivor == null or player.survivor.downed or not motor_fitted:
			_helm.erase(peer)


## How far a rower sits off the centreline (boat space), or 0 if unknown.
func _seat_x(peer: int) -> float:
	if GameState.world == null:
		return 0.0
	var player := GameState.world.players_root.get_node_or_null(str(peer)) as Player
	if player == null or player.platform != self:
		return 0.0
	return (player.global_position - proxy_xf.origin).x


# --- mooring ----------------------------------------------------------------------

## Ties the boat up with `lines` ({"local", "anchor"}), each with a little slack.
## Line lengths come from `berth` — where the boat belongs — so a boat tied up a
## little way off is drawn in to it.
func moor(lines: Array, berth: Transform3D = Transform3D()) -> void:
	untie()
	var rest := global_transform if berth == Transform3D() else berth
	for line: Dictionary in lines:
		var cleat: Vector3 = line.local
		var anchor: Vector3 = line.anchor
		var length := (rest * cleat).distance_to(anchor) * LINE_SLACK
		mooring.append({"local": cleat, "anchor": anchor, "length": length})
		var rope := MeshInstance3D.new()
		rope.mesh = _unit_rope()
		rope.material_override = Materials.rope(Color(0.72, 0.62, 0.45))
		rope.top_level = true
		rope.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(rope)
		_ropes.append(rope)


func untie() -> void:
	for rope in _ropes:
		rope.queue_free()
	_ropes.clear()
	mooring.clear()


func is_tied() -> bool:
	return not mooring.is_empty()


func _pull_mooring_lines() -> void:
	for line in mooring:
		var p := global_transform * Vector3(line.local)
		var to_anchor: Vector3 = Vector3(line.anchor) - p
		var distance := to_anchor.length()
		if distance <= float(line.length) or distance < 0.001:
			continue
		var dir := to_anchor / distance
		var closing := point_velocity(p).dot(dir)
		var tension := maxf(0.0, (distance - float(line.length)) * LINE_STIFFNESS_PER_KG * mass - closing * LINE_DAMPING_PER_KG * mass)
		tension = minf(tension, mass * 6.0)  # a line pulls hard, but never yanks the boat around
		apply_force(dir * tension, p - global_position)


static func _unit_rope() -> CylinderMesh:
	if _rope_mesh == null:
		_rope_mesh = CylinderMesh.new()
		_rope_mesh.top_radius = 1.0
		_rope_mesh.bottom_radius = 1.0
		_rope_mesh.height = 1.0
		_rope_mesh.radial_segments = 6
		_rope_mesh.rings = 1
	return _rope_mesh


## A unit cylinder stretched from `a` to `b` with the given radius.
static func _rope_transform(a: Vector3, b: Vector3, radius: float) -> Transform3D:
	var along := b - a
	var length := along.length()
	if length < 0.001:
		return Transform3D(Basis.from_scale(Vector3.ONE * 0.001), a)
	var y := along / length
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	return Transform3D(Basis(x * radius, y * length, z * radius), (a + b) * 0.5)


# --- parts ------------------------------------------------------------------------

## An interaction box on the boat, `boat:<name>:<part>` to the host.
func _add_part(part_name: String, size: Vector3, pos: Vector3) -> void:
	var part := Interactable.new()
	part.name = "Part_" + part_name
	part.interact_id = "boat:%s:%s" % [name, part_name]
	part.collision_layer = Layers.INTERACT
	part.collision_mask = 0
	part.position = pos
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	part.add_child(collider)
	add_child(part)
	parts[part_name] = part


func _part_prompt(part_name: String, player: Node) -> String:
	if GameState.world == null or GameState.world.camp == null:
		return ""
	return GameState.world.camp.part_prompt(self, part_name, player)


# --- network ----------------------------------------------------------------------

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


## A crew member's oar strokes: left / right -1..1 (negative back-rows), power = Shift.
## The host only accepts it from someone aboard who carries an oar.
@rpc("any_peer", "call_local", "reliable")
func set_row_input(left: float, right: float, power: bool) -> void:
	if not multiplayer.is_server() or not can_paddle:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	if is_zero_approx(left) and is_zero_approx(right):
		rowers.erase(sender)
		return
	var player: Player = GameState.world.players_root.get_node_or_null(str(sender)) if GameState.world != null else null
	if player == null or player.platform != self or player.survivor == null or not oars_fitted:
		rowers.erase(sender)
		return
	if player.survivor.downed:
		rowers.erase(sender)
		return
	rowers[sender] = {"left": clampf(left, -1.0, 1.0), "right": clampf(right, -1.0, 1.0), "power": power,
		"strength": SharkMath.arm_factor(player.survivor.missing_limbs, player.survivor.prosthetics)}


# --- fittings: oars, motor, fuel, tow line, cargo ----------------------------------

## The bow, where a tow line is made fast on the boat being towed.
func bow_point() -> Vector3:
	return Vector3(0.0, deck_top, hull_aabb.position.z + 0.1)


## Host: set what's fitted and tell everyone.
func set_fittings(oars: bool, motor: bool, litres: float) -> void:
	_fittings(oars, motor, litres)
	_fuel_sent = fuel
	Net.send_to_ready(self, "_fittings", [oars, motor, fuel])


@rpc("authority", "call_remote", "reliable")
func _fittings(oars: bool, motor: bool, litres: float) -> void:
	oars_fitted = oars
	motor_fitted = motor and motor_force > 0.0
	fuel = clampf(litres, 0.0, TANK_LITRES)
	if motor_fitted and _motor_node == null:
		_motor_node = Node3D.new()
		_motor_node.name = "Outboard"
		_motor_node.position = motor_mount
		_motor_node.add_child(ItemModels.build("outboard_motor"))
		add_child(_motor_node)
	elif not motor_fitted and _motor_node != null:
		_motor_node.queue_free()
		_motor_node = null
	if not motor_fitted:
		_helm.clear()


## Someone at the helm: throttle -1..1 (W/S), steer -1..1 (A/D).
@rpc("any_peer", "call_local", "reliable")
func set_motor_input(throttle: float, steer: float) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	var player: Player = GameState.world.players_root.get_node_or_null(str(sender)) if GameState.world != null else null
	if is_zero_approx(throttle) and is_zero_approx(steer) or player == null or player.platform != self \
			or player.survivor == null or player.survivor.downed or not motor_fitted:
		_helm.erase(sender)
		_send_steer(0.0)
		return
	_helm[sender] = {"throttle": clampf(throttle, -1.0, 1.0), "steer": clampf(steer, -1.0, 1.0)}
	_send_steer(clampf(steer, -1.0, 1.0))


func _send_steer(steer: float) -> void:
	if absf(steer - _steer_look) < 0.01:
		return
	_steer_look = steer
	Net.send_to_ready(self, "_steer", [steer])


@rpc("authority", "call_remote", "unreliable_ordered")
func _steer(steer: float) -> void:
	_steer_look = steer


## Host: the outboard pushes the boat along and swings its stern round, burning fuel.
func _run_motor(wet: float) -> void:
	if not motor_fitted or _helm.is_empty() or fuel <= 0.0:
		return
	var throttle := 0.0
	var steer := 0.0
	for peer: int in _helm:
		throttle = _helm[peer].throttle
		steer = _helm[peer].steer
	var dt := get_physics_process_delta_time()
	var forward := -global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		return
	forward = forward.normalized()
	# Astern it only makes a fraction of the push.
	var push := throttle if throttle >= 0.0 else throttle * 0.4
	apply_central_force(forward * push * motor_force * wet)
	var speed := linear_velocity.dot(forward)
	# Steering bites harder the faster you're going (and reverses going astern).
	var bite := clampf(0.35 + absf(speed) / 3.0, 0.0, 1.6) * (1.0 if speed >= -0.2 else -1.0)
	apply_torque(Vector3.UP * -steer * motor_torque * bite * wet)
	fuel = maxf(0.0, fuel - (0.15 + 0.85 * absf(throttle)) * FUEL_PER_SECOND * dt)
	_fuel_accum += dt
	if (_fuel_accum >= 2.0 and absf(fuel - _fuel_sent) > 0.02) or fuel <= 0.0:
		_fuel_accum = 0.0
		set_fittings(oars_fitted, motor_fitted, fuel)


## Host: take `target` in tow (null casts off).
func set_tow(target: Boat) -> void:
	var length := 0.0
	if target != null:
		length = maxf(3.0, (global_transform * tow_local).distance_to(target.global_transform * target.bow_point()) + 0.5)
	_set_tow(String(target.name) if target != null else "", length)
	Net.send_to_ready(self, "_set_tow", [String(target.name) if target != null else "", length])


@rpc("authority", "call_remote", "reliable")
func _set_tow(target_name: String, length: float) -> void:
	tow_target = GameState.find_boat(target_name) if not target_name.is_empty() else null
	tow_length = length
	if tow_target != null and _tow_rope == null:
		_tow_rope = MeshInstance3D.new()
		_tow_rope.mesh = _unit_rope()
		_tow_rope.material_override = Materials.rope(Color(0.8, 0.7, 0.5))
		_tow_rope.top_level = true
		_tow_rope.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(_tow_rope)


## Host: a taut tow line pulls the towed boat after us, and drags on us a little.
func _pull_tow_line() -> void:
	if tow_target == null or not is_instance_valid(tow_target):
		return
	var a := global_transform * tow_local
	var b := tow_target.global_transform * tow_target.bow_point()
	var to_us := a - b
	var distance := to_us.length()
	if distance <= tow_length or distance < 0.001:
		return
	var dir := to_us / distance
	var closing := (tow_target.point_velocity(b) - point_velocity(a)).dot(dir)
	var m := tow_target.mass
	var tension := maxf(0.0, (distance - tow_length) * TOW_STIFFNESS_PER_KG * m - closing * TOW_DAMPING_PER_KG * m)
	tension = minf(tension, m * 8.0)
	tow_target.freeze = false
	tow_target.apply_force(dir * tension, b - tow_target.global_position)
	apply_force(-dir * tension, a - global_position)


## Shows `drums` fuel drums standing on the deck (the raft's cargo).
func show_cargo(drums: int) -> void:
	if _cargo_look != null:
		_cargo_look.queue_free()
		_cargo_look = null
	if drums <= 0:
		return
	_cargo_look = Node3D.new()
	add_child(_cargo_look)
	for i in mini(drums, 6):
		var drum := ItemModels.build("fuel_drum")
		drum.position = Vector3((i % 2 - 0.5) * 0.7, deck_top, -0.6 + int(i / 2) * 0.62)
		drum.rotation.y = i * 0.7
		_cargo_look.add_child(drum)
