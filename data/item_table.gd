class_name ItemTable
extends RefCounted
## Every item in the game, in one readable table.
##   category: food | drink | material | tool | weapon | medical | page | book | note | chart | key | placeable | wearable
##   weight (kg), stack · food / water restored when eaten or drunk
##   spoil: seconds until it rots (0 = never) · sickness: seconds of illness, sick_chance 0..1
##   cooks_to / boils_to (fire or stove) · dries_to (drying rack)
##   tool: tool type (knife, machete, hatchet, lighter, torch...) · uses: charges on a fresh one
##   teaches: recipe ids learned when read · places: structure placed from a kit
##   empties_to: what's left after drinking · note: id in NoteTable · heal: health restored
##   slot / insulation / armor: wearables · tint: "crew" takes the crew colour
##   hint: what the item is for, shown when left click has nothing to do

const GROUPS := {"wood": ["driftwood", "log"]}
const GROUP_NAMES := {"wood": "Wood"}

const COMING_SOON := "Not usable yet — fishing and hunting arrive in the next update."

const ITEMS := {
	# --- food ---
	"coconut": {"name": "Coconut", "category": "food", "weight": 0.8, "stack": 5, "food": 10.0, "water": 18.0, "spoil": 2400.0},
	"berries": {"name": "Berries", "category": "food", "weight": 0.05, "stack": 30, "food": 4.0, "water": 1.5, "spoil": 900.0, "dries_to": "dried_berries"},
	"dried_berries": {"name": "Dried berries", "category": "food", "weight": 0.02, "stack": 30, "food": 5.0},
	"red_berries": {"name": "Red berries", "category": "food", "weight": 0.05, "stack": 30, "food": 3.0, "water": 1.0, "spoil": 900.0, "sickness": 60.0, "sick_chance": 1.0},
	"raw_fish": {"name": "Raw fish", "category": "food", "weight": 0.6, "stack": 5, "food": 8.0, "spoil": 900.0, "sickness": 60.0, "sick_chance": 0.4, "cooks_to": "cooked_fish", "dries_to": "dried_fish"},
	"cooked_fish": {"name": "Cooked fish", "category": "food", "weight": 0.5, "stack": 5, "food": 25.0, "water": 2.0, "spoil": 1800.0},
	"dried_fish": {"name": "Dried fish", "category": "food", "weight": 0.25, "stack": 10, "food": 18.0},
	"raw_meat": {"name": "Raw meat", "category": "food", "weight": 0.8, "stack": 5, "food": 10.0, "spoil": 900.0, "sickness": 90.0, "sick_chance": 0.5, "cooks_to": "cooked_meat", "dries_to": "dried_meat"},
	"cooked_meat": {"name": "Cooked meat", "category": "food", "weight": 0.7, "stack": 5, "food": 35.0, "water": 2.0, "spoil": 1800.0},
	"dried_meat": {"name": "Jerky", "category": "food", "weight": 0.3, "stack": 10, "food": 25.0},
	"spoiled_food": {"name": "Spoiled food", "category": "food", "weight": 0.5, "stack": 20, "food": 2.0, "sickness": 90.0, "sick_chance": 1.0},

	# --- drink ---
	"canteen_clean": {"name": "Canteen (clean water)", "category": "drink", "weight": 1.0, "stack": 1, "water": 40.0, "empties_to": "canteen"},
	"canteen_dirty": {"name": "Canteen (unboiled water)", "category": "drink", "weight": 1.0, "stack": 1, "water": 40.0, "sickness": 90.0, "sick_chance": 0.6, "empties_to": "canteen", "boils_to": "canteen_clean"},

	# --- materials ---
	"fiber": {"name": "Plant fiber", "category": "material", "weight": 0.05, "stack": 50, "hint": "Crafting material — twist it into rope in the survival book (B)."},
	"stone": {"name": "Stone", "category": "material", "weight": 0.6, "stack": 20, "hint": "Crafting material — a ring of stones makes a campfire (B)."},
	"flint": {"name": "Flint", "category": "material", "weight": 0.3, "stack": 20, "hint": "Crafting material — for spear tips and a stone hatchet (B)."},
	"driftwood": {"name": "Driftwood", "category": "material", "weight": 1.2, "stack": 10, "fuel": 90.0, "hint": "Wood for crafting (B), or hold it and press E on a fire to burn it."},
	"log": {"name": "Log", "category": "material", "weight": 2.5, "stack": 5, "fuel": 200.0, "hint": "Wood for crafting (B), or hold it and press E on a fire to burn it."},
	"rope": {"name": "Rope", "category": "material", "weight": 0.1, "stack": 20, "hint": "Crafting material for tents, racks and tools (B)."},
	"tarp": {"name": "Tarp", "category": "material", "weight": 1.2, "stack": 2, "hint": "Crafting material — a lean-to or a tent (B)."},
	"paracord": {"name": "Paracord", "category": "material", "weight": 0.3, "stack": 5, "hint": "Crafting material — lash together a lean-to (B)."},
	"lure": {"name": "Fishing lure", "category": "material", "weight": 0.02, "stack": 10, "hint": COMING_SOON},
	"pistol_ammo": {"name": "9mm rounds", "category": "material", "weight": 0.012, "stack": 50, "hint": COMING_SOON},
	"flare": {"name": "Flare", "category": "material", "weight": 0.15, "stack": 6, "hint": COMING_SOON},

	# --- tools & weapons ---
	"knife": {"name": "Knife", "category": "tool", "tool": "knife", "weight": 0.3, "stack": 1, "hint": "Swing at plants and bushes (left click) to cut them faster. Carrying it speeds up E too."},
	"machete": {"name": "Machete", "category": "tool", "tool": "machete", "weight": 0.8, "stack": 1, "hint": "Hack through plants and bushes (left click) — much faster than by hand."},
	"stone_hatchet": {"name": "Stone hatchet", "category": "tool", "tool": "hatchet", "weight": 1.2, "stack": 1, "hint": "Look at a tree and hold left click to chop it down for logs."},
	"lighter": {"name": "Lighter", "category": "tool", "tool": "lighter", "weight": 0.05, "stack": 1, "uses": 20, "hint": "Press E on a campfire or stove that has wood in it to light it."},
	"torch": {"name": "Torch", "category": "tool", "tool": "torch", "weight": 0.5, "stack": 3, "hint": "Lights your way while it's in your hand."},
	"canteen": {"name": "Canteen (empty)", "category": "tool", "tool": "canteen", "weight": 0.3, "stack": 1, "hint": "Hold it and press E at the spring (clean) or the stream (boil it first)."},
	"fishing_rod": {"name": "Fishing rod", "category": "tool", "tool": "fishing_rod", "weight": 1.0, "stack": 1, "hint": COMING_SOON},
	"spear": {"name": "Spear", "category": "weapon", "weight": 1.5, "stack": 1, "hint": COMING_SOON},
	"pistol": {"name": "Pistol", "category": "weapon", "weight": 0.9, "stack": 1, "hint": COMING_SOON},
	"flare_gun": {"name": "Flare gun", "category": "weapon", "weight": 0.6, "stack": 1, "hint": COMING_SOON},

	# --- medical, reading, keys ---
	"bandage": {"name": "Bandage", "category": "medical", "weight": 0.05, "stack": 10, "heal": 25.0},
	"survival_book": {"name": "Survival book", "category": "book", "weight": 0.4, "stack": 1},
	"book_page_shelter": {"name": "Book page: Shelters", "category": "page", "weight": 0.01, "stack": 5, "teaches": ["tent_kit", "drying_rack_kit"]},
	"book_page_camp": {"name": "Book page: Camp craft", "category": "page", "weight": 0.01, "stack": 5, "teaches": ["storage_crate_kit", "stone_hatchet"]},
	"logbook": {"name": "Captain's logbook", "category": "note", "weight": 0.3, "stack": 1, "note": "logbook"},
	"journal": {"name": "Castaway's journal", "category": "note", "weight": 0.2, "stack": 1, "note": "journal"},
	"sea_chart": {"name": "Sea chart", "category": "chart", "weight": 0.1, "stack": 1},
	"compartment_key": {"name": "Small brass key", "category": "key", "weight": 0.02, "stack": 1, "hint": "Opens the locked compartment in the sailboat's cabin — press E on it."},

	# --- structure kits ---
	"campfire_kit": {"name": "Campfire (place)", "category": "placeable", "weight": 3.0, "stack": 1, "places": "campfire"},
	"lean_to_kit": {"name": "Lean-to (place)", "category": "placeable", "weight": 2.5, "stack": 1, "places": "lean_to"},
	"tent_kit": {"name": "Tent (place)", "category": "placeable", "weight": 4.0, "stack": 1, "places": "tent"},
	"drying_rack_kit": {"name": "Drying rack (place)", "category": "placeable", "weight": 3.0, "stack": 1, "places": "drying_rack"},
	"storage_crate_kit": {"name": "Storage crate (place)", "category": "placeable", "weight": 6.0, "stack": 1, "places": "storage_crate"},

	# --- clothing (warmth vs. speed) ---
	"tshirt": {"name": "Crew T-shirt", "category": "wearable", "slot": "torso", "insulation": 0.05, "weight": 0.2, "stack": 1, "tint": "crew"},
	"rain_jacket": {"name": "Rain jacket", "category": "wearable", "slot": "torso", "insulation": 0.35, "weight": 1.0, "stack": 1},
	"wool_sweater": {"name": "Wool sweater", "category": "wearable", "slot": "torso", "insulation": 0.45, "weight": 0.9, "stack": 1},
	"shorts": {"name": "Board shorts", "category": "wearable", "slot": "legs", "insulation": 0.0, "weight": 0.3, "stack": 1},
	"cargo_pants": {"name": "Cargo pants", "category": "wearable", "slot": "legs", "insulation": 0.18, "weight": 0.7, "stack": 1},
	"sandals": {"name": "Sandals", "category": "wearable", "slot": "feet", "insulation": 0.0, "weight": 0.3, "stack": 1},
	"hiking_boots": {"name": "Hiking boots", "category": "wearable", "slot": "feet", "insulation": 0.1, "weight": 1.4, "stack": 1},
	"wool_beanie": {"name": "Wool beanie", "category": "wearable", "slot": "head", "insulation": 0.15, "weight": 0.1, "stack": 1},
	"sun_hat": {"name": "Sun hat", "category": "wearable", "slot": "head", "insulation": 0.02, "weight": 0.15, "stack": 1},

	# --- military gear (protection vs. weight) ---
	"combat_helmet": {"name": "Combat helmet", "category": "wearable", "slot": "head", "insulation": 0.05, "armor": 3, "weight": 1.5, "stack": 1},
	"plate_carrier": {"name": "Plate carrier", "category": "wearable", "slot": "vest", "insulation": 0.08, "armor": 3, "weight": 7.5, "stack": 1, "tint": "crew"},
	"daypack": {"name": "Daypack", "category": "wearable", "slot": "back", "insulation": 0.0, "weight": 0.8, "stack": 1},
}


static func get_item(id: String) -> Dictionary:
	return ITEMS.get(id, {})


static func exists(id: String) -> bool:
	return ITEMS.has(id)


static func display_name(id: String) -> String:
	return ITEMS.get(id, {}).get("name", id)


static func category(id: String) -> String:
	return ITEMS.get(id, {}).get("category", "")
