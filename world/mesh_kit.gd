class_name MeshKit
extends RefCounted
## Procedural organic meshes: lumpy rocks, curved tapering tubes (branches,
## palm trunks, driftwood, rope), and drooping leaf blades. Cached by their
## parameters so a whole island of props shares a handful of meshes.

static var _cache := {}


## A lumpy rock: a sphere pushed in and out by noise, flattened a little.
static func rock(variant: int, roughness: float = 0.35, squash: float = 0.7) -> ArrayMesh:
	var key := "rock_%d_%.2f_%.2f" % [variant, roughness, squash]
	if _cache.has(key):
		return _cache[key]
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 20
	sphere.rings = 12
	var arrays := sphere.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var noise := FastNoiseLite.new()
	noise.seed = 1000 + variant * 37
	noise.frequency = 1.6
	noise.fractal_octaves = 3
	for i in vertices.size():
		var v := vertices[i]
		var dir := v.normalized() if v.length() > 0.0001 else Vector3.UP
		var bump := 1.0 + noise.get_noise_3dv(dir * 1.5) * roughness
		vertices[i] = Vector3(dir.x, dir.y * squash, dir.z) * 0.5 * bump
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := _with_normals(arrays)
	_cache[key] = mesh
	return mesh


## A tube following `points`, with a radius per point, closed at both ends.
static func tube(points: PackedVector3Array, radii: PackedFloat32Array, sides: int = 10, key: String = "") -> ArrayMesh:
	if not key.is_empty() and _cache.has(key):
		return _cache[key]
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var count := points.size()
	var up_hint := Vector3.RIGHT
	for i in count:
		var forward := (points[mini(i + 1, count - 1)] - points[maxi(i - 1, 0)]).normalized()
		if absf(forward.dot(up_hint)) > 0.95:
			up_hint = Vector3.FORWARD
		var side := forward.cross(up_hint).normalized()
		var up := side.cross(forward).normalized()
		for j in sides + 1:
			var a := TAU * j / sides
			vertices.append(points[i] + (side * cos(a) + up * sin(a)) * radii[i])
	var row := sides + 1
	for i in count - 1:
		for j in sides:
			var a := i * row + j
			var b := a + row
			# Wound so the faces point outward (Godot's front faces are clockwise).
			indices.append_array([a, a + 1, b, a + 1, b + 1, b])
	# End caps.
	for end: int in [0, count - 1]:
		var center := vertices.size()
		vertices.append(points[end])
		for j in sides:
			var a := end * row + j
			# Clockwise seen from outside the cap, like the sides.
			if end == 0:
				indices.append_array([center, a + 1, a])
			else:
				indices.append_array([center, a, a + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := _with_normals(arrays)
	if not key.is_empty():
		_cache[key] = mesh
	return mesh


## A flat outline pushed out sideways: give the shape you'd draw from the side
## (x along the object, y up) and it comes back as a solid `width` thick. Shapes
## like a magwell, a pistol grip or a rifle stock have sloped and stepped
## outlines that stacked boxes can't make.
static func extrude(outline: PackedVector2Array, width: float, key: String = "") -> ArrayMesh:
	if not key.is_empty() and _cache.has(key):
		return _cache[key]
	var vertices := PackedVector3Array()
	var half := width * 0.5
	var indices := Geometry2D.triangulate_polygon(outline)
	# The two flat faces.
	for side: float in [-1.0, 1.0]:
		var count := indices.size()
		for i in range(0, count, 3):
			var order := [0, 1, 2] if side > 0.0 else [2, 1, 0]
			for step: int in order:
				var point := outline[indices[i + step]]
				vertices.append(Vector3(side * half, point.x, point.y))
	# The wall around the edge.
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var quad := [Vector3(-half, a.x, a.y), Vector3(half, a.x, a.y), Vector3(half, b.x, b.y), Vector3(-half, b.x, b.y)]
		for step: int in [0, 2, 1, 0, 3, 2]:
			vertices.append(quad[step])
	# Flat normals, worked out per triangle: hard edges, not a smoothed blob.
	var normals := PackedVector3Array()
	for i in range(0, vertices.size(), 3):
		var face := (vertices[i + 1] - vertices[i]).cross(vertices[i + 2] - vertices[i]).normalized()
		for j in 3:
			normals.append(face)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if not key.is_empty():
		_cache[key] = mesh
	return mesh


## A gently curving, tapering branch from the origin, `length` long.
static func branch(variant: int, length: float, base_radius: float, tip_radius: float, bend: float, segments: int = 8) -> ArrayMesh:
	var key := "branch_%d_%.2f_%.3f_%.3f_%.2f" % [variant, length, base_radius, tip_radius, bend]
	if _cache.has(key):
		return _cache[key]
	var noise := _branch_noise(variant)
	var points := PackedVector3Array()
	var radii := PackedFloat32Array()
	for i in segments + 1:
		var t := float(i) / segments
		points.append(_branch_point(noise, length, bend, t))
		radii.append(lerpf(base_radius, tip_radius, t) * (1.0 + noise.get_noise_1d(t * 9.0 + 7.0) * 0.12))
	return tube(points, radii, 9, key)


## Where a branch built with the same variant, length and bend runs, `t` (0..1) of
## the way along it — for hanging leaves on its tip.
static func branch_point(variant: int, length: float, bend: float, t: float) -> Vector3:
	return _branch_point(_branch_noise(variant), length, bend, t)


static func _branch_noise(variant: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = 2000 + variant * 13
	noise.frequency = 0.8
	return noise


static func _branch_point(noise: FastNoiseLite, length: float, bend: float, t: float) -> Vector3:
	var sway := Vector3(noise.get_noise_1d(t * 3.0) * 0.12, 0.0, noise.get_noise_1d(t * 3.0 + 50.0) * 0.12) * length
	return Vector3(0.0, t * length, 0.0) + Vector3(bend * t * t * length, 0.0, 0.0) + sway * t


## A palm frond along +Z: a drooping blade whose edges are cut into leaflets that
## sweep toward the tip (a sawtooth outline), folded by `fold` (negative hangs the
## leaflets down). Double-sided material recommended.
static func frond(length: float, width: float, droop: float, segments: int = 20, fold: float = -0.35) -> ArrayMesh:
	var key := "frond_%.2f_%.2f_%.2f_%d_%.2f" % [length, width, droop, segments, fold]
	if _cache.has(key):
		return _cache[key]
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var step := length / segments
	for i in segments + 1:
		var t := float(i) / segments
		var z := t * length
		var y := -droop * t * t * length
		var leaflet := i % 2 == 1 and i < segments
		var half := width * 0.5 * sin(PI * minf(t * 1.05 + 0.04, 1.0)) * (1.0 if leaflet else 0.12)
		var edge_z := z + (step * 0.9 if leaflet else 0.0)
		var edge_y := -droop * pow(edge_z / length, 2.0) * length + half * fold
		vertices.append(Vector3(-half, edge_y, edge_z))
		vertices.append(Vector3(0.0, y, z))
		vertices.append(Vector3(half, edge_y, edge_z))
	for i in segments:
		var a := i * 3
		var b := a + 3
		indices.append_array([a, b, a + 1, a + 1, b, b + 1, a + 1, b + 1, a + 2, a + 2, b + 1, b + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := _with_normals(arrays)
	_cache[key] = mesh
	return mesh


## A leaf or frond blade from the origin along +Z, drooping by `droop`,
## `segments` long, widest in the middle. Double-sided material recommended.
static func leaf(length: float, width: float, droop: float, segments: int = 8, fold: float = 0.15) -> ArrayMesh:
	var key := "leaf_%.2f_%.2f_%.2f_%.2f" % [length, width, droop, fold]
	if _cache.has(key):
		return _cache[key]
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in segments + 1:
		var t := float(i) / segments
		var half := width * 0.5 * sin(PI * minf(t * 1.1, 1.0))
		var z := t * length
		var y := -droop * t * t * length
		vertices.append(Vector3(-half, y + half * fold, z))
		vertices.append(Vector3(0.0, y, z))
		vertices.append(Vector3(half, y + half * fold, z))
	for i in segments:
		var a := i * 3
		var b := a + 3
		indices.append_array([a, b, a + 1, a + 1, b, b + 1, a + 1, b + 1, a + 2, a + 2, b + 1, b + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := _with_normals(arrays)
	_cache[key] = mesh
	return mesh


static func _with_normals(arrays: Array) -> ArrayMesh:
	var raw := ArrayMesh.new()
	raw.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var tool := SurfaceTool.new()
	tool.create_from(raw, 0)
	tool.generate_normals()
	return tool.commit()
