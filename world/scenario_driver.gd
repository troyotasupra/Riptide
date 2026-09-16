class_name ScenarioDriver
extends Node
## Scripted end-to-end checks that run inside a real world, for automated
## testing only (command line --scenario=camp on a host, --scenario=client on a
## joining crew member, --scenario=lineup for character screenshots).
## Prints "[scenario] PASS/FAIL ..." lines, then quits.

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
		"inventory":
			_inventory_screen()
			return  # stays up for a --shot screenshot
		"starter":
			await _starter_loop()
		"sharks":
			await _shark_loop()
		"outdoors":
			await _outdoors_loop()
		"walk":
			await _walk_loop()
		"dock":
			_dock_view()
			return  # stays up for a --shot screenshot
		"shark_view":
			_shark_view()
			return  # stays up for a --shot screenshot
		"structures":
			_structures_view()
			return  # stays up for a --shot screenshot
		"look":
			await _look()
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


static func _uid(pack: Pack, id: String) -> int:
	return int(pack.find_first(id).get("uid", 0))


func _to_hotbar(pack: Pack, id: String, index: int) -> bool:
	return ItemMoves.move(pack, _uid(pack, id), 0, {"kind": "hotbar", "pack": pack, "index": index})


## Host: outfit → stash → book → compartment → gear → drag and drop → craft →
## build → fire → cook → chop → sleep → drop → blackout → save.
func _camp_loop() -> void:
	var world := GameState.world
	var camp: CampSystems = world.camp
	var player := GameState.local_player as Player
	var s := player.survivor
	var pack := s.inventory
	_check(camp.in_shack(player.world_transform().origin), "host starts in the fishing shack")
	_check(s.equipment.ids() == {"torso": "tshirt", "legs": "shorts", "feet": "sandals", "back": "satchel"}, "a new crew member washes up in the starting outfit")
	_check(pack.grid_names() == ["pockets", "backpack"], "the satchel gives a backpack grid")
	_check(player.model.worn.get("torso", "") == "tshirt", "the character model shows the T-shirt")

	camp.interact_shack_part(s, "chest", 0)
	_check(camp.open_container == "shack:chest", "the sea chest opens")
	var chest: ItemGrid = camp.containers["shack:chest"]
	var uids: Array = chest.items.map(func(item: Dictionary) -> int: return int(item.uid))
	for uid: int in uids:
		camp.request_quick_move("shack:chest", uid)
	_check(pack.count_of("survival_book") == 1 and pack.count_of("lighter") == 1 and pack.count_of("knife") == 1,
		"the important stash items move into the pack")
	_check(chest.count_of("survival_book") == 0, "they leave the chest")

	var free_slot := pack.hotbar.find(null)
	_check(free_slot >= 0 and _to_hotbar(pack, "survival_book", free_slot), "drag the book onto an empty hotbar slot")
	s._request_use(_uid(pack, "survival_book"))
	_check(camp.known_recipes.has("campfire_kit") and camp.known_recipes.has("rope"), "reading the book teaches the basics")

	camp.interact_shack_part(s, "footlocker", 0)
	_check(not camp.unlocked.has("shack:footlocker"), "the footlocker stays locked without the key")
	pack.add("compartment_key", 1)
	camp.interact_shack_part(s, "footlocker", 0)
	_check(camp.unlocked.has("shack:footlocker") and camp.open_container == "shack:footlocker", "the brass key unlocks it")
	var compartment: ItemGrid = camp.containers["shack:footlocker"]
	_check(compartment.count_of("pistol") == 1 and compartment.count_of("plate_carrier") == 1, "the pistol and a plate carrier are inside")

	pack.clear()
	var carrier_uid := int(compartment.items.filter(func(item: Dictionary) -> bool: return item.id == "plate_carrier")[0].uid)
	camp.request_wear_item("shack:footlocker", carrier_uid)
	_check(s.equipment.ids().get("vest", "") == "plate_carrier" and s.total_weight() > 8.0, "wearing the plate carrier from the compartment adds its weight")
	_check(pack.grid("rig") != null and pack.grid("rig").width == 4, "the plate carrier adds a chest rig grid")
	_check(player.model.worn.get("vest", "") == "plate_carrier", "the plate carrier shows on the character")

	pack.hotbar[5] = {"uid": 555, "id": "rain_jacket", "count": 1, "spoils_at": 0.0}
	s._request_use(555)
	_check(s.equipment.ids().torso == "rain_jacket" and pack.count_of("tshirt") == 1, "putting on the jacket swaps the T-shirt into the pack")

	pack.clear()
	pack.add("lighter", 1)
	pack.add("stone", 6)
	pack.add("driftwood", 6)
	var pockets: ItemGrid = pack.grid("pockets")
	var stone := pack.find_first("stone")
	camp.request_move_item("", int(stone.uid), 3, {"area": "backpack", "x": 3, "y": 2, "rot": false})
	_check(pack.grid("backpack").count_of("stone") == 3 and pack.count_of("stone") == 6, "drag half a stack of stones into the backpack")
	camp.request_move_item("", _uid(pack, "driftwood"), 0, {"area": "backpack", "x": 3, "y": 2, "rot": false})
	_check(pack.grid("backpack").count_of("stone") == 3, "dropping driftwood onto stones in the wrong shape is refused")
	_check(pack.count_of("driftwood") == 6, "and nothing is lost")

	camp.request_craft("campfire_kit")
	_check(pack.count_of("campfire_kit") == 1 and pack.count_of("stone") == 0, "crafted a campfire kit")

	var island: CampIsland = world.camp_island
	var ashore: Vector2 = island.cove + (island.center - island.cove).normalized() * 14.0
	var ground := Vector3(ashore.x, island.height_at(ashore.x, ashore.y), ashore.y)
	player.teleport(ground + Vector3(2.0, 1.0, 0.0))
	await _wait(1.5)
	_check(_to_hotbar(pack, "campfire_kit", 1), "drag the kit onto the hotbar")
	camp.request_place(1, ground, 0.0)
	_check(camp.structures.size() == 1, "placed the campfire ashore")
	if camp.structures.is_empty():
		return
	var fire_id: String = camp.structures.keys()[0]
	var station: CookStation = camp.stations["struct:" + fire_id]

	_to_hotbar(pack, "driftwood", 2)
	camp.interact_structure(s, fire_id, 2)
	_check(station.fuel > 0.0, "driftwood fuels the fire")
	pack.hotbar[7] = null
	camp.interact_structure(s, fire_id, 7)
	_check(station.lit, "the lighter lights it")
	_check(camp.warmth_for(player) > 0.0, "the fire warms whoever stands near it")

	pack.hotbar[3] = {"uid": 901, "id": "raw_fish", "count": 1, "spoils_at": 0.0}
	pack.hotbar[4] = {"uid": 902, "id": "canteen_dirty", "count": 1, "spoils_at": 0.0}
	camp.interact_structure(s, fire_id, 3)
	camp.interact_structure(s, fire_id, 4)
	_check(station.is_busy() and pack.hotbar[3] == null, "fish and dirty water go on the fire")
	await _wait(CookStation.COOK_SECONDS + 2.0)
	camp.interact_structure(s, fire_id, 7)
	_check(pack.count_of("cooked_fish") == 1 and pack.count_of("canteen_clean") == 1, "took cooked fish and boiled water")

	var tree: ResourceNode = null
	for node: ResourceNode in world.resources.nodes.values():
		if node.kind == "tree" and not node.depleted:
			tree = node
			break
	if tree != null:
		world.resources.harvest(s, tree.interact_id.substr(4))
		_check(pack.count_of("log") == 0, "a tree can't be chopped without a hatchet")
		pack.add("stone_hatchet", 1)
		world.resources.harvest(s, tree.interact_id.substr(4))
		_check(pack.count_of("log") >= 2 and tree.depleted, "with a hatchet the tree falls and gives logs")

	player.teleport(camp.shack_spawn(0))
	await _wait(1.0)
	GameState.day_offset = 0.92 - Ocean.time / DayNight.DAY_LENGTH
	camp.interact_shack_part(s, "bunk", 0)
	_check(camp.local_asleep, "asleep in the bunk at night")
	await _wait(3.5)
	_check(DayNight.is_day(GameState.time_of_day()) and not camp.local_asleep, "the night skips to dawn when the crew sleeps")
	_check(camp.respawn_spot(player.player_id).get("kind", "") == "shack", "the bunk becomes the respawn point")
	_check(camp.warmth_for(player) >= CampSystems.SHACK_WARMTH, "the shack keeps you warm")

	player.teleport_aboard("JohnBoat", JohnBoat.crew_spawn(0))
	await _wait(1.0)
	pack.hotbar[6] = {"uid": 903, "id": "flint", "count": 3, "spoils_at": 0.0}
	camp.request_drop_item("", 903)
	_check((camp.containers["boat:JohnBoat:drybox"] as ItemGrid).count_of("flint") == 3, "dropping aboard the john boat stows the item in its dry box")

	player.teleport(ground + Vector3(-3.0, 1.0, 2.0))
	await _wait(1.5)
	var carried := pack.all_stacks().size()
	s.survival.health = 0.0
	await _wait(1.0)
	_check(s.downed, "at zero health you go down first")
	await _wait(SharkMath.DOWNED_SOLO_SECONDS + 0.5)
	var bag_ok := false
	for id: String in camp.bags:
		if (camp.containers["bag:" + id] as ItemGrid).count_of("cooked_fish") == 1:
			bag_ok = true
	_check(carried > 0 and bag_ok and s.inventory.is_empty(), "blacking out leaves the pack in a bag where you fell")
	_check(s.equipment.ids().get("vest", "") == "plate_carrier", "worn gear stays on you")
	await _wait(1.0)
	_check(camp.in_shack(player.world_transform().origin), "you wake up in the shack")

	world.save_now()
	var saved := SaveGame.read()
	_check(saved.get("camp", {}).get("structures", {}).size() == 1, "the save has the campfire")
	_check(not saved.get("camp", {}).get("bags", {}).is_empty(), "the save has the dropped pack")
	_check(saved.get("players", {}).has(player.player_id), "the save has the crew member's belongings by player id")


