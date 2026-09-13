extends "res://tests/test_case.gd"

const EquipmentScript = preload("res://player/equipment.gd")
const Looks = preload("res://data/appearance_table.gd")
const Vote = preload("res://crafting/sleep_vote.gd")
const Items = preload("res://data/item_table.gd")


func test_wearing_swaps_what_was_in_the_slot() -> void:
	var worn = EquipmentScript.new()
	check(worn.wear({"id": "tshirt", "count": 1, "spoils_at": 0.0}).is_empty(), "nothing to swap at first")
	var previous: Dictionary = worn.wear({"id": "rain_jacket", "count": 1, "spoils_at": 0.0})
	check(previous.get("id", "") == "tshirt" and worn.ids().torso == "rain_jacket", "the jacket replaces the T-shirt")
	check(worn.wear({"id": "stone", "count": 1}).is_empty() and not worn.is_wearing("stone"), "you can't wear a stone")


func test_layers_warm_you_and_gear_weighs_you_down() -> void:
	var light = EquipmentScript.new()
	for id: String in EquipmentScript.STARTING_OUTFIT:
		light.wear({"id": id, "count": 1})
	var warm = EquipmentScript.new()
	for id: String in ["wool_sweater", "cargo_pants", "hiking_boots", "wool_beanie"]:
		warm.wear({"id": id, "count": 1})
	check(warm.insulation() > light.insulation() + 0.4, "cold-weather clothes are much warmer (%.2f vs %.2f)" % [warm.insulation(), light.insulation()])
	var kitted = EquipmentScript.new()
	kitted.wear({"id": "plate_carrier", "count": 1})
	kitted.wear({"id": "combat_helmet", "count": 1})
	check(kitted.weight() > 8.0 and kitted.armor("vest") == 3 and kitted.armor("head") == 3, "plates and a helmet are heavy protection")


func test_every_wearable_has_a_real_slot() -> void:
	for id: String in Items.ITEMS:
		if Items.ITEMS[id].category == "wearable":
			check(EquipmentScript.SLOTS.has(Items.ITEMS[id].get("slot", "")), "%s has a valid slot" % id)


func test_equipment_ignores_bad_data() -> void:
	var worn = EquipmentScript.new()
	worn.from_dict({"head": {"id": "cargo_pants", "count": 1}, "feet": {"id": "sandals", "count": 1}, "wings": {"id": "tshirt"}})
	check(worn.ids() == {"feet": "sandals"}, "only valid slot/item pairs survive (got %s)" % [worn.ids()])


func test_looks_are_clamped() -> void:
	var clean: Dictionary = Looks.sanitize({"skin": 99, "hair": -4, "beard": "2", "extra": 1})
	check(clean.skin == Looks.SKIN.size() - 1 and clean.hair == 0 and clean.beard == 2 and not clean.has("extra"), "out-of-range looks are clamped (got %s)" % [clean])
	check(Looks.sanitize("nonsense") == Looks.DEFAULT_LOOK, "garbage becomes the default look")


func test_night_skips_on_a_strict_majority() -> void:
	check(Vote.needed(1) == 1, "solo")
	check(Vote.needed(2) == 2, "both of two")
	check(Vote.needed(3) == 2 and Vote.needed(4) == 3 and Vote.needed(6) == 4, "majority of bigger crews")
	check(not Vote.enough(2, 4) and Vote.enough(3, 4), "3 of 4 is enough, 2 is not")
