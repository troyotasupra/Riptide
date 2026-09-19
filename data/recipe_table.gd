class_name RecipeTable
extends RefCounted
## What the crew can make. Everyone washes up knowing KNOWN_AT_START — enough to
## get off the starter island. Reading the survival book (in the fishing shack on
## the camp island) teaches STARTING to the whole crew; book pages teach the rest.
## A need can name an item or a group from ItemTable.GROUPS ("wood" = driftwood or logs).
## `tool`: a tool type that must be carried (not used up).

const KNOWN_AT_START := ["rope", "stone_hatchet", "oar", "raft_kit"]
const STARTING := ["campfire_kit", "lean_to_kit", "spear", "bandage", "torch", "cut_bait", "jig", "compost_bin_kit"]

const RECIPES := {
	"rope": {"name": "Rope", "needs": {"fiber": 5}, "makes": "rope", "count": 1},
	"stone_hatchet": {"name": "Stone hatchet", "needs": {"wood": 1, "flint": 2, "rope": 1}, "makes": "stone_hatchet", "count": 1},
	"oar": {"name": "Oar", "needs": {"wood": 2, "rope": 1}, "makes": "oar", "count": 1, "tool": "hatchet"},
	"raft_kit": {"name": "Raft frame", "needs": {"wood": 3, "rope": 2}, "makes": "raft_kit", "count": 1, "tool": "hatchet"},
	"campfire_kit": {"name": "Campfire ring", "needs": {"stone": 2}, "makes": "campfire_kit", "count": 1},
	"lean_to_kit": {"name": "Lean-to", "needs": {"tarp": 1, "paracord": 1, "wood": 2}, "makes": "lean_to_kit", "count": 1},
	"spear": {"name": "Spear", "needs": {"wood": 1, "flint": 1, "fiber": 2}, "makes": "spear", "count": 1},
	"bandage": {"name": "Bandage", "needs": {"fiber": 4}, "makes": "bandage", "count": 1},
	"torch": {"name": "Torch", "needs": {"wood": 1, "fiber": 2}, "makes": "torch", "count": 1},
	"tent_kit": {"name": "Tent frame", "needs": {"wood": 4, "rope": 1}, "makes": "tent_kit", "count": 1, "tool": "hatchet"},
	"compost_bin_kit": {"name": "Compost bin", "needs": {"wood": 4, "rope": 1}, "makes": "compost_bin_kit", "count": 1},
	"drying_rack_kit": {"name": "Drying rack", "needs": {"wood": 6, "rope": 3}, "makes": "drying_rack_kit", "count": 1},
	"cut_bait": {"name": "Cut bait", "needs": {"baitfish": 1}, "makes": "cut_bait", "count": 4, "tool": "knife"},
	"jig": {"name": "Hand-tied jig", "needs": {"wood": 1, "fiber": 2, "flint": 1}, "makes": "jig", "count": 1, "tool": "knife"},
	"peg_leg": {"name": "Peg leg", "needs": {"log": 1, "rope": 2}, "makes": "peg_leg", "count": 1, "tool": "knife"},
	"hook_hand": {"name": "Hook hand", "needs": {"wood": 1, "rope": 1, "lure": 1}, "makes": "hook_hand", "count": 1, "tool": "knife"},
	"storage_crate_kit": {"name": "Storage crate", "needs": {"log": 3, "rope": 2}, "makes": "storage_crate_kit", "count": 1, "tool": "hatchet"},
}


static func have(inventory: Pack, need: String) -> int:
	if ItemTable.GROUPS.has(need):
		var total := 0
		for id: String in ItemTable.GROUPS[need]:
			total += inventory.count_of(id)
		return total
	return inventory.count_of(need)


static func need_label(need: String) -> String:
	return String(ItemTable.GROUP_NAMES[need]) if ItemTable.GROUP_NAMES.has(need) else ItemTable.display_name(need)


## Items still needed to craft `id` from `inventory`: {need: how many short}.
static func missing(inventory: Pack, id: String) -> Dictionary:
	var short := {}
	var needs: Dictionary = RECIPES.get(id, {}).get("needs", {})
	for need: String in needs:
		var lacking: int = int(needs[need]) - have(inventory, need)
		if lacking > 0:
			short[need] = lacking
	return short


static func missing_tool(inventory: Pack, id: String) -> String:
	var tool: String = RECIPES.get(id, {}).get("tool", "")
	return "" if tool.is_empty() or inventory.tool_types().has(tool) else tool


static func can_craft(inventory: Pack, id: String) -> bool:
	return RECIPES.has(id) and missing(inventory, id).is_empty() and missing_tool(inventory, id).is_empty()


## Removes the ingredients (groups use their first listed item first). Call after can_craft.
static func consume(inventory: Pack, id: String) -> void:
	var needs: Dictionary = RECIPES[id].needs
	for need: String in needs:
		var left: int = needs[need]
		var options: Array = ItemTable.GROUPS.get(need, [need])
		for item: String in options:
			var take := mini(left, inventory.count_of(item))
			if take > 0:
				inventory.remove(item, take)
				left -= take