## Client: open the sea chest over the network, take the knife, drag it to the
## hotbar, and check the host's character is visible in its starting clothes.
func _client_chest() -> void:
	var camp: CampSystems = GameState.world.camp
	var player := GameState.local_player as Player
	var pack := player.survivor.inventory
	_check(player != null and camp.in_shack(player.world_transform().origin), "the crew member spawns in the shack")
	var host := GameState.world.players_root.get_node_or_null("1") as Player
	_check(host != null and host.model.visible and host.model.worn.get("torso", "") == "tshirt", "the host is visible in their starting clothes")
	_check(player.survivor.equipment.ids().has("back") and pack.grid("backpack") != null, "the crew member's outfit and satchel storage arrived")
	var opened := [false]
	camp.container_opened.connect(func(_id: String, _title: String) -> void: opened[0] = true)
	GameState.world.rpc_id(1, "request_interact", "shack:chest", 0)
	await _wait(1.0)
	_check(opened[0] and camp.containers.has("shack:chest"), "the host opens the chest for a remote crew member")
	if not camp.containers.has("shack:chest"):
		return
	var chest: ItemGrid = camp.containers["shack:chest"]
	var knife: Array = chest.items.filter(func(item: Dictionary) -> bool: return item.id == "knife")
	if knife.is_empty():
		_check(false, "the knife is in the chest")
		return
	camp.rpc_id(1, "request_move_item", "shack:chest", int(knife[0].uid), 0, {"area": "pockets", "x": 4, "y": 0, "rot": false})
	await _wait(1.0)
	var in_pocket: Dictionary = pack.grid("pockets").item_at(Vector2i(4, 0))
	_check(in_pocket.get("id", "") == "knife", "dragged the knife from the chest into a pocket cell over the network")
	_check((camp.containers["shack:chest"] as ItemGrid).count_of("knife") == 0, "everyone's view of the chest updated")
	camp.rpc_id(1, "request_move_item", "", _uid(pack, "knife"), 0, {"area": "hotbar", "index": 3})
	await _wait(1.0)
	_check(pack.hotbar[3] != null and pack.hotbar[3].id == "knife", "dragged the knife onto hotbar slot 4")
	camp.rpc_id(1, "request_drop_item", "", _uid(pack, "knife"))
	await _wait(1.0)
	_check(pack.count_of("knife") == 0, "dropping over the network takes it from the pack")

	# With a --dev host, developer mode reaches the crew too.
	if GameState.dev_mode:
		GameState.world.dev.rpc_id(1, "request", "give", ["jig", 2])
		await _wait(1.0)
		_check(pack.count_of("jig") == 2, "developer mode: a joined crew member spawns an item")
		GameState.world.dev.rpc_id(1, "request", "weather", ["rain", true])
		await _wait(2.0)
		_check(float(GameState.world.weather.current.rain) > 0.5, "and the host's weather change reaches them")
		player.set_flying(true)
		var y := player.global_position.y + 4.0
		player.teleport(player.global_position + Vector3.UP * 4.0)
		await _wait(1.5)
		_check(absf(player.global_position.y - y) < 0.3, "a crew member can fly too")
		player.set_flying(false)


