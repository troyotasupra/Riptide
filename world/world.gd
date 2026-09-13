extends Node3D
## The playable world: sky, sea, the start island, the camp island, the crew,
## their boats and their camp. The host builds it from the shared seed (or a
## save); clients build the same thing once welcomed, and then the host spawns
## everyone for everyone. The host also runs survival and every interaction.

const START_ISLAND_RADIUS := 55.0
const INTERACT_RANGE := 4.5
const SPRING_DRINK := 30.0
const STREAM_DRINK := 20.0
const STREAM_SICK_CHANCE := 0.5
const STREAM_SICKNESS := 90.0

var island: IslandGenerator
var camp_island: CampIsland
var resources: ResourceField
var camp: CampSystems
var players_root := Node3D.new()
var boats_root := Node3D.new()
## Saved crew members who aren't connected right now, by name.
var saved_players := {}
var _age := 0.0
## peer id -> {"id": target, "at": ocean clock} for hold-to-gather validation
var _interact_started := {}


func _ready() -> void:
	GameState.world = self
	add_child(_build_environment())
	add_child(OceanSurface.new())
	players_root.name = "Players"
	add_child(players_root)
	boats_root.name = "Boats"
	add_child(boats_root)
	camp = CampSystems.new()
	camp.name = "Camp"
	add_child(camp)
	add_child(Hud.new())
	if not GameState.free_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	Net.peer_ready.connect(_on_peer_ready)
	Net.peer_left.connect(_on_peer_left)
	if not GameState.scenario.is_empty():
		var driver := ScenarioDriver.new()
		driver.name = "Scenario"
		add_child(driver)
	if multiplayer.is_server():
		var save := SaveGame.pending
		SaveGame.pending = {}
		var start := DayNight.START_TIME
		if not save.is_empty():
			start = save.get("time_of_day", DayNight.START_TIME)
		elif GameState.start_time >= 0.0:
			start = GameState.start_time
		GameState.day_offset = start - Ocean.time / DayNight.DAY_LENGTH
		_generate()
		if save.is_empty():
			camp.setup_new_world()
		else:
			_apply_save(save)
		Net.report_world_ready()
	else:
		Net.welcomed.connect(_on_welcomed, CONNECT_ONE_SHOT)
		Net.request_welcome()


func _exit_tree() -> void:
	if GameState.world == self:
		GameState.world = null
	GameState.ui_open = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and Net.is_hosting():
		save_now()


func _process(delta: float) -> void:
	if GameState.screenshot_path.is_empty():
		return
	_age += delta
	if _age < GameState.screenshot_delay:
		return
	var path := GameState.screenshot_path
	GameState.screenshot_path = ""
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(path)
	print("[world] screenshot %s: %s" % [path, error_string(err)])
	get_tree().quit()


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	for player: Player in players_root.get_children():
		if player.survivor == null or player.is_queued_for_deletion():
			continue
		player.survivor.host_tick(delta)
		if player.survivor.survival.is_dead():
			_respawn(player)


## Terrain height at (x, z) from the island generators, or -INF over open sea.
## Works before terrain meshes exist, so players can wait for ground to load.
func ground_height(x: float, z: float) -> float:
	if camp_island != null and Vector2(x, z).distance_to(camp_island.center) < CampIsland.RADIUS * 1.5:
		return camp_island.height_at(x, z)
	if island != null and Vector2(x, z).length() < START_ISLAND_RADIUS * 1.35:
		return island.height_at(x, z)
	return -INF


func find_boat(boat_name: String) -> Boat:
	if boat_name.is_empty():
		return null
	return boats_root.get_node_or_null(boat_name) as Boat


