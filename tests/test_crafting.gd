extends "res://tests/test_case.gd"

const InventoryScript = preload("res://player/pack.gd")
const StationScript = preload("res://crafting/cook_station.gd")
const Recipes = preload("res://data/recipe_table.gd")
const Items = preload("res://data/item_table.gd")
const Resources = preload("res://data/resource_table.gd")
const Structures = preload("res://data/structure_table.gd")
const Notes = preload("res://data/note_table.gd")


func test_recipes_reference_real_items() -> void:
	for id: String in Recipes.RECIPES:
		var recipe: Dictionary = Recipes.RECIPES[id]
		check(Items.exists(recipe.makes), "%s makes a real item" % id)
		for need: String in recipe.needs:
			check(Items.exists(need) or Items.GROUPS.has(need), "%s needs real item or group %s" % [id, need])
	for id: String in Recipes.STARTING:
		check(Recipes.RECIPES.has(id), "starting recipe %s exists" % id)


func test_items_point_at_real_things() -> void:
	for id: String in Items.ITEMS:
		var item: Dictionary = Items.ITEMS[id]
		for key: String in ["cooks_to", "dries_to", "boils_to", "empties_to"]:
			if item.has(key):
				check(Items.exists(item[key]), "%s.%s -> %s exists" % [id, key, item[key]])
		for recipe: String in item.get("teaches", []):
			check(Recipes.RECIPES.has(recipe), "%s teaches real recipe %s" % [id, recipe])
		if item.has("places"):
			check(Structures.TYPES.has(item.places), "%s places real structure" % id)
		if item.has("note"):
			check(Notes.NOTES.has(item.note), "%s has its note text" % id)


func test_can_craft_only_with_everything() -> void:
	var inv = InventoryScript.new()
	inv.add("fiber", 5)
	check(not Recipes.can_craft(inv, "rope"), "5 fiber isn't enough for rope")
	check(Recipes.missing(inv, "rope") == {"fiber": 1}, "one fiber short")
	inv.add("fiber", 1)
	check(Recipes.can_craft(inv, "rope"), "6 fiber makes rope")
	check(Recipes.missing(inv, "campfire_kit") == {"stone": 6, "wood": 3}, "campfire needs stones and wood")


func test_any_wood_counts_and_driftwood_goes_first() -> void:
	var inv = InventoryScript.new()
	inv.add("stone", 6)
	inv.add("driftwood", 1)
	inv.add("log", 3)
	check(Recipes.can_craft(inv, "campfire_kit"), "driftwood and logs together make 3 wood")
	Recipes.consume(inv, "campfire_kit")
	check(inv.count_of("driftwood") == 0 and inv.count_of("log") == 1 and inv.count_of("stone") == 0, "used the driftwood before the logs")


func test_tool_recipes_need_the_tool() -> void:
	var inv = InventoryScript.new()
	inv.add("log", 3)
	inv.add("rope", 2)
	check(not Recipes.can_craft(inv, "storage_crate_kit") and Recipes.missing_tool(inv, "storage_crate_kit") == "hatchet", "a crate needs a hatchet")
	inv.add("stone_hatchet", 1)
	check(Recipes.can_craft(inv, "storage_crate_kit"), "with a hatchet you can build a crate")


func test_trees_need_a_hatchet() -> void:
	near(Resources.harvest_seconds("tree", ["knife", "machete"]), -1.0, 0.001, "no hatchet, no chopping")
	check(Resources.harvest_seconds("tree", ["hatchet"]) > 0.0, "a hatchet chops")


func test_every_item_explains_itself() -> void:
	var handled := ["food", "drink", "medical", "page", "book", "note", "chart", "placeable", "wearable"]
	for id: String in Items.ITEMS:
		var item: Dictionary = Items.ITEMS[id]
		check(handled.has(item.category) or item.has("hint"), "%s needs a left-click action or a hint" % id)


func test_fiber_is_slow_by_hand_and_fast_with_a_machete() -> void:
	near(Resources.harvest_seconds("fiber", []), 3.0, 0.001, "by hand")
	near(Resources.harvest_seconds("fiber", ["knife"]), 1.5, 0.001, "with a knife")
	near(Resources.harvest_seconds("fiber", ["knife", "machete"]), 0.5, 0.001, "best tool counts")
	near(Resources.harvest_seconds("stone", ["machete"]), 0.0, 0.001, "stones are instant")


func test_fire_cooks_only_while_lit() -> void:
	var fire = StationScript.new("cook")
	check(not fire.start("raw_fish", 0.0), "can't cook on a cold fire")
	check(not fire.light(), "can't light with no fuel")
	fire.add_fuel(90.0)
	check(fire.light(), "lights with fuel")
	check(fire.start("raw_fish", 0.0), "fish goes on")
	check(not fire.start("stone", 0.0), "stones don't cook")
	fire.tick(10.0)
	check(not fire.has_done(10.0), "not done at 10 s")
	fire.tick(20.0)
	var done: Array = fire.take_done(30.0)
	check(done == ["cooked_fish"], "cooked fish at 30 s (got %s)" % [done])


func test_fire_burns_out_and_pauses_cooking() -> void:
	var fire = StationScript.new("cook")
	fire.add_fuel(5.0)
	fire.light()
	fire.start("raw_meat", 0.0)
	fire.tick(6.0)
	check(not fire.lit, "fire went out")
	fire.tick(100.0)
	check(not fire.has_done(106.0), "nothing cooks on a dead fire")


func test_fire_boils_water() -> void:
	var fire = StationScript.new("cook")
	fire.add_fuel(90.0)
	fire.light()
	check(fire.start("canteen_dirty", 0.0), "a dirty canteen can be boiled")
	fire.tick(StationScript.COOK_SECONDS)
	check(fire.take_done(StationScript.COOK_SECONDS) == ["canteen_clean"], "boiling makes clean water")


func test_drying_rack_needs_no_fire_and_fills_up() -> void:
	var rack = StationScript.new("dry")
	check(not rack.add_fuel(90.0), "racks take no fuel")
	for i in StationScript.SLOTS:
		check(rack.start("berries", 0.0), "berries on the rack")
	check(not rack.start("berries", 0.0), "rack is full")
	rack.tick(StationScript.DRY_SECONDS)
	check(rack.take_done(StationScript.DRY_SECONDS).size() == StationScript.SLOTS, "all dried")


func test_station_survives_a_save_with_a_new_clock() -> void:
	var fire = StationScript.new("cook")
	fire.add_fuel(200.0)
	fire.light()
	fire.start("raw_fish", 1000.0)
	var copy = StationScript.new("cook")
	copy.from_dict(str_to_var(var_to_str(fire.to_dict(1010.0))), 5.0)
	check(copy.lit and copy.fuel == 200.0, "fuel and flame restored")
	check(not copy.has_done(19.0) and copy.has_done(20.0), "15 s of cooking left after reload")
