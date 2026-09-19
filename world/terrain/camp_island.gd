class_name CampIsland
extends RefCounted
## Island 2 — the camp island. About 500 m across and generated entirely from
## the world seed: heights, biomes, the spring and its stream, and where every
## point of interest sits. Every peer builds the identical island from the seed.

enum Biome { SEA, BEACH, ROCK_SHORE, PALM_COAST, JUNGLE, MEADOW, HILLS }

const RADIUS := 250.0
const DISTANCE_FROM_START := 650.0
const NEAR_SEABED := -14.0
const DEEP_SEABED := -30.0
const BEACH_HEIGHT := 1.2
const HILL_PEAK := 48.0
const HILL_RADIUS := 110.0
const POND_RADIUS := 7.0
const STREAM_WIDTH := 1.6
## The stream drops over one big waterfall on its way down: where along the run,
## how tall the rock band it falls over is, how wide that band runs across the
## hillside, and how big the plunge pool at its foot is.
const FALL_T := 0.22
const FALL_SPAN := 0.05
const FALL_HEIGHT := 9.0
const FALL_BAND := 26.0
const PLUNGE_RADIUS := 4.5
## The reef raises the seabed to this depth around the shipwreck, so it's always diveable.
const WRECK_DEPTH := -8.0
const REEF_RADIUS := 45.0

const SAND := Color(0.86, 0.75, 0.50)
const WET_SAND := Color(0.62, 0.54, 0.38)
const SHORE_ROCK := Color(0.40, 0.38, 0.36)
const COAST_GRASS := Color(0.55, 0.62, 0.32)
const JUNGLE_FLOOR := Color(0.20, 0.40, 0.17)
const MEADOW_GRASS := Color(0.43, 0.62, 0.25)
const HILL_GRASS := Color(0.40, 0.47, 0.30)
const ROCK := Color(0.48, 0.45, 0.42)

var island_seed: int
var center := Vector2.ZERO
var hill := Vector2.ZERO
var spring := Vector2.ZERO
## Surface level of the spring pond.
var spring_height := 0.0
var stream_mouth := Vector2.ZERO
## The cave: its mouth at the foot of the waterfall's cliff, beside the fall; a
## tunnel running back into the hill, and a round chamber at the end (`cave` is
## the chamber's middle). The terrain is cut down to the cave floor there;
## CaveBuild roofs it over.
var cave := Vector2.ZERO
var cave_mouth := Vector2.ZERO
var cave_dir := Vector2.ZERO
var cave_floor := 0.0
var _cave_ready := false
const CAVE_HALF := 2.4
const CAVE_TUNNEL := 14.0
const CAVE_ROOM := 6.5
## The cut's walls take this far to rise from the floor to the hillside.
const CAVE_WALL := 2.0
var camp := Vector2.ZERO
## Top of the beach in the sheltered cove where the sailboat lies.
var cove := Vector2.ZERO
var cove_bearing := 0.0
var shipwreck := Vector2.ZERO

var _cove_angle := 0.0
var _rock_angle := 0.0
var _stream_ready := false
## Direction the stream leaves the pool (the notch in its rim).
var _outflow := Vector2.RIGHT
## Bed height along the stream, sampled evenly from the pool to the sea.
var _bed: Array[float] = []
var _terrain := FastNoiseLite.new()
var _outline := FastNoiseLite.new()
var _biomes := FastNoiseLite.new()


