class_name Materials
extends RefCounted
## Shared, cached surface materials with procedural detail — wood grain, bark,
## woven cloth, speckled stone, brushed metal — so props and items read as
## real materials instead of flat colour. Triplanar mapping avoids seams on
## scaled and generated meshes.

static var _cache := {}
static var _means := {}

const TEXTURES := "res://assets/textures/"
## How many metres one repeat of each photo texture covers.
const TEXTURE_METRES := {
	"sand_01": 2.5, "coast_sand_01": 2.5, "brown_mud_leaves_01": 3.0, "rock_face_03": 4.0,
	"coast_sand_rocks_02": 3.0, "gravelly_sand": 2.0, "rock_boulder_dry": 1.2, "bark_brown_02": 1.4,
	"palm_tree_bark": 1.0, "weathered_brown_planks": 2.0, "rough_wood": 1.2, "fine_grained_wood": 0.5,
	"rough_linen": 0.6, "hessian_230": 0.5, "corrugated_iron": 2.0, "grass_001": 2.0, "rope_001": 0.25,
	"metal_027": 0.35, "painted_metal_004": 0.5, "plastic_010": 0.3,
}


static func has_texture(folder: String) -> bool:
	return ResourceLoader.exists(TEXTURES + folder + "/albedo.jpg")


static func texture_map(folder: String, map: String) -> Texture2D:
	var path := "%s%s/%s.jpg" % [TEXTURES, folder, map]
	return load(path) if ResourceLoader.exists(path) else null


## The photo's average colour, so a material can be tinted toward the colour a
## caller asked for without the texture's own colour doubling up on it.
static func texture_mean(folder: String) -> Color:
	if _means.has(folder):
		return _means[folder]
	var mean := Color(0.5, 0.5, 0.5)
	var texture := texture_map(folder, "albedo")
	if texture != null:
		var image := texture.get_image()
		if image != null:
			if image.is_compressed():
				image.decompress()
			image.clear_mipmaps()
			while image.get_width() > 16 or image.get_height() > 16:
				image.shrink_x2()
			var total := Color(0, 0, 0)
			for y in image.get_height():
				for x in image.get_width():
					total += image.get_pixel(x, y)
			var n := float(image.get_width() * image.get_height())
			mean = Color(total.r / n, total.g / n, total.b / n)
	_means[folder] = mean
	return mean


## A photo-textured material: `folder` under assets/textures, tinted toward `color`
## (strength 0 keeps the photo's own colour, 1 matches `color` on average).
## `metres` overrides how big one repeat is; `world` maps it in world space so
## neighbouring pieces line up (terrain-like props), otherwise per object.
static func textured(folder: String, color: Color, strength: float = 0.6, metres: float = -1.0, roughness_scale: float = 1.0, world := false) -> StandardMaterial3D:
	var key := "tex_%s_%s_%.2f_%.2f_%.2f_%s" % [folder, color.to_html(false), strength, metres, roughness_scale, world]
	return _cached(key, func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		var mean := texture_mean(folder)
		var tint := Color(color.r / maxf(mean.r, 0.02), color.g / maxf(mean.g, 0.02), color.b / maxf(mean.b, 0.02))
		m.albedo_color = Color.WHITE.lerp(tint, strength)
		m.albedo_texture = texture_map(folder, "albedo")
		var normal := texture_map(folder, "normal")
		if normal != null:
			m.normal_enabled = true
			m.normal_texture = normal
			m.normal_scale = 1.0
		var rough := texture_map(folder, "rough")
		if rough != null:
			m.roughness_texture = rough
			m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		m.roughness = roughness_scale
		var size: float = metres if metres > 0.0 else float(TEXTURE_METRES.get(folder, 1.0))
		m.uv1_triplanar = true
		m.uv1_world_triplanar = world
		m.uv1_triplanar_sharpness = 4.0
		m.uv1_scale = Vector3.ONE / size
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		return m)


