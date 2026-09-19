extends "res://tests/test_case.gd"

const Structures = preload("res://data/structure_table.gd")


func test_tents_and_fires_go_up_in_stages() -> void:
	check(Structures.is_build_site("tent") and Structures.is_build_site("campfire"), "tents and fires are built in stages")
	check(not Structures.is_finished("tent", {}), "a bare tent frame isn't a tent")
	check(not Structures.is_finished("tent", {"tarp": 1}), "canvas without guy lines isn't finished")
	check(Structures.is_finished("tent", {"tarp": 1, "rope": 3}), "canvas and guy lines finish it")
	check(Structures.takes_work("tent", {"tarp": 1}) and not Structures.takes_work("tent", {"tarp": 1, "rope": 3}), "E adds materials only until it's done")
	check(Structures.takes_work("raft_site", {"log": 6, "rope": 3}), "a finished raft still takes E: to push it off")
	check(Structures.is_finished("storage_crate", {}), "things without stages are finished when placed")


func test_everything_built_has_a_cost() -> void:
	for type: String in Structures.TYPES:
		check(not Structures.kit_for(type).is_empty(), "%s is placed from a kit" % type)
		check(not Structures.cost(type, {}).is_empty(), "%s cost something to make" % type)
		check(Structures.max_hp(type) > 0.0, "%s can be damaged" % type)


func test_dismantling_gives_back_most_of_it() -> void:
	var tent := Structures.cost("tent", {"tarp": 1, "rope": 3})
	check(tent == {"driftwood": 4, "rope": 4, "tarp": 1}, "a tent is its frame, canvas and lines: %s" % [tent])
	var back := Structures.refund("tent", {"tarp": 1, "rope": 3}, Structures.DISMANTLE_SHARE)
	check(back == {"driftwood": 3, "rope": 3, "tarp": 1}, "three quarters back, at least one of each: %s" % [back])
	var half_built := Structures.refund("tent", {"tarp": 1}, Structures.DISMANTLE_SHARE)
	check(int(half_built.get("rope", 0)) == 1 and int(half_built.get("tarp", 0)) == 1, "only what was actually built comes back: %s" % [half_built])
	var wreck := Structures.refund("tent", {"tarp": 1, "rope": 3}, Structures.COLLAPSE_SHARE)
	check(wreck == {"driftwood": 1, "rope": 1}, "a collapse leaves a quarter, and no minimum: %s" % [wreck])