func _init(p_seed: int) -> void:
	island_seed = p_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("camp_island:%d" % p_seed)
	_setup_noise(_terrain, p_seed + 101, 0.012, 4)
	_setup_noise(_outline, p_seed + 202, 1.2, 2)
	_setup_noise(_biomes, p_seed + 303, 0.008, 2)

	center = Vector2.from_angle(rng.randf() * TAU) * DISTANCE_FROM_START
	var toward_start := (-center).angle()

	# Hills rise on the far side from the start island; the cove faces the approach.
	var hill_angle := toward_start + PI + rng.randf_range(-0.6, 0.6)
	hill = center + Vector2.from_angle(hill_angle) * RADIUS * 0.42
	_rock_angle = hill_angle + rng.randf_range(-0.3, 0.3)
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	_cove_angle = toward_start + side * rng.randf_range(0.5, 0.9)
	cove_bearing = _cove_angle
	camp = center + Vector2.from_angle(hill_angle - side * PI * 0.62) * RADIUS * 0.38
	# The pool sits high on the hill's flank, on the flattest bench we can find so
	# it has somewhere to sit, and far enough up that its stream can fall a long way.
	spring = _flattest_bench(hill, hill_angle + side * PI * 0.5)
	shipwreck = center + Vector2.from_angle(_rock_angle + side * 0.45) * RADIUS * 1.18

	# The spring feeds a stream running away from the hill down to the sea.
	# The pool can only stand as high as the lowest point of its rim, or it would
	# simply run out down the hill.
	var rim := INF
	for j in 12:
		var edge := spring + Vector2.from_angle(TAU * j / 12.0) * POND_RADIUS
		rim = minf(rim, _base_height(edge.x, edge.y))
	spring_height = rim - 0.25
	var away := (spring - hill).normalized()
	_outflow = away
	stream_mouth = spring
	var r := 0.0
	while r < RADIUS * 1.5:
		var p := spring + away * r
		if _base_height(p.x, p.y) < -0.5:
			break
		stream_mouth = p
		r += 2.0
	stream_mouth += away * 6.0
	_build_bed()
	_stream_ready = true
	_place_cave()

	# The cove beach: walk in from the sea along its bearing until we reach sand.
	var dir := Vector2.from_angle(_cove_angle)
	r = RADIUS * 1.2
	cove = center + dir * r
	while r > 0.0:
		var p := center + dir * r
		if height_at(p.x, p.y) > 0.4:
			cove = p
			break
		r -= 1.0


static func _setup_noise(noise: FastNoiseLite, noise_seed: int, frequency: float, octaves: int) -> void:
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_octaves = octaves


## Terrain height at world (x, z). Positive is above sea level.
func height_at(x: float, z: float) -> float:
	var h := height_over_cave(x, z)
	if _cave_ready:
		h = _cave_cut(Vector2(x, z), h)
	return h


## Behind the waterfall's cliff, beside the fall: the mouth sits at the cliff foot
## (full drop is 5 m past the brink) and the cave runs back under the brink's shelf.
func _place_cave() -> void:
	var brink := stream_point(FALL_T)
	var side := _outflow.orthogonal()
	cave_dir = -_outflow
	cave_mouth = brink + _outflow * 5.5 + side * 7.5
	cave_floor = height_at(cave_mouth.x, cave_mouth.y) + 0.05
	cave = cave_mouth + cave_dir * (CAVE_TUNNEL + CAVE_ROOM * 0.7)
	_cave_ready = true


## How far `p` is outside the cave's floor (negative inside, 0 at the wall's foot).
func cave_edge(p: Vector2) -> float:
	if not _cave_ready:
		return INF
	var rel := p - cave_mouth
	var along := rel.dot(cave_dir)
	var edge := INF
	if along > -2.5 and along < CAVE_TUNNEL + 2.0:
		# The tunnel wanders a little from side to side as it goes in.
		var wander := sin(along * 0.45) * 0.6
		edge = absf(rel.dot(cave_dir.orthogonal()) - wander) - CAVE_HALF
	return minf(edge, p.distance_to(cave) - CAVE_ROOM)


## Inside the cave, or its walls (props keep out of it).
func in_cave(p: Vector2, margin: float = 0.0) -> bool:
	return cave_edge(p) < CAVE_WALL + margin


