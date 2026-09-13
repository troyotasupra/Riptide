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
		"ship":
			_ship_view()
			return  # stays up for a --shot screenshot
		"structures":
			_structures_view()
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
	var boat := world.find_boat("Sailboat") as Sailboat
	_check(player.platform == boat, "host starts aboard the sailboat")
	_check(s.equipment.ids() == {"torso": "tshirt", "legs": "shorts", "feet": "sandals", "back": "satchel"}, "a new crew member washes up in the starting outfit")
	_check(pack.grid_names() == ["pockets", "backpack"], "the satchel gives a backpack grid")
	_check(player.model.worn.get("torso", "") == "tshirt", "the character model shows the T-shirt")

	camp.interact_boat_part(s, boat, "chest", 0)
	_check(camp.open_container == "boat:Sailboat:chest", "the sea chest opens")
	var chest: ItemGrid = camp.containers["boat:Sailboat:chest"]
	var uids: Array = chest.items.map(func(item: Dictionary) -> int: return int(item.uid))
	for uid: int in uids:
		camp.request_quick_move("boat:Sailboat:chest", uid)
	_check(pack.count_of("survival_book") == 1 and pack.count_of("lighter") == 1 and pack.count_of("knife") == 1,
		"the important stash items move into the pack")
	_check(chest.count_of("survival_book") == 0, "they leave the chest")

	var free_slot := pack.hotbar.find(null)
	_check(free_slot >= 0 and _to_hotbar(pack, "survival_book", free_slot), "drag the book onto an empty hotbar slot")
	s._request_use(_uid(pack, "survival_book"))
	_check(camp.known_recipes.has("campfire_kit") and camp.known_recipes.has("rope"), "reading the book teaches the basics")

	camp.interact_boat_part(s, boat, "compartment", 0)
	_check(not camp.unlocked.has("boat:Sailboat:compartment"), "the compartment stays locked without the key")
	pack.add("compartment_key", 1)
	camp.interact_boat_part(s, boat, "compartment", 0)
	_check(camp.unlocked.has("boat:Sailboat:compartment") and camp.open_container == "boat:Sailboat:compartment", "the brass key unlocks it")
	var compartment: ItemGrid = camp.containers["boat:Sailboat:compartment"]
	_check(compartment.count_of("pistol") == 1 and compartment.count_of("plate_carrier") == 1, "the pistol and a plate carrier are inside")

	pack.clear()
	var carrier_uid := int(compartment.items.filter(func(item: Dictionary) -> bool: return item.id == "plate_carrier")[0].uid)
	camp.request_wear_item("boat:Sailboat:compartment", carrier_uid)
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

	player.teleport_aboard("Sailboat", Sailboat.BUNK_SPAWN)
	await _wait(1.0)
	GameState.day_offset = 0.92 - Ocean.time / DayNight.DAY_LENGTH
	camp.interact_boat_part(s, boat, "bunk", 0)
	_check(camp.local_asleep, "asleep in the bunk at night")
	await _wait(3.5)
	_check(DayNight.is_day(GameState.time_of_day()) and not camp.local_asleep, "the night skips to dawn when the crew sleeps")
	_check(camp.respawn_spot(player.player_id).get("kind", "") == "boat", "the bunk becomes the respawn point")

	pack.hotbar[6] = {"uid": 903, "id": "flint", "count": 3, "spoils_at": 0.0}
	camp.request_drop_item("", 903)
	_check((camp.containers["boat:Sailboat:lockers"] as ItemGrid).count_of("flint") == 3, "dropping aboard stows the item in the crew lockers")

	player.teleport(ground + Vector3(-3.0, 1.0, 2.0))
	await _wait(1.5)
	var carried := pack.all_stacks().size()
	s.survival.health = 0.0
	await _wait(1.0)
	var bag_ok := false
	for id: String in camp.bags:
		if (camp.containers["bag:" + id] as ItemGrid).count_of("cooked_fish") == 1:
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


