class_name CampSystems
extends Node3D
## The crew's shared camp, owned by the host: containers (sea chest, lockers,
## crates), cooking and drying stations, placed structures, one-off pickups,
## recipes the crew knows, the sea chart, where each crew member respawns, and
## who is asleep. Clients keep mirrors and send requests.

signal container_opened(id: String, title: String)
signal container_changed(id: String)
signal recipes_changed
signal chart_changed
signal sleeping_changed(asleep: bool)

const STATION_TICK := 1.0
const SPOIL_CHECK := 5.0
const AUTOSAVE_SECONDS := 120.0
const STRUCTURE_REACH := 7.0
const SLEEP_HUNGER := 15.0
const SLEEP_THIRST := 20.0
const SLEEP_HEAL := 30.0

const PICKUPS := {
	"machete": {"item": "machete", "count": 1, "label": "Take the machete"},
	"compartment_key": {"item": "compartment_key", "count": 1, "label": "Take the small brass key"},
	"journal": {"item": "journal", "count": 1, "label": "Take the journal"},
	"page_shelter": {"item": "book_page_shelter", "count": 1, "label": "Take the torn book page"},
	"page_camp": {"item": "book_page_camp", "count": 1, "label": "Take the torn book page"},
}
## Offsets from the castaway camp (camp space: -Z faces the island centre).
const PICKUP_SPOTS := {
	"machete": Vector3(1.4, 0.35, 1.8),
	"compartment_key": Vector3(-0.5, 0.05, 0.3),
	"journal": Vector3(0.3, 0.05, 0.2),
	"page_shelter": Vector3(-1.6, 0.05, 1.3),
	"page_camp": Vector3(0.9, 0.05, -0.5),
}

const STASH := [["survival_book", 1], ["knife", 1], ["canteen", 1], ["lighter", 1], ["tarp", 1], ["paracord", 2],
	["logbook", 1], ["sea_chart", 1], ["fishing_rod", 1], ["lure", 3], ["flare_gun", 1], ["flare", 2], ["bandage", 4]]
const COMPARTMENT_CONTENTS := [["pistol", 1], ["pistol_ammo", 15]]

var world: Node3D
## id -> Inventory (the host's are the truth; clients mirror what they open)
var containers := {}
var container_titles := {}
## id -> CookStation
var stations := {}
## id -> {"type", "pos", "yaw"}
var structures := {}
var structure_nodes := {}
var pickup_nodes := {}
var picked := {}
var known_recipes := {}
var chart_read := false
var unlocked := {}
## player name -> {"kind": "boat", "boat", "local"} or {"kind": "structure", "id"}
var respawns := {}
## peer id -> true (host)
var sleeping := {}
## Owner-side mirrors for the local player's UI.
var local_asleep := false
var open_container := ""

var _viewers := {}
var _next_structure := 1
var _station_accum := 0.0
var _spoil_accum := 0.0
var _autosave_accum := 0.0


func _ready() -> void:
	world = get_parent()


# --- setup, sync and saves ----------------------------------------------------

## Host, fresh world: stock the abandoned sailboat.
func setup_new_world() -> void:
	var chest := _make_container("boat:Sailboat:chest", 12, "Sea chest")
	for entry: Array in STASH:
		chest.add(entry[0], entry[1], Ocean.time)
	_make_container("boat:Sailboat:lockers", 16, "Crew lockers")
	var compartment := _make_container("boat:Sailboat:compartment", 4, "Locked compartment")
	for entry: Array in COMPARTMENT_CONTENTS:
		compartment.add(entry[0], entry[1], Ocean.time)
	stations["boat:Sailboat:stove"] = CookStation.new("cook")


func create_pickups(shape: CampIsland) -> void:
	var yaw := CampIslandPois.yaw_toward(shape.camp, shape.center)
	var basis := Basis(Vector3.UP, yaw)
	var origin := Vector3(shape.camp.x, 0.0, shape.camp.y)
	for id: String in PICKUP_SPOTS:
		var offset: Vector3 = PICKUP_SPOTS[id]
		var p := origin + basis * Vector3(offset.x, 0.0, offset.z)
		p.y = shape.height_at(p.x, p.z) + offset.y
		var node := PickupNode.new()
		node.setup(id, PICKUPS[id].label, PICKUPS[id].item, p, yaw + offset.x)
		add_child(node)
		pickup_nodes[id] = node
		if picked.has(id):
			_apply_picked(id)