func _cave_cut(p: Vector2, h: float) -> float:
	var edge := cave_edge(p)
	if edge >= CAVE_WALL:
		return h
	# A floor that isn't billiard-table flat.
	var floor_h := cave_floor + sin(p.x * 0.9) * sin(p.y * 1.1) * 0.08
	return minf(h, lerpf(floor_h, h, smoothstep(0.0, CAVE_WALL, edge)))


## The hillside as it would be without the cave cut into it (the cave's roof).
func height_over_cave(x: float, z: float) -> float:
	var h := _base_height(x, z)
	if not _stream_ready:
		return h
	var p := Vector2(x, z)
	# A band of rock crosses the hillside; the stream falls over it.
	h = _after_scarp(h, FALL_HEIGHT * _scarp(p))
	var pond_distance := p.distance_to(spring)
	if pond_distance < POND_RADIUS * 2.6:
		# A low rim holds the pool in its bench, notched where the stream leaves.
		var outlet := 1.0 - smoothstep(0.3, 1.0, absf(angle_difference((p - spring).angle(), _outflow.angle())))
		var lip := smoothstep(POND_RADIUS * 2.6, POND_RADIUS * 1.1, pond_distance) * (1.0 - outlet)
		h = lerpf(h, maxf(h, minf(spring_height + 0.6, h + 1.0)), lip)
		var pond_bed := spring_height - 1.3
		h = minf(h, lerpf(pond_bed, h, smoothstep(POND_RADIUS * 0.7, POND_RADIUS * 1.3, pond_distance)))
		# A notch where the stream leaves, so the pool has an outflow.
		h = minf(h, lerpf(spring_height - 0.15, h, smoothstep(STREAM_WIDTH, STREAM_WIDTH * 2.5,
			absf((p - spring).dot(_outflow.orthogonal())))) if outlet > 0.5 else h)
	var plunge_distance := p.distance_to(stream_point(FALL_T + FALL_SPAN))
	if plunge_distance < PLUNGE_RADIUS * 1.4:
		var plunge_bed := stream_bed(FALL_T + FALL_SPAN) - 0.6
		h = minf(h, lerpf(plunge_bed, h, smoothstep(PLUNGE_RADIUS * 0.5, PLUNGE_RADIUS * 1.4, plunge_distance)))
	var along := _stream_param(p)
	if along.x > 0.0 and along.x < 1.0 and along.y < STREAM_WIDTH * 3.0:
		h = minf(h, lerpf(stream_bed(along.x), h, smoothstep(STREAM_WIDTH, STREAM_WIDTH * 3.0, along.y)))
	return h


## How much of the rock step's drop applies at `p`: the ground falls away just
## past the brink, hollowing out a basin, then climbs back to the hillside below
## it, and it fades out to either side. The island's shape is otherwise untouched.
func _scarp(p: Vector2) -> float:
	if not _stream_ready:
		return 0.0
	return _scarp_at(p, stream_point(FALL_T))


## Stream bed height at fraction `t` from the pool (0) to the sea (1), read from
## the profile worked out when the island was made.
func stream_bed(t: float) -> float:
	if _bed.is_empty():
		return spring_height - 0.5
	var at := clampf(t, 0.0, 1.0) * (_bed.size() - 1)
	var i := mini(int(at), _bed.size() - 2)
	return lerpf(_bed[i], _bed[i + 1], at - i)


## Works out the stream's bed once: it follows the hillside a little under the
## surface, only ever runs downhill, keeps a level shelf at the brink of the
## waterfall, and meets the sea at the bottom.
func _build_bed() -> void:
	const STEPS := 96
	_bed.clear()
	var lowest := spring_height - 0.5
	for i in STEPS + 1:
		var t := float(i) / STEPS
		var p := stream_point(t)
		var natural := _after_scarp(_base_height(p.x, p.y), FALL_HEIGHT * _raw_scarp(p))
		var bed := minf(lowest, natural - 0.3)
		if t > FALL_T - 0.05 and t <= FALL_T:
			bed = lowest  # a level shelf running out to the brink
		lowest = bed
		_bed.append(bed)
	# Ease the last stretch into the sea so it doesn't end on a step.
	for i in range(STEPS + 1):
		var t := float(i) / STEPS
		if t > 0.88:
			_bed[i] = lerpf(_bed[i], -1.2, smoothstep(0.88, 1.0, t))


