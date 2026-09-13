extends "res://tests/test_case.gd"

const InventoryScript = preload("res://player/inventory.gd")


func test_stacks_fill_before_new_slots() -> void:
	var inv = InventoryScript.new()
	check(inv.add("stone", 15) == 0, "15 stones fit")
	check(inv.add("stone", 10) == 0, "10 more fit")
	check(inv.slots[0].count == 20 and inv.slots[1].count == 5, "first stack tops out at 20")
	check(inv.count_of("stone") == 25, "count_of totals stacks")


func test_overflow_is_returned() -> void:
	var inv = InventoryScript.new()
	var leftover: int = inv.add("driftwood", 10 * InventoryScript.SIZE + 7)
	check(leftover == 7, "7 driftwood don't fit (got %d)" % leftover)


func test_unknown_items_are_refused() -> void:
	var inv = InventoryScript.new()
	check(inv.add("unobtainium", 3) == 3, "unknown item not added")


func test_weight_adds_up() -> void:
	var inv = InventoryScript.new()
	inv.add("stone", 5)
	inv.add("coconut", 2)
	near(inv.total_weight(), 5 * 0.6 + 2 * 0.8, 0.0001, "total weight")


func test_food_records_when_it_spoils() -> void:
	var inv = InventoryScript.new()
	inv.add("berries", 5, 100.0)
	near(inv.slots[0].spoils_at, 100.0 + 900.0, 0.0001, "berries spoil 900 s after picking")
	inv.add("stone", 1, 100.0)
	near(inv.slots[1].spoils_at, 0.0, 0.0001, "stones never spoil")


func test_move_merges_and_swaps() -> void:
	var inv = InventoryScript.new()
	inv.slots[3] = {"id": "berries", "count": 10, "spoils_at": 500.0}
	inv.slots[9] = {"id": "berries", "count": 5, "spoils_at": 300.0}
	inv.move(3, 9)
	check(inv.slots[3] == null and inv.slots[9].count == 15, "berries merged")
	near(inv.slots[9].spoils_at, 300.0, 0.0001, "merged stack keeps the earliest spoil time")
	inv.slots[4] = {"id": "stone", "count": 2, "spoils_at": 0.0}
	inv.move(4, 9)
	check(inv.slots[4].id == "berries" and inv.slots[9].id == "stone", "different items swap")


func test_remove_and_take() -> void:
	var inv = InventoryScript.new()
	inv.add("fiber", 30)
	check(not inv.remove("fiber", 31), "can't remove more than you have")
	check(inv.count_of("fiber") == 30, "failed remove takes nothing")
	check(inv.remove("fiber", 12), "remove 12")
	var taken: Dictionary = inv.take_from_slot(0, 100)
	check(taken.count == 18 and inv.slots[0] == null, "take empties the slot")


func test_containers_can_be_any_size() -> void:
	var chest = InventoryScript.new(4)
	check(chest.slots.size() == 4, "4-slot chest")
	check(chest.add("driftwood", 45) == 5, "4 stacks of 10 driftwood fit, 5 left over")
	var copy = InventoryScript.new(4)
	copy.from_dict(chest.to_dict())
	check(copy.slots.size() == 4 and copy.count_of("driftwood") == 40, "size survives a round trip")


func test_add_stack_keeps_spoil_time_and_uses() -> void:
	var inv = InventoryScript.new()
	inv.add("lighter", 1)
	check(inv.slots[0].uses == 20, "a fresh lighter has 20 uses")
	inv.slots[0].uses = 3
	var moved: Dictionary = inv.take_from_slot(0, 1)
	var other = InventoryScript.new()
	check(other.add_stack(moved) == 0 and other.slots[0].uses == 3, "uses travel with the item")
	check(other.add_stack({"id": "berries", "count": 4, "spoils_at": 77.0}) == 0, "stack added")
	near(other.slots[1].spoils_at, 77.0, 0.0001, "spoil time travels with the stack")


func test_food_rots_into_spoiled_food() -> void:
	var inv = InventoryScript.new()
	inv.add("berries", 6, 0.0)
	inv.add("stone", 2, 0.0)
	check(not inv.spoil_expired(100.0), "fresh at 100 s")
	check(inv.spoil_expired(900.0), "rotten at 900 s")
	check(inv.count_of("spoiled_food") == 6 and inv.count_of("stone") == 2, "only the food rotted")


func test_tool_types_lists_what_you_carry() -> void:
	var inv = InventoryScript.new()
	inv.add("knife", 1)
	inv.add("machete", 1)
	inv.add("stone", 3)
	var tools: Array = inv.tool_types()
	check(tools.has("knife") and tools.has("machete") and tools.size() == 2, "knife and machete (got %s)" % [tools])


func test_round_trips_through_dict() -> void:
	var inv = InventoryScript.new()
	inv.add("flint", 3)
	var copy = InventoryScript.new()
	copy.from_dict(inv.to_dict())
	check(copy.count_of("flint") == 3 and copy.slots.size() == InventoryScript.SIZE, "survives the network")