func sync_to(peer_id: int) -> void:
	var now: float = Ocean.time
	var station_data := {}
	for id: String in stations:
		station_data[id] = (stations[id] as CookStation).to_dict(now)
	_full_sync.rpc_id(peer_id, {
		"structures": structures,
		"stations": station_data,
		"picked": picked.keys(),
		"recipes": known_recipes.keys(),
		"chart": chart_read,
		"unlocked": unlocked.keys(),
	})


func to_save(now: float) -> Dictionary:
	var saved_stations := {}
	for id: String in stations:
		saved_stations[id] = (stations[id] as CookStation).to_dict(now)
	var saved_containers := {}
	for id: String in containers:
		var inventory: Inventory = containers[id]
		var copy := Inventory.new(inventory.slots.size())
		copy.from_dict(inventory.to_dict())
		copy.shift_times(-now)
		saved_containers[id] = {"size": inventory.slots.size(), "data": copy.to_dict(), "title": container_titles.get(id, "")}
	return {
		"structures": structures.duplicate(true),
		"next_structure": _next_structure,
		"stations": saved_stations,
		"containers": saved_containers,
		"picked": picked.keys(),
		"recipes": known_recipes.keys(),
		"chart": chart_read,
		"unlocked": unlocked.keys(),
		"respawns": respawns.duplicate(true),
	}


func from_save(data: Dictionary, now: float) -> void:
	var saved_structures: Dictionary = data.get("structures", {})
	for id: String in saved_structures:
		var entry: Dictionary = saved_structures[id]
		_spawn_structure(id, entry.type, entry.pos, entry.yaw)
	_next_structure = data.get("next_structure", _next_structure)
	var saved_containers: Dictionary = data.get("containers", {})
	for id: String in saved_containers:
		var entry: Dictionary = saved_containers[id]
		var inventory := _make_container(id, entry.size, entry.title)
		inventory.from_dict(entry.data)
		inventory.shift_times(now)
	var saved_stations: Dictionary = data.get("stations", {})
	for id: String in saved_stations:
		var station := CookStation.new()
		station.from_dict(saved_stations[id], now)
		stations[id] = station
		_apply_station_visual(id)
	for id: String in data.get("picked", []):
		_apply_picked(id)
	for id: String in data.get("recipes", []):
		known_recipes[id] = true
	chart_read = data.get("chart", false)
	for id: String in data.get("unlocked", []):
		unlocked[id] = true
	respawns = data.get("respawns", {})


func _make_container(id: String, size: int, title: String) -> Inventory:
	var inventory := Inventory.new(size)
	containers[id] = inventory
	container_titles[id] = title
	return inventory


@rpc("authority", "call_remote", "reliable")
func _full_sync(data: Dictionary) -> void:
	for id: String in data.structures:
		var entry: Dictionary = data.structures[id]
		_spawn_structure(id, entry.type, entry.pos, entry.yaw)
	for id: String in data.stations:
		_station_state(id, data.stations[id])
	for id: String in data.picked:
		_apply_picked(id)
	for id: String in data.recipes:
		known_recipes[id] = true
	chart_read = data.chart
	for id: String in data.unlocked:
		unlocked[id] = true
	recipes_changed.emit()
	chart_changed.emit()


# --- host tick ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_station_accum += delta
	if _station_accum >= STATION_TICK:
		var dt := _station_accum
		_station_accum = 0.0
		for id: String in stations:
			var station: CookStation = stations[id]
			var was_lit := station.lit
			station.tick(dt)
			if station.lit or was_lit or station.is_busy():
				_broadcast_station(id)
		_check_sleep()
	_spoil_accum += delta
	if _spoil_accum >= SPOIL_CHECK:
		_spoil_accum = 0.0
		for id: String in containers:
			if (containers[id] as Inventory).spoil_expired(Ocean.time):
				_push_container(id)
	_autosave_accum += delta
	if _autosave_accum >= AUTOSAVE_SECONDS:
		_autosave_accum = 0.0
		world.save_now()


