class_name ScenarioDriver
extends Node
## Scripted end-to-end checks that run inside a real world, for automated
## testing only (command line --scenario=camp on a host, --scenario=client on a
## joining crew member). Prints "[scenario] PASS/FAIL ..." lines, then quits.

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().create_timer(4.0).timeout
	match GameState.scenario:
		"camp":
			await _camp_loop()
		"client":
			await _client_chest()
		"lineup":
			_lineup()
			return  # stays up for a --shot screenshot
		_:
			_check(false, "unknown scenario '%s'" % GameState.scenario)
	print("[scenario] done: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print("[scenario] %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## Host: outfit → stash → book → compartment → gear → craft → build → fire → cook
## → chop → sleep → drop → blackout → save.
func _camp_loop() -> void:
	var world := GameState.world
	var camp: CampSystems = world.camp
	var player := GameState.local_player as Player
	var s := player.survivor
	var boat := world.find_boat("Sailboat") as Sailboat
	_check(player.platform == boat, "host starts aboard the sailboat")
	_check(s.equipment.ids() == {"torso": "tshirt", "legs": "shorts", "feet": "sandals"}, "a new crew member washes up in the starting outfit")
	_check(player.model.worn.get("torso", "") == "tshirt", "the character model shows the T-shirt")

	camp.interact_boat_part(s, boat, "chest", 0)
	_check(camp.open_container == "boat:Sailboat:chest", "the sea chest opens")
	var chest: Inventory = camp.containers["boat:Sailboat:chest"]
	for i in chest.slots.size():
		if chest.slots[i] != null:
			camp.request_transfer("boat:Sailboat:chest", true, i)
	_check(s.inventory.count_of("survival_book") == 1 and s.inventory.count_of("lighter") == 1 and s.inventory.count_of("knife") == 1,
		"the stash moves into the pack")
	_check(chest.is_empty(), "the chest is empty afterwards")

	s.inventory.move(s.inventory.first_slot_of("survival_book"), 0)
	s._request_use(0)
	_check(camp.known_recipes.has("campfire_kit") and camp.known_recipes.has("rope"), "reading the book teaches the basics")

	camp.interact_boat_part(s, boat, "compartment", 0)
	_check(not camp.unlocked.has("boat:Sailboat:compartment"), "the compartment stays locked without the key")
	s.inventory.add("compartment_key", 1)
	camp.interact_boat_part(s, boat, "compartment", 0)
	_check(camp.unlocked.has("boat:Sailboat:compartment") and camp.open_container == "boat:Sailboat:compartment", "the brass key unlocks it")
	var compartment: Inventory = camp.containers["boat:Sailboat:compartment"]
	_check(compartment.count_of("pistol") == 1 and compartment.count_of("plate_carrier") == 1, "the pistol and a plate carrier are inside")

	var carrier_slot := compartment.first_slot_of("plate_carrier")
	camp.request_transfer("boat:Sailboat:compartment", true, carrier_slot)
	s._request_wear(s.inventory.first_slot_of("plate_carrier"))
	_check(s.equipment.ids().get("vest", "") == "plate_carrier" and s.total_weight() > 8.0, "wearing the plate carrier adds its weight")
	_check(player.model.worn.get("vest", "") == "plate_carrier", "the plate carrier shows on the character")
	s.inventory.slots[5] = {"id": "rain_jacket", "count": 1, "spoils_at": 0.0}
	s._request_use(5)
	_check(s.equipment.ids().torso == "rain_jacket" and s.inventory.slots[5] != null and s.inventory.slots[5].id == "tshirt", "putting on the jacket swaps the T-shirt into the pack")

	s.inventory.add("stone", 6)
	s.inventory.add("driftwood", 6)
	camp.request_craft("campfire_kit")
	_check(s.inventory.count_of("campfire_kit") == 1 and s.inventory.count_of("stone") == 0, "crafted a campfire kit")

	var island: CampIsland = world.camp_island
	var ashore: Vector2 = island.cove + (island.center - island.cove).normalized() * 14.0
	var ground := Vector3(ashore.x, island.height_at(ashore.x, ashore.y), ashore.y)
	player.teleport(ground + Vector3(2.0, 1.0, 0.0))
	await _wait(1.5)
	s.inventory.move(s.inventory.first_slot_of("campfire_kit"), 1)
	camp.request_place(1, ground, 0.0)
	_check(camp.structures.size() == 1, "placed the campfire ashore")
	if camp.structures.is_empty():
		return
	var fire_id: String = camp.structures.keys()[0]
	var station: CookStation = camp.stations["struct:" + fire_id]

	s.inventory.move(s.inventory.first_slot_of("driftwood"), 2)
	camp.interact_structure(s, fire_id, 2)
	_check(station.fuel > 0.0, "driftwood fuels the fire")
	s.inventory.slots[7] = null
	camp.interact_structure(s, fire_id, 7)
	_check(station.lit, "the lighter lights it")
	_check(camp.warmth_for(player) > 0.0, "the fire warms whoever stands near it")

	s.inventory.slots[3] = {"id": "raw_fish", "count": 1, "spoils_at": 0.0}
	s.inventory.slots[4] = {"id": "canteen_dirty", "count": 1, "spoils_at": 0.0}
	camp.interact_structure(s, fire_id, 3)
	camp.interact_structure(s, fire_id, 4)
	_check(station.is_busy() and s.inventory.slots[3] == null, "fish and dirty water go on the fire")
	await _wait(CookStation.COOK_SECONDS + 2.0)
	camp.interact_structure(s, fire_id, 7)
	_check(s.inventory.count_of("cooked_fish") == 1 and s.inventory.count_of("canteen_clean") == 1, "took cooked fish and boiled water")

	var tree: ResourceNode = null
	for node: ResourceNode in world.resources.nodes.values():
		if node.kind == "tree" and not node.depleted:
			tree = node
			break
	if tree != null:
		world.resources.harvest(s, tree.interact_id.substr(4))
		_check(s.inventory.count_of("log") == 0, "a tree can't be chopped without a hatchet")
		s.inventory.add("stone_hatchet", 1)
		world.resources.harvest(s, tree.interact_id.substr(4))
		_check(s.inventory.count_of("log") >= 2 and tree.depleted, "with a hatchet the tree falls and gives logs")

	player.teleport_aboard("Sailboat", Sailboat.BUNK_SPAWN)
	await _wait(1.0)
	GameState.day_offset = 0.92 - Ocean.time / DayNight.DAY_LENGTH
	camp.interact_boat_part(s, boat, "bunk", 0)
	_check(camp.local_asleep, "asleep in the bunk at night")
	await _wait(3.5)
	_check(DayNight.is_day(GameState.time_of_day()) and not camp.local_asleep, "the night skips to dawn when the crew sleeps")
	_check(camp.respawn_spot(player.player_id).get("kind", "") == "boat", "the bunk becomes the respawn point")

	s.inventory.slots[6] = {"id": "flint", "count": 3, "spoils_at": 0.0}
	s._request_drop(6)
	_check((camp.containers["boat:Sailboat:lockers"] as Inventory).count_of("flint") == 3, "dropping aboard stows the item in the crew lockers")

	player.teleport(ground + Vector3(-3.0, 1.0, 2.0))
	await _wait(1.5)
	var carried := 0
	for slot in s.inventory.slots:
		if slot != null:
			carried += 1
	s.survival.health = 0.0
	await _wait(1.0)
	var bag_ok := false
	for id: String in camp.bags:
		if (camp.containers["bag:" + id] as Inventory).count_of("cooked_fish") == 1:
			bag_ok = true
	_check(carried > 0 and bag_ok and s.inventory.is_empty(), "blacking out leaves the pack in a bag where you fell")
	_check(s.equipment.ids().get("vest", "") == "plate_carrier", "worn gear stays on you")
	await _wait(1.0)
	_check(player.platform is Sailboat, "you wake up in your bunk")

	world.save_now()
	var saved := SaveGame.read()
	_check(saved.get("camp", {}).get("structures", {}).size() == 1, "the save has the campfire")
	_check(not saved.get("camp", {}).get("bags", {}).is_empty(), "the save has the dropped pack")
	_check(saved.get("players", {}).has(player.player_id), "the save has the crew member's belongings by player id")


## Visual check: a row of different characters in different outfits and poses
## in front of the camera, while the local player holds a machete.
func _lineup() -> void:
	var world := GameState.world
	var player := GameState.local_player as Player
	player.survivor.inventory.slots[0] = {"id": "machete", "count": 1, "spoils_at": 0.0}
	player.survivor.select_slot(0)
	var looks := [
		{"body": 0, "build": 1, "height": 2, "skin": 2, "face": 0, "eyes": 0, "hair": 2, "hair_color": 1, "beard": 3},
		{"body": 1, "build": 0, "height": 1, "skin": 5, "face": 2, "eyes": 1, "hair": 5, "hair_color": 0, "beard": 0},
		{"body": 0, "build": 2, "height": 4, "skin": 0, "face": 1, "eyes": 2, "hair": 6, "hair_color": 5, "beard": 1},
		{"body": 1, "build": 1, "height": 2, "skin": 3, "face": 0, "eyes": 3, "hair": 4, "hair_color": 4, "beard": 0},
		{"body": 0, "build": 1, "height": 3, "skin": 6, "face": 1, "eyes": 0, "hair": 0, "hair_color": 6, "beard": 4},
	]
	var outfits: Array = CharacterCreator.OUTFITS.values()
	var poses := ["idle", "walk", "crouch", "idle", "swing"]
	# --face=portrait puts the row close enough to judge faces.
	var portrait := GameState.face == "portrait"
	var distance := 1.25 if portrait else 4.5
	var spacing := 0.62 if portrait else 1.3
	var turn := 0.12 if portrait else 0.25
	if portrait:
		player.pitch = -0.02
		player.survivor.inventory.slots[0] = null
	var at := player.world_transform()
	var forward := Vector3(-sin(player.yaw), 0.0, -cos(player.yaw))
	var right := Vector3(cos(player.yaw), 0.0, -sin(player.yaw))
	var animator := LineupAnimator.new()
	add_child(animator)
	for i in looks.size():
		var model := CharacterModel.new()
		world.add_child(model)
		model.setup(looks[i], outfits[i % outfits.size()], GameState.crew_color, GameState.emblem)
		var p: Vector3 = at.origin + forward * distance + right * (i - 2) * spacing
		var ground: float = world.ground_height(p.x, p.z)
		p.y = ground if ground != -INF else at.origin.y
		model.global_position = p
		model.rotation.y = player.yaw + PI + (i - 2) * turn
		if poses[i] == "swing":
			model.set_held("stone_hatchet")
		animator.models.append([model, poses[i]])
	print("[scenario] lineup ready")


class LineupAnimator extends Node:
	var models: Array = []
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		for entry: Array in models:
			var model: CharacterModel = entry[0]
			match entry[1]:
				"walk":
					model.animate(delta, 4.5, false, false, 0.0)
				"crouch":
					model.animate(delta, 0.0, false, true, 0.2)
				"swing":
					if fmod(_t, 1.2) < delta:
						model.swing()
					model.animate(delta, 0.0, false, false, 0.0)
				_:
					model.animate(delta, 0.0, false, false, 0.0)


## Client: open the sea chest over the network, take the knife, and check the
## host's character is visible wearing its starting clothes.
func _client_chest() -> void:
	var camp: CampSystems = GameState.world.camp
	var player := GameState.local_player as Player
	_check(player != null and player.platform is Sailboat, "the crew member spawns aboard")
	var host := GameState.world.players_root.get_node_or_null("1") as Player
	_check(host != null and host.model.visible and host.model.worn.get("torso", "") == "tshirt", "the host is visible in their starting clothes")
	_check(player.survivor.equipment.ids().has("feet"), "the crew member's own outfit arrived")
	var opened := [false]
	camp.container_opened.connect(func(_id: String, _title: String) -> void: opened[0] = true)
	GameState.world.rpc_id(1, "request_interact", "boat:Sailboat:chest", 0)
	await _wait(1.0)
	_check(opened[0] and camp.containers.has("boat:Sailboat:chest"), "the host opens the chest for a remote crew member")
	if not camp.containers.has("boat:Sailboat:chest"):
		return
	var chest: Inventory = camp.containers["boat:Sailboat:chest"]
	var knife_slot := chest.first_slot_of("knife")
	camp.rpc_id(1, "request_transfer", "boat:Sailboat:chest", true, knife_slot)
	await _wait(1.0)
	_check(player.survivor.inventory.count_of("knife") == 1, "took the knife over the network")
	_check((camp.containers["boat:Sailboat:chest"] as Inventory).count_of("knife") == 0, "everyone's view of the chest updated")
	var slot := player.survivor.inventory.first_slot_of("knife")
	player.survivor.request_drop(slot)
	await _wait(1.0)
	_check(player.survivor.inventory.count_of("knife") == 0, "dropping over the network takes it from the pack")