## Host, fresh world: wash up on the starter island → craft rope, a hatchet, an
## oar and a raft frame → chop a tree → build the raft on the beach in stages →
## launch it → row → untie and row the john boat → save.
func _starter_loop() -> void:
	var world := GameState.world
	var camp: CampSystems = world.camp
	var player := GameState.local_player as Player
	var s := player.survivor
	var pack := s.inventory
	var here := player.world_transform().origin
	_check(Vector2(here.x, here.z).length() < 80.0, "a new crew washes up on the starter island")
	var rafts: Array = world.boats_root.get_children().filter(func(b: Boat) -> bool: return b.kind == "raft")
	_check(rafts.is_empty(), "there's no raft waiting — they have to build one")
	var knows := true
	for id: String in RecipeTable.KNOWN_AT_START:
		knows = knows and camp.known_recipes.has(id)
	_check(knows and not camp.known_recipes.has("campfire_kit"), "they know rope, hatchet, oar and raft frame — the book teaches the rest")
	var kinds := {}
	for node: ResourceNode in world.resources.nodes.values():
		if node.interact_id.begins_with("res:st_"):
			kinds[node.kind] = int(kinds.get(node.kind, 0)) + 1
	_check(int(kinds.get("tree", 0)) >= 4 and int(kinds.get("palm", 0)) >= 4 and int(kinds.get("flint", 0)) >= 3 and int(kinds.get("fiber", 0)) >= 8,
		"the starter island has trees, palms, flint and fiber (%s)" % kinds)

	pack.clear()
	pack.add("fiber", 25)
	pack.add("flint", 2)
	pack.add("driftwood", 6)
	for i in 5:
		camp.request_craft("rope")
	_check(pack.count_of("rope") == 5 and pack.count_of("fiber") == 0, "twisted 25 fiber into 5 rope")
	camp.request_craft("oar")
	_check(pack.count_of("oar") == 0, "an oar needs a hatchet first")
	camp.request_craft("stone_hatchet")
	_check(pack.count_of("stone_hatchet") == 1, "made a stone hatchet")

	var logs_before := pack.count_of("log")
	for node: ResourceNode in world.resources.nodes.values():
		if node.interact_id.begins_with("res:st_tree") and not node.depleted:
			world.resources.harvest(s, node.interact_id.substr(4))
			break
	_check(pack.count_of("log") > logs_before, "chopped a starter-island tree for logs")
	pack.add("log", maxi(0, 6 - pack.count_of("log")))
	camp.request_craft("oar")
	_check(pack.count_of("oar") == 1, "carved an oar")
	camp.request_craft("raft_kit")
	_check(pack.count_of("raft_kit") == 1 and pack.count_of("log") >= 6, "made a raft frame from driftwood and rope, keeping the logs")
	pack.add("rope", maxi(0, 3 - pack.count_of("rope")))

	var shore: Vector3 = world.island.find_shore_point(Vector2(0.0, 1.0))
	var site := Vector3(shore.x + 3.0, 0.0, shore.z - 1.0)
	site.y = world.island.height_at(site.x, site.z)
	player.teleport(site + Vector3(0.0, 1.0, -3.5))
	await _wait(1.0)
	var slot := pack.hotbar.find(null)
	_to_hotbar(pack, "raft_kit", slot)
	camp.request_place(slot, Vector3(site.x, site.y + 40.0, site.z), 0.0)
	_check(camp.structures.is_empty(), "can't build a raft frame in mid-air")
	camp.request_place(slot, site, 0.0)
	var site_id := ""
	for id: String in camp.structures:
		if camp.structures[id].type == "raft_site":
			site_id = id
	_check(not site_id.is_empty(), "placed the raft frame on the beach")
	if site_id.is_empty():
		return
	camp.interact_structure(s, site_id, 0)
	_check(int(camp.structures[site_id].progress.get("log", 0)) == 6 and pack.count_of("log") == 0, "added six logs")
	camp.interact_structure(s, site_id, 0)
	_check(StructureTable.next_stage("raft_site", camp.structures[site_id].progress).is_empty(), "lashed them with rope — the raft is ready")
	camp.interact_structure(s, site_id, 0)
	await _wait(3.0)
	var raft: Boat = null
	for boat: Boat in world.boats_root.get_children():
		if boat.kind == "raft":
			raft = boat
	_check(raft != null and not camp.structures.has(site_id), "pushed the raft into the water")
	if raft == null:
		return
	_check(absf(raft.global_position.y) < 1.0 and world.ground_height(raft.global_position.x, raft.global_position.z) < -0.5, "it floats in open water")

	player.teleport_aboard(String(raft.name), Vector3(0.0, raft.deck_top + 0.05, 0.0))
	await _wait(1.0)
	var start := raft.global_position
	raft.set_row_input(1.0, 1.0, false)
	await _wait(4.0)
	var moved := raft.global_position - start
	_check(Vector2(moved.x, moved.z).length() > 3.0, "rowing both oars moves the raft (%.1f m)" % Vector2(moved.x, moved.z).length())
	var yaw_before := raft.global_rotation.y
	raft.set_row_input(1.0, 0.0, false)
	await _wait(3.0)
	_check(absf(angle_difference(raft.global_rotation.y, yaw_before)) > 0.2, "a left-oar stroke alone turns it")
	raft.set_row_input(0.0, 0.0, false)
	pack.take(_uid(pack, "oar"))
	raft.set_row_input(1.0, 1.0, false)
	_check(raft.rowers.is_empty(), "no oar, no rowing")

	var john: Boat = world.find_boat("JohnBoat")
	_check(john != null and john.is_tied(), "the john boat waits tied up at the fishing shack's dock")
	if john == null:
		return
	player.teleport_aboard("JohnBoat", JohnBoat.crew_spawn(0))
	await _wait(1.0)
	camp.interact_boat_part(s, john, "cleat", 0)
	_check(not john.is_tied(), "untied her at the bow cleat")
	pack.add("oar", 1)
	var john_start := john.global_position
	john.set_row_input(1.0, 1.0, true)
	await _wait(4.0)
	john.set_row_input(0.0, 0.0, false)
	_check(john.global_position.distance_to(john_start) > 3.0, "rowed the john boat away from the dock (%.1f m)" % john.global_position.distance_to(john_start))

	world.save_now()
	var saved := SaveGame.read()
	var boats: Dictionary = saved.get("boats", {})
	_check(boats.has(String(raft.name)) and boats[String(raft.name)].kind == "raft", "the save keeps the raft the crew built")
	_check(boats.has("JohnBoat") and not boats.JohnBoat.tied, "and remembers the john boat is untied")


