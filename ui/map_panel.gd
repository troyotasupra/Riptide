class_name MapPanel
extends PanelContainer
## The chart (M): both islands drawn from the world's own terrain, but only the
## parts you've been near are filled in; the rest is blank parchment until you go
## and look. In developer mode the whole chart shows. Marks you (an arrow), your
## crew, the fishing shack and what you've found.
##
## What's been seen is kept per world on this machine (user://maps/<seed>.map),
## so it survives a quit.

const METRES_PER_PIXEL := 4.0
const REVEAL_RADIUS := 70.0
## Seen areas are tracked on a coarser grid of this many metres.
const CELL := 12.0
const PARCHMENT := Color(0.86, 0.8, 0.66)
const INK := Color(0.28, 0.2, 0.13)

var _image: Image
var _full: ImageTexture
var _seen := {}
var _bounds := Rect2()
var _chart: TextureRect
var _marks: Control
var _dirty := true
var _reveal_accum := 0.0
var _seed := 0
var _unsaved := false
var _save_accum := 0.0


func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	UiKit.title(box, "Chart")
	_chart = TextureRect.new()
	_chart.custom_minimum_size = Vector2(760.0, 560.0)
	_chart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_chart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(_chart)
	# The marks draw straight over the chart, in its own rectangle.
	_marks = Control.new()
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.draw.connect(_draw_marks)
	_chart.add_child(_marks)
	_marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# One line: a wrapping label with no width to wrap to asks for a huge height.
	UiKit.label(box, "Only what you've seen is on the chart.   M / Esc: close", true).autowrap_mode = TextServer.AUTOWRAP_OFF
	visibility_changed.connect(func() -> void:
		_dirty = true)


func _process(delta: float) -> void:
	var world := GameState.world
	var player := GameState.local_player as Player
	if world == null or player == null or world.camp_island == null:
		return
	if _seed != GameState.world_seed:
		# A new world: forget the old chart; it's drawn again when first opened.
		_seed = GameState.world_seed
		_image = null
		_load_seen()
	_reveal_accum += delta
	if _reveal_accum >= 0.5:
		_reveal_accum = 0.0
		_reveal(player.world_transform().origin)
	_save_accum += delta
	if _unsaved and _save_accum >= 10.0:
		_save_accum = 0.0
		_unsaved = false
		_save_seen()
	if visible:
		# Keep it at its own size in the middle of the screen, whatever stretched it.
		var want := get_combined_minimum_size()
		if size != want:
			set_anchors_preset(Control.PRESET_TOP_LEFT)
			size = want
		position = (get_viewport_rect().size - want) * 0.5
		if _image == null:
			_build(world)
		if _dirty:
			_refresh()
		_marks.queue_redraw()


## Draws the terrain of both islands into one image, once per world (the first
## time the chart is opened, so loading a world never waits on it).
func _build(world: Node) -> void:
	var camp: CampIsland = world.camp_island
	var reach := CampIsland.RADIUS * 1.25
	var start_reach := 80.0
	var lo := Vector2(minf(camp.center.x - reach, -start_reach), minf(camp.center.y - reach, -start_reach))
	var hi := Vector2(maxf(camp.center.x + reach, start_reach), maxf(camp.center.y + reach, start_reach))
	_bounds = Rect2(lo, hi - lo)
	var width := int(_bounds.size.x / METRES_PER_PIXEL)
	var height := int(_bounds.size.y / METRES_PER_PIXEL)
	_image = Image.create(width, height, false, Image.FORMAT_RGB8)
	for py in height:
		for px in width:
			var p := lo + Vector2(px + 0.5, py + 0.5) * METRES_PER_PIXEL
			var h: float = world.ground_height(p.x, p.y)
			var color: Color
			if h == -INF or h < -0.3:
				var depth := 30.0 if h == -INF else -h
				color = Color(0.55, 0.72, 0.78).lerp(Color(0.25, 0.42, 0.55), clampf(depth / 30.0, 0.0, 1.0))
			elif p.distance_to(camp.center) < CampIsland.RADIUS * 1.5:
				color = CampIsland.color_for(camp.biome_at(p.x, p.y, h), h, camp.normal_y_at(p.x, p.y))
				# Contour-ish shading: higher ground a touch lighter.
				color = color.lightened(clampf(h / 120.0, 0.0, 0.25))
			else:
				color = CampIsland.SAND if h < 1.6 else CampIsland.COAST_GRASS
			# Every 10 m of height, a faint contour line.
			if h > 2.0 and fposmod(h, 10.0) < 0.6:
				color = color.darkened(0.25)
			_image.set_pixel(px, py, color)
	_full = ImageTexture.create_from_image(_image)
	_dirty = true


