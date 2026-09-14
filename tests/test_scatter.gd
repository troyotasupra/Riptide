extends "res://tests/test_case.gd"

const CampScript = preload("res://world/terrain/camp_island.gd")
const ScatterScript = preload("res://world/scatter.gd")


func test_same_seed_same_props() -> void:
	var a: Array = ScatterScript.generate(CampScript.new(31))
	var b: Array = ScatterScript.generate(CampScript.new(31))
	check(a.size() == b.size(), "same prop count (%d vs %d)" % [a.size(), b.size()])
	for i in mini(a.size(), b.size()):
		if a[i].id != b[i].id or a[i].kind != b[i].kind or a[i].pos != b[i].pos:
			check(false, "prop %d differs" % i)
			break


func test_props_are_plentiful_unique_and_on_land() -> void:
	var island = CampScript.new(31)
	var spots: Array = ScatterScript.generate(island)
	check(spots.size() > 300 and spots.size() < 3000, "prop count %d" % spots.size())
	var ids := {}
	var kinds := {}
	for spot: Dictionary in spots:
		check(not ids.has(spot.id), "duplicate id %s" % spot.id)
		ids[spot.id] = true
		kinds[spot.kind] = true
		if spot.pos.y < 0.3:
			check(false, "%s %s is under water" % [spot.kind, spot.id])
			break
	for kind: String in ["palm", "fiber", "stone", "berry_bush", "red_berry_bush", "driftwood", "tree"]:
		check(kinds.has(kind), "island should have some %s" % kind)


func test_starter_island_has_just_enough() -> void:
	const IslandScript = preload("res://world/island_generator.gd")
	var island = IslandScript.new(31, 55.0)
	var a: Array = ScatterScript.generate_start(island)
	var b: Array = ScatterScript.generate_start(IslandScript.new(31, 55.0))
	check(a.size() == b.size() and (a.is_empty() or a[0].pos == b[0].pos), "same seed, same starter props")
	var counts := {}
	var ids := {}
	for spot: Dictionary in a:
		counts[spot.kind] = int(counts.get(spot.kind, 0)) + 1
		check(not ids.has(spot.id) and String(spot.id).begins_with("st_"), "unique starter id %s" % spot.id)
		ids[spot.id] = true
		check(spot.pos.y > 0.4, "%s is on land" % spot.id)
	check(int(counts.get("tree", 0)) >= 4, "enough trees for a raft's logs (%s)" % counts)
	check(int(counts.get("flint", 0)) >= 2 and int(counts.get("fiber", 0)) >= 8, "flint for a hatchet, fiber for rope")
	check(a.size() < 70, "but supplies are limited (%d props)" % a.size())


func test_steep_ground_only_gets_rocks() -> void:
	check(ScatterScript.pick(CampScript.Biome.JUNGLE, 0.5, 0.05) == "rock", "steep slope, low roll -> rock")
	check(ScatterScript.pick(CampScript.Biome.JUNGLE, 0.5, 0.9) == "", "steep slope, high roll -> nothing")