func spawn_point(index: int) -> Vector3:
	if GameState.spawn_override in ["camp", "boat"] and camp_island != null:
		var inland := (camp_island.center - camp_island.cove).normalized()
		var p := camp_island.cove + inland * 10.0 + inland.orthogonal() * (index - 2.5) * 1.5
		return Vector3(p.x, camp_island.height_at(p.x, p.y) + 1.2, p.y)
	var shore := island.find_shore_point(Vector2(0.0, 1.0))
	var x := shore.x + (index - 2.5) * 1.5
	var z := shore.z - 6.0
	return Vector3(x, island.height_at(x, z) + 1.2, z)


func _generate() -> void:
	island = IslandGenerator.new(GameState.world_seed, START_ISLAND_RADIUS)
	add_child(island.build())
	var shore := island.find_shore_point(Vector2(0.0, 1.0))
	var raft := Boat.create_raft(0)
	raft.position = Vector3(shore.x, 0.3, shore.z + 7.0)
	boats_root.add_child(raft)

	camp_island = CampIsland.new(GameState.world_seed)
	var camp_root := Node3D.new()
	camp_root.name = "CampIsland"
	add_child(camp_root)
	var terrain := TerrainBuilder.new()
	terrain.name = "Terrain"
	camp_root.add_child(terrain)
	terrain.start(camp_island)
	resources = ResourceField.new()
	resources.name = "Resources"
	camp_root.add_child(resources)
	resources.populate(camp_island)
	camp_root.add_child(CampIslandPois.build(camp_island))

	var layout := Sailboat.mooring_layout(camp_island)
	var sailboat := Sailboat.create(1)
	sailboat.transform = layout.transform
	boats_root.add_child(sailboat)
	sailboat.moor(layout.lines)

	camp.create_pickups(camp_island)


func _on_welcomed() -> void:
	_generate()
	Net.report_world_ready()


# --- saving --------------------------------------------------------------------

func save_now() -> void:
	if not multiplayer.is_server() or camp_island == null:
		return
	var now: float = Ocean.time
	var players := saved_players.duplicate(true)
	for player: Player in players_root.get_children():
		players[player.display_name] = player.survivor.to_save(now)
	var depleted := {}
	for id: String in resources.depleted:
		depleted[id] = maxf(0.0, resources.depleted[id] - now)
	var boats := {}
	for boat: Boat in boats_root.get_children():
		boats[String(boat.name)] = boat.global_transform
	var ok := SaveGame.write({
		"version": 1,
		"seed": GameState.world_seed,
		"time_of_day": GameState.time_of_day(),
		"resources": depleted,
		"boats": boats,
		"camp": camp.to_save(now),
		"players": players,
	})
	print("[save] world saved: %s" % ok)


func _apply_save(data: Dictionary) -> void:
	var now: float = Ocean.time
	var depleted: Dictionary = data.get("resources", {})
	for id: String in depleted:
		resources.depleted[id] = now + float(depleted[id])
	var boats: Dictionary = data.get("boats", {})
	for boat_name: String in boats:
		var boat := find_boat(boat_name)
		if boat != null:
			boat.global_transform = boats[boat_name]
			boat.reset_physics_interpolation()
	camp.from_save(data.get("camp", {}), now)
	saved_players = data.get("players", {})
	print("[save] world loaded (%d crew members on record)" % saved_players.size())


# --- interactions (host decides) -------------------------------------------

func spring_prompt(player: Node) -> String:
	if CampSystems.held_item(player) == "canteen":
		return "Fill the canteen with spring water"
	return "Drink from the spring"


func stream_prompt(player: Node) -> String:
	if CampSystems.held_item(player) == "canteen":
		return "Fill the canteen (unboiled)"
	return "Drink from the stream (unboiled — risky)"


@rpc("any_peer", "call_local", "reliable")
func begin_interact(target_id: String) -> void:
	if multiplayer.is_server():
		_interact_started[_sender_id()] = {"id": target_id, "at": Ocean.time}


