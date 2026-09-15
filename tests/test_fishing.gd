extends "res://tests/test_case.gd"

const Fishing = preload("res://items/fishing_math.gd")
const Fish = preload("res://data/fish_table.gd")
const Items = preload("res://data/item_table.gd")
const Recipes = preload("res://data/recipe_table.gd")


func test_every_species_is_a_real_item() -> void:
	for id: String in Fish.SPECIES:
		var s: Dictionary = Fish.SPECIES[id]
		check(Items.exists(s.item), "%s's item %s exists" % [id, s.item])
		check(Items.get_item(s.item).has("cooks_to"), "%s can be cooked" % id)
	for bait: String in Fish.BAITS:
		check(Items.exists(bait), "bait %s is an item" % bait)
	check(Recipes.RECIPES.has("cut_bait") and Recipes.RECIPES.has("jig"), "you can make cut bait and jigs")


func test_spots_come_from_depth() -> void:
	check(Fishing.spot_of(1.5, false) == "shore", "shallow water")
	check(Fishing.spot_of(8.0, false) == "reef", "mid depths near the islands")
	check(Fishing.spot_of(8.0, true) == "reef" and Fishing.spot_of(40.0, true) == "reef", "the reef is the reef")
	check(Fishing.spot_of(40.0, false) == "deep", "open water")


func test_bait_and_place_decide_the_fish() -> void:
	var shore_grub: Dictionary = Fishing.weights("shore", "grub", "day", "clear")
	check(shore_grub.has("sardine") and not shore_grub.has("tuna"), "grubs off the beach catch sardines, not tuna")
	var deep_jig: Dictionary = Fishing.weights("deep", "jig", "day", "clear")
	check(deep_jig.has("mahi_mahi") and deep_jig.has("tuna") and not deep_jig.has("sardine"), "a jig in open water is for mahi-mahi and tuna")
	var night_reef: Dictionary = Fishing.weights("reef", "cut_bait", "night", "clear")
	var day_reef: Dictionary = Fishing.weights("reef", "cut_bait", "day", "clear")
	check(float(night_reef.grouper) > float(day_reef.grouper), "grouper bite better at night")
	check(Fishing.weights("deep", "grub", "day", "clear").is_empty() or not Fishing.weights("deep", "grub", "day", "clear").has("tuna"), "tuna ignore grubs")
	var storm: Dictionary = Fishing.weights("deep", "jig", "day", "storm")
	check(float(storm.tuna) > float(deep_jig.tuna), "tuna feed hard in a storm")


func test_picks_follow_the_odds() -> void:
	var odds := {"a": 1.0, "b": 3.0}
	check(Fishing.pick(odds, 0.1) == "a" and Fishing.pick(odds, 0.9) == "b", "rolls land in proportion")
	check(Fishing.pick({}, 0.5) == "", "nothing to catch, nothing caught")
	check(Fishing.bite_seconds({}, 0.5) == INF, "no bite without fish that want the bait")
	check(Fishing.bite_seconds({"a": 6.0}, 0.5) < Fishing.bite_seconds({"a": 0.5}, 0.5), "busier water bites sooner")


func test_sizes_and_strength() -> void:
	for i in 11:
		var kg: float = Fishing.roll_kg("snapper", i / 10.0)
		check(kg >= 1.0 and kg <= 7.0, "snapper %.1f kg within its range" % kg)
	check(Fishing.strength("tuna", 45.0) > Fishing.strength("sardine", 0.2), "a big tuna pulls harder than a sardine")


func _play(strength: float, style: String, shark: bool = false) -> String:
	var fight: Dictionary = Fishing.new_fight(12.0)
	fight.shark = shark
	var t := 0.0
	for i in 3000:
		t += 0.02
		var reeling := true
		match style:
			"never":
				reeling = false
			"smart":
				reeling = fight.tension < 0.7
		var result: String = Fishing.step(fight, reeling, 0.02, Fishing.surge_at(t, 1.0), strength)
		if not result.is_empty():
			return result
	return "timeout"


func test_the_fight() -> void:
	check(_play(Fishing.strength("sardine", 0.1), "hold") == "landed", "a sardine can be reeled straight in")
	check(_play(Fishing.strength("tuna", 40.0), "hold") == "snapped", "hold a big tuna too hard and the line snaps")
	check(_play(Fishing.strength("tuna", 40.0), "smart") == "landed", "ease off when it pulls and you land the tuna")
	check(_play(Fishing.strength("snapper", 3.0), "never") == "escaped", "never reel and it gets away")
	check(_play(Fishing.strength("snapper", 3.0), "hold", true) == "snapped", "a shark on the line pulls far harder")
