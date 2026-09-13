class_name TerrainChunk
extends RefCounted
## One 64 m square of island terrain. build_data() is pure — no nodes — so it
## runs on worker threads and in tests; make_node() turns the data into a
## flat-shaded mesh with cheap heightmap collision on the main thread.

const SIZE := 64.0
const CELL := 2.0
const SAMPLES := 33  # SIZE / CELL + 1


static func build_data(shape: CampIsland, origin: Vector2) -> Dictionary:
	var heights := PackedFloat32Array()
	heights.resize(SAMPLES * SAMPLES)
	var max_height := -INF
	for iz in SAMPLES:
		for ix in SAMPLES:
			var h := shape.height_at(origin.x + ix * CELL, origin.y + iz * CELL)
			heights[iz * SAMPLES + ix] = h
			max_height = maxf(max_height, h)

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for iz in SAMPLES - 1:
		for ix in SAMPLES - 1:
			var a := Vector3(ix * CELL, heights[iz * SAMPLES + ix], iz * CELL)
			var b := Vector3((ix + 1) * CELL, heights[iz * SAMPLES + ix + 1], iz * CELL)
			var c := Vector3(ix * CELL, heights[(iz + 1) * SAMPLES + ix], (iz + 1) * CELL)
			var d := Vector3((ix + 1) * CELL, heights[(iz + 1) * SAMPLES + ix + 1], (iz + 1) * CELL)
			for tri: Array in [[a, b, c], [b, d, c]]:
				var p0: Vector3 = tri[0]
				var p1: Vector3 = tri[1]
				var p2: Vector3 = tri[2]
				var normal := (p2 - p0).cross(p1 - p0).normalized()
				var centroid := (p0 + p1 + p2) / 3.0
				var biome := shape.biome_at(origin.x + centroid.x, origin.y + centroid.z, centroid.y)
				var jitter := fposmod(sin((origin.x + p0.x) * 12.9898 + (origin.y + p0.z) * 78.233) * 43758.5453, 1.0)
				var color := CampIsland.color_for(biome, centroid.y, normal.y).darkened(jitter * 0.07)
				for p: Vector3 in [p0, p1, p2]:
					vertices.append(p)
					normals.append(normal)
					colors.append(color)
	return {
		"origin": origin,
		"heights": heights,
		"max_height": max_height,
		"vertices": vertices,
		"normals": normals,
		"colors": colors,
	}


static func make_node(data: Dictionary, material: Material) -> StaticBody3D:
	var origin: Vector2 = data.origin
	var body := StaticBody3D.new()
	body.name = "Chunk_%d_%d" % [int(origin.x), int(origin.y)]
	body.position = Vector3(origin.x, 0.0, origin.y)
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data.vertices
	arrays[Mesh.ARRAY_NORMAL] = data.normals
	arrays[Mesh.ARRAY_COLOR] = data.colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	body.add_child(visual)

	# HeightMapShape3D samples are 1 unit apart and centred on the node, so scale
	# the shape uniformly by the cell size and divide the heights to match.
	var source: PackedFloat32Array = data.heights
	var scaled := PackedFloat32Array()
	scaled.resize(source.size())
	for i in source.size():
		scaled[i] = source[i] / CELL
	var shape := HeightMapShape3D.new()
	shape.map_width = SAMPLES
	shape.map_depth = SAMPLES
	shape.map_data = scaled
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.scale = Vector3.ONE * CELL
	collider.position = Vector3(SIZE * 0.5, 0.0, SIZE * 0.5)
	body.add_child(collider)
	return body
