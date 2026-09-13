extends Node
## Item pictures, rendered from each item's own 3D model in an off-screen
## studio (soft key light, rim light, transparent background) the first time
## they're needed, then cached. Icons match the item's grid shape, so a log's
## picture is long and a helmet's is square.

signal icon_ready(id: String)

const CELL_PIXELS := 96

var _cache := {}
var _queue: Array[String] = []
var _busy := false
var _viewport: SubViewport
var _camera: Camera3D
var _stage: Node3D


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.78, 0.85)
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_viewport.add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45.0, -35.0, 0.0)
	key.light_energy = 1.25
	_viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20.0, 150.0, 0.0)
	rim.light_energy = 0.6
	rim.light_color = Color(0.8, 0.9, 1.0)
	_viewport.add_child(rim)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.position = Vector3(0.0, 0.0, 10.0)
	_viewport.add_child(_camera)
	_stage = Node3D.new()
	_viewport.add_child(_stage)


## The picture for `id`, or null until it has been rendered (listen for icon_ready).
## `square` asks for a 1×1 picture of a long item laid diagonally (for hotbar slots).
func get_icon(id: String, square: bool = false) -> Texture2D:
	var key := id + ("#square" if square else "")
	if _cache.has(key):
		return _cache[key]
	if _viewport != null and not _queue.has(key) and ItemTable.exists(id):
		_queue.append(key)
	return null


func _process(_delta: float) -> void:
	if _busy or _queue.is_empty():
		return
	_render(_queue.pop_front())


func _render(key: String) -> void:
	_busy = true
	var square := key.ends_with("#square")
	var id := key.trim_suffix("#square")
	var cells := Vector2i.ONE if square else ItemTable.size_of(id)
	_viewport.size = cells * CELL_PIXELS
	var model := ItemModels.build(id)
	var pivot := Node3D.new()
	_stage.add_child(pivot)
	pivot.add_child(model)
	pivot.basis = _pose(model, cells, square)
	# Frame what the camera actually sees: the model's bounds after it's been posed.
	var bounds := _bounds_in(pivot, _stage)
	pivot.position = -bounds.get_center()
	var aspect := float(cells.x) / float(cells.y)
	_camera.size = maxf(bounds.size.y, bounds.size.x / aspect) * 1.08
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	_cache[key] = ImageTexture.create_from_image(image)
	pivot.queue_free()
	_busy = false
	icon_ready.emit(id)


## Lays the model's long side along the icon's long side (or its diagonal, for a
## square picture of a long item), turned a little so it reads as 3D.
static func _pose(model: Node3D, cells: Vector2i, square: bool = false) -> Basis:
	var local := _bounds(model)
	var long_axis := Vector3.RIGHT
	if local.size.y >= local.size.x and local.size.y >= local.size.z:
		long_axis = Vector3.UP
	elif local.size.z >= local.size.x:
		long_axis = Vector3.BACK
	var target := Vector3.RIGHT if cells.x > cells.y else Vector3.UP
	if square:
		target = Vector3(1.0, 1.0, 0.0).normalized()
	var align := Basis.IDENTITY
	if not long_axis.is_equal_approx(target):
		align = Basis(long_axis.cross(target).normalized(), long_axis.angle_to(target))
	var view := Basis(Vector3.UP, deg_to_rad(28.0)) * Basis(Vector3.RIGHT, deg_to_rad(22.0))
	if cells.x == cells.y and not square and long_axis != Vector3.BACK:
		view = view * Basis(Vector3.BACK, deg_to_rad(-35.0))
	return view * align


## Bounds of everything under `root`, measured in `space`'s coordinates.
static func _bounds_in(root: Node3D, space: Node3D) -> AABB:
	var inverse := space.global_transform.affine_inverse()
	var merged := AABB()
	var first := true
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var box := (inverse * mesh_instance.global_transform) * mesh_instance.get_aabb()
		merged = box if first else merged.merge(box)
		first = false
	return merged if not first else AABB(Vector3(-0.1, -0.1, -0.1), Vector3(0.2, 0.2, 0.2))


static func _bounds(root: Node3D) -> AABB:
	var inverse := root.global_transform.affine_inverse() if root.is_inside_tree() else Transform3D.IDENTITY
	var merged := AABB()
	var first := true
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var to_root := _relative(root, mesh_instance, inverse)
		var box := to_root * mesh_instance.get_aabb()
		merged = box if first else merged.merge(box)
		first = false
	return merged if not first else AABB(Vector3(-0.1, -0.1, -0.1), Vector3(0.2, 0.2, 0.2))


static func _relative(root: Node3D, node: Node3D, inverse: Transform3D) -> Transform3D:
	if root.is_inside_tree() and node.is_inside_tree():
		return inverse * node.global_transform
	var xf := node.transform
	var parent := node.get_parent()
	while parent != null and parent != root:
		if parent is Node3D:
			xf = (parent as Node3D).transform * xf
		parent = parent.get_parent()
	return root.transform.affine_inverse() * root.transform * xf if parent == root else xf
