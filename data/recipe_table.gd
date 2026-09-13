class_name RecipeTable
extends RefCounted
## What the survival book teaches. Reading the book teaches STARTING to the whole
## crew; book pages found around the island teach the rest.

const STARTING := ["rope", "campfire_kit", "lean_to_kit", "spear", "bandage", "torch"]

const RECIPES := {
	"rope": {"name": "Rope", "needs": {"fiber": 6}, "makes": "rope", "count": 1},
	"campfire_kit": {"name": "Campfire", "needs": {"stone": 6, "driftwood": 3}, "makes": "campfire_kit", "count": 1},
	"lean_to_kit": {"name": "Lean-to", "needs": {"tarp": 1, "paracord": 1, "driftwood": 2}, "makes": "lean_to_kit", "count": 1},
	"spear": {"name": "Spear", "needs": {"driftwood": 1, "flint": 1, "fiber": 2}, "makes": "spear", "count": 1},
	"bandage": {"name": "Bandage", "needs": {"fiber": 4}, "makes": "bandage", "count": 1},
	"torch": {"name": "Torch", "needs": {"driftwood": 1, "fiber": 2}, "makes": "torch", "count": 1},
	"tent_kit": {"name": "Tent", "needs": {"tarp": 1, "rope": 4, "driftwood": 4}, "makes": "tent_kit", "count": 1},
	"drying_rack_kit": {"name": "Drying rack", "needs": {"driftwood": 6, "rope": 3}, "makes": "drying_rack_kit", "count": 1},
	"storage_crate_kit": {"name": "Storage crate", "needs": {"driftwood": 10, "rope": 2}, "makes": "storage_crate_kit", "count": 1},
	"stone_hatchet": {"name": "Stone hatchet", "needs": {"driftwood": 1, "flint": 2, "rope": 1}, "makes": "stone_hatchet", "count": 1},
}


## Items still needed to craft `id` from `inventory`: {item_id: how many short}.
static func missing(inventory: Inventory, id: String) -> Dictionary:
	var short := {}
	var needs: Dictionary = RECIPES.get(id, {}).get("needs", {})
	for item: String in needs:
		var lacking: int = int(needs[item]) - inventory.count_of(item)
		if lacking > 0:
			short[item] = lacking
	return short


static func can_craft(inventory: Inventory, id: String) -> bool:
	return RECIPES.has(id) and missing(inventory, id).is_empty()