static func _noise(noise_seed: int, frequency: float, stretch: Vector2, octaves: int = 3, type: FastNoiseLite.NoiseType = FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = type
	noise.frequency = frequency
	noise.fractal_octaves = octaves
	noise.domain_warp_enabled = stretch != Vector2.ONE
	return noise


static func _texture(noise: FastNoiseLite, ramp: Gradient, size: Vector2i = Vector2i(256, 256), normal: bool = false, bump: float = 4.0) -> NoiseTexture2D:
	var texture := NoiseTexture2D.new()
	texture.width = size.x
	texture.height = size.y
	texture.noise = noise
	texture.seamless = true
	if normal:
		texture.as_normal_map = true
		texture.bump_strength = bump
	elif ramp != null:
		texture.color_ramp = ramp
	return texture


static func _ramp(dark: Color, light: Color, mid: float = 0.5) -> Gradient:
	var gradient := Gradient.new()
	gradient.set_color(0, dark)
	gradient.set_color(1, light)
	gradient.add_point(mid, dark.lerp(light, 0.5))
	return gradient


static func _cached(key: String, maker: Callable) -> StandardMaterial3D:
	if not _cache.has(key):
		_cache[key] = maker.call()
	return _cache[key]


static func plain(color: Color, roughness: float = 0.85) -> StandardMaterial3D:
	return _cached("plain_%s_%.2f" % [color.to_html(false), roughness], func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = roughness
		return m)


## Planed wood with long grain.
static func wood(color: Color) -> StandardMaterial3D:
	if has_texture("rough_wood"):
		return textured("rough_wood", color, 0.75)
	return _cached("wood_" + color.to_html(false), func() -> StandardMaterial3D:
		var noise := _noise(11, 0.02, Vector2(1.0, 8.0), 4)
		noise.frequency = 0.012
		var m := StandardMaterial3D.new()
		m.albedo_texture = _texture(noise, _ramp(color.darkened(0.28), color.lightened(0.12)), Vector2i(128, 512))
		m.normal_enabled = true
		m.normal_texture = _texture(_noise(12, 0.03, Vector2.ONE, 2), null, Vector2i(128, 512), true, 2.0)
		m.normal_scale = 0.4
		m.roughness = 0.8
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(1.6, 0.35, 1.6)
		return m)


## Rough, furrowed bark.
static func bark(color: Color) -> StandardMaterial3D:
	if has_texture("bark_brown_02"):
		return textured("bark_brown_02", color, 0.6)
	return _cached("bark_" + color.to_html(false), func() -> StandardMaterial3D:
		var noise := _noise(21, 0.05, Vector2.ONE, 5, FastNoiseLite.TYPE_CELLULAR)
		var m := StandardMaterial3D.new()
		m.albedo_texture = _texture(noise, _ramp(color.darkened(0.45), color.lightened(0.08), 0.6))
		m.normal_enabled = true
		m.normal_texture = _texture(_noise(22, 0.06, Vector2.ONE, 5, FastNoiseLite.TYPE_CELLULAR), null, Vector2i(256, 256), true, 10.0)
		m.normal_scale = 1.2
		m.roughness = 1.0
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(2.5, 0.8, 2.5)
		return m)


## Speckled, pitted stone.
static func stone(color: Color) -> StandardMaterial3D:
	if has_texture("rock_boulder_dry"):
		return textured("rock_boulder_dry", color, 0.7)
	return _cached("stone_" + color.to_html(false), func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_texture = _texture(_noise(31, 0.08, Vector2.ONE, 5), _ramp(color.darkened(0.3), color.lightened(0.15)))
		m.normal_enabled = true
		m.normal_texture = _texture(_noise(32, 0.12, Vector2.ONE, 4), null, Vector2i(256, 256), true, 6.0)
		m.normal_scale = 0.8
		m.roughness = 0.95
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(1.5, 1.5, 1.5)
		return m)


## Woven fabric.
static func cloth(color: Color) -> StandardMaterial3D:
	if has_texture("rough_linen"):
		return textured("rough_linen", color, 0.9)
	return _cached("cloth_" + color.to_html(false), func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.albedo_texture = _texture(_noise(41, 0.3, Vector2.ONE, 2), _ramp(Color(0.86, 0.86, 0.86), Color.WHITE))
		m.normal_enabled = true
		m.normal_texture = _texture(_noise(42, 0.45, Vector2.ONE, 1, FastNoiseLite.TYPE_CELLULAR), null, Vector2i(128, 128), true, 3.0)
		m.normal_scale = 0.35
		m.roughness = 1.0
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(6.0, 6.0, 6.0)
		return m)


static func leather(color: Color) -> StandardMaterial3D:
	return _cached("leather_" + color.to_html(false), func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.normal_enabled = true
		m.normal_texture = _texture(_noise(51, 0.25, Vector2.ONE, 3, FastNoiseLite.TYPE_CELLULAR), null, Vector2i(128, 128), true, 2.0)
		m.normal_scale = 0.3
		m.roughness = 0.65
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(4.0, 4.0, 4.0)
		return m)


static func metal(color: Color, roughness: float = 0.35) -> StandardMaterial3D:
	if has_texture("metal_027"):
		var m := textured("metal_027", color, 0.9, -1.0, roughness / 0.35)
		m.metallic = 0.45 if roughness < 0.45 else 0.25
		m.metallic_specular = 0.55
		return m
	return _cached("metal_%s_%.2f" % [color.to_html(false), roughness], func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		# Mostly-metallic surfaces mirror the blue sky (even indoors); keep it subtle.
		m.metallic = 0.45 if roughness < 0.45 else 0.25
		m.metallic_specular = 0.55
		m.roughness = roughness
		return m)


## Board siding and floors: grain with dark seams between boards (`board_width`
## metres wide) and staggered butt joints. Triplanar, so walls get vertical boards.
static func planks(color: Color, board_width: float = 0.25) -> StandardMaterial3D:
	if has_texture("weathered_brown_planks"):
		# The photo is eight boards across its two metres.
		return textured("weathered_brown_planks", color, 0.4, board_width * 8.0)
	return _cached("planks_%s_%.2f" % [color.to_html(false), board_width], func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.albedo_texture = plank_texture()
		m.uv1_triplanar = true
		var scale := 1.0 / (board_width * PLANK_COUNT)
		m.uv1_scale = Vector3(scale, scale, scale)
		m.roughness = 0.9
		return m)


const PLANK_COUNT := 8
static var _plank_image: ImageTexture


## Grayscale boards (tinted by the material colour): PLANK_COUNT boards across.
static func plank_texture() -> ImageTexture:
	if _plank_image != null:
		return _plank_image
	var width := 128
	var height := 512
	var noise := _noise(71, 0.05, Vector2.ONE, 3)
	var image := Image.create(width, height, false, Image.FORMAT_RGB8)
	for x in width:
		var board := x * PLANK_COUNT / width
		var across := x - board * width / PLANK_COUNT
		var shade := 0.88 + 0.1 * sin(board * 12.9898)
		var joint := int(fposmod(board * 173.0, float(height)))
		for y in height:
			var v := shade + noise.get_noise_2d(x * 1.5, y * 0.12) * 0.13
			if across < 2:
				v *= 0.42
			elif across == 2:
				v *= 0.78
			if absi(y - joint) < 2:
				v *= 0.55
			image.set_pixel(x, y, Color(v, v * 0.97, v * 0.93))
	image.generate_mipmaps()
	_plank_image = ImageTexture.create_from_image(image)
	return _plank_image


## Glowing, unlit (flames, embers).
static func glow(color: Color, energy: float = 2.0) -> StandardMaterial3D:
	return _cached("glow_%s_%.1f" % [color.to_html(false), energy], func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = color
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = energy
		return m)


## Growth rings for the cut end of a log.
static func tree_rings(color: Color) -> StandardMaterial3D:
	return _cached("rings_" + color.to_html(false), func() -> StandardMaterial3D:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.1, 0.2, 0.32, 0.44, 0.56, 0.68, 0.8, 0.88, 1.0])
		var light := color.lightened(0.25)
		var dark := color.darkened(0.1)
		gradient.colors = PackedColorArray([color.darkened(0.3), light, dark, light, dark, light, dark, light, color.darkened(0.45), color.darkened(0.55)])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 128
		texture.height = 128
		var m := StandardMaterial3D.new()
		m.albedo_texture = texture
		m.roughness = 0.9
		return m)