## °C a crew member gains from nearby fires, shelters, or the sailboat's cabin.
func warmth_for(player: Player) -> float:
	var at := player.world_transform().origin
	var warmth := 0.0
	for id: String in structures:
		var entry: Dictionary = structures[id]
		var info := StructureTable.get_type(entry.type)
		if at.distance_to(entry.pos) > float(info.get("warm_radius", 0.0)):
			continue
		if info.has("warmth"):
			var station: CookStation = stations.get("struct:" + id)
			if station != null and station.lit:
				warmth = maxf(warmth, info.warmth)
		elif info.has("shelter"):
			warmth = maxf(warmth, info.shelter)
	if player.platform is Sailboat:
		var local := player.global_position - player.platform.proxy_xf.origin
		if local.y < Sailboat.DECK_Y - 0.2:
			var stove: CookStation = stations.get("boat:%s:stove" % player.platform.name)
			warmth = maxf(warmth, Sailboat.CABIN_WARMTH + (Sailboat.STOVE_WARMTH if stove != null and stove.lit else 0.0))
	return warmth


# --- prompts (any peer, for the local player's crosshair) --------------------

func part_prompt(boat: Sailboat, part_name: String, player: Node) -> String:
	var container_id := "boat:%s:%s" % [boat.name, part_name]
	match part_name:
		"bunk":
			return "" if local_asleep else "Sleep in the bunk"
		"chest":
			return "Open the sea chest"
		"lockers":
			return "Open the crew lockers"
		"compartment":
			if unlocked.has(container_id):
				return "Open the compartment"
			if player != null and player.survivor != null and player.survivor.inventory.count_of("compartment_key") > 0:
				return "Unlock the compartment with the brass key"
			return "Locked compartment"
		"stove":
			return station_prompt(container_id, "Galley stove", player)
		"chart":
			return "Chart table — islands marked on your compass" if chart_read else "Study the chart table"
	return ""


func structure_prompt(id: String, player: Node) -> String:
	var entry: Dictionary = structures.get(id, {})
	if entry.is_empty():
		return ""
	var info := StructureTable.get_type(entry.type)
	if info.has("station"):
		return station_prompt("struct:" + id, info.name, player)
	if info.has("container"):
		return "Open the %s" % String(info.name).to_lower()
	if info.get("sleep", false):
		return "" if local_asleep else "Sleep in the %s" % String(info.name).to_lower()
	return ""


func station_prompt(id: String, title: String, player: Node) -> String:
	var station: CookStation = stations.get(id)
	if station == null:
		return title
	var now: float = Ocean.time
	if station.has_done(now):
		return "%s — take what's ready" % title
	var held := held_item(player)
	var item := ItemTable.get_item(held)
	if station.needs_fire() and item.has("fuel"):
		return "%s — add %s (%ds of fuel)" % [title, String(item.name).to_lower(), int(station.fuel)]
	if not station.result_for(held).is_empty():
		if station.needs_fire() and not station.lit:
			return "%s — light it before cooking" % title
		var verb := "Dry" if station.mode == "dry" else ("Boil" if item.has("boils_to") else "Cook")
		return "%s — %s %s" % [title, verb.to_lower(), String(item.name).to_lower()]
	if station.needs_fire() and not station.lit:
		return "%s — %s" % [title, "light it" if station.fuel > 0.0 else "needs driftwood"]
	if station.needs_fire():
		return "%s — burning, %ds of fuel%s" % [title, int(station.fuel), " · cooking" if station.is_busy() else ""]
	return "%s — %s" % [title, "drying" if station.is_busy() else "hold raw food to dry it"]


static func held_item(player: Node) -> String:
	if player == null or player.survivor == null:
		return ""
	var slot = player.survivor.inventory.slots[player.survivor.selected_slot]
	return "" if slot == null else slot.id


# --- host: interactions --------------------------------------------------------