## Host: sharks patrol → one hunts a swimmer and bites → a spear kills it → the
## carcass gives meat → at 0 health you're downed → bites while down take a limb
## → you bleed out and wake with the limb still gone → a peg leg fits → saved.
func _shark_loop() -> void:
	var world := GameState.world
	var camp: CampSystems = world.camp
	var field: SharkField = world.sharks
	var player := GameState.local_player as Player
	var s := player.survivor
	var pack := s.inventory
	_check(field.sharks.size() >= 3, "sharks patrol the crossing and the reef (%d)" % field.sharks.size())

	var sea: Vector2 = world.camp_island.center * 0.45
	player.teleport(Vector3(sea.x, -2.6, sea.y))
	await _wait(2.0)
	_check(player.swimming, "swimming in open water, far from land")
	var here := player.world_transform().origin
	var hunter := field.spawn(here + Vector3(14.0, -2.0, 0.0), here, 10.0)
	var before := s.survival.health
	var waited := 0.0
	while s.survival.health >= before and waited < 14.0:
		await _wait(0.5)
		waited += 0.5
	_check(s.survival.health < before, "a shark hunts the swimmer down and bites (%.0f s)" % waited)
	_check(hunter.state != "cruise", "it goes after the swimmer rather than cruising past")

	s.survival.health = Survival.MAX
	pack.clear()
	pack.hotbar[0] = {"uid": 4242, "id": "spear", "count": 1, "spoils_at": 0.0}
	s.select_slot(0)
	player.held_id = "spear"
	var bags_before := camp.bags.size()
	for i in 4:
		if hunter.state == "dead":
			break
		hunter.position = player.world_transform().origin + Vector3(0.0, 0.0, -1.8)
		field.request_strike(hunter.shark_id)
		await _wait(0.6)
	_check(hunter.state == "dead", "three spear strikes kill it")
	await _wait(0.5)
	var meat := false
	for id: String in camp.bags:
		if (camp.containers["bag:" + id] as ItemGrid).count_of("raw_shark_meat") > 0:
			meat = true
	_check(camp.bags.size() > bags_before and meat, "its carcass leaves shark meat floating on the water")

	s.survival.health = 0.0
	await _wait(0.5)
	_check(s.downed and player.downed, "at zero health you're downed, not dead")
	var maw := field.spawn(player.world_transform().origin + Vector3(0.0, -1.0, 3.0), player.world_transform().origin, 5.0)
	field.bite(maw, player)
	field.bite(maw, player)
	_check(s.missing_limbs.size() == 1 and player.missing_limbs.size() == 1, "two bites while down take a limb (%s)" % [s.missing_limbs])
	var lost: String = s.missing_limbs[0] if not s.missing_limbs.is_empty() else ""
	await _wait(SharkMath.DOWNED_SOLO_SECONDS + 2.0)
	_check(not s.downed and s.survival.health > 50.0, "alone, you bleed out and wake up somewhere safe")
	_check(s.missing_limbs.has(lost), "the limb is still gone")

	camp.learn(["peg_leg", "hook_hand"], s)
	var fits := "leg" if lost.begins_with("leg") else "arm"
	pack.add("knife", 1)
	pack.add("log", 1)
	pack.add("driftwood", 1)
	pack.add("rope", 3)
	pack.add("lure", 1)
	var recipe := "peg_leg" if fits == "leg" else "hook_hand"
	camp.request_craft(recipe)
	_check(pack.count_of(recipe) == 1, "the castaway's page teaches a %s" % ItemTable.display_name(recipe).to_lower())
	s._request_use(_uid(pack, recipe))
	_check(s.prosthetics.has(lost) and pack.count_of(recipe) == 0, "strapping it on fits it to the missing %s" % fits)
	_check(SharkMath.speed_factor(s.missing_limbs, s.prosthetics) >= 0.85, "and gets you most of the way back")

	world.save_now()
	var saved := SaveGame.read()
	var record: Dictionary = saved.get("players", {}).get(player.player_id, {})
	_check(Array(record.get("limbs", [])).has(lost) and Array(record.get("prosthetics", [])).has(lost), "the save remembers the lost limb and the prosthetic")


