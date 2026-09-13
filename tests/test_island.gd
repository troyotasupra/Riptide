extends "res://tests/test_case.gd"

const IslandScript = preload("res://world/island_generator.gd")


func test_same_seed_same_island() -> void:
	var a = IslandScript.new(1234, 55.0)
	var b = IslandScript.new(1234, 55.0)
	for i in 50:
		var x := i * 2.3 - 50.0
		var z := i * 1.7 - 40.0
		near(a.height_at(x, z), b.height_at(x, z), 0.00001, "height at %.1f, %.1f" % [x, z])


func test_different_seeds_differ() -> void:
	var a = IslandScript.new(1, 55.0)
	var b = IslandScript.new(2, 55.0)
	var difference := 0.0
	for i in 50:
		difference += absf(a.height_at(i * 2.0 - 50.0, 10.0) - b.height_at(i * 2.0 - 50.0, 10.0))
	check(difference > 1.0, "different seeds should make different islands (%.3f)" % difference)


func test_center_is_land_and_edges_are_sea() -> void:
	for island_seed: int in [1, 77, 90210]:
		var island = IslandScript.new(island_seed, 55.0)
		check(island.height_at(0.0, 0.0) > 3.0, "seed %d centre should be well above water" % island_seed)
		check(island.height_at(55.0 * 1.3, 0.0) < -2.0, "seed %d edge should be under water" % island_seed)


func test_shore_point_is_a_beach() -> void:
	for island_seed: int in [1, 77, 90210]:
		var island = IslandScript.new(island_seed, 55.0)
		var shore: Vector3 = island.find_shore_point(Vector2(0.0, 1.0))
		check(shore.y >= 0.8 and shore.y < 4.0, "seed %d shore height %.2f" % [island_seed, shore.y])
		check(shore.z > 10.0, "seed %d shore should be away from the centre (%.1f)" % [island_seed, shore.z])
