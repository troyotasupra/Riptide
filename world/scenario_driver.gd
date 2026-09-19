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
		"guns":
			await _gun_loop()
		"gear":
			await _gear_loop()
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
		"tour":
			var tour := ScenarioTour.new()
			add_child(tour)
			await tour.run()
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


## Somewhere properly deep between the islands (the worlds are random, so look).
static func _deep_water(world: Node, deepest: float = -INF) -> Vector2:
	var center: Vector2 = world.camp_island.center
	for k in 80:
		var probe: Vector2 = center * (0.62 + 0.004 * k) + Vector2.from_angle(k * 0.7) * 20.0
		# Deep, but in the island's lee: the open ocean's swell lifts a swimmer in and
		# out of the water between checks.
		var depth: float = world.ground_height(probe.x, probe.y)
		if depth != -INF and depth < -8.0 and depth > deepest:
			return probe
	return center * 0.45


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
	_check(compartment.count_of("m1911") == 1 and compartment.count_of("plate_carrier") == 1, "the pistol and a plate carrier are inside")

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
	_check(pack.count_of("campfire_kit") == 1 and pack.count_of("stone") == 4, "crafted a campfire ring from two stones")

	var island: CampIsland = world.camp_island
	var ashore: Vector2 = island.cove + (island.center - island.cove).normalized() * 14.0
	var ground := Vector3(ashore.x, island.height_at(ashore.x, ashore.y), ashore.y)
	player.teleport(ground + Vector3(2.0, 1.0, 0.0))
	await _wait(1.5)
	_check(_to_hotbar(pack, "campfire_kit", 1), "drag the kit onto the hotbar")
	_check(camp.structures.has(CampSystems.CASTAWAY_TENT), "the castaway's old tent stands at their camp")
	var before := camp.structures.size()
	var warmth_before := camp.warmth_for(player)
	camp.request_place(1, ground, 0.0)
	_check(camp.structures.size() == before + 1, "placed the campfire ring ashore")
	var fire_id := ""
	for id: String in camp.structures:
		if camp.structures[id].type == "campfire":
			fire_id = id
	if fire_id.is_empty():
		return
	var station: CookStation = camp.stations["struct:" + fire_id]
	# The ring goes up in stages: the rest of the stones, then the wood.
	_to_hotbar(pack, "stone", 5)
	camp.interact_structure(s, fire_id, 5)
	camp.interact_structure(s, fire_id, 2)
	_check(StructureTable.is_finished("campfire", camp.structures[fire_id].get("progress", {})), "stones and wood finish the campfire (%s)" % [camp.structures[fire_id].get("progress", {})])
	_check(camp.warmth_for(player) == warmth_before, "an unlit fire gives no warmth")

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
	var opened := [""]
	camp.cooking_opened.connect(func(station_id: String, _title: String) -> void: opened[0] = station_id)
	pack.hotbar[7] = null
	camp.interact_structure(s, fire_id, 7)
	_check(opened[0] == "struct:" + fire_id, "pressing on the fire empty-handed opens what's cooking")
	await _wait(CookStation.COOK_SECONDS + 2.0)
	camp.request_take_cooked("struct:" + fire_id, 0)
	_check(pack.count_of("cooked_fish") + pack.count_of("canteen_clean") == 1, "took one thing off the fire on its own")
	camp.request_take_cooked("struct:" + fire_id, -1)
	_check(pack.count_of("cooked_fish") == 1 and pack.count_of("canteen_clean") == 1, "and the rest with one press")

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

	# A tent goes up in stages, then comes apart again for most of its materials.
	pack.clear()
	pack.add("tent_kit", 1)
	pack.add("tarp", 1)
	pack.add("rope", 3)
	player.teleport(ground + Vector3(8.0, 1.0, 6.0))
	await _wait(1.0)
	_to_hotbar(pack, "tent_kit", 0)
	# The first dry spot within reach, clear of everything built so far.
	var stand := player.world_transform().origin
	var tent_id := ""
	for k in 16:
		var tent_at := stand + Vector3(cos(k * 0.9), 0.0, sin(k * 0.9)) * (3.5 + (k % 3))
		tent_at.y = world.ground_height(tent_at.x, tent_at.z)
		camp.request_place(0, tent_at, 0.0)
		for id: String in camp.structures:
			if camp.structures[id].type == "tent" and id != CampSystems.CASTAWAY_TENT:
				tent_id = id
		if not tent_id.is_empty():
			break
	_check(not tent_id.is_empty(), "pitched a tent frame")
	if not tent_id.is_empty():
		camp.interact_structure(s, tent_id, 0)
		camp.interact_structure(s, tent_id, 0)
		_check(StructureTable.is_finished("tent", camp.structures[tent_id].get("progress", {})), "canvas and guy lines finish the tent")
		camp.request_dismantle_start(tent_id)
		await _wait(StructureTable.DISMANTLE_SECONDS + 0.2)
		camp.request_dismantle(tent_id)
		_check(not camp.structures.has(tent_id), "held the dismantle key: the tent comes down")
		_check(pack.count_of("tarp") == 1 and pack.count_of("rope") == 3 and pack.count_of("driftwood") == 3,
			"and most of it comes back (tarp %d, rope %d, wood %d)" % [pack.count_of("tarp"), pack.count_of("rope"), pack.count_of("driftwood")])

	# Fire: light the grass beside a crate and it spreads, burns the crate down, and hurts.
	var fire: FireService = world.fire
	var meadow := Vector2.INF
	for attempt in 400:
		var probe: Vector2 = island.center + Vector2.from_angle(attempt * 2.39) * (30.0 + attempt * 0.4)
		var h := island.height_at(probe.x, probe.y)
		if island.biome_at(probe.x, probe.y, h) in [CampIsland.Biome.MEADOW, CampIsland.Biome.JUNGLE] and fire.grid.fuel(FireGrid.cell_of(probe)) > 0.6:
			meadow = probe
			break
	_check(meadow != Vector2.INF, "found dry grass to burn")
	if meadow != Vector2.INF:
		var crate_at := Vector3(meadow.x + 2.0, island.height_at(meadow.x + 2.0, meadow.y), meadow.y)
		camp._spawn_structure("s_firetest", "storage_crate", crate_at, 0.0)
		world.weather.set_state("clear", true)
		world.weather.set_wind(0.0, 8.0)
		_check(fire.ignite_at(Vector3(meadow.x, 0.0, meadow.y)), "the grass catches")
		await _wait(8.0)
		_check(fire.grid.burning.size() + fire.grid.burnt.size() > 3, "the fire spreads (%d burning, %d burnt)" % [fire.grid.burning.size(), fire.grid.burnt.size()])
		_check(fire.burning_cells.size() > 0 or fire.burnt_cells.size() > 0, "and everyone is told where it's burning")
		player.teleport(Vector3(meadow.x, island.height_at(meadow.x, meadow.y) + 0.5, meadow.y))
		var health_before := s.survival.health
		# Stand in whichever cell has the longest left to burn.
		var fires_near := false
		var hottest := Vector2i.ZERO
		for cell: Vector2i in fire.grid.burning:
			if not fires_near or float(fire.grid.burning[cell]) > float(fire.grid.burning[hottest]):
				hottest = cell
				fires_near = true
		if fires_near:
			var c := FireGrid.center_of(hottest)
			player.teleport(Vector3(c.x, island.height_at(c.x, c.y) + 0.3, c.y))
		await _wait(1.0)
		if fires_near:
			_check(s.survival.health < health_before, "standing in the fire burns you")
		await _wait(26.0)
		_check(not camp.structures.has("s_firetest"), "the crate beside it burned down")
		world.weather.set_state("storm", true)
		await _wait(8.0)
		_check(fire.grid.burning.size() == 0, "the rain puts it out (%d still burning)" % fire.grid.burning.size())
		world.weather.set_state("clear", true)

	world.save_now()
	var saved := SaveGame.read()
	var saved_types: Array = saved.get("camp", {}).get("structures", {}).values().map(func(e: Dictionary) -> String: return e.type)
	_check(saved_types.has("campfire"), "the save has the campfire")
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

	# A stretch of beach low enough, with open water close by (worlds differ, so look round).
	var site := Vector3.ZERO
	for k in 24:
		var shore: Vector3 = world.island.find_shore_point(Vector2.from_angle(PI * 0.5 + k * 0.26))
		var inland := -Vector3(shore.x, 0.0, shore.z).normalized()
		var probe := shore + inland * 3.0
		probe.y = world.island.height_at(probe.x, probe.z)
		if probe.y > 0.35 and probe.y < StructureTable.SHORE_MAX_HEIGHT and not world.water_spot(probe).is_empty():
			site = probe
			break
	player.teleport(site + Vector3(0.0, 1.0, -3.5))
	await _wait(1.0)
	var slot := pack.hotbar.find(null)
	_to_hotbar(pack, "raft_kit", slot)
	camp.request_place(slot, Vector3(site.x, site.y + 40.0, site.z), 0.0)
	# The castaway's tent is always there, so look for a raft site rather than for nothing.
	var floating := false
	for id: String in camp.structures:
		floating = floating or camp.structures[id].type == "raft_site"
	_check(not floating, "can't build a raft frame in mid-air")
	player.teleport(site + Vector3(0.0, 1.0, 0.0))
	await _wait(0.5)
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
	await _wait(6.0)  # it slides down the sand into the water
	var raft: Boat = null
	for boat: Boat in world.boats_root.get_children():
		if boat.kind == "raft":
			raft = boat
	_check(raft != null and not camp.structures.has(site_id), "pushed the raft into the water")
	if raft == null:
		return
	_check(absf(raft.global_position.y) < 1.0 and world.ground_height(raft.global_position.x, raft.global_position.z) < -0.5, "it floats in open water")

	_check(raft.oars_fitted and pack.count_of("oar") == 0, "the oars went into the raft's oarlocks when it was launched")
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
	camp.interact_boat_part(s, raft, "oars", 0)
	_check(not raft.oars_fitted and pack.count_of("oar") == 1, "took the oars out of the raft (the key)")
	raft.set_row_input(1.0, 1.0, false)
	_check(raft.rowers.is_empty(), "no oars, no rowing")

	var john: Boat = world.find_boat("JohnBoat")
	_check(john != null and john.is_tied(), "the john boat waits tied up at the fishing shack's dock")
	if john == null:
		return
	player.teleport_aboard("JohnBoat", JohnBoat.crew_spawn(0))
	await _wait(1.0)
	camp.interact_boat_part(s, john, "cleat", 0)
	_check(not john.is_tied(), "untied her at the bow cleat")
	_check(john.oars_fitted, "her own oars are in her oarlocks")
	var john_start := john.global_position
	john.set_row_input(1.0, 1.0, true)
	await _wait(5.0)
	john.set_row_input(0.0, 0.0, false)
	_check(john.global_position.distance_to(john_start) > 3.0, "rowed the john boat away from the dock (%.1f m)" % john.global_position.distance_to(john_start))

	# Out in open water, heading away from land, for the motor and the tow.
	var open_sea := _deep_water(world)
	var away := Vector3(open_sea.x - world.camp_island.center.x, 0.0, open_sea.y - world.camp_island.center.y).normalized()
	john.global_transform = Transform3D(Basis.looking_at(away, Vector3.UP), Vector3(open_sea.x, 0.0, open_sea.y))
	john.linear_velocity = Vector3.ZERO
	john.angular_velocity = Vector3.ZERO
	await _wait(1.0)
	# The outboard from the cave, fuel from a drum, and a spin at the helm.
	pack.add("outboard_motor", 1)
	camp.interact_boat_part(s, john, "transom", 0)
	_check(john.motor_fitted and pack.count_of("outboard_motor") == 0, "clamped the outboard onto the transom")
	pack.add("fuel_drum", 1)
	camp.interact_boat_part(s, john, "transom", 0)
	_check(john.fuel > 11.0 and pack.find_first("fuel_drum").get("fuel", 0.0) > 7.0, "poured a drum into the tank, and some's left in it (%.1f L)" % john.fuel)
	var motor_start := john.global_position
	john.set_motor_input(1.0, 0.0)
	await _wait(5.0)
	var fuel_after := john.fuel
	john.set_motor_input(0.0, 0.0)
	_check(john.global_position.distance_to(motor_start) > 8.0, "under power she goes (%.1f m in 5 s)" % john.global_position.distance_to(motor_start))
	_check(fuel_after < 12.0, "and burns fuel doing it (%.2f L)" % fuel_after)
	# Take the raft in tow: bring it up astern and make the line fast.
	raft.global_transform = Transform3D(john.global_transform.basis, john.global_transform * Vector3(0.0, 0.0, 5.0))
	raft.linear_velocity = Vector3.ZERO
	await _wait(0.3)
	camp.interact_boat_part(s, john, "tow", 0)
	_check(john.tow_target == raft, "took the raft in tow")
	var raft_start := raft.global_position
	john.set_motor_input(1.0, 0.0)
	await _wait(6.0)
	john.set_motor_input(0.0, 0.0)
	_check(raft.global_position.distance_to(raft_start) > 6.0, "and it follows on the line (%.1f m)" % raft.global_position.distance_to(raft_start))

	world.save_now()
	var saved := SaveGame.read()
	var boats: Dictionary = saved.get("boats", {})
	_check(boats.has(String(raft.name)) and boats[String(raft.name)].kind == "raft", "the save keeps the raft the crew built")
	_check(boats.has("JohnBoat") and not boats.JohnBoat.tied, "and remembers the john boat is untied")
	_check(bool(boats.JohnBoat.get("motor", false)) and String(boats.JohnBoat.get("tow", "")) == String(raft.name), "and her motor and tow")


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

	var sea := _deep_water(world)
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
	_check(s.fish_log.has(cast.species), "landed it, and it goes in the fish log")
	_check(pack.count_of("cut_bait") <= bait_before, "the cut bait was used up")
	var fish: LandedFish = null
	for entry: LandedFish in world.fishing.landed.values():
		fish = entry
		break
	_check(fish != null and fish.alive, "it's flopping on the dock, still alive")
	if fish != null:
		var fish_at := player.world_transform().origin
		world.fishing.interact_landed(s, fish.fish_id, fish_at)
		_check(not fish.alive, "first go kills it")
		_check(pack.count_of(item) == 0, "it isn't in your pack until you pick it up")
		world.fishing.interact_landed(s, fish.fish_id, fish_at)
		_check(pack.count_of(item) >= 1, "second go takes it")
		_check(world.fishing.landed.is_empty(), "and it's gone from the dock")

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