func interact_boat_part(survivor: Survivor, boat: Sailboat, part_name: String, slot: int) -> void:
	var id := "boat:%s:%s" % [boat.name, part_name]
	match part_name:
		"bunk":
			request_sleep_at(survivor, {"kind": "boat", "boat": String(boat.name), "local": Sailboat.BUNK_SPAWN})
		"chest", "lockers":
			open_container_for(survivor, id)
		"compartment":
			if not unlocked.has(id):
				if survivor.inventory.count_of("compartment_key") == 0:
					survivor.notify("It's locked tight. Someone must have the key.")
					return
				unlocked[id] = true
				Net.send_to_ready(self, "_set_unlocked", [id])
				survivor.notify("The brass key turns.")
			open_container_for(survivor, id)
		"stove":
			_use_station(survivor, id, slot)
		"chart":
			read_chart(survivor)


func interact_structure(survivor: Survivor, id: String, slot: int) -> void:
	var entry: Dictionary = structures.get(id, {})
	if entry.is_empty():
		return
	var info := StructureTable.get_type(entry.type)
	if info.has("station"):
		_use_station(survivor, "struct:" + id, slot)
	elif info.has("container"):
		open_container_for(survivor, "struct:" + id)
	elif info.get("sleep", false):
		request_sleep_at(survivor, {"kind": "structure", "id": id})


func pickup(survivor: Survivor, id: String) -> void:
	if picked.has(id) or not PICKUPS.has(id):
		return
	var entry: Dictionary = PICKUPS[id]
	if survivor.inventory.add(entry.item, entry.count, Ocean.time) > 0:
		survivor.notify("Your pack is full.")
		return
	_apply_picked(id)
	Net.send_to_ready(self, "_set_picked", [id])
	survivor.notify("+%d %s" % [entry.count, ItemTable.display_name(entry.item)])
	survivor.push_inventory()


func learn(recipe_ids: Array, survivor: Survivor) -> void:
	var fresh: PackedStringArray = []
	for id: String in recipe_ids:
		if RecipeTable.RECIPES.has(id) and not known_recipes.has(id):
			known_recipes[id] = true
			fresh.append(RecipeTable.RECIPES[id].name)
	if fresh.is_empty():
		survivor.notify("Nothing here the crew doesn't already know.")
		return
	Net.send_to_ready(self, "_set_recipes", [known_recipes.keys()])
	recipes_changed.emit()
	_notify_crew("%s learned how to make: %s  (B to craft)" % [survivor.player.display_name, ", ".join(fresh)])


func read_chart(survivor: Survivor) -> void:
	if chart_read:
		survivor.notify("The islands are already marked on your compass.")
		return
	chart_read = true
	Net.send_to_ready(self, "_set_chart", [true])
	chart_changed.emit()
	_notify_crew("%s studied the sea chart — nearby islands are marked on everyone's compass." % survivor.player.display_name)


func request_sleep_at(survivor: Survivor, spot: Dictionary) -> void:
	respawns[survivor.player.display_name] = spot
	if DayNight.is_day(GameState.time_of_day()):
		survivor.notify("Respawn point set here. You can sleep once night falls.")
		return
	sleeping[survivor.player.peer_id] = true
	_set_sleeping_for(survivor.player.peer_id, true)
	survivor.notify("Respawn point set. You settle in to sleep...")


func respawn_spot(player_name: String) -> Dictionary:
	var spot: Dictionary = respawns.get(player_name, {})
	match spot.get("kind", ""):
		"boat":
			if world.find_boat(spot.boat) != null:
				return spot
		"structure":
			if structures.has(spot.id):
				return spot
	return {}


## Puts `player` at their respawn spot. False if they have none.
func teleport_to_spot(player: Player, spot: Dictionary) -> bool:
	match spot.get("kind", ""):
		"boat":
			player.teleport_aboard(spot.boat, spot.local)
			return true
		"structure":
			var entry: Dictionary = structures[spot.id]
			var p: Vector3 = entry.pos + Basis(Vector3.UP, entry.yaw) * Vector3(0.0, 0.6, 2.2)
			player.teleport(p)
			return true
	return false