## Leaves and fronds: double-sided so thin blades show from both sides.
static func foliage(color: Color) -> StandardMaterial3D:
	return _cached("foliage_" + color.to_html(false), func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.albedo_texture = _texture(_noise(61, 0.1, Vector2.ONE, 3), _ramp(Color(0.8, 0.85, 0.8), Color.WHITE))
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.9
		m.backlight_enabled = true
		m.backlight = color.darkened(0.3)
		m.uv1_triplanar = true
		return m)


## A trunk the fire went through: black char with a faint grey bloom of ash,
## the cracks glinting a little.
static func charred() -> StandardMaterial3D:
	return _cached("charred", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.07, 0.065, 0.06)
		m.albedo_texture = _texture(_noise(83, 0.35, Vector2(1.0, 3.0), 4), _ramp(Color(0.55, 0.55, 0.55), Color(1.6, 1.55, 1.5), 0.62))
		m.roughness = 0.95
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * 0.8
		return m)


## Palm trunk rings.
static func palm_bark(color: Color) -> StandardMaterial3D:
	return textured("palm_tree_bark", color, 0.5) if has_texture("palm_tree_bark") else bark(color)


## Rope and lashings.
static func rope(color: Color) -> StandardMaterial3D:
	return textured("rope_001", color, 0.6) if has_texture("rope_001") else cloth(color)


