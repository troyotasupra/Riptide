class_name FishTable
extends RefCounted
## Fish species: where they live, what they bite, when, how big and how hard they fight.
##   habitats: weight by spot — shore (shallow water), reef (near islands and the wreck), deep (open sea)
##   baits: appetite by bait kind — "bare" is an empty hook
##   times: multiplier by time band (dawn, day, dusk, night) · weather: by weather state
##   kg: [min, max] · fight: 0..1 how hard it pulls · speed: how often it surges

const SPECIES := {
	"sardine": {"name": "Sardine", "item": "raw_sardine", "kg": [0.06, 0.22], "fight": 0.12, "speed": 1.4,
		"habitats": {"shore": 3.0, "reef": 1.2, "deep": 0.4}, "baits": {"bare": 0.5, "grub": 1.6, "berries": 0.8, "cut_bait": 0.4},
		"times": {"dawn": 1.3, "dusk": 1.3, "night": 0.5}, "weather": {"storm": 0.4}},
	"mullet": {"name": "Mullet", "item": "raw_mullet", "kg": [0.4, 2.2], "fight": 0.3, "speed": 1.0,
		"habitats": {"shore": 2.4, "reef": 0.6}, "baits": {"bare": 0.2, "grub": 1.2, "berries": 1.8},
		"times": {"dawn": 1.2, "night": 0.6}, "weather": {"rain": 1.4, "storm": 0.5}},
	"pufferfish": {"name": "Pufferfish", "item": "raw_pufferfish", "kg": [0.3, 1.3], "fight": 0.18, "speed": 0.6,
		"habitats": {"shore": 0.7, "reef": 1.1}, "baits": {"bare": 0.3, "grub": 0.9, "cut_bait": 0.6},
		"times": {}, "weather": {}},
	"snapper": {"name": "Red snapper", "item": "raw_snapper", "kg": [1.0, 7.0], "fight": 0.5, "speed": 1.0,
		"habitats": {"shore": 0.6, "reef": 2.8, "deep": 0.6}, "baits": {"grub": 0.8, "cut_bait": 1.6, "lure": 0.7},
		"times": {"dawn": 1.3, "dusk": 1.4, "night": 0.8}, "weather": {"rain": 1.3}},
	"grouper": {"name": "Grouper", "item": "raw_grouper", "kg": [3.0, 22.0], "fight": 0.78, "speed": 0.7,
		"habitats": {"reef": 1.8, "deep": 0.9}, "baits": {"cut_bait": 1.8, "lure": 0.5},
		"times": {"day": 0.6, "dusk": 1.6, "night": 1.8}, "weather": {}},
	"barracuda": {"name": "Barracuda", "item": "raw_barracuda", "kg": [2.0, 14.0], "fight": 0.82, "speed": 1.8,
		"habitats": {"reef": 1.2, "deep": 1.4}, "baits": {"cut_bait": 0.5, "lure": 2.0, "jig": 1.7},
		"times": {"dawn": 1.4, "day": 1.1, "dusk": 1.2, "night": 0.5}, "weather": {}},
	"mahi_mahi": {"name": "Mahi-mahi", "item": "raw_mahi_mahi", "kg": [4.0, 16.0], "fight": 0.86, "speed": 1.6,
		"habitats": {"deep": 2.4, "reef": 0.3}, "baits": {"lure": 1.4, "jig": 2.0, "cut_bait": 0.6},
		"times": {"dawn": 1.2, "day": 1.3, "dusk": 0.9, "night": 0.3}, "weather": {"storm": 0.6}},
	"tuna": {"name": "Yellowfin tuna", "item": "raw_tuna", "kg": [10.0, 48.0], "fight": 1.0, "speed": 1.3,
		"habitats": {"deep": 1.1}, "baits": {"jig": 1.4, "cut_bait": 1.0, "lure": 0.8},
		"times": {"dawn": 1.5, "day": 0.9, "dusk": 1.3, "night": 0.4}, "weather": {"rain": 1.3, "storm": 1.6}},
}

## Bait items: the kind of bait each is, and whether it survives a catch.
const BAITS := {
	"grub": {"kind": "grub", "reusable": false},
	"berries": {"kind": "berries", "reusable": false},
	"cut_bait": {"kind": "cut_bait", "reusable": false},
	"lure": {"kind": "lure", "reusable": true},
	"jig": {"kind": "jig", "reusable": true},
}


static func get_species(id: String) -> Dictionary:
	return SPECIES.get(id, {})


static func species_for_item(item_id: String) -> String:
	for id: String in SPECIES:
		if SPECIES[id].item == item_id:
			return id
	return ""


static func bait_kind(item_id: String) -> String:
	return BAITS.get(item_id, {}).get("kind", "bare")


static func bait_reusable(item_id: String) -> bool:
	return BAITS.get(item_id, {}).get("reusable", false)