func open_container_for(survivor: Survivor, id: String) -> void:
	if not containers.has(id):
		return
	var peer := survivor.player.peer_id
	if not _viewers.has(id):
		_viewers[id] = {}
	_viewers[id][peer] = true
	_send_container(id, peer, true)


func forget_peer(peer_id: int) -> void:
	sleeping.erase(peer_id)
	for id: String in _viewers:
		_viewers[id].erase(peer_id)


func _use_station(survivor: Survivor, id: String, slot: int) -> void:
	var station: CookStation = stations.get(id)
	if station == null:
		return
	var now: float = Ocean.time
	var inventory := survivor.inventory
	if station.has_done(now):
		var names: PackedStringArray = []
		for result in station.take_done(now):
			if inventory.add(result, 1, now) > 0:
				survivor.notify("Your pack is full — the %s is ruined." % ItemTable.display_name(result).to_lower())
			else:
				names.append(ItemTable.display_name(result))
		if not names.is_empty():
			survivor.notify("Took " + ", ".join(names))
		survivor.push_inventory()
		_broadcast_station(id)
		return
	var held = inventory.slots[slot]
	var held_id: String = "" if held == null else held.id
	var item := ItemTable.get_item(held_id)
	if station.needs_fire() and item.has("fuel"):
		if station.add_fuel(item.fuel):
			inventory.take_from_slot(slot, 1)
			survivor.notify("Added %s — %ds of fuel" % [String(item.name).to_lower(), int(station.fuel)])
			survivor.push_inventory()
			_broadcast_station(id)
		else:
			survivor.notify("It can't take any more fuel.")
		return
	if not station.result_for(held_id).is_empty():
		if station.needs_fire() and not station.lit:
			survivor.notify("Light the fire first.")
		elif station.start(held_id, now):
			inventory.take_from_slot(slot, 1)
			survivor.notify("%s the %s..." % ["Drying" if station.mode == "dry" else "Heating", String(item.name).to_lower()])
			survivor.push_inventory()
			_broadcast_station(id)
		else:
			survivor.notify("There's no room for more.")
		return
	if station.needs_fire() and not station.lit:
		if station.fuel <= 0.0:
			survivor.notify("Hold driftwood and press E to add fuel.")
			return
		var lighter_slot := inventory.first_slot_of("lighter")
		if lighter_slot == -1:
			survivor.notify("You need something to light it with.")
			return
		station.light()
		var lighter: Dictionary = inventory.slots[lighter_slot]
		lighter.uses = int(lighter.get("uses", 1)) - 1
		if lighter.uses <= 0:
			inventory.slots[lighter_slot] = null
			survivor.notify("The fire catches — and the lighter sputters out for good.")
		else:
			survivor.notify("The fire catches. (Lighter: %d uses left)" % lighter.uses)
		survivor.push_inventory()
		_broadcast_station(id)
		return
	survivor.notify("Hold food to cook, water to boil, or driftwood to burn — then press E.")


func _check_sleep() -> void:
	if sleeping.is_empty():
		return
	if DayNight.is_day(GameState.time_of_day()):
		_wake_everyone()
		return
	for id: int in Net.roster:
		if Net.roster[id].get("ready", false) and not sleeping.has(id):
			return
	var advance := fposmod(DayNight.SUNRISE + 0.005 - GameState.time_of_day(), 1.0)
	GameState.day_offset += advance
	Net.send_to_ready(self, "_set_day_offset", [GameState.day_offset])
	for player: Player in world.players_root.get_children():
		var s := player.survivor
		s.survival.hunger = maxf(0.0, s.survival.hunger - SLEEP_HUNGER)
		s.survival.thirst = maxf(0.0, s.survival.thirst - SLEEP_THIRST)
		s.survival.heal(SLEEP_HEAL)
		s.notify("The crew sleeps through the night. You wake at dawn, hungry and thirsty.")
		s.push_survival()
	_wake_everyone()


func _wake_everyone() -> void:
	for id: int in sleeping.keys():
		_set_sleeping_for(id, false)
	sleeping.clear()


