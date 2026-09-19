class_name CampSystems
extends Node3D
## The crew's shared camp, owned by the host: storage grids (the fishing shack's
## sea chest, gear locker and footlocker, the john boat's dry box, crates,
## dropped bags), cooking and drying stations, placed and half-built
## structures, one-off pickups, recipes the crew knows, the sea chart, where
## each crew member respawns, and the vote to sleep through the night. It also
## applies every drag-and-drop item move. Clients keep mirrors and send requests.

signal container_opened(id: String, title: String)
signal cooking_opened(station_id: String, title: String)
signal container_changed(id: String)
signal container_closed(id: String)
signal recipes_changed
signal chart_changed
signal sleeping_changed(asleep: bool)
## seconds_left < 0 means no countdown is running.
signal sleep_status_changed(seconds_left: float, asleep: int, needed: int)

const STATION_TICK := 1.0
const SPOIL_CHECK := 5.0
const AUTOSAVE_SECONDS := 120.0
const STRUCTURE_REACH := 7.0
const CASTAWAY_TENT := "castaway_tent"
## Pushing a finished boat in: how far back up the beach it can start, and how
## hard the crew shove it.
const LAUNCH_RUN := 9.0
const LAUNCH_SPEED := 5.5
const SLEEP_HUNGER := 15.0
const SLEEP_THIRST := 20.0
const SLEEP_HEAL := 30.0
const BAG_SIZE := Vector2i(10, 8)
const BAG_MERGE_RANGE := 1.5
## How far from an open container a crew member can still move things in and out.
const CONTAINER_RANGE := 6.0
const SHACK_STORAGE := {
	"chest": {"title": "Sea chest", "size": Vector2i(10, 6)},
	"lockers": {"title": "Gear locker", "size": Vector2i(8, 6)},
	"footlocker": {"title": "Locked footlocker", "size": Vector2i(5, 4)},
}
const DRYBOX_SIZE := Vector2i(4, 3)
## °C of shelter inside the fishing shack, plus more while its stove burns.
const SHACK_WARMTH := 5.0
const STOVE_WARMTH := 6.0
## Saves from before the sloop was replaced by the fishing shack.
const SAVE_RENAMES := {
	"boat:Sailboat:chest": "shack:chest", "boat:Sailboat:lockers": "shack:lockers",
	"boat:Sailboat:compartment": "shack:footlocker", "boat:Sailboat:stove": "shack:stove",
}

const PICKUPS := {
	"machete": {"item": "machete", "count": 1, "label": "Take the machete"},
	"compartment_key": {"item": "compartment_key", "count": 1, "label": "Take the small brass key"},
	"journal": {"item": "journal", "count": 1, "label": "Take the journal"},
	"page_shelter": {"item": "book_page_shelter", "count": 1, "label": "Take the torn book page"},
	"page_camp": {"item": "book_page_camp", "count": 1, "label": "Take the torn book page"},
	"page_prosthetics": {"item": "book_page_prosthetics", "count": 1, "label": "Take the torn book page"},
}
## Offsets from the castaway camp (camp space: -Z faces the island centre).
const PICKUP_SPOTS := {
	"machete": Vector3(2.1, 0.35, 2.0),
	"compartment_key": Vector3(-0.5, 0.05, 0.3 - CampIslandPois.TENT_BACK),
	"journal": Vector3(0.3, 0.05, 0.2 - CampIslandPois.TENT_BACK),
	"page_shelter": Vector3(-1.6, 0.05, 1.3),
	"page_camp": Vector3(0.6, 0.05, -0.5 - CampIslandPois.TENT_BACK),
	"page_prosthetics": Vector3(-1.3, 0.05, -0.7),
}

const STASH := [["survival_book", 1], ["knife", 1], ["canteen", 1], ["lighter", 1], ["tarp", 1], ["paracord", 2],
	["logbook", 1], ["sea_chart", 1], ["fishing_rod", 1], ["lure", 3], ["flare_gun", 1], ["flare", 2], ["bandage", 4], ["sun_hat", 1]]
const LOCKER_CONTENTS := [["rain_jacket", 1], ["cargo_pants", 1], ["hiking_boots", 1], ["wool_beanie", 1], ["wool_sweater", 1], ["daypack", 1]]
const FOOTLOCKER_CONTENTS :=[["m1911", 1], ["ammo_45", 21], ["plate_carrier", 1], ["combat_helmet", 1]]

var world: Node3D
## id -> ItemGrid (the host's are the truth; clients mirror what they open)
var containers := {}
var container_titles := {}
## id -> CookStation
var stations := {}
## id -> {"type", "pos", "yaw"}
var structures := {}
## World-placed structures already put down once (never re-seeded).
var seeded := {}
## peer -> {"id", "since"}: who is holding the dismantle key on what.
var _dismantling := {}
var structure_nodes := {}
## id -> {"pos", "title"}
var bags := {}
var bag_nodes := {}
var pickup_nodes := {}
var picked := {}
var known_recipes := {}
var chart_read := false
var unlocked := {}
## player id -> {"kind": "shack"} or {"kind": "structure", "id"}
var respawns := {}
## FishingShack.layout() for this world (set by the world before anything else).
var shack := {}
var shack_glow: OmniLight3D
## peer id -> true (host)
var sleeping := {}
## Owner-side mirrors for the local player's UI.
var local_asleep := false
var open_container := ""
var sleep_status := {"left": -1.0, "asleep": 0, "needed": 0}

## container id -> {peer id: true}
var _viewers := {}
## peer id -> the container they have open
var _open_by_peer := {}
var _next_structure := 1
var _next_bag := 1
var _skip_at := 0.0
var _station_accum := 0.0
var _spoil_accum := 0.0
var _autosave_accum := 0.0


func _ready() -> void:
	world = get_parent()


# --- setup, sync and saves ----------------------------------------------------

## Host, fresh world: stock the fishing shack and the john boat, and teach the
## crew what they already know when they wash up.
func setup_new_world() -> void:
	_stock_shack()
	_seed_structures()
	stations["shack:stove"] = CookStation.new("cook")
	_make_container("boat:JohnBoat:drybox", DRYBOX_SIZE, "Dry box")
	for id: String in RecipeTable.KNOWN_AT_START:
		known_recipes[id] = true


func _stock_shack() -> void:
	var contents := {"chest": STASH, "lockers": LOCKER_CONTENTS, "footlocker": FOOTLOCKER_CONTENTS}
	for part: String in SHACK_STORAGE:
		var info: Dictionary = SHACK_STORAGE[part]
		var grid := _make_container("shack:" + part, info.size, info.title)
		for entry: Array in contents[part]:
			grid.add_stack(fresh_stack(entry[0], entry[1]))


## Where the n-th crew member stands when they wake in the shack.
func shack_spawn(index: int) -> Vector3:
	if shack.is_empty():
		return Vector3.ZERO
	var xf: Transform3D = shack.xf
	return xf * (FishingShack.SPAWN + Vector3((index % 3 - 1) * 0.6, 0.0, -int(index / 3.0) * 0.5))


