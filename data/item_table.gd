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

const GROUPS := {"wood": ["driftwood", "log"], "baitfish": ["raw_sardine", "raw_mullet", "raw_fish"]}
const GROUP_NAMES := {"wood": "Wood", "baitfish": "Small fish"}
const BAIT_HINT := "Fishing bait — with the rod selected, right click to put it on the hook."

const COMING_SOON := "Not usable yet — it arrives in a later update."
const GUN_HINT := "Left click fires, right click brings the sights up, R reloads, X switches fire mode. Open the inventory to fit attachments."
const AMMO_HINT := "Rounds for one calibre of gun — they don't fit anything else. Reload with R."
const ATTACH_HINT := "Fits a gun: open the inventory, select the gun, and drop this on one of its slots."

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
	"raw_sardine": {"name": "Sardine", "category": "food", "weight": 0.15, "stack": 10, "food": 4.0, "spoil": 900.0, "sickness": 45.0, "sick_chance": 0.25, "cooks_to": "cooked_fish", "dries_to": "dried_fish"},
	"raw_mullet": {"name": "Mullet", "category": "food", "weight": 0.9, "stack": 5, "food": 7.0, "spoil": 900.0, "sickness": 60.0, "sick_chance": 0.35, "cooks_to": "cooked_fish", "dries_to": "dried_fish"},
	"raw_pufferfish": {"name": "Pufferfish", "category": "food", "weight": 0.6, "stack": 5, "food": 5.0, "spoil": 900.0, "sickness": 240.0, "sick_chance": 1.0, "cooks_to": "cooked_pufferfish"},
	"cooked_pufferfish": {"name": "Cooked pufferfish", "category": "food", "weight": 0.5, "stack": 5, "food": 22.0, "water": 1.0, "spoil": 1800.0, "sickness": 150.0, "sick_chance": 0.35},
	"raw_snapper": {"name": "Red snapper", "category": "food", "weight": 2.5, "stack": 3, "food": 10.0, "spoil": 900.0, "sickness": 60.0, "sick_chance": 0.35, "cooks_to": "fish_steak", "dries_to": "dried_fish"},
	"raw_grouper": {"name": "Grouper", "category": "food", "weight": 6.0, "stack": 2, "food": 14.0, "spoil": 900.0, "sickness": 60.0, "sick_chance": 0.35, "cooks_to": "fish_steak", "dries_to": "dried_fish"},
	"raw_barracuda": {"name": "Barracuda", "category": "food", "weight": 4.0, "stack": 2, "food": 12.0, "spoil": 900.0, "sickness": 150.0, "sick_chance": 0.6, "cooks_to": "fish_steak", "dries_to": "dried_fish"},
	"raw_mahi_mahi": {"name": "Mahi-mahi", "category": "food", "weight": 5.0, "stack": 2, "food": 13.0, "spoil": 900.0, "sickness": 60.0, "sick_chance": 0.35, "cooks_to": "fish_steak", "dries_to": "dried_fish"},
	"raw_tuna": {"name": "Yellowfin tuna", "category": "food", "weight": 12.0, "stack": 1, "food": 16.0, "spoil": 900.0, "sickness": 45.0, "sick_chance": 0.25, "cooks_to": "fish_steak", "dries_to": "dried_fish"},
	"fish_steak": {"name": "Fish steak", "category": "food", "weight": 0.7, "stack": 5, "food": 40.0, "water": 3.0, "spoil": 1800.0},
	"raw_shark_meat": {"name": "Raw shark meat", "category": "food", "weight": 0.9, "stack": 5, "food": 12.0, "spoil": 900.0, "sickness": 90.0, "sick_chance": 0.4, "cooks_to": "cooked_shark", "dries_to": "dried_meat"},
	"cooked_shark": {"name": "Shark steak", "category": "food", "weight": 0.8, "stack": 5, "food": 32.0, "water": 2.0, "spoil": 1800.0},
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
	"lure": {"name": "Spoon lure", "category": "material", "weight": 0.02, "stack": 10, "hint": "A shiny metal lure: predators go for it, and it isn't used up by a catch — only lost if the line snaps. With the rod selected, right click to put it on."},
	"grub": {"name": "Grub", "category": "material", "weight": 0.01, "stack": 30, "spoil": 1800.0, "hint": BAIT_HINT + " Small fish love them. Found when chopping trees and turning driftwood."},
	"cut_bait": {"name": "Cut bait", "category": "material", "weight": 0.05, "stack": 30, "spoil": 900.0, "hint": BAIT_HINT + " Reef fish and big predators go for it. Cut from small fish (B)."},
	"jig": {"name": "Hand-tied jig", "category": "material", "weight": 0.03, "stack": 5, "hint": "A feathered jig for open water — mahi-mahi and tuna. Not used up by a catch, only lost if the line snaps. Right click with the rod to put it on."},
	"flare": {"name": "Flare", "category": "material", "weight": 0.15, "stack": 6, "hint": COMING_SOON},

	# --- tools & weapons ---
	"knife": {"name": "Knife", "category": "tool", "tool": "knife", "weight": 0.3, "stack": 1, "hint": "Swing at plants and bushes (left click) to cut them faster. Carrying it speeds up E too."},
	"machete": {"name": "Machete", "category": "tool", "tool": "machete", "weight": 0.8, "stack": 1, "hint": "Hack through plants and bushes (left click) — much faster than by hand."},
	"stone_hatchet": {"name": "Stone hatchet", "category": "tool", "tool": "hatchet", "weight": 1.2, "stack": 1, "hint": "Look at a tree and hold left click to chop it down for logs."},
	"oar": {"name": "Oar", "category": "tool", "tool": "oar", "weight": 1.4, "stack": 1, "hint": "Carry it aboard a raft or boat and press F to row: Q strokes the left oar, E the right, both to go straight. Hold S to back-row, Shift to pull hard."},
	"lighter": {"name": "Lighter", "category": "tool", "tool": "lighter", "weight": 0.05, "stack": 1, "uses": 20, "hint": "Press E on a campfire or stove that has wood in it to light it."},
	"torch": {"name": "Torch", "category": "tool", "tool": "torch", "weight": 0.5, "stack": 3, "hint": "Lights your way while it's in your hand."},
	"canteen": {"name": "Canteen (empty)", "category": "tool", "tool": "canteen", "weight": 0.3, "stack": 1, "hint": "Hold it and press E at the spring (clean) or the stream (boil it first)."},
	"fishing_rod": {"name": "Fishing rod", "category": "tool", "tool": "fishing_rod", "weight": 1.0, "stack": 1, "hint": "Hold left click to wind up a cast and let go to throw. When the bobber dips, left click to strike, then hold to reel and ease off before the line snaps. Right click picks your bait."},
	"spear": {"name": "Spear", "category": "weapon", "tool": "spear", "weight": 1.5, "stack": 1, "hint": "Look at a shark and left click to strike — the best reach and damage you've got."},
	"flare_gun": {"name": "Flare gun", "category": "weapon", "weight": 0.6, "stack": 1, "hint": COMING_SOON},

	# --- guns (how each one shoots lives in WeaponTable) ---
	"m1911": {"name": "M1911", "category": "weapon", "weapon": "m1911", "weight": 1.1, "stack": 1, "hint": GUN_HINT},
	"uzi": {"name": "Uzi", "category": "weapon", "weapon": "uzi", "weight": 3.6, "stack": 1, "hint": GUN_HINT},
	"m4": {"name": "M4", "category": "weapon", "weapon": "m4", "weight": 3.4, "stack": 1, "hint": GUN_HINT},
	"mossberg": {"name": "Mossberg", "category": "weapon", "weapon": "mossberg", "weight": 3.2, "stack": 1, "hint": GUN_HINT},
	"intervention": {"name": "Intervention", "category": "weapon", "weapon": "intervention", "weight": 6.5, "stack": 1, "hint": GUN_HINT},
	"cleaning_kit": {"name": "Cleaning kit", "category": "tool", "tool": "cleaning_kit", "weight": 0.3, "stack": 1, "uses": 10,
		"hint": "Select a gun, then use this to clean it. A fouled gun jams."},

	# --- ammunition (calibres never interchange) ---
	"ammo_45": {"name": ".45 ACP", "category": "material", "weight": 0.015, "stack": 50, "hint": AMMO_HINT},
	"ammo_9mm": {"name": "9mm", "category": "material", "weight": 0.012, "stack": 60, "hint": AMMO_HINT},
	"ammo_556": {"name": "5.56", "category": "material", "weight": 0.013, "stack": 60, "hint": AMMO_HINT},
	"ammo_12ga": {"name": "12 gauge", "category": "material", "weight": 0.045, "stack": 30, "hint": AMMO_HINT},
	"ammo_408": {"name": ".408", "category": "material", "weight": 0.032, "stack": 20, "hint": AMMO_HINT},

	# --- attachments (what each one does lives in AttachmentTable) ---
	"red_dot": {"name": "Red dot", "category": "attachment", "attachment": "red_dot", "weight": 0.12, "stack": 1, "hint": ATTACH_HINT},
	"holo_sight": {"name": "Holographic sight", "category": "attachment", "attachment": "holo_sight", "weight": 0.18, "stack": 1, "hint": ATTACH_HINT},
	"prism_3x": {"name": "3x prism", "category": "attachment", "attachment": "prism_3x", "weight": 0.3, "stack": 1, "hint": ATTACH_HINT},
	"lpvo_6x": {"name": "1-6x LPVO", "category": "attachment", "attachment": "lpvo_6x", "weight": 0.42, "stack": 1, "hint": ATTACH_HINT},
	"sniper_scope": {"name": "Sniper scope", "category": "attachment", "attachment": "sniper_scope", "weight": 0.6, "stack": 1, "hint": ATTACH_HINT},
	"compensator": {"name": "Compensator", "category": "attachment", "attachment": "compensator", "weight": 0.1, "stack": 1, "hint": ATTACH_HINT},
	"muzzle_brake": {"name": "Muzzle brake", "category": "attachment", "attachment": "muzzle_brake", "weight": 0.16, "stack": 1, "hint": ATTACH_HINT},
	"suppressor": {"name": "Suppressor", "category": "attachment", "attachment": "suppressor", "weight": 0.45, "stack": 1, "hint": ATTACH_HINT},
	"vertical_grip": {"name": "Vertical grip", "category": "attachment", "attachment": "vertical_grip", "weight": 0.14, "stack": 1, "hint": ATTACH_HINT},
	"angled_grip": {"name": "Angled grip", "category": "attachment", "attachment": "angled_grip", "weight": 0.11, "stack": 1, "hint": ATTACH_HINT},
	"bipod": {"name": "Bipod", "category": "attachment", "attachment": "bipod", "weight": 0.5, "stack": 1, "hint": ATTACH_HINT},
	"extended_mag": {"name": "Extended magazine", "category": "attachment", "attachment": "extended_mag", "weight": 0.25, "stack": 1, "hint": ATTACH_HINT},
	"quickdraw_mag": {"name": "Quickdraw magazine", "category": "attachment", "attachment": "quickdraw_mag", "weight": 0.08, "stack": 1, "hint": ATTACH_HINT},
	"light_stock": {"name": "Light stock", "category": "attachment", "attachment": "light_stock", "weight": 0.1, "stack": 1, "hint": ATTACH_HINT},
	"heavy_stock": {"name": "Heavy stock", "category": "attachment", "attachment": "heavy_stock", "weight": 0.55, "stack": 1, "hint": ATTACH_HINT},
	"folding_stock": {"name": "Folding stock", "category": "attachment", "attachment": "folding_stock", "weight": 0.2, "stack": 1, "hint": ATTACH_HINT},
	"laser": {"name": "Laser", "category": "attachment", "attachment": "laser", "weight": 0.07, "stack": 1, "hint": ATTACH_HINT},
	"flashlight": {"name": "Flashlight", "category": "attachment", "attachment": "flashlight", "weight": 0.12, "stack": 1, "hint": ATTACH_HINT},

	# --- medical, reading, keys ---
	"bandage": {"name": "Bandage", "category": "medical", "weight": 0.05, "stack": 10, "heal": 25.0},
	"peg_leg": {"name": "Peg leg", "category": "prosthetic", "fits": "leg", "weight": 1.5, "stack": 1},
	"hook_hand": {"name": "Hook hand", "category": "prosthetic", "fits": "arm", "weight": 0.5, "stack": 1},
	"book_page_prosthetics": {"name": "Book page: Field prosthetics", "category": "page", "weight": 0.01, "stack": 5, "teaches": ["peg_leg", "hook_hand"]},
	"survival_book": {"name": "Survival book", "category": "book", "weight": 0.4, "stack": 1},
	"book_page_shelter": {"name": "Book page: Shelters", "category": "page", "weight": 0.01, "stack": 5, "teaches": ["tent_kit", "drying_rack_kit"]},
	"book_page_camp": {"name": "Book page: Camp craft", "category": "page", "weight": 0.01, "stack": 5, "teaches": ["storage_crate_kit", "stone_hatchet"]},
	"logbook": {"name": "Captain's logbook", "category": "note", "weight": 0.3, "stack": 1, "note": "logbook"},
	"journal": {"name": "Castaway's journal", "category": "note", "weight": 0.2, "stack": 1, "note": "journal"},
	"sea_chart": {"name": "Sea chart", "category": "chart", "weight": 0.1, "stack": 1},
	"compartment_key": {"name": "Small brass key", "category": "key", "weight": 0.02, "stack": 1, "hint": "Opens the locked footlocker in the fishing shack — press E on it."},

	# --- structure kits ---
	"campfire_kit": {"name": "Campfire (place)", "category": "placeable", "weight": 3.0, "stack": 1, "places": "campfire"},
	"lean_to_kit": {"name": "Lean-to (place)", "category": "placeable", "weight": 2.5, "stack": 1, "places": "lean_to"},
	"tent_kit": {"name": "Tent (place)", "category": "placeable", "weight": 4.0, "stack": 1, "places": "tent"},
	"drying_rack_kit": {"name": "Drying rack (place)", "category": "placeable", "weight": 3.0, "stack": 1, "places": "drying_rack"},
	"storage_crate_kit": {"name": "Storage crate (place)", "category": "placeable", "weight": 6.0, "stack": 1, "places": "storage_crate"},
	"raft_kit": {"name": "Raft frame (place)", "category": "placeable", "weight": 5.0, "stack": 1, "places": "raft_site"},

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
	"satchel": {"name": "Canvas satchel", "category": "wearable", "slot": "back", "insulation": 0.0, "weight": 0.4, "stack": 1},
}

