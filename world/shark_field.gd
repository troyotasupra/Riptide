class_name SharkField
extends Node3D
## The sharks in the sea: a couple patrolling the crossing between the islands
## and one haunting the reef by the wreck. The host decides where they swim and
## whom they bite; this node spawns them for everyone, resolves crew members'
## strikes, and turns a dead shark into a bag of meat floating on the water.

var sharks := {}
var _zones: Array[Dictionary] = []
var _next_id := 1
## [{"at": ocean time, "zone": index}]
var _respawns: Array[Dictionary] = []
## peer id -> ocean time of their last strike
var _last_strike := {}


## Host: work out the patrol zones from the islands and fill them.
func setup_host(camp_island: CampIsland) -> void:
	var camp_center := Vector3(camp_island.center.x, 0.0, camp_island.center.y)
	var crossing := camp_center * 0.45
	_zones = [
		{"home": crossing, "radius": 60.0},
		{"home": camp_center * 0.56, "radius": 45.0},
		{"home": Vector3(camp_island.shipwreck.x, 0.0, camp_island.shipwreck.y), "radius": 26.0},
	]
	for i in _zones.size():
		_spawn_in_zone(i)


func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	var now: float = Ocean.time
	for id: String in sharks.keys():
		var shark: Shark = sharks[id]
		if shark.state == "dead" and shark.dead_for > SharkMath.CARCASS_SECONDS:
			_respawns.append({"at": now + SharkMath.RESPAWN_SECONDS, "zone": shark.zone})
			_remove_shark(id)
			Net.send_to_ready(self, "_remove_shark", [id])
	for i in range(_respawns.size() - 1, -1, -1):
		if now >= float(_respawns[i].at):
			_spawn_in_zone(int(_respawns[i].zone))
			_respawns.remove_at(i)


func _spawn_in_zone(zone: int) -> Shark:
	var info: Dictionary = _zones[zone]
	var angle := randf() * TAU
	var at: Vector3 = info.home + Vector3(cos(angle), 0.0, sin(angle)) * float(info.radius) * 0.6 + Vector3(0.0, -2.0, 0.0)
	return spawn(at, info.home, info.radius, zone)


## Host: put a shark in the water for everyone.
func spawn(at: Vector3, home: Vector3, radius: float, zone: int = -1) -> Shark:
	var id := "k%d" % _next_id
	_next_id += 1
	_spawn_shark(id, at, home, radius, zone)
	Net.send_to_ready(self, "_spawn_shark", [id, at, home, radius, zone])
	return sharks[id]


func sync_to(peer_id: int) -> void:
	for id: String in sharks:
		var shark: Shark = sharks[id]
		_spawn_shark.rpc_id(peer_id, id, shark.position, shark.home, shark.roam_radius, shark.zone)


@rpc("authority", "call_remote", "reliable")
func _spawn_shark(id: String, at: Vector3, home: Vector3, radius: float, zone: int) -> void:
	if sharks.has(id):
		return
	var shark := Shark.new()
	shark.setup(id, at, home, radius, zone)
	add_child(shark)
	sharks[id] = shark
	if multiplayer.is_server():
		shark.died.connect(_on_died)


@rpc("authority", "call_remote", "reliable")
func _remove_shark(id: String) -> void:
	var shark: Shark = sharks.get(id)
	if shark != null:
		shark.queue_free()
	sharks.erase(id)


func _on_died(shark: Shark) -> void:
	var world := GameState.world
	var stacks: Array = []
	for entry: Array in SharkMath.LOOT:
		stacks.append(CampSystems.fresh_stack(entry[0], entry[1]))
	var at := shark.global_position
	world.camp.drop_loot(Vector3(at.x, 0.15, at.z), stacks, "Shark carcass")
	world.sfx_at("splash", at)


## A crew member swings at shark `id` with whatever they're holding.
@rpc("any_peer", "call_local", "reliable")
func request_strike(id: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	var world := GameState.world
	var player := world.players_root.get_node_or_null(str(sender)) as Player
	var shark: Shark = sharks.get(id)
	if player == null or shark == null or shark.state == "dead" or player.survivor == null or player.survivor.downed:
		return
	var now: float = Ocean.time
	if now - float(_last_strike.get(sender, -99.0)) < SharkMath.STRIKE_COOLDOWN:
		return
	var at := player.world_transform().origin + Vector3.UP
	if at.distance_to(shark.global_position) > SharkMath.STRIKE_REACH + 1.5:
		return
	var s := player.survivor
	var tool: String = ItemTable.get_item(player.held_id).get("tool", "")
	var damage := SharkMath.weapon_damage(tool, SharkMath.arm_factor(s.missing_limbs, s.prosthetics))
	if damage <= 0.0:
		s.notify("You need a spear or a blade to fight a shark.")
		return
	_last_strike[sender] = now
	shark.hit(damage, at)
	world.sfx_at("hit", shark.global_position)
	if shark.state == "dead":
		s.notify("The shark goes still. Its carcass floats up — there's meat on it.")


## Host: `shark` bites `player`. Enough bites in a short time — or two while
## you're down — take a limb for good.
func bite(shark: Shark, player: Player) -> void:
	var world := GameState.world
	var s := player.survivor
	var now: float = Ocean.time
	s.recent_bites = s.recent_bites.filter(func(t: float) -> bool: return now - t < SharkMath.BITE_WINDOW)
	s.recent_bites.append(now)
	var was_down := s.downed
	s.survival.take_damage(SharkMath.BITE_DAMAGE)
	world.sfx_at("hit", shark.global_position)
	if SharkMath.costs_limb(s.recent_bites.size(), was_down):
		var limb := SharkMath.limb_to_lose(s.missing_limbs, randf())
		if not limb.is_empty():
			s.lose_limb(limb)
			s.recent_bites.clear()
	else:
		s.notify("A shark bites you! Get out of the water!")
	s.push_survival()
