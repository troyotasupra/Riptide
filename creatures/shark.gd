class_name Shark
extends Node3D
## A shark. The host swims it: cruising a patch of open water, going after crew
## members who are in the water (never anyone aboard a boat, never in the
## shallows), biting, darting off when struck, and dying. Clients draw it from
## the host's snapshots.

signal died(shark: Shark)

const SEND_SECONDS := 0.1

var shark_id := ""
var zone := 0
var home := Vector3.ZERO
var roam_radius := 40.0
var health := SharkMath.MAX_HEALTH
## "cruise", "chase", "flee" or "dead"
var state := "cruise"
var target_peer := 0
var heading := 0.0
var speed := SharkMath.CRUISE_SPEED
var dead_for := 0.0

var _bite_cooldown := 0.0
var _flee_t := 0.0
var _flee_from := Vector3.ZERO
var _think := 0.0
var _send_accum := 0.0
var _orbit := 0.0
var _swim_phase := 0.0
var _tail: Node3D
var _net_position := Vector3.ZERO
var _net_heading := 0.0
var _has_net_state := false


func setup(id: String, at: Vector3, p_home: Vector3, radius: float, p_zone: int) -> void:
	shark_id = id
	name = "Shark_" + id
	position = at
	home = p_home
	roam_radius = radius
	zone = p_zone
	_orbit = absf(float(hash(id) % 628)) / 100.0
	heading = _orbit


func _ready() -> void:
	_build()
	var hitbox := Interactable.new()
	hitbox.name = "Hitbox"
	hitbox.interact_id = "shark:" + shark_id
	hitbox.collision_layer = Layers.INTERACT
	hitbox.collision_mask = 0
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 0.9, 2.8)
	var collider := CollisionShape3D.new()
	collider.shape = box
	hitbox.add_child(collider)
	hitbox.text_provider = func(_player: Node) -> String:
		return "" if state == "dead" else "Shark — strike it with a spear or blade (left click)"
	add_child(hitbox)


func _physics_process(delta: float) -> void:
	_swim_phase += delta * (3.0 + speed * 1.2)
	if _tail != null:
		_tail.rotation.y = 0.0 if state == "dead" else sin(_swim_phase) * (0.25 + 0.05 * speed)
	if not multiplayer.is_server():
		if _has_net_state:
			var blend := 1.0 - exp(-8.0 * delta)
			position = position.lerp(_net_position, blend)
			heading = lerp_angle(heading, _net_heading, blend)
		rotation = Vector3(0.0, heading, PI if state == "dead" else 0.0)
		return
	_host_tick(delta)
	rotation = Vector3(0.0, heading, PI if state == "dead" else 0.0)
	_send_accum += delta
	if _send_accum >= SEND_SECONDS:
		_send_accum = 0.0
		Net.send_to_ready(self, "_net_state", [position, heading, state])


func forward() -> Vector3:
	return Vector3(-sin(heading), 0.0, -cos(heading))


# --- host ------------------------------------------------------------------------

func _host_tick(delta: float) -> void:
	var world := GameState.world
	if world == null:
		return
	var surface := Waves.height_at(Vector2(position.x, position.z), Ocean.time)
	if state == "dead":
		dead_for += delta
		speed = 0.0
		position.y = lerpf(position.y, surface - 0.25, 1.0 - exp(-1.2 * delta))
		return
	_bite_cooldown = maxf(0.0, _bite_cooldown - delta)
	_think -= delta
	if _think <= 0.0:
		_think = 0.4
		_look_for_prey()

	var desired := heading
	var want_speed := SharkMath.CRUISE_SPEED
	var want_y := surface - 1.8
	match state:
		"chase":
			var prey := _prey()
			if prey == null:
				state = "cruise"
			else:
				var at: Vector3 = prey.world_transform().origin + Vector3(0.0, 0.3, 0.0)
				var to := at - position
				desired = atan2(-to.x, -to.z)
				want_speed = SharkMath.CHASE_SPEED
				want_y = minf(at.y - 0.3, surface - 0.5)
				if Vector2(to.x, to.z).length() < SharkMath.BITE_RANGE and absf(to.y) < 1.6 and _bite_cooldown <= 0.0:
					_bite_cooldown = SharkMath.BITE_COOLDOWN
					world.sharks.bite(self, prey)
					_flee(at, 1.2)
		"flee":
			_flee_t -= delta
			var away := position - _flee_from
			desired = atan2(-away.x, -away.z)
			want_speed = SharkMath.CHASE_SPEED
			if _flee_t <= 0.0:
				state = "chase" if target_peer != 0 else "cruise"
		_:
			_orbit += delta * SharkMath.CRUISE_SPEED / maxf(roam_radius, 5.0)
			var point := home + Vector3(cos(_orbit), 0.0, sin(_orbit)) * roam_radius
			var to := point - position
			desired = atan2(-to.x, -to.z)

	# Turn back from the shallows.
	var ahead := position + forward() * 7.0
	var seabed: float = world.ground_height(ahead.x, ahead.z)
	if seabed != -INF and seabed > SharkMath.SHALLOWS:
		desired = heading + PI * 0.7
		if state == "chase":
			state = "cruise"
			target_peer = 0
	heading = rotate_toward(heading, desired, SharkMath.TURN_RATE * delta)
	speed = lerpf(speed, want_speed, 1.0 - exp(-2.0 * delta))
	position += forward() * speed * delta
	position.y = lerpf(position.y, want_y, 1.0 - exp(-2.0 * delta))


