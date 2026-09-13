class_name Objectives
extends RefCounted
## A light guide through the first island, shown on the HUD. Each objective is
## checked against what the local player can see; once met it stays met.

const LIST := [
	["reach_camp", "Paddle the raft to the island under the smoke"],
	["board_sailboat", "Swim out to the moored sailboat and climb aboard"],
	["read_book", "Find the survival book in the sea chest and read it"],
	["castaway_camp", "Search the castaway camp inland"],
	["unlock", "Unlock the compartment in the sailboat's cabin"],
	["campfire", "Build a campfire"],
	["cook", "Cook food or boil water on a fire"],
	["sleep", "Sleep through the night in a bed"],
	["hatchet", "Make a stone hatchet and chop down a tree"],
	["repair", "Repair the sailboat (next update)"],
]


static func check(id: String, world: Node, player: Player) -> bool:
	var camp: CampSystems = world.camp
	var inventory := player.survivor.inventory
	match id:
		"reach_camp":
			var at := player.world_transform().origin
			return world.camp_island != null and Vector2(at.x, at.z).distance_to(world.camp_island.center) < CampIsland.RADIUS * 1.1
		"board_sailboat":
			return player.platform is Sailboat
		"read_book":
			return not camp.known_recipes.is_empty()
		"castaway_camp":
			return camp.picked.has("machete") or camp.picked.has("compartment_key") or camp.picked.has("journal")
		"unlock":
			return camp.unlocked.has("boat:Sailboat:compartment")
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
		"hatchet":
			return inventory.count_of("log") > 0
	return false


## The next `count` objectives still to do.
static func upcoming(world: Node, player: Player, count: int = 3) -> PackedStringArray:
	var done: Dictionary = GameState.objectives_done
	for entry: Array in LIST:
		if not done.has(entry[0]) and check(entry[0], world, player):
			done[entry[0]] = true
	if done.has("read_book"):
		done["reach_camp"] = true
		done["board_sailboat"] = true
	var out: PackedStringArray = []
	for entry: Array in LIST:
		if not done.has(entry[0]):
			out.append(entry[1])
			if out.size() >= count:
				break
	return out