func _set_sleeping_for(peer_id: int, asleep: bool) -> void:
	if not asleep:
		sleeping.erase(peer_id)
	if peer_id == multiplayer.get_unique_id():
		_apply_sleeping(asleep)
	else:
		_set_sleeping.rpc_id(peer_id, asleep)


func _apply_sleeping(asleep: bool) -> void:
	local_asleep = asleep
	sleeping_changed.emit(asleep)


func _notify_crew(message: String) -> void:
	for player: Player in world.players_root.get_children():
		player.survivor.notify(message)


func _broadcast_station(id: String) -> void:
	var data := (stations[id] as CookStation).to_dict(Ocean.time)
	_apply_station_visual(id)
	Net.send_to_ready(self, "_station_state", [id, data])


func _apply_station_visual(id: String) -> void:
	var station: CookStation = stations.get(id)
	if station == null:
		return
	if id.begins_with("struct:"):
		var node: StructureNode = structure_nodes.get(id.substr(7))
		if node != null:
			node.set_lit(station.lit)
	elif id.begins_with("boat:"):
		var boat := world.find_boat(id.split(":")[1]) as Sailboat
		if boat != null:
			boat.set_stove_lit(station.lit)


func _apply_picked(id: String) -> void:
	picked[id] = true
	var node: PickupNode = pickup_nodes.get(id)
	if node != null:
		node.visible = false
		node.collision_layer = 0


func _push_container(id: String) -> void:
	for peer: int in _viewers.get(id, {}):
		_send_container(id, peer, false)


func _send_container(id: String, peer: int, opening: bool) -> void:
	if peer == multiplayer.get_unique_id():
		if opening:
			open_container = id
			container_opened.emit(id, container_titles.get(id, "Storage"))
		else:
			container_changed.emit(id)
	else:
		_container_contents.rpc_id(peer, id, container_titles.get(id, "Storage"), containers[id].to_dict(), opening)


func _sender_player() -> Player:
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	return world.players_root.get_node_or_null(str(sender)) as Player


# --- requests from crew members (host validates) ------------------------------

@rpc("any_peer", "call_local", "reliable")
func request_transfer(id: String, from_container: bool, slot: int) -> void:
	if not multiplayer.is_server():
		return
	var player := _sender_player()
	if player == null or not containers.has(id) or not _viewers.get(id, {}).has(player.peer_id):
		return
	var container: Inventory = containers[id]
	var pack := player.survivor.inventory
	var source := container if from_container else pack
	var target := pack if from_container else container
	if slot < 0 or slot >= source.slots.size() or source.slots[slot] == null:
		return
	var stack := source.take_from_slot(slot, source.slots[slot].count)
	var left := target.add_stack(stack)
	if left > 0:
		stack.count = left
		source.add_stack(stack)
		player.survivor.notify("No room for all of it.")
	player.survivor.push_inventory()
	_push_container(id)


@rpc("any_peer", "call_local", "reliable")
func request_close(id: String) -> void:
	if not multiplayer.is_server():
		return
	var player := _sender_player()
	if player != null and _viewers.has(id):
		_viewers[id].erase(player.peer_id)


@rpc("any_peer", "call_local", "reliable")
func request_craft(recipe_id: String) -> void:
	if not multiplayer.is_server():
		return
	var player := _sender_player()
	if player == null or not known_recipes.has(recipe_id):
		return
	var survivor := player.survivor
	if not RecipeTable.can_craft(survivor.inventory, recipe_id):
		survivor.notify("You don't have everything for that.")
		return
	var recipe: Dictionary = RecipeTable.RECIPES[recipe_id]
	var trial := Inventory.new(survivor.inventory.slots.size())
	trial.from_dict(survivor.inventory.to_dict())
	for item: String in recipe.needs:
		trial.remove(item, recipe.needs[item])
	if trial.add(recipe.makes, recipe.count, Ocean.time) > 0:
		survivor.notify("No room in your pack for that.")
		return
	survivor.inventory = trial
	survivor.notify("Made: %s" % recipe.name)
	survivor.push_inventory()