## A new stack of `id` with its spoil time and charges filled in.
static func fresh_stack(id: String, count: int) -> Dictionary:
	var item := ItemTable.get_item(id)
	var spoil: float = item.get("spoil", 0.0)
	var stack := {"id": id, "count": count, "spoils_at": Ocean.time + spoil if spoil > 0.0 else 0.0}
	if item.has("uses"):
		stack["uses"] = int(item.uses)
	if item.has("weapon"):
		# A gun turns up loaded, in fair condition, on its first fire mode.
		var gun := WeaponMath.stats(String(item.weapon))
		stack["ammo"] = int(gun.mag)
		stack["condition"] = 0.85
		stack["mode"] = String(gun.modes[0])
		stack["attachments"] = {}
	return stack


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
		"bags": bags,
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
		var copy := ItemGrid.new()
		copy.from_dict((containers[id] as ItemGrid).to_dict())
		copy.shift_times(-now)
		saved_containers[id] = {"grid": copy.to_dict(), "title": container_titles.get(id, "")}
	return {
		"structures": structures.duplicate(true),
		"next_structure": _next_structure,
		"bags": bags.duplicate(true),
		"next_bag": _next_bag,
		"stations": saved_stations,
		"containers": saved_containers,
		"picked": picked.keys(),
		"recipes": known_recipes.keys(),
		"chart": chart_read,
		"unlocked": unlocked.keys(),
		"respawns": respawns.duplicate(true),
		"seeded": seeded.keys(),
	}


func from_save(data: Dictionary, now: float) -> void:
	var saved_structures: Dictionary = data.get("structures", {})
	for id: String in saved_structures:
		var entry: Dictionary = saved_structures[id]
		_spawn_structure(id, entry.type, entry.pos, entry.yaw)
		var progress: Dictionary = entry.get("progress", {})
		# Built before tents and fires went up in stages: they were already whole.
		if not entry.has("progress") and not StructureTable.get_type(entry.type).has("launches"):
			for stage: Dictionary in StructureTable.get_type(entry.type).get("stages", []):
				progress[stage.item] = int(stage.count)
		_apply_progress(id, progress)
		if entry.has("hp"):
			structures[id].hp = float(entry.hp)
	_next_structure = data.get("next_structure", _next_structure)
	for id: String in data.get("seeded", []):
		seeded[id] = true
	_seed_structures()
	var saved_containers: Dictionary = data.get("containers", {})
	for id: String in saved_containers:
		var entry: Dictionary = saved_containers[id]
		if not entry.has("grid"):
			continue  # saved before grid inventories; the stock is replaced below
		var grid := ItemGrid.new()
		grid.from_dict(entry.grid)
		grid.shift_times(now)
		var key: String = SAVE_RENAMES.get(id, id)
		containers[key] = grid
		container_titles[key] = SHACK_STORAGE[key.substr(6)].title if SHACK_STORAGE.has(key.substr(6)) and key.begins_with("shack:") else entry.get("title", "Storage")
	# Storage that grew since the save keeps its contents in the bigger grid.
	for part: String in SHACK_STORAGE:
		var size: Vector2i = SHACK_STORAGE[part].size
		var old: ItemGrid = containers.get("shack:" + part)
		if old != null and (old.width < size.x or old.height < size.y):
			var bigger := ItemGrid.new(size.x, size.y)
			for item: Dictionary in old.items:
				bigger.add_stack(item)
			containers["shack:" + part] = bigger
	if not containers.has("shack:chest"):
		_stock_shack()
	if not containers.has("boat:JohnBoat:drybox"):
		_make_container("boat:JohnBoat:drybox", DRYBOX_SIZE, "Dry box")
	var saved_bags: Dictionary = data.get("bags", {})
	for id: String in saved_bags:
		if containers.has("bag:" + id):
			_spawn_bag(id, saved_bags[id].pos, saved_bags[id].title)
	_next_bag = data.get("next_bag", _next_bag)
	var saved_stations: Dictionary = data.get("stations", {})
	for id: String in saved_stations:
		var station := CookStation.new()
		station.from_dict(saved_stations[id], now)
		var key: String = SAVE_RENAMES.get(id, id)
		stations[key] = station
		_apply_station_visual(key)
	if not stations.has("shack:stove"):
		stations["shack:stove"] = CookStation.new("cook")
	for id: String in data.get("picked", []):
		_apply_picked(id)
	for id: String in data.get("recipes", []):
		known_recipes[id] = true
	for id: String in RecipeTable.KNOWN_AT_START:
		known_recipes[id] = true
	chart_read = data.get("chart", false)
	for id: String in data.get("unlocked", []):
		unlocked[SAVE_RENAMES.get(id, id)] = true
	respawns = data.get("respawns", {})
	for player_id: String in respawns.keys():
		if respawns[player_id].get("kind", "") == "boat":
			respawns[player_id] = {"kind": "shack"}


func _make_container(id: String, size: Vector2i, title: String) -> ItemGrid:
	var grid := ItemGrid.new(size.x, size.y)
	containers[id] = grid
	container_titles[id] = title
	return grid


@rpc("authority", "call_remote", "reliable")
func _full_sync(data: Dictionary) -> void:
	for id: String in data.structures:
		var entry: Dictionary = data.structures[id]
		_spawn_structure(id, entry.type, entry.pos, entry.yaw)
		_apply_progress(id, entry.get("progress", {}))
		if entry.get("burning", false):
			_structure_burning(id, true)
	for id: String in data.bags:
		_spawn_bag(id, data.bags[id].pos, data.bags[id].title)
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


# --- the world's own structures, dismantling and damage ------------------------

## Structures the world starts with (the castaway's old tent). Each is placed once;
## after that it's the crew's to keep or take apart.
func _seed_structures() -> void:
	if world == null or world.camp_island == null:
		return
	if seeded.has(CASTAWAY_TENT):
		_move_old_castaway_tent()
		return
	seeded[CASTAWAY_TENT] = true
	var shape: CampIsland = world.camp_island
	var at: Vector3 = CampIslandPois.castaway_tent_spot(shape)
	var yaw: float = CampIslandPois.yaw_toward(shape.camp, shape.center)
	_spawn_structure(CASTAWAY_TENT, "tent", at, yaw)
	var whole := {}
	for stage: Dictionary in StructureTable.get_type("tent").stages:
		whole[stage.item] = int(stage.count)
	_apply_progress(CASTAWAY_TENT, whole)
	Net.send_to_ready(self, "_spawn_structure", [CASTAWAY_TENT, "tent", at, yaw])
	Net.send_to_ready(self, "_structure_progress", [CASTAWAY_TENT, whole])


## Worlds saved before the tent was moved back from the fire pit had it pitched
## right over the camp's middle; move it to where it stands now.
func _move_old_castaway_tent() -> void:
	var entry: Dictionary = structures.get(CASTAWAY_TENT, {})
	if entry.is_empty():
		return
	var shape: CampIsland = world.camp_island
	var old := Vector3(shape.camp.x, 0.0, shape.camp.y)
	var pos: Vector3 = entry.pos
	if Vector2(pos.x - old.x, pos.z - old.z).length() > 0.5:
		return
	var at: Vector3 = CampIslandPois.castaway_tent_spot(shape)
	entry.pos = at
	var node: StructureNode = structure_nodes.get(CASTAWAY_TENT)
	if node != null:
		node.position = at