## The step before the bed exists (used while working the bed out).
func _raw_scarp(p: Vector2) -> float:
	return _scarp_at(p, spring + _outflow * (stream_mouth - spring).length() * FALL_T)


## The rock step never cuts the hillside below this, so it can't gouge a hole in
## the island or let the sea in behind the beach.
const SCARP_FLOOR := 3.0


static func _after_scarp(h: float, step: float) -> float:
	if step <= 0.0:
		return h
	return maxf(h - step, minf(h, SCARP_FLOOR))


func _scarp_at(p: Vector2, brink: Vector2) -> float:
	var ahead := (p - brink).dot(_outflow)
	var across := absf((p - brink).dot(_outflow.orthogonal()))
	if ahead < -2.0 or ahead > 30.0 or across > FALL_BAND:
		return 0.0
	var down := smoothstep(0.0, 5.0, ahead) * (1.0 - smoothstep(13.0, 30.0, ahead))
	return down * (1.0 - smoothstep(FALL_BAND * 0.5, FALL_BAND, across))


## The flattest patch of hillside near the top, for the pool to sit in.
func _flattest_bench(from: Vector2, bearing: float) -> Vector2:
	var best := from + Vector2.from_angle(bearing) * 32.0
	var best_score := INF
	for i in 24:
		var angle := bearing + (i % 6 - 2.5) * 0.22
		var radius := 26.0 + float(i / 6) * 7.0
		var spot := from + Vector2.from_angle(angle) * radius
		var middle := _base_height(spot.x, spot.y)
		var score := 0.0
		for j in 8:
			var edge := spot + Vector2.from_angle(TAU * j / 8.0) * POND_RADIUS
			score += absf(_base_height(edge.x, edge.y) - middle)
		if score < best_score:
			best_score = score
			best = spot
	return best


## The brink and the foot of the waterfall, and which way the water is falling.
func waterfall() -> Dictionary:
	var top := stream_point(FALL_T)
	var foot := stream_point(FALL_T + FALL_SPAN)
	var direction := (foot - top)
	if direction.length() < 0.01:
		direction = _outflow
	return {
		"top": Vector3(top.x, stream_bed(FALL_T), top.y),
		"foot": Vector3(foot.x, stream_bed(FALL_T + FALL_SPAN), foot.y),
		"direction": direction.normalized(),
	}


## World position of the stream's centre line at fraction `t`.
func stream_point(t: float) -> Vector2:
	var along := stream_mouth - spring
	return spring + along * t + along.normalized().orthogonal() * _stream_offset(t)


func distance_to_stream(p: Vector2) -> float:
	var along := _stream_param(p)
	return along.y if along.x > 0.0 and along.x < 1.0 else INF


func normal_y_at(x: float, z: float) -> float:
	const E := 1.0
	var hx := height_at(x + E, z) - height_at(x - E, z)
	var hz := height_at(x, z + E) - height_at(x, z - E)
	return Vector3(-hx, 2.0 * E, -hz).normalized().y


func biome_at(x: float, z: float, h: float) -> Biome:
	if h < -0.3:
		return Biome.SEA
	var p := Vector2(x, z)
	if h < BEACH_HEIGHT + 0.8:
		if absf(angle_difference((p - center).angle(), _rock_angle)) < 0.55:
			return Biome.ROCK_SHORE
		return Biome.BEACH
	if p.distance_to(hill) < HILL_RADIUS * 0.6 or h > 30.0:
		return Biome.HILLS
	if h < BEACH_HEIGHT + 3.5:
		return Biome.PALM_COAST
	if _biomes.get_noise_2d(x, z) > -0.1:
		return Biome.JUNGLE
	return Biome.MEADOW


