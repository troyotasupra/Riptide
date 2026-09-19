class_name TerrainLayers
extends RefCounted
## The ground's photo layers — sand, grass, jungle floor, rock, wet sand — and the
## splat material that blends them. Each terrain vertex carries its layer as
## weights (UV = sand, grass; UV2 = jungle, rock; wet sand is what's left) and a
## tint in COLOR, relative to the layer's own colour, with 0.5 meaning "as is".

const SAND := 0
const GRASS := 1
const JUNGLE := 2
const ROCK := 3
const WET := 4

const FOLDERS := ["sand_01", "grass_001", "brown_mud_leaves_01", "rock_face_03", "coast_sand_01"]
## Metres per repeat, per layer.
const SCALES := [3.0, 2.5, 3.5, 5.0, 3.0]

static var _material: ShaderMaterial


## UV and UV2 for a vertex that is all `layer`.
static func uvs(layer: int) -> Array[Vector2]:
	var w := [0.0, 0.0, 0.0, 0.0]
	if layer < 4:
		w[layer] = 1.0
	return [Vector2(w[0], w[1]), Vector2(w[2], w[3])]


## A tint that shifts `layer`'s photo toward `wanted` (0.5 grey = unchanged).
static func tint(wanted: Color, base: Color) -> Color:
	return Color(
		clampf(0.5 * wanted.r / maxf(base.r, 0.02), 0.0, 1.0),
		clampf(0.5 * wanted.g / maxf(base.g, 0.02), 0.0, 1.0),
		clampf(0.5 * wanted.b / maxf(base.b, 0.02), 0.0, 1.0))


static func available() -> bool:
	for folder: String in FOLDERS:
		if not Materials.has_texture(folder):
			return false
	return true


## The shared splat material, or a plain vertex-colour one if the photos are missing.
static func material() -> Material:
	if _material != null:
		return _material
	if not available():
		var fallback := StandardMaterial3D.new()
		fallback.vertex_color_use_as_albedo = true
		fallback.vertex_color_is_srgb = true
		fallback.roughness = 1.0
		return fallback
	_material = ShaderMaterial.new()
	_material.shader = load("res://world/terrain/terrain.gdshader")
	var names := ["sand", "grass", "jungle", "rock", "wet"]
	for i in FOLDERS.size():
		_material.set_shader_parameter(names[i] + "_albedo", Materials.texture_map(FOLDERS[i], "albedo"))
		_material.set_shader_parameter(names[i] + "_normal", Materials.texture_map(FOLDERS[i], "normal"))
	_material.set_shader_parameter("scales_a", Vector4(SCALES[0], SCALES[1], SCALES[2], SCALES[3]))
	_material.set_shader_parameter("scale_wet", SCALES[4])
	var noise := FastNoiseLite.new()
	noise.seed = 77
	noise.frequency = 0.02
	noise.fractal_octaves = 4
	var macro := NoiseTexture2D.new()
	macro.width = 256
	macro.height = 256
	macro.seamless = true
	macro.noise = noise
	_material.set_shader_parameter("macro", macro)
	return _material


## Where burnt ground is (an R8 mask over `rect`), for the fire.
static func set_burn_mask(texture: Texture2D, rect: Rect2) -> void:
	var m := material()
	if m is ShaderMaterial:
		m.set_shader_parameter("burn_mask", texture)
		m.set_shader_parameter("burn_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
