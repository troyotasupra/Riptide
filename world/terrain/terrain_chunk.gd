class_name TerrainChunk
extends RefCounted
## One 64 m square of island terrain. build_data() is pure — no nodes — so it
## runs on worker threads and in tests; make_node() turns the data into a
## smooth, photo-splatted mesh with cheap heightmap collision on the main thread.

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

	# One vertex per grid sample, shared by its triangles: smooth normals from the
	# heightfield (sampled past the edge, so neighbouring chunks agree), and the
	# ground layer and tint for the photo splat.
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	for iz in SAMPLES:
		for ix in SAMPLES:
			var wx := origin.x + ix * CELL
			var wz := origin.y + iz * CELL
			var h := heights[iz * SAMPLES + ix]
			var left := heights[iz * SAMPLES + ix - 1] if ix > 0 else shape.height_at(wx - CELL, wz)
			var right := heights[iz * SAMPLES + ix + 1] if ix < SAMPLES - 1 else shape.height_at(wx + CELL, wz)
			var back := heights[(iz - 1) * SAMPLES + ix] if iz > 0 else shape.height_at(wx, wz - CELL)
			var front := heights[(iz + 1) * SAMPLES + ix] if iz < SAMPLES - 1 else shape.height_at(wx, wz + CELL)
			var normal := Vector3(left - right, 2.0 * CELL, back - front).normalized()
			var biome := shape.biome_at(wx, wz, h)
			var layer := CampIsland.layer_for(biome, h, normal.y)
			var jitter := fposmod(sin(wx * 12.9898 + wz * 78.233) * 43758.5453, 1.0)
			var wanted := CampIsland.color_for(biome, h, normal.y).darkened(jitter * 0.07)
			var layer_uvs := TerrainLayers.uvs(layer)
			vertices.append(Vector3(ix * CELL, h, iz * CELL))
			normals.append(normal)
			colors.append(TerrainLayers.tint(wanted, CampIsland.LAYER_BASE[layer]))
			uv.append(layer_uvs[0])
			uv2.append(layer_uvs[1])
	var indices := PackedInt32Array()
	for iz in SAMPLES - 1:
		for ix in SAMPLES - 1:
			var a := iz * SAMPLES + ix
			var b := a + 1
			var c := a + SAMPLES
			var d := c + 1
			# Clockwise from above: Godot's front faces.
			indices.append_array([a, b, c, b, d, c])
	return {
		"origin": origin,
		"heights": heights,
		"max_height": max_height,
		"vertices": vertices,
		"normals": normals,
		"colors": colors,
		"uv": uv,
		"uv2": uv2,
		"indices": indices,
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
	arrays[Mesh.ARRAY_TEX_UV] = data.uv
	arrays[Mesh.ARRAY_TEX_UV2] = data.uv2
	arrays[Mesh.ARRAY_INDEX] = data.indices
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
