class_name Scatter
extends RefCounted
## Deterministic prop placement on the camp island: the same seed puts the same
## palms, bushes and stones in the same places on every machine, so the host
## only ever sends *changes* (what got picked), never the props themselves.

const CELL := 16.0
const TRIES_PER_CELL := 3
const LANDMARK_CLEARANCE := 14.0
const STREAM_CLEARANCE := 5.0

## Per-try chance of each kind, by biome.
const TABLE := {
	CampIsland.Biome.BEACH: [["palm", 0.10], ["driftwood", 0.12], ["stone", 0.04]],
	CampIsland.Biome.ROCK_SHORE: [["stone", 0.22], ["flint", 0.12], ["rock", 0.08]],
	CampIsland.Biome.PALM_COAST: [["palm", 0.32], ["fiber", 0.14], ["berry_bush", 0.06], ["stone", 0.04]],
	CampIsland.Biome.JUNGLE: [["tree", 0.38], ["fiber", 0.14], ["berry_bush", 0.07], ["red_berry_bush", 0.08], ["palm", 0.04]],
	CampIsland.Biome.MEADOW: [["fiber", 0.20], ["berry_bush", 0.12], ["red_berry_bush", 0.05], ["tree", 0.06], ["stone", 0.05]],
	CampIsland.Biome.HILLS: [["rock", 0.22], ["stone", 0.14], ["flint", 0.12], ["tree", 0.05]],
}


static func generate(shape: CampIsland) -> Array[Dictionary]:
	var spots: Array[Dictionary] = []
	var landmarks: Array[Vector2] = [shape.camp, shape.cove, shape.cave, shape.spring]
	var extent := CampIsland.RADIUS * 1.1
	var cells := int(ceil(extent * 2.0 / CELL))
	for iz in cells:
		for ix in cells:
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(Vector3i(shape.island_seed, ix, iz))
			for i in TRIES_PER_CELL:
				# Draw every random number up front so skipped tries never shift later ones.
				var x := shape.center.x - extent + (ix + rng.randf()) * CELL
				var z := shape.center.y - extent + (iz + rng.randf()) * CELL
				var roll := rng.randf()
				var yaw := rng.randf() * TAU
				var size := rng.randf_range(0.85, 1.2)
				var h := shape.height_at(x, z)
				if h < 0.3:
					continue
				var kind := pick(shape.biome_at(x, z, h), shape.normal_y_at(x, z), roll)
				if kind.is_empty() or _crowds_landmark(shape, landmarks, Vector2(x, z)):
					continue
				spots.append({"id": "%d_%d_%d" % [ix, iz, i], "kind": kind, "pos": Vector3(x, h, z), "yaw": yaw, "scale": size})
	return spots


static func pick(biome: int, normal_y: float, roll: float) -> String:
	if normal_y < 0.75:
		if roll < 0.15:
			return "rock"
		return "stone" if roll < 0.25 else ""
	var cumulative := 0.0
	for entry: Array in TABLE.get(biome, []):
		cumulative += float(entry[1])
		if roll < cumulative:
			return entry[0]
	return ""


static func _crowds_landmark(shape: CampIsland, landmarks: Array[Vector2], p: Vector2) -> bool:
	for landmark in landmarks:
		if p.distance_to(landmark) < LANDMARK_CLEARANCE:
			return true
	return shape.distance_to_stream(p) < STREAM_CLEARANCE