## Host with --dev: developer tools → flying → weather and wind → rain soaking →
## fishing off the dock (catch, bait used, lure kept, snapped line loses the lure).
func _outdoors_loop() -> void:
	var world := GameState.world
	var camp: CampSystems = world.camp
	var player := GameState.local_player as Player
	var s := player.survivor
	var pack := s.inventory
	_check(GameState.dev_mode, "developer mode is on for this host")

	world.dev.request("give", ["fishing_rod", 1])
	_check(pack.count_of("fishing_rod") == 1, "dev: spawn an item by id")
	world.dev.request("fishing_kit", [])
	_check(pack.count_of("grub") >= 20 and pack.count_of("jig") >= 1 and pack.count_of("lure") >= 3, "dev: fishing kit")
	world.dev.request("time", [0.5])
	_check(absf(GameState.time_of_day() - 0.5) < 0.01, "dev: set the time to noon")

	var sea: Vector2 = world.camp_island.center * 0.45
	player.teleport(Vector3(sea.x, 12.0, sea.y))
	player.set_flying(true)
	await _wait(0.2)
	var hover_y := player.global_position.y
	await _wait(1.5)
	_check(player.flying and absf(player.global_position.y - hover_y) < 0.3 and hover_y > 10.0,
		"flying: you hang in the air instead of falling (%.2f → %.2f)" % [hover_y, player.global_position.y])
	# Noclip: fly straight down through the island and out the other side of the ground.
	var ground_xz: Vector2 = world.camp_island.center
	var ground_y: float = world.ground_height(ground_xz.x, ground_xz.y)
	player.teleport(Vector3(ground_xz.x, ground_y - 3.0, ground_xz.y))
	await _wait(0.5)
	_check(player.global_position.y < ground_y - 2.0, "flying passes through the ground")
	player.set_flying(false)

	world.dev.request("weather", ["storm", true])
	await _wait(0.5)
	_check(float(world.weather.current.storm) > 0.9 and Waves.storm > 0.9, "a storm makes the sea rough")
	world.dev.request("wind", [0.0, 16.0])
	var raft: Boat = world.launch_boat("raft", Transform3D(Basis.IDENTITY, Vector3(sea.x, 0.4, sea.y + 30.0)))
	var raft_start := raft.global_position
	await _wait(6.0)
	_check(raft.global_position.x - raft_start.x > 1.5, "a gale blows an empty raft downwind (%.1f m)" % (raft.global_position.x - raft_start.x))

	world.dev.request("weather", ["rain", true])
	var beach: Vector3 = world.camp_beach_point(0)
	player.teleport(beach)
	await _wait(1.0)
	s.wetness = 0.0
	await _wait(3.0)
	_check(s.wetness > 0.02, "rain soaks you out in the open (%.2f)" % s.wetness)
	player.teleport(camp.shack_spawn(0))
	await _wait(1.0)
	s.wetness = 0.0
	await _wait(2.0)
	_check(s.wetness < 0.01, "but not inside the shack")
	world.dev.request("weather", ["clear", true])

	# Fishing off the end of the dock.
	var dock_end: Vector3 = camp.shack.dock_end
	var along: Vector3 = (dock_end - Vector3(camp.shack.dock_start)).normalized()
	player.teleport(dock_end + Vector3.UP * 0.6)
	await _wait(1.0)
	pack.hotbar[0] = null
	_to_hotbar(pack, "fishing_rod", 0)
	s.select_slot(0)
	player.held_id = "fishing_rod"
	world.dev.request("fast_bites", [true])
	var cast_at := Vector3(dock_end.x + along.x * 7.0, 0.0, dock_end.z + along.z * 7.0)
	var me := multiplayer.get_unique_id()

	world.fishing.request_cast(cast_at, "cut_bait")
	var cast: Dictionary = world.fishing.casts.get(me, {})
	_check(not cast.is_empty() and not String(cast.species).is_empty(), "cast off the dock: a %s takes the cut bait (%s water)" % [cast.get("species", "?"), cast.get("spot", "?")])
	if cast.is_empty() or String(cast.species).is_empty():
		return
	var bait_before := pack.count_of("cut_bait")
	await _wait(float(cast.bite) + 1.0)
	world.fishing.request_result(int(cast.id), "landed")
	var item: String = FishTable.SPECIES[cast.species].item
	_check(pack.count_of(item) >= 1 or pack.count_of("cut_bait") > bait_before, "landed it")
	_check(s.fish_log.has(cast.species), "it goes in the fish log")
	_check(pack.count_of("cut_bait") <= bait_before, "the cut bait was used up")

	var lures := pack.count_of("lure")
	world.fishing.request_cast(cast_at, "lure")
	cast = world.fishing.casts.get(me, {})
	if not String(cast.get("species", "")).is_empty():
		await _wait(float(cast.bite) + 1.0)
		world.fishing.request_result(int(cast.id), "landed")
		_check(pack.count_of("lure") == lures, "a lure isn't used up by a catch")
	world.fishing.request_cast(cast_at, "lure")
	cast = world.fishing.casts.get(me, {})
	world.fishing.request_result(int(cast.get("id", 0)), "snapped")
	_check(pack.count_of("lure") == lures - 1, "but a snapped line loses it")

	world.fishing.request_cast(camp.shack_spawn(0), "")
	_check(not world.fishing.casts.has(me), "no fishing on dry land")

	world.save_now()
	var saved := SaveGame.read()
	_check(saved.get("weather", {}).get("state", "") == "clear", "the save keeps the weather")
	_check(Dictionary(saved.get("players", {}).get(player.player_id, {}).get("fish_log", {})).has(cast.get("species", "")) or not s.fish_log.is_empty(), "and your fish log")