## A crew member starts holding the dismantle key on a structure.
@rpc("any_peer", "call_local", "reliable")
func request_dismantle_start(id: String) -> void:
	if not multiplayer.is_server():
		return
	var player := _sender_player()
	if player == null or not structures.has(id):
		return
	_dismantling[player.peer_id] = {"id": id, "since": Time.get_ticks_msec() * 0.001}


## ...and held it long enough: take it apart and hand back most of what went into it.
@rpc("any_peer", "call_local", "reliable")
func request_dismantle(id: String) -> void:
	if not multiplayer.is_server():
		return
	var player := _sender_player()
	if player == null or not structures.has(id):
		return
	var started: Dictionary = _dismantling.get(player.peer_id, {})
	_dismantling.erase(player.peer_id)
	var held := Time.get_ticks_msec() * 0.001 - float(started.get("since", INF))
	if started.get("id", "") != id or held < StructureTable.DISMANTLE_SECONDS - 0.4:
		return
	var entry: Dictionary = structures[id]
	if player.world_transform().origin.distance_to(entry.pos) > STRUCTURE_REACH:
		return
	var name := String(StructureTable.get_type(entry.type).name).to_lower()
	var back := StructureTable.refund(entry.type, entry.get("progress", {}), StructureTable.DISMANTLE_SHARE)
	var left: Array = []
	for item: String in back:
		var over: int = player.survivor.inventory.add(item, int(back[item]), Ocean.time)
		if over > 0:
			left.append(fresh_stack(item, over))
	left.append_array(_contents_of(id))
	if not left.is_empty():
		drop_loot(Vector3(entry.pos) + Vector3.UP * 0.1, left, "the %s's things" % name)
	_take_down(id)
	world.sfx_at("chop", entry.pos)
	var got: Array[String] = []
	for item: String in back:
		got.append("%d %s" % [int(back[item]), _plural(item, int(back[item]))])
	player.survivor.notify("Took the %s apart%s." % [name, (": " + ", ".join(got)) if not got.is_empty() else ""])
	player.survivor.push_inventory()


## Host: weapons, fire and storms wear structures down; at nothing they fall apart,
## leaving a little of what they were made of (fire leaves nothing).
func damage_structure(id: String, amount: float, cause: String = "") -> void:
	if not multiplayer.is_server() or not structures.has(id) or amount <= 0.0:
		return
	var entry: Dictionary = structures[id]
	var hp := float(entry.get("hp", StructureTable.max_hp(entry.type))) - amount
	entry.hp = hp
	if hp > 0.0:
		return
	var name := String(StructureTable.get_type(entry.type).name).to_lower()
	var left: Array = []
	if cause != "fire":
		var back := StructureTable.refund(entry.type, entry.get("progress", {}), StructureTable.COLLAPSE_SHARE)
		for item: String in back:
			left.append(fresh_stack(item, int(back[item])))
		left.append_array(_contents_of(id))
	if not left.is_empty():
		drop_loot(Vector3(entry.pos) + Vector3.UP * 0.1, left, "what's left of the %s" % name)
	_take_down(id)
	world.sfx_at("tree_fall", entry.pos)
	_notify_crew("The %s %s." % [name, "burned down" if cause == "fire" else "fell apart"])


## Host: a structure catches fire (or the rain puts it out).
func set_structure_burning(id: String, on: bool) -> void:
	if not structures.has(id):
		return
	structures[id].burning = on
	_structure_burning(id, on)
	Net.send_to_ready(self, "_structure_burning", [id, on])
	if on:
		_notify_crew("The %s is on fire!" % String(StructureTable.get_type(structures[id].type).name).to_lower())


@rpc("authority", "call_remote", "reliable")
func _structure_burning(id: String, on: bool) -> void:
	if structures.has(id):
		structures[id].burning = on
	var node: StructureNode = structure_nodes.get(id)
	if node != null:
		node.set_burning(on)


## The structure id standing at (or nearest within `radius` of) a point, or "".
func structure_at(point: Vector3, radius: float) -> String:
	var best := ""
	var best_d := radius
	for id: String in structures:
		var entry: Dictionary = structures[id]
		var d := Vector2(entry.pos.x - point.x, entry.pos.z - point.z).length() - float(StructureTable.get_type(entry.type).get("footprint", 1.0)) * 0.5
		if d < best_d:
			best_d = d
			best = id
	return best


## What a structure was holding: a crate's contents, food on a fire or rack.
func _contents_of(id: String) -> Array:
	var out: Array = []
	var grid: ItemGrid = containers.get("struct:" + id)
	if grid != null:
		for item: Dictionary in grid.items:
			out.append(item.duplicate(true))
	var station: CookStation = stations.get("struct:" + id)
	if station != null:
		for slot in station.slots:
			if slot != null:
				out.append(fresh_stack(String(slot.id), 1))
	return out


func _take_down(id: String) -> void:
	_remove_structure(id)
	Net.send_to_ready(self, "_remove_structure", [id])


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
			if (containers[id] as ItemGrid).spoil_expired(Ocean.time):
				_push_container(id)
	_autosave_accum += delta
	if _autosave_accum >= AUTOSAVE_SECONDS:
		_autosave_accum = 0.0
		world.save_now()


## °C a crew member gains from nearby fires, shelters, or the fishing shack.
func warmth_for(player: Player) -> float:
	var at := player.world_transform().origin
	var warmth := 0.0
	for id: String in structures:
		var entry: Dictionary = structures[id]
		var info := StructureTable.get_type(entry.type)
		if at.distance_to(entry.pos) > float(info.get("warm_radius", 0.0)):
			continue
		if not StructureTable.is_finished(entry.type, entry.get("progress", {})):
			continue
		if info.has("warmth"):
			var station: CookStation = stations.get("struct:" + id)
			if station != null and station.lit:
				warmth = maxf(warmth, info.warmth)
		elif info.has("shelter"):
			warmth = maxf(warmth, info.shelter)
	if player.platform == null and FishingShack.contains(shack, at):
		var stove: CookStation = stations.get("shack:stove")
		warmth = maxf(warmth, SHACK_WARMTH + (STOVE_WARMTH if stove != null and stove.lit else 0.0))
	return warmth


func in_shack(p: Vector3) -> bool:
	return FishingShack.contains(shack, p)


# --- prompts (any peer, for the local player's crosshair) --------------------

func part_prompt(boat: Boat, part_name: String, _player: Node) -> String:
	match part_name:
		"drybox":
			return "Open the dry box"
		"cleat":
			if boat.is_tied():
				return "Untie the boat from the dock"
			return "Tie up to the dock" if _near_dock(boat) else "Bring her alongside the dock to tie up"
	return ""