## Grid footprint [width, height] in inventory cells. Anything missing is 1×1.
const SIZES := {
	"raw_fish": [2, 1], "cooked_fish": [2, 1], "raw_mullet": [2, 1], "raw_snapper": [2, 1], "raw_grouper": [3, 2], "raw_barracuda": [3, 1],
	"raw_mahi_mahi": [3, 2], "raw_tuna": [2, 4], "fish_steak": [2, 1], "raw_shark_meat": [2, 1], "cooked_shark": [2, 1], "peg_leg": [1, 3], "hook_hand": [1, 2], "canteen_clean": [1, 2], "canteen_dirty": [1, 2], "canteen": [1, 2],
	"driftwood": [2, 1], "log": [3, 1], "tarp": [2, 2],
	"knife": [1, 2], "machete": [1, 3], "stone_hatchet": [1, 3], "oar": [1, 4], "raft_kit": [3, 3], "torch": [1, 3], "fishing_rod": [1, 4], "spear": [1, 4],
	"m1911": [2, 2], "uzi": [2, 3], "m4": [2, 4], "mossberg": [2, 4], "intervention": [2, 5], "flare_gun": [2, 1],
	"sniper_scope": [1, 3], "lpvo_6x": [1, 2], "prism_3x": [1, 2], "suppressor": [1, 2], "bipod": [1, 2],
	"heavy_stock": [2, 2], "light_stock": [2, 2], "folding_stock": [2, 1], "extended_mag": [1, 2], "cleaning_kit": [2, 1],
	"survival_book": [2, 2], "logbook": [2, 2], "sea_chart": [1, 2],
	"campfire_kit": [2, 2], "lean_to_kit": [2, 3], "tent_kit": [3, 2], "drying_rack_kit": [2, 3], "storage_crate_kit": [3, 3],
	"tshirt": [2, 2], "rain_jacket": [2, 3], "wool_sweater": [2, 2], "shorts": [2, 2], "cargo_pants": [2, 3],
	"sandals": [2, 1], "hiking_boots": [2, 2], "sun_hat": [2, 2], "combat_helmet": [2, 2],
	"plate_carrier": [3, 3], "daypack": [3, 3], "satchel": [2, 2],
}