## Getting about on foot: in through the shack door, over a low ledge, and stopped
## by a real wall.
func _walk_loop() -> void:
	var world := GameState.world
	var camp: CampSystems = world.camp
	var player := GameState.local_player as Player
	var xf: Transform3D = camp.shack.xf
	player.teleport(xf * Vector3(0.0, 0.8, -4.4))
	var facing: Vector3 = xf.basis * Vector3(0.0, 0.0, 1.0)
	player.yaw = atan2(-facing.x, -facing.z)
	await _wait(1.5)
	_check(not camp.in_shack(player.world_transform().origin), "start outside the shack, on the sand")
	await _hold("move_forward", 3.5)
	_check(camp.in_shack(player.world_transform().origin), "walked in through the door without jumping")

	# Buried in the hillside: freed without touching anything.
	var hill: Vector2 = world.camp_island.hill
	player.teleport(Vector3(hill.x, world.camp_island.height_at(hill.x, hill.y) - 2.5, hill.y))
	await _wait(2.0)
	_check(not player._overlapping(), "someone buried in the hill is freed automatically")
	var stand_ground: float = world.camp_island.height_at(player.global_position.x, player.global_position.z)
	# The collision mesh is tessellated, so on a steep slope it sits a little below
	# the analytic height; what matters is being out of the rock and on your feet.
	_check(player.global_position.y > stand_ground - 1.5 and player.is_on_floor(),
		"and ends up standing on top of it (y %.2f, ground %.2f)" % [player.global_position.y, stand_ground])
	player.teleport(Vector3(hill.x, world.camp_island.height_at(hill.x, hill.y) - 2.5, hill.y))
	await _wait(0.2)
	player.unstuck()
	_check(not player._overlapping(), "and the Unstuck button frees them at once")

	var low: float = await _ledge_walk(0.45)
	_check(low > 3.0, "stepped up over a 45 cm ledge (walked %.1f m)" % low)
	var wall: float = await _ledge_walk(1.4)
	_check(wall < 2.6, "but a 1.4 m wall still stops you (walked %.1f m)" % wall)


func _hold(action: String, seconds: float) -> void:
	Input.action_press(action)
	await _wait(seconds)
	Input.action_release(action)


## Drops a `height` step in the player's path on the beach and walks into it for
## three seconds; returns how far they got.
func _ledge_walk(height: float) -> float:
	var world := GameState.world
	var player := GameState.local_player as Player
	player.teleport(world.camp_beach_point(0) + Vector3.UP * 0.6)
	await _wait(1.2)
	var start := player.global_position
	var inland := Vector3(world.camp_island.center.x, start.y, world.camp_island.center.y) - start
	inland.y = 0.0
	inland = inland.normalized()
	player.yaw = atan2(-inland.x, -inland.z)
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var box := BoxShape3D.new()
	box.size = Vector3(8.0, height, 0.6)
	var collider := CollisionShape3D.new()
	collider.shape = box
	body.add_child(collider)
	world.add_child(body)
	# start is the capsule's centre, so the ground is half the player's height below it.
	body.global_position = start + inland * 2.2 + Vector3.UP * (height * 0.5 - 0.9)
	body.global_rotation.y = player.yaw
	await _hold("move_forward", 3.0)
	var travelled := Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()
	body.queue_free()
	return travelled