func shack_prompt(part_name: String, player: Node) -> String:
	var container_id := "shack:" + part_name
	match part_name:
		"bunk":
			return "" if local_asleep else "Sleep in the bunk (sets your respawn)"
		"chest":
			return "Open the sea chest"
		"lockers":
			return "Open the gear locker"
		"footlocker":
			if unlocked.has(container_id):
				return "Open the footlocker"
			if player != null and player.survivor != null and player.survivor.inventory.count_of("compartment_key") > 0:
				return "Unlock the footlocker with the brass key"
			return "Locked footlocker — someone must have the key"
		"stove":
			return station_prompt(container_id, "Wood stove", player)
		"chart":
			return "Chart table — islands marked on your compass" if chart_read else "Study the chart on the table"
	return ""


func _near_dock(boat: Boat) -> bool:
	if shack.is_empty() or boat.kind != "john_boat":
		return false
	return boat.global_position.distance_to(Transform3D(shack.boat_xf).origin) < 6.0


func structure_prompt(id: String, player: Node) -> String:
	var entry: Dictionary = structures.get(id, {})
	if entry.is_empty():
		return ""
	var main := _structure_action(id, entry, player)
	var take_apart := "%s hold to take it apart" % Controls.tag("dismantle")
	return take_apart if main.is_empty() else "%s   ·   %s" % [main, take_apart]


func _structure_action(id: String, entry: Dictionary, player: Node) -> String:
	var info := StructureTable.get_type(entry.type)
	var progress: Dictionary = entry.get("progress", {})
	if StructureTable.takes_work(entry.type, progress):
		var stage := StructureTable.next_stage(entry.type, progress)
		if stage.is_empty():
			return "%s — push it into the water (hold)" % info.name
		var have := 0
		if player != null and player.survivor != null:
			have = RecipeTable.have(player.survivor.inventory, stage.item)
		return "%s — add %s (%d/%d)%s" % [info.name, _plural(stage.item, 2), int(progress.get(stage.item, 0)), int(stage.count),
			"" if have > 0 else " · you're not carrying any"]
	if info.has("station"):
		return station_prompt("struct:" + id, info.name, player)
	if info.has("container"):
		return "Open the %s" % String(info.name).to_lower()
	if info.get("sleep", false):
		return "" if local_asleep else "Sleep in the %s (sets your respawn)" % String(info.name).to_lower()
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
		return "%s — %s" % [title, "light it" if station.fuel > 0.0 else "hold wood and press to fuel it"]
	if station.needs_fire():
		return "%s — burning, %ds of fuel%s" % [title, int(station.fuel), " · cooking" if station.is_busy() else ""]
	return "%s — %s" % [title, "drying" if station.is_busy() else "hold raw food to dry it"]


static func held_item(player: Node) -> String:
	if player == null or player.survivor == null:
		return ""
	var slot = player.survivor.inventory.hotbar[player.survivor.selected_slot]
	return "" if slot == null else slot.id


# --- host: interactions --------------------------------------------------------

func interact_boat_part(survivor: Survivor, boat: Boat, part_name: String, _slot: int) -> void:
	var id := "boat:%s:%s" % [boat.name, part_name]
	var at: Vector3 = (boat.parts[part_name] as Node3D).global_position if boat.parts.has(part_name) else boat.global_position
	match part_name:
		"drybox":
			if containers.has(id):
				world.sfx_at("chest", at)
				open_container_for(survivor, id)
		"cleat":
			if boat.is_tied():
				world.set_boat_tied(boat, false)
				world.sfx_at("cloth", at)
				survivor.notify("You cast off. Carry an oar, press F to row — Q strokes left, E strokes right.")
			elif _near_dock(boat):
				world.set_boat_tied(boat, true)
				world.sfx_at("cloth", at)
				survivor.notify("Tied up at the dock.")
			else:
				survivor.notify("There's nothing to tie up to here — bring her back alongside the dock.")


func interact_shack_part(survivor: Survivor, part_name: String, slot: int) -> void:
	var id := "shack:" + part_name
	var at: Vector3 = shack.parts[part_name]
	match part_name:
		"bunk":
			request_sleep_at(survivor, {"kind": "shack"})
		"chest", "lockers":
			world.sfx_at("chest", at)
			open_container_for(survivor, id)
		"footlocker":
			if not unlocked.has(id):
				if survivor.inventory.count_of("compartment_key") == 0:
					survivor.notify("It's locked tight. Someone must have the key.")
					return
				unlocked[id] = true
				Net.send_to_ready(self, "_set_unlocked", [id])
				world.sfx_at("latch", at)
				survivor.notify("The brass key turns.")
			open_container_for(survivor, id)
		"stove":
			_use_station(survivor, id, slot, at)
		"chart":
			read_chart(survivor)


func interact_structure(survivor: Survivor, id: String, slot: int) -> void:
	var entry: Dictionary = structures.get(id, {})
	if entry.is_empty():
		return
	var info := StructureTable.get_type(entry.type)
	if StructureTable.takes_work(entry.type, entry.get("progress", {})):
		_work_build_site(survivor, id, entry)
	elif info.has("station"):
		_use_station(survivor, "struct:" + id, slot, entry.pos)
	elif info.has("container"):
		world.sfx_at("chest", entry.pos)
		open_container_for(survivor, "struct:" + id)
	elif info.get("sleep", false):
		request_sleep_at(survivor, {"kind": "structure", "id": id})


func pickup(survivor: Survivor, id: String) -> void:
	if picked.has(id) or not PICKUPS.has(id):
		return
	var entry: Dictionary = PICKUPS[id]
	if survivor.inventory.add(entry.item, entry.count, Ocean.time) > 0:
		survivor.notify("You have no room for that.")
		return
	var node: Node3D = pickup_nodes.get(id)
	if node != null:
		world.sfx_at("pickup", node.global_position)
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
	_notify_crew("%s learned how to make: %s  (open the book to craft)" % [survivor.player.display_name, ", ".join(fresh)])


func read_chart(survivor: Survivor) -> void:
	if chart_read:
		survivor.notify("The islands are already marked on your compass.")
		return
	chart_read = true
	Net.send_to_ready(self, "_set_chart", [true])
	chart_changed.emit()
	_notify_crew("%s studied the sea chart — nearby islands are marked on everyone's compass." % survivor.player.display_name)


func request_sleep_at(survivor: Survivor, spot: Dictionary) -> void:
	respawns[survivor.player.player_id] = spot
	if DayNight.is_day(GameState.time_of_day()):
		survivor.notify("Respawn point set here. You can sleep once night falls.")
		return
	sleeping[survivor.player.peer_id] = true
	_set_sleeping_for(survivor.player.peer_id, true)
	survivor.notify("Respawn point set. You settle in to sleep...")


func respawn_spot(player_id: String) -> Dictionary:
	var spot: Dictionary = respawns.get(player_id, {})
	match spot.get("kind", ""):
		"shack":
			if not shack.is_empty():
				return spot
		"structure":
			if structures.has(spot.id):
				return spot
	return {}


