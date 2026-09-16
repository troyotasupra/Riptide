class_name ShelterMap
extends RefCounted
## Where the sea is sheltered. A coarse world-space map of "openness": 0 in the
## shallows — coves, the dock, the beach shelf — rising to 1 out in open water.
## Waves.roughness and water.gdshader both read it, so the waves you see and the
## waves boats float on stay identical. Every peer builds it from the same seed.

## Water this deep (metres) is fully open sea; shallower water calms toward shore.
const SHOAL_DEPTH := 11.0

static var texture: ImageTexture
## World-space area the map covers (x, z).
static var rect := Rect2()

static var _image: Image


## Samples `height_at(x, z)` (terrain height, -INF for open sea) over `world_rect`.
static func build(height_at: Callable, world_rect: Rect2, resolution: int = 256) -> void:
	var image := Image.create_empty(resolution, resolution, false, Image.FORMAT_R8)
	var step := world_rect.size / float(resolution)
	for iy in resolution:
		for ix in resolution:
			var x := world_rect.position.x + (ix + 0.5) * step.x
			var z := world_rect.position.y + (iy + 0.5) * step.y
			var h: float = height_at.call(x, z)
			var openness := 1.0 if h == -INF else smoothstep(0.0, SHOAL_DEPTH, -h)
			image.set_pixel(ix, iy, Color(openness, 0.0, 0.0))
	_blur(image)
	_image = image
	rect = world_rect
	texture = ImageTexture.create_from_image(image)


## Softens the map so the sea eases from calm to open instead of stepping.
static func _blur(image: Image) -> void:
	var size := image.get_width()
	for pass_index in 2:
		var source := image.duplicate() as Image
		for y in size:
			for x in size:
				var total := 0.0
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						total += source.get_pixel(clampi(x + dx, 0, size - 1), clampi(y + dy, 0, size - 1)).r
				image.set_pixel(x, y, Color(total / 9.0, 0.0, 0.0))


static func clear() -> void:
	_image = null
	texture = null
	rect = Rect2()


## 0 fully sheltered .. 1 open sea, sampled bilinearly like the shader does.
static func value(xz: Vector2) -> float:
	if _image == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return 1.0
	var uv := (xz - rect.position) / rect.size
	if uv.x < 0.0 or uv.y < 0.0 or uv.x > 1.0 or uv.y > 1.0:
		return 1.0
	var w := _image.get_width()
	var h := _image.get_height()
	var px := uv.x * w - 0.5
	var py := uv.y * h - 0.5
	var x0 := floori(px)
	var y0 := floori(py)
	var fx := px - x0
	var fy := py - y0
	var top := lerpf(_texel(x0, y0, w, h), _texel(x0 + 1, y0, w, h), fx)
	var bottom := lerpf(_texel(x0, y0 + 1, w, h), _texel(x0 + 1, y0 + 1, w, h), fx)
	return lerpf(top, bottom, fy)


static func _texel(x: int, y: int, w: int, h: int) -> float:
	return _image.get_pixel(clampi(x, 0, w - 1), clampi(y, 0, h - 1)).r