## Each photo layer's own colour, which color_for's colours are measured against.
const LAYER_BASE := [SAND, MEADOW_GRASS, JUNGLE_FLOOR, ROCK, WET_SAND]


## Which photo layer (TerrainLayers) the ground here is.
static func layer_for(biome: Biome, h: float, normal_y: float) -> int:
	if biome == Biome.SEA:
		return TerrainLayers.WET
	if normal_y < 0.72 and biome != Biome.BEACH:
		return TerrainLayers.ROCK
	match biome:
		Biome.BEACH:
			return TerrainLayers.SAND if h > 0.35 else TerrainLayers.WET
		Biome.ROCK_SHORE:
			return TerrainLayers.ROCK
		Biome.PALM_COAST, Biome.MEADOW:
			return TerrainLayers.GRASS
		Biome.JUNGLE:
			return TerrainLayers.JUNGLE
	return TerrainLayers.ROCK if h > 40.0 else TerrainLayers.GRASS


static func color_for(biome: Biome, h: float, normal_y: float) -> Color:
	if biome == Biome.SEA:
		return WET_SAND.darkened(clampf(-h / 30.0, 0.0, 0.5))
	if normal_y < 0.72 and biome != Biome.BEACH:
		return ROCK
	if biome == Biome.BEACH:
		return SAND
	if biome == Biome.ROCK_SHORE:
		return SHORE_ROCK
	if biome == Biome.PALM_COAST:
		return COAST_GRASS
	if biome == Biome.JUNGLE:
		return JUNGLE_FLOOR
	if biome == Biome.MEADOW:
		return MEADOW_GRASS
	return ROCK if h > 40.0 else HILL_GRASS


func _base_height(x: float, z: float) -> float:
	var local := Vector2(x, z) - center
	var angle := local.angle()
	var edge := RADIUS * (0.84 + 0.26 * _outline.get_noise_2d(cos(angle) * 1.5, sin(angle) * 1.5))
	edge *= 1.0 - 0.25 * _angular_bump(angle, _cove_angle, 0.32)  # the cove bites into the coast
	var d := local.length() / edge
	var shelf := 1.0 - smoothstep(0.8, 1.0, d)
	var inland := 1.0 - smoothstep(0.1, 0.72, d)
	var bumps := (_terrain.get_noise_2d(x, z) + 1.0) * 0.5
	var lowland := 3.0 + 14.0 * bumps
	var hill_lift := HILL_PEAK * pow(maxf(0.0, 1.0 - Vector2(x, z).distance_to(hill) / HILL_RADIUS), 1.6)
	var sea_floor := lerpf(DEEP_SEABED, NEAR_SEABED, clampf(2.2 - d * 1.2, 0.0, 1.0))
	var reef := maxf(0.0, 1.0 - Vector2(x, z).distance_to(shipwreck) / REEF_RADIUS)
	var coast := lerpf(lerpf(sea_floor, WRECK_DEPTH, reef), BEACH_HEIGHT, shelf)
	return coast + lowland * inland + hill_lift * shelf


## (t along the stream 0..1, distance from its wandering centre line)
func _stream_param(p: Vector2) -> Vector2:
	var along := stream_mouth - spring
	var length_sq := along.length_squared()
	if length_sq < 1.0:
		return Vector2(-1.0, INF)
	var t := (p - spring).dot(along) / length_sq
	var offset := (p - spring).dot(along.normalized().orthogonal()) - _stream_offset(clampf(t, 0.0, 1.0))
	return Vector2(t, absf(offset))


func _stream_offset(t: float) -> float:
	return _outline.get_noise_1d(t * 5.0 + 91.0) * 8.0 * sin(PI * t)


static func _angular_bump(angle: float, target: float, width: float) -> float:
	return 1.0 - smoothstep(0.0, width, absf(angle_difference(angle, target)))
