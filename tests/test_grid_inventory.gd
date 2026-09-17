extends "res://tests/test_case.gd"

const Grid = preload("res://player/item_grid.gd")
const PackScript = preload("res://player/pack.gd")
const Moves = preload("res://player/item_moves.gd")
const Items = preload("res://data/item_table.gd")


func test_items_take_up_their_size() -> void:
	var grid = Grid.new(5, 2)
	check(grid.place({"id": "log", "count": 1, "spoils_at": 0.0}, 0, 0, false), "a 3×1 log fits at the top left")
	check(not grid.fits("driftwood", 2, 0, false), "cells under the log are taken")
	check(grid.fits("driftwood", 3, 0, false), "the rest of the row is free")
	check(not grid.fits("log", 3, 1, false), "a log can't hang off the edge")
	check(not grid.in_bounds("machete", 0, 0, false) and grid.in_bounds("machete", 0, 0, true), "a 1×3 machete only fits a 2-tall grid sideways")


func test_find_space_rotates_when_needed() -> void:
	var grid = Grid.new(3, 1)
	var spot: Dictionary = grid.find_space("machete")
	check(spot.get("rot", false) == true, "a machete lies down to fit a 3×1 grid")


func test_add_stack_merges_then_fills_new_cells() -> void:
	var grid = Grid.new(2, 1)
	check(grid.add_stack({"id": "stone", "count": 25, "spoils_at": 0.0}) == 0, "25 stones fit in two 20-stacks")
	check(grid.items.size() == 2 and grid.count_of("stone") == 25, "two stacks")
	check(grid.add_stack({"id": "stone", "count": 20, "spoils_at": 0.0}) == 5, "15 top up the second stack, 5 don't fit")


func test_pack_grids_come_from_gear() -> void:
	var pack = PackScript.new()
	check(pack.grid_names() == ["pockets"], "just pockets with no gear")
	pack.configure({"back": "satchel", "vest": "plate_carrier"})
	check(pack.grid_names() == ["pockets", "rig", "backpack"], "a satchel and a plate carrier add storage")
	check(pack.grid("backpack").width == 4 and pack.grid("rig").width == 4, "sizes come from the item table")
	pack.grid("backpack").place({"id": "rope", "count": 3, "spoils_at": 0.0}, 3, 2, false)
	pack.configure({"back": "daypack", "vest": "plate_carrier"})
	check(pack.grid("backpack").width == 6 and pack.grid("backpack").count_of("rope") == 3, "upgrading the backpack keeps its contents")
	var displaced: Array = pack.configure({"vest": "plate_carrier"})
	check(displaced.size() == 1 and displaced[0].id == "rope" and not pack.grids.has("backpack"), "taking the backpack off returns what was in it")


func test_pack_fills_storage_before_the_hotbar() -> void:
	var pack = PackScript.new()
	check(pack.add("stone", 3) == 0 and pack.grid("pockets").count_of("stone") == 3 and pack.hotbar[0] == null, "stones go in pockets")
	check(pack.add("fishing_rod", 1) == 0 and pack.hotbar[0] == null, "a 1×4 rod fits sideways in 5-wide pockets")
	check(pack.add("storage_crate_kit", 1) == 0 and pack.hotbar[0] != null and pack.hotbar[0].id == "storage_crate_kit", "a 3×3 kit too big for pockets lands on the hotbar")
	check(pack.remove("stone", 2) and pack.count_of("stone") == 1, "remove counts across storage")


func test_drag_onto_hotbar_and_swap() -> void:
	var pack = PackScript.new()
	pack.add("berries", 5)
	pack.hotbar[2] = {"uid": 77, "id": "knife", "count": 1, "spoils_at": 0.0}
	var berries: Dictionary = pack.grid("pockets").items[0]
	check(Moves.move(pack, int(berries.uid), 0, {"kind": "hotbar", "pack": pack, "index": 2}), "dragging berries onto the knife's slot works")
	check(pack.hotbar[2].id == "berries" and pack.grid("pockets").count_of("berries") == 0, "berries on the hotbar")
	check(pack.grid("pockets").get_item(77).get("id", "") == "knife", "the knife swapped into the berries' old cell")