func _look_for_prey() -> void:
	if state == "flee":
		return
	if state == "chase" and _prey() != null:
		return
	var best: Player = null
	var best_distance := SharkMath.AGGRO_RANGE
	for player: Player in GameState.world.players_root.get_children():
		if not _is_prey(player):
			continue
		var distance := player.world_transform().origin.distance_to(position)
		if distance < best_distance:
			best = player
			best_distance = distance
	target_peer = best.peer_id if best != null else 0
	state = "chase" if best != null else "cruise"


func _is_prey(player: Player) -> bool:
	if player == null or player.survivor == null or player.is_queued_for_deletion():
		return false
	var at := player.world_transform().origin
	var seabed: float = GameState.world.ground_height(at.x, at.z)
	var in_water := at.y < Waves.height_at(Vector2(at.x, at.z), Ocean.time) + 0.2
	return SharkMath.is_prey(player.swimming, player.platform != null, player.survivor.downed and in_water, -INF if seabed == -INF else seabed)


func _prey() -> Player:
	if target_peer == 0:
		return null
	var player := GameState.world.players_root.get_node_or_null(str(target_peer)) as Player
	if not _is_prey(player) or player.world_transform().origin.distance_to(position) > SharkMath.GIVE_UP_RANGE:
		return null
	return player


func _flee(from: Vector3, seconds: float) -> void:
	state = "flee"
	_flee_from = from
	_flee_t = seconds


## Host: struck for `amount` by someone at `from`.
func hit(amount: float, from: Vector3) -> void:
	if state == "dead":
		return
	health -= amount
	if health <= 0.0:
		health = 0.0
		state = "dead"
		dead_for = 0.0
		target_peer = 0
		died.emit(self)
		Net.send_to_ready(self, "_net_state", [position, heading, state])
		return
	_flee(from, SharkMath.FLEE_SECONDS if amount >= 20.0 else 1.5)


@rpc("authority", "call_remote", "unreliable_ordered")
func _net_state(pos: Vector3, p_heading: float, p_state: String) -> void:
	_net_position = pos
	_net_heading = p_heading
	if not _has_net_state:
		position = pos
		heading = p_heading
		_has_net_state = true
	state = p_state


# --- looks -----------------------------------------------------------------------

func _build() -> void:
	var skin := Materials.plain(Color(0.36, 0.43, 0.5), 0.5)
	var belly := Materials.plain(Color(0.86, 0.87, 0.85), 0.6)
	var dark := Materials.plain(Color(0.04, 0.04, 0.05), 0.2)
	var points := PackedVector3Array()
	var radii := PackedFloat32Array()
	for i in 13:
		var t := i / 12.0
		points.append(Vector3(0.0, 0.03 * sin(t * PI), lerpf(-1.35, 1.05, t)))
		radii.append(0.02 + 0.34 * pow(sin(PI * clampf(t * 0.9 + 0.06, 0.0, 1.0)), 0.75))
	var body := MeshInstance3D.new()
	body.mesh = MeshKit.tube(points, radii, 14, "shark_body")
	body.material_override = skin
	body.scale = Vector3(0.9, 0.82, 1.0)
	add_child(body)
	var under := MeshInstance3D.new()
	under.mesh = MeshKit.rock(99, 0.0, 1.0)
	under.material_override = belly
	under.position = Vector3(0.0, -0.14, -0.05)
	under.scale = Vector3(0.38, 0.2, 1.6)
	add_child(under)
	_fin(self, Vector3(0.04, 0.62, 0.72), Vector3(0.0, 0.46, -0.05), Vector3(0.0, PI / 2.0, 0.0), 0.25, skin)
	for side: float in [-1.0, 1.0]:
		_fin(self, Vector3(0.62, 0.32, 0.035), Vector3(side * 0.42, -0.14, -0.45), Vector3(-PI / 2.0, 0.0, side * 0.35), 0.15 if side < 0.0 else 0.85, skin)
		var eye := MeshInstance3D.new()
		eye.mesh = MeshKit.rock(98, 0.0, 1.0)
		eye.material_override = dark
		eye.scale = Vector3.ONE * 0.05
		eye.position = Vector3(side * 0.2, 0.07, -1.02)
		add_child(eye)
	_tail = Node3D.new()
	_tail.position = Vector3(0.0, 0.02, 1.0)
	add_child(_tail)
	_fin(_tail, Vector3(0.04, 0.72, 0.55), Vector3(0.0, 0.3, 0.32), Vector3(0.0, PI / 2.0, 0.0), 0.9, skin)
	_fin(_tail, Vector3(0.04, 0.42, 0.4), Vector3(0.0, -0.18, 0.24), Vector3(PI, PI / 2.0, 0.0), 0.9, skin)


static func _fin(parent: Node3D, size: Vector3, pos: Vector3, rot: Vector3, lean: float, mat: Material) -> void:
	var prism := PrismMesh.new()
	prism.size = Vector3(size.z, size.y, size.x)
	prism.left_to_right = lean
	var fin := MeshInstance3D.new()
	fin.mesh = prism
	fin.material_override = mat
	fin.position = pos
	fin.rotation = rot
	parent.add_child(fin)
