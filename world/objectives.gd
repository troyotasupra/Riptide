class_name Objectives
extends RefCounted
## A light guide from the starter island to the camp island, shown on the HUD.
## Each objective is checked against what the local player can see; once met it stays met.

const LIST := [
	["gather", "Gather fiber, flint and driftwood on the beach"],
	["rope", "Twist fiber into rope (B opens your crafting book)"],
	["hatchet", "Make a stone hatchet and chop down a tree for logs"],
	["oar", "Carve an oar"],
	["raft_site", "Place a raft frame on the beach near the water"],
	["raft", "Add logs and rope lashings, then launch the raft"],
	["reach_camp", "Row to the island under the smoke (F to row, Q/E strokes)"],
	["shack", "Find the fishing shack and read the survival book"],
	["castaway_camp", "Search the castaway camp inland"],
	["unlock", "Unlock the footlocker in the fishing shack"],
	["campfire", "Build a campfire"],
	["cook", "Cook food or boil water on a fire"],
	["sleep", "Sleep through the night in a bed"],
	["john_boat", "Untie the john boat at the dock and take it out"],
]


static func check(id: String, world: Node, player: Player) -> bool:
	var camp: CampSystems = world.camp
	var inventory := player.survivor.inventory
	match id:
		"gather":
			return inventory.count_of("fiber") > 0 or inventory.count_of("flint") > 0 or inventory.count_of("driftwood") > 0
		"rope":
			return inventory.count_of("rope") > 0
		"hatchet":
			return inventory.count_of("log") > 0
		"oar":
			return inventory.count_of("oar") > 0
		"raft_site":
			for entry: Dictionary in camp.structures.values():
				if entry.type == "raft_site":
					return true
			return _has_boat(world, "raft")
		"raft":
			return _has_boat(world, "raft")
		"reach_camp":
			var at := player.world_transform().origin
			return world.camp_island != null and Vector2(at.x, at.z).distance_to(world.camp_island.center) < CampIsland.RADIUS * 1.1
		"shack":
			return camp.known_recipes.has("campfire_kit")
		"castaway_camp":
			return camp.picked.has("machete") or camp.picked.has("compartment_key") or camp.picked.has("journal")
		"unlock":
			return camp.unlocked.has("shack:footlocker")
		"campfire":
			for entry: Dictionary in camp.structures.values():
				if entry.type == "campfire":
					return true
		"cook":
			for item: String in ["cooked_fish", "cooked_meat", "canteen_clean", "dried_fish", "dried_meat", "dried_berries"]:
				if inventory.count_of(item) > 0:
					return true
		"sleep":
			return camp.local_asleep
		"john_boat":
			var boat: Boat = world.find_boat("JohnBoat")
			return boat != null and not boat.is_tied() and player.platform == boat
	return false


static func _has_boat(world: Node, kind: String) -> bool:
	for boat: Boat in world.boats_root.get_children():
		if boat.kind == kind:
			return true
	return false


## The next `count` objectives still to do.
static func upcoming(world: Node, player: Player, count: int = 3) -> PackedStringArray:
	var done: Dictionary = GameState.objectives_done
	for entry: Array in LIST:
		if not done.has(entry[0]) and check(entry[0], world, player):
			done[entry[0]] = true
	# Anyone who has reached the camp island is past the starter island's steps.
	if done.has("reach_camp") or done.has("shack"):
		for id: String in ["gather", "rope", "hatchet", "oar", "raft_site", "raft", "reach_camp"]:
			done[id] = true
	var out: PackedStringArray = []
	for entry: Array in LIST:
		if not done.has(entry[0]):
			out.append(entry[1])
			if out.size() >= count:
				break
	return out
