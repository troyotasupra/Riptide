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


## Host: stash → book → compartment → craft → build → fire → cook → sleep → save.
func _camp_loop() -> void:
	var world := GameState.world
	var camp: CampSystems = world.camp
	var player := GameState.local_player as Player
	var s := player.survivor
	var boat := world.find_boat("Sailboat") as Sailboat
	_check(player.platform == boat, "host starts aboard the sailboat")

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
	_check((camp.containers["boat:Sailboat:compartment"] as Inventory).count_of("pistol") == 1, "the pistol is inside")

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

	player.teleport_aboard("Sailboat", Sailboat.BUNK_SPAWN)
	await _wait(1.0)
	GameState.day_offset = 0.92 - Ocean.time / DayNight.DAY_LENGTH
	camp.interact_boat_part(s, boat, "bunk", 0)
	_check(camp.local_asleep, "asleep in the bunk at night")
	await _wait(2.5)
	_check(DayNight.is_day(GameState.time_of_day()) and not camp.local_asleep, "the night skips to dawn when the whole crew sleeps")
	_check(camp.respawn_spot(player.display_name).get("kind", "") == "boat", "the bunk becomes the respawn point")

	world.save_now()
	var saved := SaveGame.read()
	_check(saved.get("camp", {}).get("structures", {}).size() == 1, "the save has the campfire")
	_check(saved.get("players", {}).has(player.display_name), "the save has the crew member's belongings")


## Client: ask the host to open the sea chest and take the knife over the network.
func _client_chest() -> void:
	var camp: CampSystems = GameState.world.camp
	var player := GameState.local_player as Player
	_check(player != null and player.platform is Sailboat, "the crew member spawns aboard")
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