func test_swap_falls_back_to_free_space() -> void:
	var pack = PackScript.new()
	pack.grid("pockets").place({"id": "stone", "count": 1, "spoils_at": 0.0}, 0, 0, false)
	pack.grid("pockets").place({"id": "flint", "count": 1, "spoils_at": 0.0}, 1, 0, false)
	pack.hotbar[0] = {"uid": 88, "id": "log", "count": 1, "spoils_at": 0.0}
	var stone: Dictionary = pack.grid("pockets").items[0]
	check(Moves.move(pack, int(stone.uid), 0, {"kind": "hotbar", "pack": pack, "index": 0}), "a 1×1 stone swaps with a 3×1 log")
	check(pack.hotbar[0].id == "stone" and pack.grid("pockets").get_item(88).get("id", "") == "log", "the log found room elsewhere in the pockets")


func test_drag_merges_partial_stacks_and_splits_by_count() -> void:
	var pack = PackScript.new()
	var pockets: ItemGrid = pack.grid("pockets")
	pockets.place({"uid": 1, "id": "fiber", "count": 45, "spoils_at": 0.0}, 0, 0, false)
	pockets.place({"uid": 2, "id": "fiber", "count": 10, "spoils_at": 0.0}, 2, 0, false)
	check(Moves.move(pack, 2, 0, {"kind": "grid", "grid": pockets, "x": 0, "y": 0, "rot": false}), "dropping fiber on fiber merges")
	check(int(pockets.get_item(1).count) == 50 and int(pockets.get_item(2).count) == 5, "tops up to 50 and leaves 5 behind")
	check(Moves.move(pack, 1, 20, {"kind": "grid", "grid": pockets, "x": 4, "y": 1, "rot": false}), "dragging part of a stack to an empty cell")
	check(pockets.count_of("fiber") == 55 and pockets.items.size() == 3, "split off 20 into a new stack")


func test_blocked_drop_undoes_cleanly() -> void:
	var chest = Grid.new(3, 3)
	var pack = PackScript.new()
	pack.grid("pockets").place({"uid": 5, "id": "log", "count": 1, "spoils_at": 0.0}, 0, 0, false)
	chest.place({"uid": 6, "id": "stone", "count": 1, "spoils_at": 0.0}, 1, 1, false)
	chest.place({"uid": 7, "id": "flint", "count": 1, "spoils_at": 0.0}, 2, 1, false)
	check(not Moves.move(pack, 5, 0, {"kind": "grid", "grid": chest, "x": 0, "y": 1, "rot": false}), "a log can't land on two items")
	var log: Dictionary = pack.grid("pockets").get_item(5)
	check(not log.is_empty() and log.x == 0 and log.y == 0, "the log is back where it was")
	check(chest.items.size() == 2, "the chest is untouched")


func test_quick_move_to_a_container() -> void:
	var pack = PackScript.new()
	pack.add("stone", 12)
	var chest = Grid.new(4, 4)
	var uid := int(pack.grid("pockets").items[0].uid)
	check(Moves.quick_move(pack, uid, chest) and chest.count_of("stone") == 12 and pack.count_of("stone") == 0, "quick move sends the whole stack")


func test_round_trip_keeps_positions() -> void:
	var pack = PackScript.new()
	pack.configure({"back": "daypack"})
	pack.grid("backpack").place({"uid": 9, "id": "tarp", "count": 1, "spoils_at": 0.0}, 3, 2, true)
	pack.hotbar[4] = {"uid": 10, "id": "lighter", "count": 1, "spoils_at": 0.0, "uses": 7}
	var copy = PackScript.new()
	copy.from_dict(str_to_var(var_to_str(pack.to_dict())))
	var tarp: Dictionary = copy.grid("backpack").get_item(9)
	check(tarp.x == 3 and tarp.y == 2 and tarp.rot == true, "grid positions survive a save")
	check(copy.hotbar[4].uses == 7, "hotbar items keep their uses")


func test_every_item_has_a_sensible_size() -> void:
	for id: String in Items.ITEMS:
		var size: Vector2i = Items.size_of(id)
		# A long gun is the biggest thing you can carry: two cells across, five down.
		check(size.x >= 1 and size.y >= 1 and size.x <= 3 and size.y <= 5, "%s is %s" % [id, size])
	for id: String in Items.STORAGE:
		check(Items.ITEMS[id].category == "wearable", "%s gives storage and can be worn" % id)