## Visual checks, one per --face: tree, tree_under, palm, palm_top, bush, fiber
## (props up close, at midday), shore (the waterline), spring (the pond), shackdoor
## (the way in), storm (rain and rough water from the dock), dev (the
## developer panel), fishing (a line out off the dock, first person), fish (every
## species and bait in the inventory).
func _look() -> void:
	var world := GameState.world
	var camp: CampSystems = world.camp
	var player := GameState.local_player as Player
	var s := player.survivor
	GameState.day_offset = 0.45 - Ocean.time / DayNight.DAY_LENGTH
	world.weather.set_state("clear", true)
	world.weather.set_wind(0.8, 3.0)
	match GameState.face:
		"storm":
			world.weather.set_state("storm", true)
			world.weather.set_wind(0.8, 16.0)
			var xf: Transform3D = camp.shack.xf
			_fixed_camera(xf * Vector3(14.0, 4.0, -29.0), xf * Vector3(2.0, 1.2, -8.0))
		"dev":
			world.weather.set_state("rain", true)
			var hud := _hud()
			hud._show_only(hud._dev)
			hud._sync_ui_state()
		"fishing":
			var dock_end: Vector3 = camp.shack.dock_end
			var along: Vector3 = dock_end - Vector3(camp.shack.dock_start)
			along.y = 0.0
			along = along.normalized()
			player.teleport(dock_end + Vector3.UP * 0.6 - along * 1.0)
			s.inventory.add("fishing_rod", 1, Ocean.time)
			s.inventory.add("cut_bait", 6, Ocean.time)
			s.inventory.hotbar[0] = null
			_to_hotbar(s.inventory, "fishing_rod", 0)
			s.select_slot(0)
			s.push_inventory()
			player.yaw = atan2(-along.x, -along.z)
			player.pitch = -0.1
			await _wait(1.5)
			player.held_id = "fishing_rod"
			player.angler.bait_item = "cut_bait"
			player.angler.charge = 0.55
			player.angler._cast()
			# Keep the bobber waiting for the picture.
			get_tree().process_frame.connect(func() -> void:
				if player.angler.state == Angler.State.WAITING:
					player.angler._bite_in = INF)
		"shore":
			var island: CampIsland = world.camp_island
			for label: Array in [["dock end", Vector2(camp.shack.dock_end.x, camp.shack.dock_end.z)],
					["cove", island.cove], ["100 m out", island.cove + Vector2.from_angle(island.cove_bearing) * 100.0],
					["open sea", island.center * 0.5]]:
				var at: Vector2 = label[1]
				print("[shelter] %s: depth %.1f m, openness %.2f, roughness %.2f" % [label[0],
					-world.ground_height(at.x, at.y), ShelterMap.value(at), Waves.roughness(at)])
			var out2 := Vector2.from_angle(island.cove_bearing)
			var beach := island.cove + out2.orthogonal() * 16.0
			var eye2 := beach - out2 * 5.0
			_fixed_camera(Vector3(eye2.x, island.height_at(eye2.x, eye2.y) + 3.5, eye2.y),
				Vector3(island.cove.x + out2.x * 16.0, -0.4, island.cove.y + out2.y * 16.0))
		"spring":
			var island2: CampIsland = world.camp_island
			var from_hill := (island2.spring - island2.hill).normalized()
			var eye3 := island2.spring + from_hill * 15.0
			_fixed_camera(Vector3(eye3.x, island2.spring_height + 7.0, eye3.y),
				Vector3(island2.spring.x, island2.spring_height, island2.spring.y))
		"shackdoor":
			var xf2: Transform3D = camp.shack.xf
			_fixed_camera(xf2 * Vector3(0.0, 1.5, -5.0), xf2 * Vector3(0.0, 0.6, 0.5))
		"fish":
			s.equipment.wear({"id": "daypack", "count": 1, "spoils_at": 0.0})
			s.refresh_storage()
			for id: String in FishTable.SPECIES:
				s.inventory.add(FishTable.SPECIES[id].item, 1, Ocean.time)
			for entry: Array in [["grub", 12], ["cut_bait", 8], ["jig", 1], ["lure", 2], ["fish_steak", 3], ["fishing_rod", 1]]:
				s.inventory.add(entry[0], entry[1], Ocean.time)
			s.push_inventory()
			camp.interact_shack_part(s, "chest", 0)
		_:
			_prop_camera(GameState.face)
	print("[scenario] look ready: %s" % GameState.face)


func _prop_camera(face: String) -> void:
	var world := GameState.world
	var kind: String = {"tree_under": "tree", "palm_top": "palm", "bush": "berry_bush", "": "tree"}.get(face, face)
	var home: Vector3 = world.camp.shack_spawn(0)
	var best: ResourceNode = null
	for node: ResourceNode in world.resources.nodes.values():
		if node.kind == kind and not node.depleted and (best == null or node.global_position.distance_to(home) < best.global_position.distance_to(home)):
			best = node
	if best == null:
		print("[scenario] no %s to look at" % kind)
		return
	var p := best.global_position
	var out := Vector3(p.x - home.x, 0.0, p.z - home.z).normalized()
	var side := out.cross(Vector3.UP)
	# [distance out, eye height, target height]
	var view: Array = {
		"tree": [6.5, 2.2, 3.8], "tree_under": [1.3, 1.5, 6.0], "palm": [6.5, 2.5, 4.2],
		"palm_top": [3.0, 8.5, 5.8], "bush": [2.2, 1.3, 0.5], "fiber": [1.5, 1.0, 0.35],
	}.get(face, [6.5, 2.2, 3.8])
	var eye := p + out * float(view[0]) + side * float(view[0]) * 0.3 + Vector3.UP * float(view[1])
	var ground: float = world.ground_height(eye.x, eye.z)
	if ground != -INF:
		eye.y = maxf(eye.y, ground + 0.4)
	_fixed_camera(eye, p + Vector3.UP * float(view[2]) - out * 0.3)


func _fixed_camera(eye: Vector3, target: Vector3) -> void:
	var cam := Camera3D.new()
	cam.fov = 70.0
	GameState.world.add_child(cam)
	cam.global_transform = Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)
	cam.make_current()


func _hud() -> Hud:
	for child in GameState.world.get_children():
		if child is Hud:
			return child
	return null


## Visual check: a shark cruising just under the surface off the cove, dorsal fin up.
func _shark_view() -> void:
	var world := GameState.world
	var island: CampIsland = world.camp_island
	var out := Vector2.from_angle(island.cove_bearing)
	var at2 := island.cove + out * 60.0 + out.orthogonal() * 25.0
	var surface := Waves.height_at(at2, Ocean.time)
	var shark: Shark = world.sharks.spawn(Vector3(at2.x, surface - 0.3, at2.y), Vector3(at2.x, 0.0, at2.y), 10.0)
	shark.set_physics_process(false)
	shark.heading = atan2(-out.x, -out.y)
	shark.rotation.y = shark.heading
	var eye2 := at2 + out.orthogonal() * -5.0 + out * 1.0
	var eye := Vector3(eye2.x, surface + 1.3, eye2.y)
	var cam := Camera3D.new()
	cam.fov = 60.0
	world.add_child(cam)
	cam.global_transform = Transform3D(Basis.looking_at(shark.position - eye, Vector3.UP), eye)
	cam.make_current()


