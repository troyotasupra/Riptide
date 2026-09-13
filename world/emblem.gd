class_name Emblem
extends RefCounted
## Crew emblems drawn into small transparent textures in code, cached by
## emblem and colour. Shapes are tested per pixel in [-1, 1] space (v points down).

const SIZE := 64

static var _cache := {}
static var _star := PackedVector2Array()


static func texture(index: int, color: Color) -> Texture2D:
	var key := "%d_%s" % [index, color.to_html()]
	if _cache.has(key):
		return _cache[key]
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var hits := 0
			for sy in 2:
				for sx in 2:
					var u := (x + 0.25 + sx * 0.5) / SIZE * 2.0 - 1.0
					var v := (y + 0.25 + sy * 0.5) / SIZE * 2.0 - 1.0
					if inside(index, u, v):
						hits += 1
			if hits > 0:
				image.set_pixel(x, y, Color(color, hits / 4.0))
	var tex := ImageTexture.create_from_image(image)
	_cache[key] = tex
	return tex


## White on dark colours, near-black on light ones.
static func contrast(background: Color) -> Color:
	return Color(0.08, 0.08, 0.09) if background.get_luminance() > 0.55 else Color(0.96, 0.96, 0.94)


static func inside(index: int, u: float, v: float) -> bool:
	match index:
		1:
			return _in_star(u, v)
		2:
			return _in_anchor(u, v)
		3:
			return _in_skull(u, v)
		4:
			return _in_wave(u, v)
		5:
			return _in_compass(u, v)
		6:
			return absf(u) + absf(v) < 0.82
		7:
			return _in_chevron(u, v)
	return false


static func _in_star(u: float, v: float) -> bool:
	if _star.is_empty():
		for i in 10:
			var radius := 0.92 if i % 2 == 0 else 0.38
			var angle := -PI / 2.0 + i * PI / 5.0
			_star.append(Vector2(cos(angle), sin(angle)) * radius)
	return Geometry2D.is_point_in_polygon(Vector2(u, v + 0.06), _star)


static func _in_anchor(u: float, v: float) -> bool:
	var ring := Vector2(u, v + 0.64).length()
	if ring > 0.1 and ring < 0.2:
		return true
	if absf(u) < 0.075 and v > -0.46 and v < 0.66:
		return true
	if absf(v + 0.3) < 0.06 and absf(u) < 0.36:
		return true
	var arc := Vector2(u, v - 0.05).length()
	if arc > 0.55 and arc < 0.68 and v > 0.22:
		return true
	return v > 0.14 and v < 0.4 and absf(absf(u) - 0.62) < 0.05 + (0.4 - v) * 0.25


static func _in_skull(u: float, v: float) -> bool:
	var p := Vector2(u, v)
	var cranium := p.distance_to(Vector2(0.0, -0.14)) < 0.62
	var jaw := absf(u) < 0.34 and v > 0.2 and v < 0.68
	if not (cranium or jaw):
		return false
	if p.distance_to(Vector2(-0.24, -0.1)) < 0.16 or p.distance_to(Vector2(0.24, -0.1)) < 0.16:
		return false
	if v > 0.1 and v < 0.3 and absf(u) < (v - 0.1) * 0.45:
		return false
	return not (v > 0.46 and absf(fposmod(u + 1.0, 0.17) - 0.085) < 0.02)


static func _in_wave(u: float, v: float) -> bool:
	for offset: float in [-0.3, 0.3]:
		if absf(v - (sin(u * PI * 1.4) * 0.18 + offset)) < 0.11 and absf(u) < 0.86:
			return true
	return false


static func _in_compass(u: float, v: float) -> bool:
	var r := Vector2(u, v).length()
	if r > 0.72 and r < 0.84:
		return true
	return absf(u) * 3.2 + absf(v) < 0.78 or absf(v) * 3.2 + absf(u) < 0.5


static func _in_chevron(u: float, v: float) -> bool:
	for offset: float in [-0.32, 0.18]:
		if absf(v - (absf(u) * 0.75 + offset)) < 0.12 and absf(u) < 0.76:
			return true
	return false
