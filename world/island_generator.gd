class_name IslandGenerator
extends RefCounted
## Builds a low-poly island from a seed. Same seed, same island, on every
## machine — so the host only has to send a number, never the terrain.

const CELL := 2.0
const SEABED := -7.0
const BEACH_HEIGHT := 1.2

const WET_SAND := Color(0.66, 0.56, 0.38)
const SAND := Color(0.86, 0.75, 0.50)
const GRASS := Color(0.34, 0.58, 0.24)
const DARK_GRASS := Color(0.22, 0.44, 0.19)
const ROCK := Color(0.48, 0.45, 0.42)

var island_seed: int
var radius: float
var peak: float

var _terrain := FastNoiseLite.new()
var _outline := FastNoiseLite.new()


func _init(p_seed: int, p_radius: float = 55.0, p_peak: float = 4.5) -> void:
	island_seed = p_seed
	radius = p_radius
	peak = p_peak
	_terrain.seed = p_seed
	_terrain.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_terrain.frequency = 0.035
	_terrain.fractal_octaves = 3
	_outline.seed = p_seed + 7919
	_outline.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_outline.frequency = 0.9


## Terrain height at local (x, z). Positive is above sea level.
func height_at(x: float, z: float) -> float:
	var angle := atan2(z, x)
	var edge := radius * (0.8 + 0.35 * _outline.get_noise_2d(cos(angle) * 1.5, sin(angle) * 1.5))
	var d := Vector2(x, z).length() / edge
	# Profile from the sea inward: seabed -> shallow shelf -> flat beach -> low, gently rolling ground.
	var shelf := 1.0 - smoothstep(0.78, 1.0, d)
	var inland := 1.0 - smoothstep(0.2, 0.7, d)
	var bumps := (_terrain.get_noise_2d(x, z) + 1.0) * 0.5
	var upland := BEACH_HEIGHT + (peak - BEACH_HEIGHT) * (0.45 + 0.55 * bumps)
	return lerpf(SEABED, BEACH_HEIGHT, shelf) + (upland - BEACH_HEIGHT) * inland


## Walks out from the centre along `direction` and returns the last point
## still at or above `shore_height` — i.e. the top of the beach.
func find_shore_point(direction: Vector2, shore_height: float = 0.8) -> Vector3:
	var dir := direction.normalized()
	var last := Vector3(0.0, height_at(0.0, 0.0), 0.0)
	var r := 0.0
	while r < radius * 1.4:
		var p := dir * r
		var h := height_at(p.x, p.y)
		if h < shore_height:
			return last
		last = Vector3(p.x, h, p.y)
		r += 1.0
	return last


func build() -> StaticBody3D:
	var extent := radius * 1.35
	var cells := int(ceil(extent * 2.0 / CELL))
	var row := cells + 1
	var heights := PackedFloat32Array()
	heights.resize(row * row)
	for iz in row:
		for ix in row:
			heights[iz * row + ix] = height_at(-extent + ix * CELL, -extent + iz * CELL)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in cells:
		for ix in cells:
			var x0 := -extent + ix * CELL
			var z0 := -extent + iz * CELL
			var a := Vector3(x0, heights[iz * row + ix], z0)
			var b := Vector3(x0 + CELL, heights[iz * row + ix + 1], z0)
			var c := Vector3(x0, heights[(iz + 1) * row + ix], z0 + CELL)
			var d := Vector3(x0 + CELL, heights[(iz + 1) * row + ix + 1], z0 + CELL)
			if maxf(maxf(a.y, b.y), maxf(c.y, d.y)) <= SEABED + 0.01:
				continue
			_add_triangle(st, a, b, c)
			_add_triangle(st, b, d, c)
	st.index()
	st.generate_normals()
	var mesh := st.commit()

	var body := StaticBody3D.new()
	body.name = "Island"
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = TerrainLayers.material()
	body.add_child(visual)
	var collider := CollisionShape3D.new()
	collider.shape = mesh.create_trimesh_shape()
	body.add_child(collider)
	return body


func _add_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for p: Vector3 in [a, b, c]:
		# The slope at the vertex (not the face), so shared vertices match and merge.
		var slope := Vector3(height_at(p.x - CELL, p.z) - height_at(p.x + CELL, p.z), 2.0 * CELL,
			height_at(p.x, p.z - CELL) - height_at(p.x, p.z + CELL)).normalized()
		var normal := slope
		var layer := _layer_at(p.y, normal.y)
		var jitter := fposmod(sin(p.x * 12.9898 + p.z * 78.233) * 43758.5453, 1.0)
		var wanted := _color_at(p.y, normal.y).darkened(jitter * 0.08)
		var layer_uvs := TerrainLayers.uvs(layer)
		st.set_color(TerrainLayers.tint(wanted, LAYER_BASE[layer]))
		st.set_uv(layer_uvs[0])
		st.set_uv2(layer_uvs[1])
		st.add_vertex(p)


const LAYER_BASE := [SAND, GRASS, DARK_GRASS, ROCK, WET_SAND]


func _layer_at(h: float, normal_y: float) -> int:
	if h < -0.4:
		return TerrainLayers.WET
	if h < 1.4:
		return TerrainLayers.SAND if h > 0.35 else TerrainLayers.WET
	if normal_y < 0.75:
		return TerrainLayers.ROCK
	return TerrainLayers.GRASS


func _color_at(h: float, normal_y: float) -> Color:
	if h < -0.4:
		return WET_SAND
	if h < 1.4:
		return SAND
	if normal_y < 0.75:
		return ROCK
	return GRASS if h < peak * 0.7 else DARK_GRASS
