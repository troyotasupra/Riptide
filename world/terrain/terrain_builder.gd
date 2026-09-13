class_name TerrainBuilder
extends Node3D
## Builds an island's terrain chunks on worker threads and adds them to the
## scene a couple per frame, so a 500 m island loads without a hitch.

signal finished

const CHUNKS_PER_FRAME := 2
## Chunks lying entirely deeper than this are open ocean floor nobody will see.
const SKIP_BELOW := CampIsland.DEEP_SEABED + 2.0

var _shape: CampIsland
var _origins: Array[Vector2] = []
var _built: Array[Dictionary] = []
var _mutex := Mutex.new()
var _task := -1
var _handled := 0
var _material := StandardMaterial3D.new()


func start(shape: CampIsland) -> void:
	_shape = shape
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_material.roughness = 1.0
	var extent := CampIsland.RADIUS * 1.5
	var first := ((shape.center - Vector2(extent, extent)) / TerrainChunk.SIZE).floor() * TerrainChunk.SIZE
	var count := int(ceil(extent * 2.0 / TerrainChunk.SIZE)) + 1
	for iz in count:
		for ix in count:
			_origins.append(first + Vector2(ix, iz) * TerrainChunk.SIZE)
	_task = WorkerThreadPool.add_group_task(_build_chunk, _origins.size(), -1, false, "Camp island terrain")


func _build_chunk(index: int) -> void:
	var data := TerrainChunk.build_data(_shape, _origins[index])
	_mutex.lock()
	_built.append(data)
	_mutex.unlock()


func _process(_delta: float) -> void:
	if _task == -1:
		return
	_mutex.lock()
	var batch := _built.slice(0, CHUNKS_PER_FRAME)
	_built = _built.slice(CHUNKS_PER_FRAME)
	_mutex.unlock()
	for data in batch:
		_handled += 1
		if data.max_height > SKIP_BELOW:
			add_child(TerrainChunk.make_node(data, _material))
	if _handled >= _origins.size():
		WorkerThreadPool.wait_for_group_task_completion(_task)
		_task = -1
		print("[terrain] camp island built: %d chunks" % get_child_count())
		finished.emit()


func _exit_tree() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_group_task_completion(_task)
		_task = -1