## Puts `player` at their respawn spot. False if they have none.
func teleport_to_spot(player: Player, spot: Dictionary) -> bool:
	match spot.get("kind", ""):
		"shack":
			player.teleport(shack_spawn(absi(hash(player.player_id)) % 3))
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
	var previous: String = _open_by_peer.get(peer, "")
	if not previous.is_empty() and _viewers.has(previous):
		_viewers[previous].erase(peer)
	if not _viewers.has(id):
		_viewers[id] = {}
	_viewers[id][peer] = true
	_open_by_peer[peer] = id
	_send_container(id, peer, true)


## Shows `survivor` what's cooking at `id`.
func open_cooking_for(survivor: Survivor, id: String, title: String = "") -> void:
	if not stations.has(id):
		return
	if title.is_empty():
		title = station_title(id)
	var peer := survivor.player.peer_id
	if peer == multiplayer.get_unique_id():
		cooking_opened.emit(id, title)
	else:
		_open_cooking.rpc_id(peer, id, title)


@rpc("authority", "call_remote", "reliable")
func _open_cooking(id: String, title: String) -> void:
	cooking_opened.emit(id, title)


## Takes one finished thing off a station (index -1 takes everything that's ready).
@rpc("any_peer", "call_local", "reliable")
func request_take_cooked(id: String, index: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	var player := world.players_root.get_node_or_null(str(sender)) as Player
	var station: CookStation = stations.get(id)
	if player == null or player.survivor == null or station == null:
		return
	var at := player.world_transform().origin
	var where := station_position(id)
	if where != Vector3.INF and at.distance_to(where) > STRUCTURE_REACH:
		return
	var survivor := player.survivor
	var now: float = Ocean.time
	var taken: PackedStringArray = []
	for i in CookStation.SLOTS:
		if index >= 0 and i != index:
			continue
		var slot = station.slots[i]
		if slot == null or now < float(slot.done_at):
			continue
		var result := String(slot.result)
		if survivor.inventory.add(result, 1, now) > 0:
			survivor.notify("You have no room for the %s." % ItemTable.display_name(result).to_lower())
			continue
		station.slots[i] = null
		taken.append(ItemTable.display_name(result))
	if taken.is_empty():
		return
	survivor.notify("Took " + ", ".join(taken))
	world.sfx_at("pot", where if where != Vector3.INF else at)
	survivor.push_inventory()
	_broadcast_station(id)


## What to call a station in the cooking panel.
func station_title(id: String) -> String:
	if id == "shack:stove":
		return "Wood stove"
	if id.begins_with("struct:"):
		var structure: Dictionary = structures.get(id.substr(7), {})
		var kind: String = structure.get("type", "")
		return String(StructureTable.TYPES.get(kind, {}).get("name", "Fire"))
	return "Fire"


## Where a station stands, or Vector3.INF if we can't say.
func station_position(id: String) -> Vector3:
	if id.begins_with("struct:"):
		var node: Node3D = structure_nodes.get(id.substr(7))
		return node.global_position if node != null else Vector3.INF
	if id == "shack:stove" and not shack.is_empty():
		return shack.parts.get("stove", Vector3.INF)
	return Vector3.INF


func forget_peer(peer_id: int) -> void:
	sleeping.erase(peer_id)
	_open_by_peer.erase(peer_id)
	for id: String in _viewers:
		_viewers[id].erase(peer_id)


## Host: leaves stacks in the world near `player`. Aboard a boat with a dry box
## they go in there first, so nothing is left hanging over the water.
func drop_items(player: Player, stacks: Array, title: String) -> void:
	var left: Array = []
	var box_id := "boat:%s:drybox" % player.platform.name if player.platform != null else ""
	if containers.has(box_id):
		var box: ItemGrid = containers[box_id]
		for stack: Dictionary in stacks:
			var remaining := box.add_stack(stack)
			if remaining > 0:
				var rest := stack.duplicate()
				rest.count = remaining
				left.append(rest)
		if left.size() < stacks.size() or _total(left) < _total(stacks):
			_push_container(box_id)
			player.survivor.notify("Stowed in the dry box.")
		if left.is_empty():
			return
	else:
		left = stacks
	var at := player.world_transform().origin
	var ground: float = world.ground_height(at.x, at.z)
	var pos := Vector3(at.x, 0.15, at.z) if ground == -INF or at.y < 0.0 else Vector3(at.x, maxf(at.y, ground) + 0.05, at.z)
	drop_loot(pos, left, title)


## Host: leaves `stacks` in a bag at `pos` — merged into a bag already there, and
## spilling into more bags when one is full.
func drop_loot(pos: Vector3, stacks: Array, title: String) -> void:
	var pending: Array = stacks
	for id: String in bags:
		if Vector3(bags[id].pos).distance_to(pos) < BAG_MERGE_RANGE:
			pending = _fill_bag(id, pending)
			break
	# Whatever doesn't fit spills into more bags in a ring around the spot.
	var spill := 0
	while not pending.is_empty():
		var id := "b%d" % _next_bag
		_next_bag += 1
		var spot := pos
		if spill > 0:
			var angle := spill * 2.4
			spot += Vector3(cos(angle), 0.0, sin(angle)) * (0.9 + 0.25 * spill)
			var ground_here: float = world.ground_height(spot.x, spot.z)
			if ground_here != -INF and pos.y > 0.2:
				spot.y = maxf(pos.y - 0.5, ground_here) + 0.05
		_make_container("bag:" + id, BAG_SIZE, title)
		_spawn_bag(id, spot, title)
		Net.send_to_ready(self, "_spawn_bag", [id, spot, title])
		var before := _total(pending)
		pending = _fill_bag(id, pending)
		spill += 1
		if _total(pending) == before:
			push_warning("An item is too big for any bag: %s" % str(pending))
			break
	world.sfx_at("drop", pos)


## Puts `stacks` into bag `id`; returns what didn't fit.
func _fill_bag(id: String, stacks: Array) -> Array:
	var bag: ItemGrid = containers["bag:" + id]
	var rest: Array = []
	for stack: Dictionary in stacks:
		var remaining := bag.add_stack(stack)
		if remaining > 0:
			var piece := stack.duplicate()
			piece.count = remaining
			rest.append(piece)
	_push_container("bag:" + id)
	return rest


static func _total(stacks: Array) -> int:
	var total := 0
	for stack: Dictionary in stacks:
		total += int(stack.count)
	return total


func _use_station(survivor: Survivor, id: String, slot: int, at: Vector3) -> void:
	var station: CookStation = stations.get(id)
	if station == null:
		return
	var now: float = Ocean.time
	var pack := survivor.inventory
	var held = pack.hotbar[slot]
	if held == null:
		# Empty-handed: strike a light if it needs one, otherwise see what's on.
		if not _light_station(survivor, station, id, at, true):
			open_cooking_for(survivor, id)
		return
	var held_id: String = "" if held == null else held.id
	var item := ItemTable.get_item(held_id)
	if station.needs_fire() and item.has("fuel"):
		if station.add_fuel(item.fuel):
			pack.take(int(held.uid), 1)
			survivor.notify("Added %s — %ds of fuel" % [String(item.name).to_lower(), int(station.fuel)])
			world.sfx_at("thud", at)
			survivor.push_inventory()
			_broadcast_station(id)
		else:
			survivor.notify("It can't take any more fuel.")
		return
	if not station.result_for(held_id).is_empty():
		if station.needs_fire() and not station.lit:
			survivor.notify("Light the fire first.")
		elif station.start(held_id, now):
			pack.take(int(held.uid), 1)
			survivor.notify("%s the %s..." % ["Drying" if station.mode == "dry" else "Heating", String(item.name).to_lower()])
			world.sfx_at("pot", at)
			survivor.push_inventory()
			_broadcast_station(id)
		else:
			survivor.notify("There's no room for more.")
		return
	if station.needs_fire() and not station.lit:
		_light_station(survivor, station, id, at, false)
		return
	survivor.notify("Hold food to cook, water to boil, or wood to burn — then press on it.")


## Tries to light `station` with a lighter from the pack. `quiet` keeps it silent
## when there's nothing to light, so pressing on a burning fire opens it instead.
func _light_station(survivor: Survivor, station: CookStation, id: String, at: Vector3, quiet: bool) -> bool:
	if not station.needs_fire() or station.lit:
		return false
	var pack := survivor.inventory
	if station.fuel <= 0.0:
		if not quiet:
			survivor.notify("Hold driftwood or a log and press on it to add fuel.")
		return false
	var lighter := pack.find_first("lighter")
	if lighter.is_empty():
		if not quiet:
			survivor.notify("You need something to light it with.")
		return false
	station.light()
	lighter.uses = int(lighter.get("uses", 1)) - 1
	if lighter.uses <= 0:
		pack.take(int(lighter.uid))
		survivor.notify("The fire catches — and the lighter sputters out for good.")
	else:
		survivor.notify("The fire catches. (Lighter: %d uses left)" % lighter.uses)
	world.sfx_at("stone", at)
	survivor.push_inventory()
	_broadcast_station(id)
	return true


func _check_sleep() -> void:
	var day := DayNight.is_day(GameState.time_of_day())
	if day or sleeping.is_empty():
		if not sleeping.is_empty():
			_wake_everyone()
		if _skip_at > 0.0 or sleep_status.left >= 0.0 or sleep_status.asleep > 0:
			_skip_at = 0.0
			_send_sleep_status(-1.0, 0, 0)
		return
	var crew := 0
	for id: int in Net.roster:
		if Net.roster[id].get("ready", false):
			crew += 1
	var needed := SleepVote.needed(crew)
	if not SleepVote.enough(sleeping.size(), crew):
		_skip_at = 0.0
		_send_sleep_status(-1.0, sleeping.size(), needed)
		return
	if _skip_at <= 0.0:
		_skip_at = Ocean.time + (1.5 if crew == 1 else SleepVote.COUNTDOWN)
	var left: float = _skip_at - Ocean.time
	_send_sleep_status(maxf(0.0, left), sleeping.size(), needed)
	if left > 0.0:
		return
	_skip_at = 0.0
	var advance := fposmod(DayNight.SUNRISE + 0.005 - GameState.time_of_day(), 1.0)
	GameState.day_offset += advance
	Net.send_to_ready(self, "_set_day_offset", [GameState.day_offset])
	for player: Player in world.players_root.get_children():
		var s := player.survivor
		s.survival.hunger = maxf(0.0, s.survival.hunger - SLEEP_HUNGER)
		s.survival.thirst = maxf(0.0, s.survival.thirst - SLEEP_THIRST)
		if sleeping.has(player.peer_id):
			s.survival.heal(SLEEP_HEAL)
			s.notify("The crew sleeps through the night. You wake at dawn, rested but hungry.")
		else:
			s.notify("The night passes while the crew sleeps. Dawn breaks.")
		s.push_survival()
	_wake_everyone()
	_send_sleep_status(-1.0, 0, needed)


func _wake_everyone() -> void:
	for id: int in sleeping.keys():
		_set_sleeping_for(id, false)
	sleeping.clear()


func _send_sleep_status(left: float, asleep: int, needed: int) -> void:
	_apply_sleep_status(left, asleep, needed)
	Net.send_to_ready(self, "_sleep_status", [left, asleep, needed])


func _apply_sleep_status(left: float, asleep: int, needed: int) -> void:
	sleep_status = {"left": left, "asleep": asleep, "needed": needed}
	sleep_status_changed.emit(left, asleep, needed)


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
	elif id == "shack:stove" and shack_glow != null:
		shack_glow.visible = station.lit


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
		_container_contents.rpc_id(peer, id, container_titles.get(id, "Storage"), (containers[id] as ItemGrid).to_dict(), opening)


## Host: an emptied bag vanishes for everyone, closing it on anyone looking inside.
func _remove_bag_if_empty(id: String) -> void:
	if not id.begins_with("bag:") or not containers.has(id) or not (containers[id] as ItemGrid).is_empty():
		return
	for peer: int in _viewers.get(id, {}):
		_open_by_peer.erase(peer)
		if peer == multiplayer.get_unique_id():
			_close_container(id)
		else:
			_container_gone.rpc_id(peer, id)
	_viewers.erase(id)
	_remove_bag(id.substr(4))
	Net.send_to_ready(self, "_remove_bag", [id.substr(4)])


func _sender_player() -> Player:
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	return world.players_root.get_node_or_null(str(sender)) as Player


## The pack, or a container this player has open and is still near. Null if not allowed.
func _source_for(player: Player, container_id: String) -> Object:
	if container_id.is_empty():
		return player.survivor.inventory
	if _may_use(player, container_id):
		return containers[container_id]
	return null


## Has this player opened container `id`, and are they still within reach of it?
func _may_use(player: Player, id: String) -> bool:
	if not containers.has(id) or not _viewers.get(id, {}).has(player.peer_id):
		return false
	var bits := id.split(":")
	var spot := Vector3.INF
	match bits[0]:
		"boat":
			var boat: Boat = world.find_boat(bits[1])
			if boat != null and bits.size() > 2 and boat.parts.has(bits[2]):
				spot = (boat.parts[bits[2]] as Node3D).global_position
		"shack":
			if bits.size() > 1 and shack.get("parts", {}).has(bits[1]):
				spot = shack.parts[bits[1]]
		"struct":
			if structures.has(bits[1]):
				spot = structures[bits[1]].pos
		"bag":
			if bags.has(bits[1]):
				spot = bags[bits[1]].pos
	return spot == Vector3.INF or player.world_transform().origin.distance_to(spot) <= CONTAINER_RANGE


## Turns a UI drop target into an ItemMoves place. Empty if not allowed.
## {"area": "hotbar", "index"} · {"area": "pockets"|"rig"|"backpack", "x", "y", "rot"}
## · {"area": "container", "container", "x", "y", "rot"}
func _place_for(player: Player, target: Dictionary) -> Dictionary:
	var pack := player.survivor.inventory
	var area: String = target.get("area", "")
	if area == "hotbar":
		return {"kind": "hotbar", "pack": pack, "index": int(target.get("index", -1))}
	var grid: ItemGrid = null
	if area == "container":
		var id: String = target.get("container", "")
		if _may_use(player, id):
			grid = containers[id]
	else:
		grid = pack.grid(area)
	if grid == null:
		return {}
	return {"kind": "grid", "grid": grid, "x": int(target.get("x", 0)), "y": int(target.get("y", 0)), "rot": bool(target.get("rot", false))}


func _after_item_change(player: Player, container_ids: Array) -> void:
	player.survivor.push_inventory()
	for id in container_ids:
		if not String(id).is_empty() and containers.has(id):
			_push_container(id)
			_remove_bag_if_empty(id)


# --- requests from crew members (host validates) ------------------------------

## Drag and drop: move `count` (0 = all) of item `uid` from the pack ("") or an
## open container to `target`.
@rpc("any_peer", "call_local", "reliable")
func request_move_item(source_container: String, uid: int, count: int, target: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var player := _sender_player()
	if player == null:
		return
	var source := _source_for(player, source_container)
	var place := _place_for(player, target)
	if source == null or place.is_empty():
		return
	ItemMoves.move(source, uid, count, place)
	_after_item_change(player, [source_container, target.get("container", "")])


## Ctrl-click / controller Y: send an item across — pack ⇄ open container, or
## hotbar ⇄ storage when nothing is open.
@rpc("any_peer", "call_local", "reliable")
func request_quick_move(source_container: String, uid: int) -> void:
	if not multiplayer.is_server():
		return
	var player := _sender_player()
	if player == null:
		return
	var pack := player.survivor.inventory
	var open: String = _open_by_peer.get(player.peer_id, "")
	if not source_container.is_empty():
		var source := _source_for(player, source_container)
		if source != null:
			ItemMoves.quick_move(source, uid, pack)
		_after_item_change(player, [source_container])
		return
	if not open.is_empty() and containers.has(open):
		ItemMoves.quick_move(pack, uid, containers[open])
		_after_item_change(player, [open])
		return
	var where := pack.locate(uid)
	if where.is_empty():
		return
	if where.area == "hotbar":
		var piece := pack.take(uid)
		var left := pack.add_to_storage(piece)
		if left > 0:
			var rest := piece.duplicate()
			rest.count = left
			pack.hotbar[where.index] = rest
	else:
		var index := pack.hotbar.find(null)
		if index >= 0:
			ItemMoves.move(pack, uid, 0, {"kind": "hotbar", "pack": pack, "index": index})
	_after_item_change(player, [])


@rpc("any_peer", "call_local", "reliable")
func request_split_item(source_container: String, uid: int) -> void:
	if not multiplayer.is_server():
		return
	var player := _sender_player()
	if player == null:
		return
	var source := _source_for(player, source_container)
	if source is ItemGrid:
		source.split(uid)
	elif source is Pack:
		var where: Dictionary = source.locate(uid)
		if where.is_empty():
			return
		if where.area == "hotbar":
			var stack: Dictionary = source.hotbar[where.index]
			if int(stack.count) >= 2:
				var half: Dictionary = source.take(uid, int(stack.count) / 2)
				var left: int = source.add_to_storage(half)
				if left > 0:
					stack.count += left
		else:
			source.grid(where.area).split(uid)
	_after_item_change(player, [source_container])


@rpc("any_peer", "call_local", "reliable")
func request_drop_item(source_container: String, uid: int) -> void:
	if not multiplayer.is_server():
		return
	var player := _sender_player()
	if player == null:
		return
	var source := _source_for(player, source_container)
	if source == null:
		return
	var stack: Dictionary = source.take(uid)
	if stack.is_empty():
		return
	drop_items(player, [stack], "%s's dropped items" % player.display_name)
	_after_item_change(player, [source_container])


@rpc("any_peer", "call_local", "reliable")
func request_wear_item(source_container: String, uid: int) -> void:
	if not multiplayer.is_server():
		return
	var player := _sender_player()
	if player == null:
		return
	if not source_container.is_empty():
		# Pull it into the pack first so wearing works the same from anywhere.
		var source := _source_for(player, source_container)
		if source == null:
			return
		var stack: Dictionary = source.take(uid)
		if stack.is_empty() or ItemTable.category(stack.id) != "wearable":
			if not stack.is_empty():
				source.add_stack(stack)
			return
		var pack := player.survivor.inventory
		var index := pack.hotbar.find(null)
		if index >= 0:
			pack.hotbar[index] = stack
		elif pack.add_to_storage(stack) > 0:
			source.add_stack(stack)
			player.survivor.notify("Make some room in your pack to put that on.")
			_after_item_change(player, [source_container])
			return
		uid = int(pack.find_first(stack.id).get("uid", 0)) if pack.get_stack(int(stack.uid)).is_empty() else int(stack.uid)
		_push_container(source_container)
	player.survivor.wear(uid)
	_after_item_change(player, [source_container])


@rpc("any_peer", "call_local", "reliable")
func request_close(id: String) -> void:
	if not multiplayer.is_server():
		return
	var player := _sender_player()
	if player != null and _viewers.has(id):
		_viewers[id].erase(player.peer_id)
		if _open_by_peer.get(player.peer_id, "") == id:
			_open_by_peer.erase(player.peer_id)


@rpc("any_peer", "call_local", "reliable")
func request_craft(recipe_id: String) -> void:
	if not multiplayer.is_server():
		return
	var player := _sender_player()
	if player == null or not known_recipes.has(recipe_id):
		return
	var survivor := player.survivor
	var tool := RecipeTable.missing_tool(survivor.inventory, recipe_id)
	if not tool.is_empty():
		survivor.notify("You need a %s to make that." % tool)
		return
	if not RecipeTable.can_craft(survivor.inventory, recipe_id):
		survivor.notify("You don't have everything for that.")
		return
	var recipe: Dictionary = RecipeTable.RECIPES[recipe_id]
	# Try it on a copy first, then do the same to the real pack (which the UI and
	# everything else hold on to) only if the result fits.
	var trial := Pack.new()
	trial.from_dict(survivor.inventory.to_dict())
	RecipeTable.consume(trial, recipe_id)
	if trial.add(recipe.makes, recipe.count, Ocean.time) > 0:
		survivor.notify("You have no room for that.")
		return
	RecipeTable.consume(survivor.inventory, recipe_id)
	survivor.inventory.add(recipe.makes, recipe.count, Ocean.time)
	survivor.notify("Made: %s" % recipe.name)
	survivor.push_inventory()


@rpc("any_peer", "call_local", "reliable")
func request_place(slot: int, pos: Vector3, yaw: float) -> void:
	if not multiplayer.is_server():
		return
	var player := _sender_player()
	if player == null or slot < 0 or slot >= Pack.HOTBAR_SIZE:
		return
	var survivor := player.survivor
	var stack = survivor.inventory.hotbar[slot]
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
	if StructureTable.get_type(type).get("shore", false) and (ground > StructureTable.SHORE_MAX_HEIGHT or world.water_spot(pos).is_empty()):
		survivor.notify("Build that on the beach, close to the water.")
		return
	var footprint: float = StructureTable.get_type(type).get("footprint", 1.0)
	for other: Dictionary in structures.values():
		var clearance: float = footprint + float(StructureTable.get_type(other.type).get("footprint", 1.0))
		if Vector2(other.pos.x, other.pos.z).distance_to(Vector2(pos.x, pos.z)) < clearance:
			survivor.notify("Too close to something you've already built.")
			return
	survivor.inventory.take(int(stack.uid), 1)
	var id := "s%d" % _next_structure
	_next_structure += 1
	_spawn_structure(id, type, pos, yaw)
	Net.send_to_ready(self, "_spawn_structure", [id, type, pos, yaw])
	world.sfx_at("thud", pos)
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
		_make_container("struct:" + id, Vector2i(info.container[0], info.container[1]), info.name)


@rpc("authority", "call_remote", "reliable")
func _remove_structure(id: String) -> void:
	structures.erase(id)
	stations.erase("struct:" + id)
	containers.erase("struct:" + id)
	var node: Node = structure_nodes.get(id)
	if node != null:
		node.queue_free()
	structure_nodes.erase(id)


@rpc("authority", "call_remote", "reliable")
func _structure_progress(id: String, progress: Dictionary) -> void:
	_apply_progress(id, progress)


func _apply_progress(id: String, progress: Dictionary) -> void:
	if not structures.has(id):
		return
	structures[id].progress = progress
	var node: StructureNode = structure_nodes.get(id)
	if node != null:
		node.set_progress(progress)


## Host: add whatever the build site's current stage needs from the crew member's pack,
## or push the finished boat into the water.
func _work_build_site(survivor: Survivor, id: String, entry: Dictionary) -> void:
	var progress: Dictionary = entry.get("progress", {}).duplicate()
	var stage := StructureTable.next_stage(entry.type, progress)
	if stage.is_empty():
		_launch(survivor, id, entry)
		return
	var item: String = stage.item
	var needed: int = int(stage.count) - int(progress.get(item, 0))
	var adding := mini(needed, RecipeTable.have(survivor.inventory, item))
	if adding <= 0:
		survivor.notify("It still needs %d %s." % [needed, _plural(item, needed)])
		return
	_take_need(survivor.inventory, item, adding)
	progress[item] = int(progress.get(item, 0)) + adding
	_apply_progress(id, progress)
	Net.send_to_ready(self, "_structure_progress", [id, progress])
	world.sfx_at("thud", entry.pos)
	var next := StructureTable.next_stage(entry.type, progress)
	if next.is_empty():
		if StructureTable.get_type(entry.type).has("launches"):
			_notify_crew("The raft is lashed together. Hold E on it to push it into the water.")
		else:
			_notify_crew("%s finished the %s." % [survivor.player.display_name, String(StructureTable.get_type(entry.type).name).to_lower()])
	elif next.item != item:
		survivor.notify("Added %d %s. Now it needs %d %s." % [adding, _plural(item, adding), int(next.count), _plural(next.item, int(next.count))])
	else:
		survivor.notify("Added %d %s (%d/%d)." % [adding, _plural(item, adding), int(progress[item]), int(stage.count)])
	survivor.push_inventory()


func _launch(survivor: Survivor, id: String, entry: Dictionary) -> void:
	var spot: Dictionary = world.water_spot(entry.pos)
	if spot.is_empty():
		survivor.notify("There's no open water close enough to push it into.")
		return
	var dir: Vector2 = spot.dir
	var pos: Vector3 = spot.pos
	# Don't launch a new raft on top of one already floating there.
	var sideways := Vector3(-dir.y, 0.0, dir.x)
	for attempt in 6:
		var clear := true
		for boat: Boat in world.boats_root.get_children():
			if Vector2(boat.global_position.x, boat.global_position.z).distance_to(Vector2(pos.x, pos.z)) < 4.5:
				clear = false
		if clear:
			break
		pos += sideways * 4.5
	# It starts where it was built and is shoved down the sand into the water,
	# rather than appearing out there already afloat.
	var start: Vector3 = entry.pos
	start.y = maxf(start.y, pos.y) + 0.25
	if Vector2(start.x - pos.x, start.z - pos.z).length() > LAUNCH_RUN:
		start = pos + Vector3(-dir.x, 0.0, -dir.y) * LAUNCH_RUN + Vector3.UP * 0.25
	var xf := Transform3D(Basis(Vector3.UP, atan2(-dir.x, -dir.y)), start)
	var boat: Boat = world.launch_boat(StructureTable.get_type(entry.type).get("launches", "raft"), xf)
	if boat != null:
		boat.shove(Vector3(dir.x, 0.0, dir.y) * LAUNCH_SPEED)
	_remove_structure(id)
	Net.send_to_ready(self, "_remove_structure", [id])
	world.sfx_at("thud", entry.pos)
	_notify_crew("%s pushed the raft into the water! Climb aboard with an oar and press F to row — Q and E stroke." % survivor.player.display_name)


## Take `count` of an item or a group ("wood" = any driftwood or logs).
static func _take_need(inventory: Pack, need: String, count: int) -> void:
	var left := count
	for item: String in ItemTable.GROUPS.get(need, [need]):
		var take := mini(left, inventory.count_of(item))
		if take > 0:
			inventory.remove(item, take)
			left -= take


static func _plural(item: String, count: int) -> String:
	var name := RecipeTable.need_label(item).to_lower()
	return name if count == 1 or name.ends_with("s") else name + "s"


@rpc("authority", "call_remote", "reliable")
func _spawn_bag(id: String, pos: Vector3, title: String) -> void:
	if bag_nodes.has(id):
		return
	bags[id] = {"pos": pos, "title": title}
	var node := BagNode.new()
	node.setup(id, title, pos)
	add_child(node)
	bag_nodes[id] = node


@rpc("authority", "call_remote", "reliable")
func _remove_bag(id: String) -> void:
	bags.erase(id)
	containers.erase("bag:" + id)
	var node: Node = bag_nodes.get(id)
	if node != null:
		node.queue_free()
	bag_nodes.erase(id)


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
	var mirror: ItemGrid = containers.get(id)
	if mirror == null:
		mirror = ItemGrid.new()
		containers[id] = mirror
	mirror.from_dict(data)
	container_titles[id] = title
	if opening:
		open_container = id
		container_opened.emit(id, title)
	else:
		container_changed.emit(id)


@rpc("authority", "call_remote", "reliable")
func _container_gone(id: String) -> void:
	_close_container(id)


func _close_container(id: String) -> void:
	if open_container == id:
		open_container = ""
	container_closed.emit(id)


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


@rpc("authority", "call_remote", "unreliable_ordered")
func _sleep_status(left: float, asleep: int, needed: int) -> void:
	_apply_sleep_status(left, asleep, needed)