## Shooting: the kit, the fire rate, real bullets that take time to arrive,
## reloading, fire modes, attachments, fouling and jams.
func _gun_loop() -> void:
	var world := GameState.world
	var player := GameState.local_player as Player
	var s := player.survivor
	var pack := s.inventory
	_check(GameState.dev_mode, "developer mode is on for this host")
	s.equipment.wear({"id": "daypack", "count": 1, "spoils_at": 0.0})
	s.refresh_storage()
	for wanted: Array in [["m4", 1], ["m1911", 1], ["ammo_556", 60], ["ammo_45", 14],
			["suppressor", 1], ["sniper_scope", 1], ["cleaning_kit", 1]]:
		world.dev.request("give", [wanted[0], wanted[1]])
	_check(pack.count_of("m4") == 1 and pack.count_of("ammo_556") >= 60, "dev: a rifle, a pistol and ammunition")

	# Out over open water, where a shark can be put in front of us.
	var sea: Vector2 = world.camp_island.center * 0.5
	player.teleport(Vector3(sea.x, 14.0, sea.y))
	player.set_flying(true)
	await _wait(1.0)

	pack.hotbar[0] = null
	_to_hotbar(pack, "m4", 0)
	s.select_slot(0)
	player.held_id = "m4"
	await _wait(0.3)
	var rifle: Dictionary = CombatService.held_gun(player)
	_check(not rifle.is_empty(), "the M4 is in hand")
	if rifle.is_empty():
		return
	var state := CombatService.gun_state(rifle)
	_check(int(state.ammo) == 30 and int(state.mag) == 30, "it came loaded: %d/%d" % [state.ammo, state.mag])
	_check(String(state.mode) == "auto" and String(state.round) == "ammo_556", "on automatic, eating 5.56")

	# A shark ten metres ahead, at eye level, and a shot into it.
	var ahead := Vector3(0.0, 0.0, -1.0)
	player.yaw = 0.0
	player.pitch = 0.0
	var shark_at := Vector3(sea.x, -0.5, sea.y)
	var shark: Shark = world.sharks.spawn(shark_at, shark_at, 6.0)
	shark.set_physics_process(false)
	await _wait(0.3)
	# Stand off ten metres with the sights level with it.
	player.teleport(shark.global_position - ahead * 10.0 - Vector3.UP * Player.EYE_HEIGHT)
	await _wait(0.4)
	var before: float = shark.health
	world.combat.request_shot(ahead, 1.0)
	await _wait(0.4)
	_check(shark.health < before, "a shot hits a shark ten metres out (%.0f → %.0f)" % [before, shark.health])
	_check(int(rifle.get("ammo", 0)) == 29, "and costs one round (%d left)" % int(rifle.get("ammo", 0)))

	world.combat.request_shot(ahead, 1.0)
	world.combat.request_shot(ahead, 1.0)
	_check(int(rifle.get("ammo", 0)) == 28, "the rate of fire won't let you spam the trigger")

	# The real trigger: a left click through the player's own input handling.
	await _wait(0.3)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var was_free := GameState.free_mouse
	GameState.free_mouse = true  # the test window never has the mouse captured
	player._unhandled_input(click)
	var release := click.duplicate()
	release.pressed = false
	player._unhandled_input(release)
	GameState.free_mouse = was_free
	await _wait(0.3)
	_check(int(rifle.get("ammo", 0)) == 27, "a left click fires the gun in hand (%d left)" % int(rifle.get("ammo", 0)))

	# Out of the way, so it can't soak up the next shot.
	world.sharks.sharks.erase(shark.shark_id)
	shark.queue_free()
	await _wait(0.3)

	# A bullet is not instant: a shark 200 m out is hit a moment later.
	# Along a line of open sea: on some worlds an island sits in the way straight ahead.
	var clear := ahead
	for turn in 16:
		var dir := ahead.rotated(Vector3.UP, turn * TAU / 16.0)
		var open := true
		for k in 21:
			var p := player.global_position + dir * (k * 10.0)
			var ground: float = world.ground_height(p.x, p.z)
			open = open and (ground == -INF or ground < -2.0)
		if open:
			clear = dir
			break
	# A few metres up, so a shot from someone swimming doesn't skim into the swell.
	var far_at := player.global_position + clear * 200.0 + Vector3.UP * (Player.EYE_HEIGHT + 3.0)
	var far_shark: Shark = world.sharks.spawn(far_at, far_at, 6.0)
	far_shark.set_physics_process(false)
	await _wait(0.5)
	var far_before: float = far_shark.health
	# Aim at it rather than assuming it sits exactly on the sight line.
	var eye := player.world_transform().origin + Vector3.UP * Player.EYE_HEIGHT
	var at_far := (far_shark.global_position - eye).normalized()
	world.combat.request_shot(at_far, 1.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(far_shark.health == far_before, "a 200 m shot hasn't arrived after two frames")
	await _wait(0.8)
	# Aimed spread still wanders ~0.5 m at 200 m, so give it a few rounds to connect.
	for retry in 3:
		if far_shark.health < far_before:
			break
		world.combat.request_shot(at_far, 1.0)
		await _wait(0.9)
	_check(far_shark.health < far_before, "but it gets there (%.0f → %.0f)" % [far_before, far_shark.health])

	# Empty it, then reload from the pack.
	rifle["ammo"] = 1
	var rounds_before := pack.count_of("ammo_556")
	world.combat.request_shot(ahead, 1.0)
	await _wait(0.3)
	_check(int(rifle.get("ammo", 0)) == 0, "fired it dry")
	world.combat.request_reload()
	await _wait(WeaponMath.reload_seconds(CombatService.gun_stats(rifle), true) + 0.6)
	_check(int(rifle.get("ammo", 0)) == 30, "reloaded a full magazine")
	_check(pack.count_of("ammo_556") == rounds_before - 30, "the rounds came out of the pack")

	# Fire modes.
	world.combat.request_fire_mode()
	_check(String(rifle.get("mode", "")) == "semi", "switched to semi-automatic")
	world.combat.request_fire_mode()
	_check(String(rifle.get("mode", "")) == "auto", "and back to automatic")

	# Attachments: fit a suppressor from the pack and it quietens the gun.
	var loud_before := WeaponMath.loudness(CombatService.gun_stats(rifle))
	var can: Dictionary = pack.find_first("suppressor")
	world.combat.request_fit("muzzle", int(can.get("uid", 0)))
	_check(Dictionary(rifle.get("attachments", {})).get("muzzle", "") == "suppressor", "fitted the suppressor")
	_check(WeaponMath.loudness(CombatService.gun_stats(rifle)) < loud_before * 0.6, "and it carries nowhere near as far")
	_check(pack.count_of("suppressor") == 0, "it came out of the pack")
	world.combat.request_fit("muzzle", 0)
	_check(pack.count_of("suppressor") == 1, "and taking it off gives it back")
	var scope: Dictionary = pack.find_first("sniper_scope")
	world.combat.request_fit("optic", int(scope.get("uid", 0)))
	_check(float(CombatService.gun_stats(rifle).zoom) > 8.0, "a scope on the M4 magnifies")

	# A neglected gun jams, and the same key clears it.
	rifle["condition"] = 0.02
	var jammed := false
	# About a 1-in-18 chance a round: seed the dice and allow plenty of rounds,
	# so this check never fails on luck.
	seed(1911)
	for i in 120:
		rifle["ammo"] = 30
		world.combat.request_shot(ahead, 1.0)
		await _wait(0.12)
		if bool(rifle.get("jammed", false)):
			jammed = true
			break
	_check(jammed, "a fouled gun jams sooner or later")
	if jammed:
		var ammo_at_jam := int(rifle.get("ammo", 0))
		world.combat.request_shot(ahead, 1.0)
		_check(int(rifle.get("ammo", 0)) == ammo_at_jam, "a jammed gun won't fire")
		world.combat.request_reload()
		await _wait(CombatService.CLEAR_JAM_SECONDS + 0.6)
		_check(not bool(rifle.get("jammed", false)), "and clearing it takes a moment")
	world.combat.request_clean()
	_check(float(rifle.get("condition", 0.0)) > 0.98, "a cleaning kit puts it right")

	# The pistol is a different gun with different rounds.
	pack.hotbar[1] = null
	_to_hotbar(pack, "m1911", 1)
	s.select_slot(1)
	player.held_id = "m1911"
	await _wait(0.3)
	var pistol: Dictionary = CombatService.held_gun(player)
	var pistol_state := CombatService.gun_state(pistol)
	_check(String(pistol_state.round) == "ammo_45" and int(pistol_state.mag) == 7, "the 1911 holds seven .45")
	pistol["ammo"] = 0
	pack.remove("ammo_45", pack.count_of("ammo_45"))
	world.combat.request_reload()
	await _wait(1.0)
	_check(int(pistol.get("ammo", 0)) == 0, "with no .45 in the pack there's nothing to load")
	player.set_flying(false)


## Gear: a swap puts the old piece where the new one was; a canteen is four
## drinks; a whole bag can be picked up (weight and all) and set down again.
func _gear_loop() -> void:
	var world := GameState.world
	var camp: CampSystems = world.camp
	var player := GameState.local_player as Player
	var s := player.survivor
	var pack := s.inventory
	s.equipment.wear({"id": "sun_hat", "count": 1, "spoils_at": 0.0})
	s.refresh_storage()
	pack.hotbar[3] = null
	pack.add("wool_beanie", 1)
	_to_hotbar(pack, "wool_beanie", 3)
	s.wear(_uid(pack, "wool_beanie"))
	_check(s.equipment.ids().get("head", "") == "wool_beanie", "put the beanie on")
	_check(pack.hotbar[3] != null and pack.hotbar[3].id == "sun_hat", "and the sun hat went into the hotbar slot the beanie came from")

	pack.add("canteen", 1)
	var canteen: Dictionary = pack.find_first("canteen")
	canteen.id = "canteen_clean"
	canteen["sips"] = 4
	s.survival.thirst = 0.0
	for i in 3:
		s.use_item(int(canteen.uid))
	_check(pack.find_first("canteen_clean").get("sips", 0) == 1, "three drinks leave one in the canteen")
	s.use_item(int(canteen.uid))
	_check(pack.count_of("canteen") == 1 and pack.count_of("canteen_clean") == 0, "the fourth empties it")
	_check(s.survival.thirst >= 99.0, "and four drinks take you from parched to full (%.0f)" % s.survival.thirst)

	var here := player.world_transform().origin + Vector3(1.0, 0.0, 0.0)
	camp.drop_loot(here, [{"id": "stone", "count": 10, "spoils_at": 0.0}, {"id": "log", "count": 2, "spoils_at": 0.0}], "Test bag")
	var bag_id: String = camp.bags.keys()[camp.bags.size() - 1]
	var before := pack.total_weight()
	camp.request_take_bag(bag_id)
	_check(not camp.bags.has(bag_id) and pack.count_of("loot_bag") == 1, "picked the whole bag up")
	_check(pack.total_weight() > before + 5.0, "and carry its weight (%.1f kg more)" % (pack.total_weight() - before))
	var count := camp.bags.size()
	s.use_item(_uid(pack, "loot_bag"))
	var set_down: String = camp.bags.keys()[camp.bags.size() - 1]
	_check(camp.bags.size() == count + 1 and pack.count_of("loot_bag") == 0, "set it down again")
	_check((camp.containers["bag:" + set_down] as ItemGrid).count_of("stone") == 10, "with everything still in it")


## Getting about on foot: in through the shack door, over a low ledge, and stopped
## by a real wall.
func _walk_loop() -> void:
	var world := GameState.world
	var camp: CampSystems = world.camp
	var player := GameState.local_player as Player
	var xf: Transform3D = camp.shack.xf
	var s0 := player.survivor
	# Out on the sand past the foot of the steps, facing the door.
	var start := xf * Vector3(0.0, 0.0, -FishingShack.SIZE.z * 0.5 - 0.1 - FishingShack._stair_run(world.camp_island, xf * Vector3(0.0, 0.0, -FishingShack.SIZE.z * 0.5 - 0.1), xf.basis * Vector3.FORWARD) - 1.5)
	start.y = world.camp_island.height_at(start.x, start.z) + 0.3
	player.teleport(start)
	var facing: Vector3 = xf.basis * Vector3(0.0, 0.0, 1.0)
	player.yaw = atan2(-facing.x, -facing.z)
	await _wait(1.5)
	_check(not camp.in_shack(player.world_transform().origin), "start outside the shack, on the sand")
	_check(not camp.shack_door.open, "the shack door starts shut")
	await _hold("move_forward", 2.5)
	_check(not camp.in_shack(player.world_transform().origin), "a shut door stops you")
	camp.interact_shack_part(s0, "door", 0)
	_check(camp.shack_door.open, "and opens")
	await _hold("move_forward", 4.0)
	_check(camp.in_shack(player.world_transform().origin), "walked up the steps and in through the door without jumping")
	camp.interact_shack_part(s0, "door", 0)
	camp.interact_shack_part(s0, "door_bolt", 0)
	_check(not camp.shack_door.open and camp.shack_door.locked, "shut and bolted it from the inside")
	player.teleport(start)
	await _wait(0.5)
	camp.interact_shack_part(s0, "door", 0)
	_check(not camp.shack_door.open, "from outside a bolted door won't open")
	camp.interact_shack_part(s0, "door_bolt", 0)
	_check(camp.shack_door.locked, "and there's no bolt to draw from outside")
	camp._set_door(false, false)

	# Up the steps onto the dock from the beach.
	var dock_start: Vector3 = camp.shack.dock_start
	var dock_dir: Vector3 = (Vector3(camp.shack.dock_end) - dock_start).normalized()
	var beach := dock_start - dock_dir * (FishingShack._stair_run(world.camp_island, dock_start, -dock_dir) + 1.5)
	beach.y = world.camp_island.height_at(beach.x, beach.z) + 0.3
	player.teleport(beach)
	player.yaw = atan2(-dock_dir.x, -dock_dir.z)
	await _wait(1.0)
	await _hold("move_forward", 4.0)
	var on_dock: Vector3 = player.world_transform().origin
	_check(on_dock.y > FishingShack.DOCK_Y - 0.15 and (on_dock - dock_start).dot(dock_dir) > 0.5,
		"walked up the steps onto the dock (y %.2f, dock %.2f)" % [on_dock.y, FishingShack.DOCK_Y])

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

	# Diving: down, breath running out, and back up.
	var s := player.survivor
	var sea := _deep_water(world, -14.0)
	player.teleport(Vector3(sea.x, 0.6, sea.y))
	await _wait(2.5)
	_check(player.swimming, "swimming out in open water")
	var air := s.survival.breath
	await _hold("crouch", 8.0)
	_check(player.underwater, "holding crouch takes you under the surface")
	_check(s.survival.breath < air - 12.0, "and your breath runs down (%.0f)" % s.survival.breath)
	# Back at the top, and staying there through the swell for a few seconds.
	await _wait(9.0)
	var dunked := false
	for t in 30:
		await _wait(0.1)
		dunked = dunked or player.underwater
	_check(not dunked, "and the swell doesn't keep ducking you once you're up")
	_check(not player.underwater, "let go and you come back up")
	# However long the ascent took, breath is back once your head is out.
	await _wait(3.0)
	_check(s.survival.breath > 95.0, "and get your breath back (%.0f)" % s.survival.breath)

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
	# A face can carry an argument after a colon, e.g. "guns:m4".
	match GameState.face.split(":")[0]:
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
		"waterfall":
			var fall: Dictionary = world.camp_island.waterfall()
			var foot: Vector3 = fall.foot
			var top: Vector3 = fall.top
			var out3 := Vector3(float(fall.direction.x), 0.0, float(fall.direction.y))
			var side3 := out3.cross(Vector3.UP)
			_fixed_camera(foot + out3 * 26.0 + side3 * 10.0 + Vector3.UP * 9.0, top.lerp(foot, 0.55))
		"castaway":
			var island: CampIsland = world.camp_island
			var yaw := CampIslandPois.yaw_toward(island.camp, island.center)
			var basis := Basis(Vector3.UP, yaw)
			var at := Vector3(island.camp.x, island.height_at(island.camp.x, island.camp.y), island.camp.y)
			GameState.day_offset = 0.8 - Ocean.time / DayNight.DAY_LENGTH
			_fixed_camera(at + basis * Vector3(3.2, 1.7, 5.8), at + basis * Vector3(0.0, 0.6, 0.8))
		"tentcamp":
			# A tent pitched and finished, and a campfire burning in front of it.
			var island2: CampIsland = world.camp_island
			var spot: Vector2 = island2.cove + (island2.center - island2.cove).normalized() * 30.0
			var base := Vector3(spot.x, island2.height_at(spot.x, spot.y), spot.y)
			camp._spawn_structure("look_tent", "tent", base, 0.4)
			camp._apply_progress("look_tent", {"tarp": 1, "rope": 3})
			var fire_at := base + Vector3(sin(0.4), 0.0, cos(0.4)) * 3.2
			fire_at.y = island2.height_at(fire_at.x, fire_at.z)
			camp._spawn_structure("look_fire", "campfire", fire_at, 0.0)
			camp._apply_progress("look_fire", {"stone": 4, "wood": 3})
			var ring: CookStation = camp.stations["struct:look_fire"]
			ring.add_fuel(400.0)
			ring.light()
			camp._broadcast_station("struct:look_fire")
			GameState.day_offset = 0.78 - Ocean.time / DayNight.DAY_LENGTH
			var side := Vector3(cos(0.4), 0.0, -sin(0.4))
			_fixed_camera(fire_at + side * 3.5 + Vector3(sin(0.4), 0.0, cos(0.4)) * 3.0 + Vector3.UP * 1.8, base.lerp(fire_at, 0.5) + Vector3.UP * 0.6)
		"wildfire":
			var island3: CampIsland = world.camp_island
			var fire: FireService = world.fire
			var meadow := island3.center
			for attempt in 400:
				var probe: Vector2 = island3.center + Vector2.from_angle(attempt * 2.39) * (30.0 + attempt * 0.4)
				if fire.grid.fuel(FireGrid.cell_of(probe)) > 0.75:
					meadow = probe
					break
			world.weather.set_wind(0.0, 7.0)
			fire.ignite_at(Vector3(meadow.x, 0.0, meadow.y))
			await _wait(16.0)
			var ground_at := Vector3(meadow.x, island3.height_at(meadow.x, meadow.y), meadow.y)
			_fixed_camera(ground_at + Vector3(-14.0, 7.0, 10.0), ground_at + Vector3(4.0, 0.5, 0.0))
		"cooking":
			var stove: CookStation = camp.stations["shack:stove"]
			stove.add_fuel(400.0)
			stove.light()
			stove.start("raw_fish", Ocean.time)
			stove.start("canteen_dirty", Ocean.time - CookStation.COOK_SECONDS)
			camp._broadcast_station("shack:stove")
			var stove_at: Vector3 = camp.shack.parts.stove
			player.teleport(stove_at + Vector3(1.6, 0.2, 0.6))
			player.yaw = atan2(-(stove_at.x - player.global_position.x), -(stove_at.z - player.global_position.z))
			await _wait(0.6)
			var hud3 := _hud()
			hud3._on_cooking_opened("shack:stove", camp.station_title("shack:stove"))
		"gun", "scope":
			world.dev.request("give", ["m4", 1])
			world.dev.request("give", ["ammo_556", 60])
			var gun_pack := player.survivor.inventory
			gun_pack.hotbar[0] = null
			_to_hotbar(gun_pack, "m4", 0)
			player.survivor.select_slot(0)
			player.held_id = "m4"
			var dock_end2: Vector3 = camp.shack.dock_end
			var out4: Vector3 = (dock_end2 - Vector3(camp.shack.dock_start)).normalized()
			out4.y = 0.0
			player.teleport(dock_end2 + Vector3.UP * 0.6)
			player.yaw = atan2(-out4.x, -out4.z)
			player.pitch = -0.02
			# Something worth looking at, a long way out.
			var mark := dock_end2 + out4.normalized() * 120.0
			var far_shark: Shark = world.sharks.spawn(Vector3(mark.x, -0.4, mark.z), Vector3(mark.x, 0.0, mark.z), 8.0)
			far_shark.set_physics_process(false)
			await _wait(0.5)
			if GameState.face == "scope":
				world.dev.request("give", ["sniper_scope", 1])
				await _wait(0.2)
				var optic: Dictionary = gun_pack.find_first("sniper_scope")
				world.combat.request_fit("optic", int(optic.get("uid", 0)))
				Input.action_press("secondary")
		"guns":
			# Every gun in a row, side on, for judging their shapes.
			# --face=guns racks them all; --face=guns:m4 fills the frame with one.
			var pick := GameState.face.split(":")
			var rack := ["m1911", "uzi", "mossberg", "m4", "intervention"] if pick.size() < 2 else [pick[1]]
			var stand := player.world_transform().origin + Vector3(0.0, 40.0, 0.0)
			var holder := Node3D.new()
			world.add_child(holder)
			holder.global_position = stand
			for i in rack.size():
				var model := ItemModels.build(rack[i])
				holder.add_child(model)
				# Lay each one on its side, muzzle to the left, stacked down the view.
				model.position = Vector3(0.0, (float(rack.size() - 1) * 0.5 - i) * 0.42, 0.0)
				# Barrel to the left, sights up: we want the side of each gun.
				model.transform.basis = Basis(Vector3(0.0, 0.0, -1.0), Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0))
			var rack_cam := Camera3D.new()
			rack_cam.fov = 48.0 if rack.size() > 1 else 32.0
			world.add_child(rack_cam)
			var rack_at := stand + (Vector3(-0.3, 0.0, 2.4) if rack.size() > 1 else Vector3(-0.38, 0.0, 1.5))
			rack_cam.global_transform = Transform3D(Basis.looking_at(Vector3.FORWARD, Vector3.UP), rack_at)
			rack_cam.make_current()
			var lamp2 := DirectionalLight3D.new()
			lamp2.light_energy = 1.2
			world.add_child(lamp2)
			lamp2.global_rotation = Vector3(-0.7, 0.9, 0.0)
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
			["m1911", 1], ["ammo_45", 30], ["rope", 5], ["berries", 12], ["tarp", 1], ["stone_hatchet", 1]]:
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