## 0 common · 1 uncommon · 2 rare · 3 epic · 4 legendary · 5 exotic. Anything missing is common.
const RARITY := {
	"cooked_fish": 1, "cooked_meat": 1, "dried_fish": 1, "dried_meat": 1, "dried_berries": 1, "canteen_clean": 1,
	"rope": 1, "flare": 1, "bandage": 1, "lighter": 1, "knife": 1, "stone_hatchet": 1, "fishing_rod": 1, "lure": 1,
	"machete": 2, "flare_gun": 2, "survival_book": 2, "sea_chart": 2, "logbook": 2, "journal": 2,
	"rain_jacket": 1, "wool_sweater": 1, "cargo_pants": 1, "hiking_boots": 1, "wool_beanie": 1, "daypack": 2,
	"m1911": 3, "mossberg": 3, "uzi": 3, "m4": 4, "intervention": 5,
	"ammo_45": 2, "ammo_9mm": 2, "ammo_556": 2, "ammo_12ga": 2, "ammo_408": 3, "cleaning_kit": 1,
	"red_dot": 2, "holo_sight": 2, "prism_3x": 3, "lpvo_6x": 3, "sniper_scope": 4,
	"compensator": 2, "muzzle_brake": 2, "suppressor": 4, "vertical_grip": 2, "angled_grip": 2, "bipod": 3,
	"extended_mag": 2, "quickdraw_mag": 2, "light_stock": 2, "heavy_stock": 2, "folding_stock": 2, "laser": 3, "flashlight": 2,
	"plate_carrier": 3, "combat_helmet": 3, "compartment_key": 3,
	"tent_kit": 1, "storage_crate_kit": 1, "book_page_shelter": 2, "book_page_camp": 2,
	"raw_snapper": 1, "raw_pufferfish": 1, "raw_grouper": 2, "raw_barracuda": 2, "raw_mahi_mahi": 2, "raw_tuna": 3, "fish_steak": 1, "jig": 1,
	"cooked_shark": 1, "peg_leg": 2, "hook_hand": 2, "book_page_prosthetics": 2, "oar": 1,
}
const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Exotic"]
const RARITY_COLORS := [
	Color(0.45, 0.47, 0.50), Color(0.30, 0.62, 0.34), Color(0.25, 0.48, 0.85),
	Color(0.58, 0.34, 0.82), Color(0.90, 0.68, 0.20), Color(0.86, 0.26, 0.24),
]

## Gear that gives you storage: [width, height] of the grid it adds.
const STORAGE := {"satchel": [4, 3], "daypack": [6, 5], "plate_carrier": [4, 2]}


static func size_of(id: String) -> Vector2i:
	var size: Array = SIZES.get(id, [1, 1])
	return Vector2i(size[0], size[1])


static func rarity(id: String) -> int:
	return RARITY.get(id, 0)


static func rarity_color(id: String) -> Color:
	return RARITY_COLORS[rarity(id)]


static func get_item(id: String) -> Dictionary:
	return ITEMS.get(id, {})


static func exists(id: String) -> bool:
	return ITEMS.has(id)


static func display_name(id: String) -> String:
	return ITEMS.get(id, {}).get("name", id)


static func category(id: String) -> String:
	return ITEMS.get(id, {}).get("category", "")