func _reveal(at: Vector3) -> void:
	var here := Vector2(at.x, at.z)
	var steps := int(ceil(REVEAL_RADIUS / CELL))
	var base := Vector2i(floori(here.x / CELL), floori(here.y / CELL))
	var added := false
	for dy in range(-steps, steps + 1):
		for dx in range(-steps, steps + 1):
			var cell := base + Vector2i(dx, dy)
			if _seen.has(cell):
				continue
			if (Vector2(cell) + Vector2(0.5, 0.5)).distance_to(here / CELL) * CELL <= REVEAL_RADIUS:
				_seen[cell] = true
				added = true
	if added:
		_dirty = true
		_unsaved = true


func _refresh() -> void:
	_dirty = false
	if _image == null:
		return
	if GameState.dev_mode:
		_chart.texture = _full
		return
	# Unseen ground is blank parchment; the edge of what's seen fades into it.
	var shown := _image.duplicate() as Image
	var width := shown.get_width()
	var height := shown.get_height()
	for py in height:
		for px in width:
			var p := _bounds.position + Vector2(px + 0.5, py + 0.5) * METRES_PER_PIXEL
			var cell := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
			if not _seen.has(cell):
				shown.set_pixel(px, py, PARCHMENT)
	_chart.texture = ImageTexture.create_from_image(shown)


## Where world point `p` falls on the chart as drawn (the texture is fitted and centred).
func _to_chart(p: Vector2) -> Vector2:
	var size := _marks.size
	var scale := minf(size.x / _bounds.size.x, size.y / _bounds.size.y)
	var offset := (size - _bounds.size * scale) * 0.5
	return offset + (p - _bounds.position) * scale


func _draw_marks() -> void:
	var world := GameState.world
	var player := GameState.local_player as Player
	if world == null or player == null or _image == null:
		return
	if not world.camp.shack.is_empty():
		var shack: Vector3 = Transform3D(world.camp.shack.xf).origin
		if _known(Vector2(shack.x, shack.z)):
			var at := _to_chart(Vector2(shack.x, shack.z))
			_marks.draw_rect(Rect2(at - Vector2(5, 5), Vector2(10, 10)), INK)
			_marks.draw_string(ThemeDB.fallback_font, at + Vector2(8, 4), "Shack", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)
	var camp: CampIsland = world.camp_island
	for spot: Array in [[camp.cave_mouth, "Cave"], [camp.camp, "Camp"], [camp.spring, "Spring"]]:
		if _known(spot[0]):
			var at := _to_chart(spot[0])
			_marks.draw_circle(at, 4.0, INK)
			_marks.draw_string(ThemeDB.fallback_font, at + Vector2(7, 4), spot[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)
	for other: Player in world.players_root.get_children():
		if other == player:
			continue
		var o := other.world_transform().origin
		_marks.draw_circle(_to_chart(Vector2(o.x, o.z)), 5.0, Color(0.2, 0.45, 0.85))
	# You: an arrow pointing the way you face.
	var me := player.world_transform().origin
	var at := _to_chart(Vector2(me.x, me.z))
	var facing := Vector2(-sin(player.yaw), -cos(player.yaw))
	var side := facing.orthogonal()
	_marks.draw_colored_polygon(PackedVector2Array([at + facing * 11.0, at - facing * 6.0 + side * 6.0, at - facing * 3.0, at - facing * 6.0 - side * 6.0]),
		Color(0.8, 0.15, 0.1))


func _known(p: Vector2) -> bool:
	return GameState.dev_mode or _seen.has(Vector2i(floori(p.x / CELL), floori(p.y / CELL)))


func _path() -> String:
	return "user://maps/%d.map" % _seed


func _load_seen() -> void:
	_seen.clear()
	if not GameState.scenario.is_empty():
		return
	var file := FileAccess.open(_path(), FileAccess.READ)
	if file == null:
		return
	var data: Variant = file.get_var()
	if data is PackedInt32Array:
		for i in range(0, (data as PackedInt32Array).size() - 1, 2):
			_seen[Vector2i(data[i], data[i + 1])] = true


func _save_seen() -> void:
	if not GameState.scenario.is_empty():
		return  # test runs never write to the player's own files
	DirAccess.make_dir_recursive_absolute("user://maps")
	var packed := PackedInt32Array()
	for cell: Vector2i in _seen:
		packed.append(cell.x)
		packed.append(cell.y)
	var file := FileAccess.open(_path(), FileAccess.WRITE)
	if file != null:
		file.store_var(packed)