@rpc("any_peer", "call_local", "reliable")
func request_interact(target_id: String, slot: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := _sender_id()
	var player := players_root.get_node_or_null(str(sender)) as Player
	if player == null or player.survivor == null:
		return
	var survivor := player.survivor
	slot = clampi(slot, 0, Inventory.HOTBAR_SIZE - 1)
	var at := player.world_transform().origin
	var parts := target_id.split(":")
	match parts[0]:
		"spring":
			_use_spring(survivor, at, slot)
		"stream":
			_use_stream(survivor, at, slot)
		"res":
			if parts.size() < 2:
				return
			var node: ResourceNode = resources.nodes.get(parts[1])
			if node == null or at.distance_to(node.global_position) > INTERACT_RANGE:
				return
			var needed := ResourceTable.harvest_seconds(node.kind, survivor.inventory.tool_types())
			if needed > 0.0:
				var started: Dictionary = _interact_started.get(sender, {})
				if started.get("id", "") != target_id or Ocean.time - float(started.get("at", 0.0)) < needed * 0.75:
					return
			_interact_started.erase(sender)
			resources.harvest(survivor, parts[1])
		"pickup":
			var pickup: Node3D = camp.pickup_nodes.get(parts[1]) if parts.size() > 1 else null
			if pickup != null and at.distance_to(pickup.global_position) <= INTERACT_RANGE:
				camp.pickup(survivor, parts[1])
		"struct":
			var structure: Node3D = camp.structure_nodes.get(parts[1]) if parts.size() > 1 else null
			if structure != null and at.distance_to(structure.global_position) <= INTERACT_RANGE + 1.0:
				camp.interact_structure(survivor, parts[1], slot)
		"boat":
			if parts.size() < 3:
				return
			var boat := find_boat(parts[1]) as Sailboat
			var part: Node3D = boat.parts.get(parts[2]) if boat != null else null
			if part != null and at.distance_to(part.global_position) <= INTERACT_RANGE:
				camp.interact_boat_part(survivor, boat, parts[2], slot)


func _use_spring(survivor: Survivor, at: Vector3, slot: int) -> void:
	var spring := Vector3(camp_island.spring.x, camp_island.spring_height, camp_island.spring.y)
	if at.distance_to(spring) > CampIsland.POND_RADIUS + INTERACT_RANGE:
		return
	if _fill_canteen(survivor, slot, "canteen_clean"):
		survivor.notify("Filled the canteen with clean spring water.")
		return
	survivor.survival.drink(SPRING_DRINK)
	survivor.notify("The spring water is cold and clean.")
	survivor.push_survival()


func _use_stream(survivor: Survivor, at: Vector3, slot: int) -> void:
	if camp_island.distance_to_stream(Vector2(at.x, at.z)) > INTERACT_RANGE:
		return
	if _fill_canteen(survivor, slot, "canteen_dirty"):
		survivor.notify("Filled the canteen. Boil it before you trust it.")
		return
	survivor.survival.drink(STREAM_DRINK)
	if randf() < STREAM_SICK_CHANCE:
		survivor.survival.make_sick(STREAM_SICKNESS)
		survivor.notify("The water tastes of mud... your stomach cramps.")
	else:
		survivor.notify("You drink from the stream. Lucky this time.")
	survivor.push_survival()


func _fill_canteen(survivor: Survivor, slot: int, filled: String) -> bool:
	var stack = survivor.inventory.slots[slot]
	if stack == null or stack.id != "canteen":
		return false
	survivor.inventory.slots[slot] = {"id": filled, "count": 1, "spoils_at": 0.0}
	survivor.push_inventory()
	return true


func _respawn(player: Player) -> void:
	var s := player.survivor
	s.survival.health = Survival.MAX
	s.survival.hunger = maxf(s.survival.hunger, 50.0)
	s.survival.thirst = maxf(s.survival.thirst, 50.0)
	s.survival.body_temp = Survival.NORMAL_TEMP
	s.survival.sickness = 0.0
	s.wetness = 0.0
	if camp.teleport_to_spot(player, camp.respawn_spot(player.display_name)):
		s.notify("You blacked out... and woke where you last slept.")
	else:
		player.teleport(spawn_point(randi() % Net.MAX_PLAYERS))
		s.notify("You blacked out... and woke up back on the first beach.")
	s.push_survival()


func _sender_id() -> int:
	var sender := multiplayer.get_remote_sender_id()
	return sender if sender != 0 else multiplayer.get_unique_id()


# --- crew spawning (host decides, everyone obeys) --------------------------

func _on_peer_ready(peer_id: int) -> void:
	if peer_id != multiplayer.get_unique_id():
		for existing: Player in players_root.get_children():
			_spawn_player.rpc_id(peer_id, existing.peer_id, existing.display_name, existing.world_transform().origin)
		resources.sync_to(peer_id)
		camp.sync_to(peer_id)
	var player_name: String = Net.roster[peer_id]["name"]
	var index := players_root.get_child_count()
	var pos := spawn_point(index)
	_spawn_player(peer_id, player_name, pos)
	Net.send_to_ready(self, "_spawn_player", [peer_id, player_name, pos])
	var player := players_root.get_node(str(peer_id)) as Player
	if saved_players.has(player_name):
		player.survivor.from_save(saved_players[player_name], Ocean.time)
		saved_players.erase(player_name)
		player.survivor.push_inventory()
		player.survivor.push_survival()
	if GameState.spawn_override == "boat":
		player.teleport_aboard("Sailboat", Sailboat.BUNK_SPAWN + Vector3(0.0, 0.0, 1.0 + index * 0.8))
	else:
		camp.teleport_to_spot(player, camp.respawn_spot(player_name))


func _on_peer_left(peer_id: int) -> void:
	for boat: Boat in get_tree().get_nodes_in_group("boats"):
		boat.paddlers.erase(peer_id)
	var player := players_root.get_node_or_null(str(peer_id)) as Player
	if player != null:
		saved_players[player.display_name] = player.survivor.to_save(Ocean.time)
	camp.forget_peer(peer_id)
	_despawn_player(peer_id)
	Net.send_to_ready(self, "_despawn_player", [peer_id])


@rpc("authority", "call_remote", "reliable")
func _spawn_player(peer_id: int, player_name: String, pos: Vector3) -> void:
	if players_root.has_node(str(peer_id)):
		return
	var player := Player.new()
	player.name = str(peer_id)
	player.peer_id = peer_id
	player.display_name = player_name
	player.is_local = peer_id == multiplayer.get_unique_id()
	player.set_multiplayer_authority(peer_id)
	player.yaw = PI  # face out to sea, toward the raft
	player.pitch = -0.12
	if camp_island != null and (GameState.spawn_override == "camp" or GameState.face in ["camp", "sea"]):
		var to_camp := camp_island.center - Vector2(pos.x, pos.z)
		player.yaw = atan2(-to_camp.x, -to_camp.y)
		player.pitch = 0.04
		if GameState.face == "sea":
			player.yaw += PI
			player.pitch = -0.08
	player.position = pos
	players_root.add_child(player)
	print("[world] peer %d spawned %s (peer %d)%s at %s" % [
		multiplayer.get_unique_id(), player_name, peer_id, " [local]" if player.is_local else "", pos])


@rpc("authority", "call_remote", "reliable")
func _despawn_player(peer_id: int) -> void:
	var player := players_root.get_node_or_null(str(peer_id))
	if player != null:
		player.queue_free()


func _build_environment() -> SkyController:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.ground_bottom_color = Color(0.08, 0.24, 0.34)
	var sky := Sky.new()
	sky.sky_material = sky_material

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_white = 1.6
	environment.fog_enabled = true
	environment.fog_density = 0.0015
	environment.fog_sky_affect = 0.3
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)

	var controller := SkyController.new()
	controller.name = "Sky"
	controller.sun = sun
	controller.environment = environment
	controller.sky_material = sky_material
	return controller
