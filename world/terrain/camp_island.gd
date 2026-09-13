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
const POND_RADIUS := 9.0
const STREAM_WIDTH := 2.5
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
var cave := Vector2.ZERO
var camp := Vector2.ZERO
## Top of the beach in the sheltered cove where the sailboat lies.
var cove := Vector2.ZERO
var cove_bearing := 0.0
var shipwreck := Vector2.ZERO

var _cove_angle := 0.0
var _rock_angle := 0.0
var _stream_ready := false
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
	cave = hill + (center - hill).normalized() * 40.0
	spring = hill + Vector2.from_angle(hill_angle + side * PI * 0.5) * 48.0
	shipwreck = center + Vector2.from_angle(_rock_angle + side * 0.45) * RADIUS * 1.18

	# The spring feeds a stream running away from the hill down to the sea.
	spring_height = _base_height(spring.x, spring.y) - 1.0
	var away := (spring - hill).normalized()
	stream_mouth = spring
	var r := 0.0
	while r < RADIUS * 1.5:
		var p := spring + away * r
		if _base_height(p.x, p.y) < -0.5:
			break
		stream_mouth = p
		r += 2.0
	stream_mouth += away * 6.0
	_stream_ready = true

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
	var h := _base_height(x, z)
	if not _stream_ready:
		return h
	var p := Vector2(x, z)
	var pond_distance := p.distance_to(spring)
	if pond_distance < POND_RADIUS * 2.0:
		var pond_bed := spring_height - 1.3
		h = minf(h, lerpf(pond_bed, h, smoothstep(POND_RADIUS * 0.7, POND_RADIUS * 2.0, pond_distance)))
	var along := _stream_param(p)
	if along.x > 0.0 and along.x < 1.0 and along.y < STREAM_WIDTH * 3.0:
		h = minf(h, lerpf(stream_bed(along.x), h, smoothstep(STREAM_WIDTH, STREAM_WIDTH * 3.0, along.y)))
	return h


## Stream bed height at fraction `t` from the spring (0) to the sea (1).
func stream_bed(t: float) -> float:
	return lerpf(spring_height - 0.6, -1.2, t)


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