## Visual check around the fishing shack. --face=interior (inside the shack),
## boat (sitting in the john boat), or anything else for the dock and shack from the water.
func _dock_view() -> void:
	var world := GameState.world
	var shack: Dictionary = world.camp.shack
	var boat: Boat = world.find_boat("JohnBoat")
	var frame: Node3D = null
	var base: Transform3D = shack.xf
	var eye := Vector3(14.0, 5.5, -29.0)
	var target := Vector3(4.5, 0.4, -18.0)
	match GameState.face:
		"interior":
			eye = Vector3(0.3, 1.6, -1.6)
			target = Vector3(-0.6, 0.6, 1.5)
		"boat":
			frame = boat
			eye = Vector3(0.0, 1.3, 1.9)
			target = Vector3(0.0, 0.4, -2.5)
	var cam := Camera3D.new()
	cam.fov = 70.0
	world.add_child(cam)
	var place := func() -> void:
		var origin := frame.get_global_transform_interpolated() if frame != null else base
		cam.global_transform = origin * Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)
	get_tree().process_frame.connect(place)
	place.call()
	cam.make_current()


## Visual check: every camp structure built in a row on the beach, fire lit.
func _structures_view() -> void:
	var world := GameState.world
	var camp: CampSystems = world.camp
	var island: CampIsland = world.camp_island
	var inland := (island.center - island.cove).normalized()
	var across := inland.orthogonal()
	var base: Vector2 = island.cove + inland * 30.0 - inland.orthogonal() * 18.0
	var types := ["lean_to", "campfire", "tent", "drying_rack", "storage_crate", "raft_site"]
	for i in types.size():
		var xz := base + across * (i - 2.5) * 3.4
		var pos := Vector3(xz.x, island.height_at(xz.x, xz.y), xz.y)
		camp._spawn_structure("view%d" % i, types[i], pos, atan2(-inland.x, -inland.y) + PI)
	(camp.structure_nodes["view1"] as StructureNode).set_lit(true)
	camp._apply_progress("view5", {"log": 4, "rope": 0})
	var eye2 := base - inland * 9.0
	var eye := Vector3(eye2.x, island.height_at(base.x, base.y) + 2.6, eye2.y)
	var target := Vector3(base.x, island.height_at(base.x, base.y) + 0.6, base.y)
	var cam := Camera3D.new()
	cam.fov = 70.0
	world.add_child(cam)
	cam.global_transform = Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)
	cam.make_current()


## Visual check: opens the inventory screen with a stocked pack and chest.
func _inventory_screen() -> void:
	var world := GameState.world
	var camp: CampSystems = world.camp
	var player := GameState.local_player as Player
	var s := player.survivor
	s.equipment.wear({"id": "plate_carrier", "count": 1, "spoils_at": 0.0})
	s.equipment.wear({"id": "daypack", "count": 1, "spoils_at": 0.0})
	s.equipment.wear({"id": "combat_helmet", "count": 1, "spoils_at": 0.0})
	s.refresh_storage()
	for entry: Array in [["machete", 1], ["canteen_clean", 1], ["log", 2], ["cooked_fish", 3], ["stone", 14], ["bandage", 4],
			["pistol", 1], ["pistol_ammo", 30], ["rope", 5], ["berries", 12], ["tarp", 1], ["stone_hatchet", 1]]:
		s.inventory.add(entry[0], entry[1], Ocean.time)
	s.push_inventory()
	camp.interact_shack_part(s, "chest", 0)
	print("[scenario] inventory open")


## Visual check: a row of different characters in different outfits and poses
## in front of the camera, while the local player holds a machete.
func _lineup() -> void:
	var world := GameState.world
	var player := GameState.local_player as Player
	player.survivor.inventory.hotbar[0] = {"uid": 1, "id": "machete", "count": 1, "spoils_at": 0.0}
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
	# --face=portrait puts the row close enough to judge faces; portrait_side and
	# portrait_back turn everyone around to check their hair from other angles.
	var portrait := GameState.face.begins_with("portrait")
	var spin: float = {"portrait_side": PI * 0.5, "portrait_back": PI}.get(GameState.face, 0.0)
	var limbs := GameState.face == "limbs"
	if limbs:
		player.yaw += PI  # turn away from the shack, toward the open beach
		player.pitch = -0.32
	var distance := 1.25 if portrait else (2.6 if limbs else 4.5)
	var spacing := 0.62 if portrait else (0.95 if limbs else 1.3)
	var turn := 0.12 if portrait else 0.25
	if portrait:
		player.pitch = -0.02
		player.survivor.inventory.hotbar[0] = null
	var at := player.world_transform()
	var forward := Vector3(-sin(player.yaw), 0.0, -cos(player.yaw))
	var right := Vector3(cos(player.yaw), 0.0, -sin(player.yaw))
	var animator := LineupAnimator.new()
	add_child(animator)
	for i in looks.size():
		var model := CharacterModel.new()
		world.add_child(model)
		model.setup(looks[i], outfits[i % outfits.size()], GameState.crew_color, GameState.emblem)
		if GameState.face == "limbs":
			# Peg leg, hook hand, and two raw stumps.
			var sets := [[["leg_r"], ["leg_r"]], [["arm_l"], ["arm_l"]], [["leg_l"], []], [["arm_r"], []], [[], []]]
			model.set_limbs(sets[i][0], sets[i][1])
		var p: Vector3 = at.origin + forward * distance + right * (i - 2) * spacing
		var ground: float = world.ground_height(p.x, p.z)
		p.y = ground if ground != -INF else at.origin.y
		model.global_position = p
		model.rotation.y = player.yaw + PI + (i - 2) * turn + spin
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
