class_name Materials
extends RefCounted
## Shared, cached surface materials with procedural detail — wood grain, bark,
## woven cloth, speckled stone, brushed metal — so props and items read as
## real materials instead of flat colour. Triplanar mapping avoids seams on
## scaled and generated meshes.

static var _cache := {}


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
	return _cached("metal_%s_%.2f" % [color.to_html(false), roughness], func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		# Mostly-metallic surfaces mirror the blue sky (even indoors); keep it subtle.
		m.metallic = 0.45 if roughness < 0.45 else 0.25
		m.metallic_specular = 0.55
		m.roughness = roughness
		return m)


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
