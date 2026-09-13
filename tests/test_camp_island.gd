extends "res://tests/test_case.gd"

const CampScript = preload("res://world/terrain/camp_island.gd")
const ChunkScript = preload("res://world/terrain/terrain_chunk.gd")


func test_same_seed_same_island() -> void:
	var a = CampScript.new(4242)
	var b = CampScript.new(4242)
	check(a.center == b.center and a.cove == b.cove and a.spring == b.spring and a.shipwreck == b.shipwreck, "landmarks match")
	for i in 40:
		var x: float = a.center.x + i * 9.7 - 190.0
		var z: float = a.center.y - i * 7.3 + 140.0
		near(a.height_at(x, z), b.height_at(x, z), 0.00001, "height at %.0f, %.0f" % [x, z])


func test_placed_650m_out_and_about_500m_across() -> void:
	for island_seed: int in [1, 99, 123456]:
		var island = CampScript.new(island_seed)
		near(island.center.length(), CampScript.DISTANCE_FROM_START, 0.01, "seed %d distance from start" % island_seed)
		check(island.height_at(island.center.x, island.center.y) > 3.0, "seed %d centre is land" % island_seed)
		var total := 0.0
		for k in 8:
			var dir := Vector2.from_angle(k * TAU / 8.0)
			var r := 0.0
			while r < CampScript.RADIUS * 1.6:
				var p: Vector2 = island.center + dir * r
				if island.height_at(p.x, p.y) < 0.0:
					break
				r += 2.0
			total += r
		var diameter := total / 8.0 * 2.0
		check(diameter > 330.0 and diameter < 600.0, "seed %d average land diameter %.0f m" % [island_seed, diameter])


func test_spring_pond_is_fresh_water_above_sea() -> void:
	for island_seed: int in [1, 99, 123456]:
		var island = CampScript.new(island_seed)
		check(island.spring_height > 3.0, "seed %d spring above sea (%.1f)" % [island_seed, island.spring_height])
		check(island.height_at(island.spring.x, island.spring.y) < island.spring_height, "seed %d pond bed is under the water line" % island_seed)


func test_stream_runs_downhill_into_the_sea() -> void:
	for island_seed: int in [1, 99, 123456]:
		var island = CampScript.new(island_seed)
		check(island.stream_bed(0.0) > island.stream_bed(1.0), "seed %d stream flows downhill" % island_seed)
		var mouth: Vector2 = island.stream_point(1.0)
		check(island.height_at(mouth.x, mouth.y) < 0.5, "seed %d stream reaches the sea" % island_seed)


func test_cove_is_a_beach_and_the_wreck_is_diveable() -> void:
	for island_seed: int in [1, 99, 123456]:
		var island = CampScript.new(island_seed)
		var cove_height: float = island.height_at(island.cove.x, island.cove.y)
		check(cove_height > 0.3 and cove_height < 3.0, "seed %d cove beach height %.2f" % [island_seed, cove_height])
		var wreck_depth: float = island.height_at(island.shipwreck.x, island.shipwreck.y)
		check(wreck_depth > -13.0 and wreck_depth < -4.0, "seed %d wreck seabed %.1f m" % [island_seed, wreck_depth])


func test_chunk_edges_meet_their_neighbours() -> void:
	var island = CampScript.new(7)
	var origin: Vector2 = (island.center / ChunkScript.SIZE).floor() * ChunkScript.SIZE
	var a: Dictionary = ChunkScript.build_data(island, origin)
	var b: Dictionary = ChunkScript.build_data(island, origin + Vector2(ChunkScript.SIZE, 0.0))
	var samples: int = ChunkScript.SAMPLES
	for iz in samples:
		near(a.heights[iz * samples + samples - 1], b.heights[iz * samples], 0.00001, "seam row %d" % iz)
	check(a.vertices.size() == (samples - 1) * (samples - 1) * 6, "two triangles per cell")