## Client: open the sea chest over the network, take the knife, drag it to the
## hotbar, and check the host's character is visible in its starting clothes.
func _client_chest() -> void:
	var camp: CampSystems = GameState.world.camp
	var player := GameState.local_player as Player
	var pack := player.survivor.inventory
	_check(player != null and player.platform is Sailboat, "the crew member spawns aboard")
	var host := GameState.world.players_root.get_node_or_null("1") as Player
	_check(host != null and host.model.visible and host.model.worn.get("torso", "") == "tshirt", "the host is visible in their starting clothes")
	_check(player.survivor.equipment.ids().has("back") and pack.grid("backpack") != null, "the crew member's outfit and satchel storage arrived")
	var opened := [false]
	camp.container_opened.connect(func(_id: String, _title: String) -> void: opened[0] = true)
	GameState.world.rpc_id(1, "request_interact", "boat:Sailboat:chest", 0)
	await _wait(1.0)
	_check(opened[0] and camp.containers.has("boat:Sailboat:chest"), "the host opens the chest for a remote crew member")
	if not camp.containers.has("boat:Sailboat:chest"):
		return
	var chest: ItemGrid = camp.containers["boat:Sailboat:chest"]
	var knife: Array = chest.items.filter(func(item: Dictionary) -> bool: return item.id == "knife")
	if knife.is_empty():
		_check(false, "the knife is in the chest")
		return
	camp.rpc_id(1, "request_move_item", "boat:Sailboat:chest", int(knife[0].uid), 0, {"area": "pockets", "x": 4, "y": 0, "rot": false})
	await _wait(1.0)
	var in_pocket: Dictionary = pack.grid("pockets").item_at(Vector2i(4, 0))
	_check(in_pocket.get("id", "") == "knife", "dragged the knife from the chest into a pocket cell over the network")
	_check((camp.containers["boat:Sailboat:chest"] as ItemGrid).count_of("knife") == 0, "everyone's view of the chest updated")
	camp.rpc_id(1, "request_move_item", "", _uid(pack, "knife"), 0, {"area": "hotbar", "index": 3})
	await _wait(1.0)
	_check(pack.hotbar[3] != null and pack.hotbar[3].id == "knife", "dragged the knife onto hotbar slot 4")
	camp.rpc_id(1, "request_drop_item", "", _uid(pack, "knife"))
	await _wait(1.0)
	_check(pack.count_of("knife") == 0, "dropping over the network takes it from the pack")


## Visual check: a fixed camera on the sloop. --face=deck (from the helm),
## cabin (below deck), or anything else for a three-quarter view from the water.
func _ship_view() -> void:
	var boat := GameState.world.find_boat("Sailboat") as Sailboat
	if boat == null:
		return
	var eye := Vector3(13.0, 4.5, -11.0)
	var target := Vector3(0.0, 4.0, 0.5)
	match GameState.face:
		"deck":
			eye = Vector3(0.6, Sailboat.QUARTER_Y + 1.7, 5.6)
			target = Vector3(0.0, Sailboat.DECK_Y + 2.5, -5.0)
		"cabin":
			eye = Vector3(0.0, Sailboat.FLOOR_Y + 1.55, 3.4)
			target = Vector3(0.0, Sailboat.FLOOR_Y + 0.6, -2.4)
		"stern":
			eye = Vector3(-9.0, 3.5, 14.0)
			target = Vector3(0.0, 3.5, 0.0)
	var cam := Camera3D.new()
	cam.fov = 70.0
	GameState.world.add_child(cam)
	var place := func() -> void:
		cam.global_transform = boat.get_global_transform_interpolated() * Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)
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
	var base: Vector2 = island.cove + inland * 16.0
	var types := ["lean_to", "campfire", "tent", "drying_rack", "storage_crate"]
	for i in types.size():
		var xz := base + across * (i - 2) * 3.2
		var pos := Vector3(xz.x, island.height_at(xz.x, xz.y), xz.y)
		camp._spawn_structure("view%d" % i, types[i], pos, atan2(-inland.x, -inland.y) + PI)
	(camp.structure_nodes["view1"] as StructureNode).set_lit(true)
	var eye2 := base - inland * 7.0
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
	var boat := world.find_boat("Sailboat") as Sailboat
	camp.interact_boat_part(s, boat, "chest", 0)
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
	# --face=portrait puts the row close enough to judge faces.
	var portrait := GameState.face == "portrait"
	var distance := 1.25 if portrait else 4.5
	var spacing := 0.62 if portrait else 1.3
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