@rpc("any_peer", "call_local", "reliable")
func request_place(slot: int, pos: Vector3, yaw: float) -> void:
	if not multiplayer.is_server():
		return
	var player := _sender_player()
	if player == null or slot < 0 or slot >= Inventory.HOTBAR_SIZE:
		return
	var survivor := player.survivor
	var stack = survivor.inventory.slots[slot]
	if stack == null:
		return
	var type: String = ItemTable.get_item(stack.id).get("places", "")
	if type.is_empty():
		return
	if player.world_transform().origin.distance_to(pos) > STRUCTURE_REACH:
		survivor.notify("That's too far away.")
		return
	var ground: float = world.ground_height(pos.x, pos.z)
	if ground < 0.3 or absf(pos.y - ground) > 1.2:
		survivor.notify("You can't build there.")
		return
	var footprint: float = StructureTable.get_type(type).get("footprint", 1.0)
	for other: Dictionary in structures.values():
		var clearance: float = footprint + float(StructureTable.get_type(other.type).get("footprint", 1.0))
		if Vector2(other.pos.x, other.pos.z).distance_to(Vector2(pos.x, pos.z)) < clearance:
			survivor.notify("Too close to something you've already built.")
			return
	survivor.inventory.take_from_slot(slot, 1)
	var id := "s%d" % _next_structure
	_next_structure += 1
	_spawn_structure(id, type, pos, yaw)
	Net.send_to_ready(self, "_spawn_structure", [id, type, pos, yaw])
	survivor.notify("Built a %s." % String(StructureTable.get_type(type).name).to_lower())
	survivor.push_inventory()


@rpc("any_peer", "call_local", "reliable")
func request_wake() -> void:
	if not multiplayer.is_server():
		return
	var player := _sender_player()
	if player != null and sleeping.has(player.peer_id):
		_set_sleeping_for(player.peer_id, false)


# --- host → peers -------------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _spawn_structure(id: String, type: String, pos: Vector3, yaw: float) -> void:
	if structure_nodes.has(id):
		return
	structures[id] = {"type": type, "pos": pos, "yaw": yaw}
	var node := StructureNode.new()
	node.setup(id, type, pos, yaw)
	add_child(node)
	structure_nodes[id] = node
	var info := StructureTable.get_type(type)
	if info.has("station") and not stations.has("struct:" + id):
		stations["struct:" + id] = CookStation.new(info.station)
	if info.has("container") and not containers.has("struct:" + id):
		_make_container("struct:" + id, info.container, info.name)


@rpc("authority", "call_remote", "unreliable_ordered")
func _station_state(id: String, data: Dictionary) -> void:
	var station: CookStation = stations.get(id)
	if station == null:
		station = CookStation.new(data.get("mode", "cook"))
		stations[id] = station
	station.from_dict(data, Ocean.time)
	_apply_station_visual(id)


@rpc("authority", "call_remote", "reliable")
func _container_contents(id: String, title: String, data: Dictionary, opening: bool) -> void:
	var slots: Array = data.get("slots", [])
	var mirror: Inventory = containers.get(id)
	if mirror == null or mirror.slots.size() != slots.size():
		mirror = Inventory.new(slots.size())
		containers[id] = mirror
	mirror.from_dict(data)
	container_titles[id] = title
	if opening:
		open_container = id
		container_opened.emit(id, title)
	else:
		container_changed.emit(id)


@rpc("authority", "call_remote", "reliable")
func _set_picked(id: String) -> void:
	_apply_picked(id)


@rpc("authority", "call_remote", "reliable")
func _set_recipes(ids: Array) -> void:
	for id: String in ids:
		known_recipes[id] = true
	recipes_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _set_chart(value: bool) -> void:
	chart_read = value
	chart_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _set_unlocked(id: String) -> void:
	unlocked[id] = true


@rpc("authority", "call_remote", "reliable")
func _set_day_offset(offset: float) -> void:
	GameState.day_offset = offset


@rpc("authority", "call_remote", "reliable")
func _set_sleeping(asleep: bool) -> void:
	_apply_sleeping(asleep)