## Tin roofing.
static func tin(color: Color) -> StandardMaterial3D:
	if not has_texture("corrugated_iron"):
		return metal(color, 0.5)
	var m := textured("corrugated_iron", color, 0.5)
	m.metallic = 0.5
	return m


## Burlap sacks and packs.
static func burlap(color: Color) -> StandardMaterial3D:
	return textured("hessian_230", color, 0.7) if has_texture("hessian_230") else cloth(color)


## A flat colour carrying only a photo's surface detail — its bumps and where it's
## rough or polished — for finishes whose colour matters more than the photo's.
static func detail(folder: String, color: Color, metres: float, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "detail_%s_%s_%.2f_%.2f_%.2f" % [folder, color.to_html(false), metres, roughness, metallic]
	return _cached(key, func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.metallic = metallic
		m.metallic_specular = 0.6
		var normal := texture_map(folder, "normal")
		if normal != null:
			m.normal_enabled = true
			m.normal_texture = normal
			m.normal_scale = 0.6
		var rough := texture_map(folder, "rough")
		if rough != null:
			m.roughness_texture = rough
			m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		m.roughness = roughness
		m.uv1_triplanar = true
		m.uv1_triplanar_sharpness = 6.0
		m.uv1_scale = Vector3.ONE / metres
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		return m)


## Gun parts: their own finish, with fine wear and machining marks from photos.
static func gun_steel(color: Color, roughness: float = 0.4) -> StandardMaterial3D:
	if not has_texture("metal_027"):
		return metal(color, roughness)
	return detail("metal_027", color, 0.15, clampf(roughness * 1.6, 0.3, 1.0), 0.55)


static func gun_polymer(color: Color) -> StandardMaterial3D:
	if not has_texture("plastic_010"):
		return plain(color, 0.8)
	return detail("plastic_010", color, 0.06, 1.0)


static func gun_wood(color: Color) -> StandardMaterial3D:
	return textured("fine_grained_wood", color, 0.85, 0.25) if has_texture("fine_grained_wood") else wood(color)
