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
## outlines that stacked boxes can't make. Every edge gets a small chamfer so it
## catches the light, and the faces carry UVs in metres × UV_PER_METRE.
const UV_PER_METRE := 8.0


static func extrude(outline: PackedVector2Array, width: float, key: String = "", bevel: float = -1.0) -> ArrayMesh:
	if not key.is_empty() and _cache.has(key):
		return _cache[key]
	var shape := _counter_clockwise(outline)
	var half := width * 0.5
	if bevel < 0.0:
		bevel = minf(0.0015, width * 0.12)
	var inner := _inset(shape, bevel) if bevel > 0.0 else shape
	var core := half - bevel
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The two flat faces, drawn from the inset outline.
	var indices := Geometry2D.triangulate_polygon(inner)
	if indices.is_empty():
		indices = Geometry2D.triangulate_polygon(shape)
		inner = shape
	for side: float in [-1.0, 1.0]:
		for i in range(0, indices.size(), 3):
			var a := inner[indices[i]]
			var b := inner[indices[i + 1]]
			var c := inner[indices[i + 2]]
			_face(tool, [Vector3(side * half, a.x, a.y), Vector3(side * half, b.x, b.y), Vector3(side * half, c.x, c.y)],
				[a * UV_PER_METRE, b * UV_PER_METRE, c * UV_PER_METRE], Vector3(side, 0.0, 0.0))
	# The wall around the edge, and the chamfers from it to each face.
	var run := 0.0
	var count := shape.size()
	for i in count:
		var a := shape[i]
		var b := shape[(i + 1) % count]
		var ia := inner[i]
		var ib := inner[(i + 1) % count]
		var along := b - a
		var out2 := Vector2(along.y, -along.x).normalized()
		var out := Vector3(0.0, out2.x, out2.y)
		var u0 := run * UV_PER_METRE
		var u1 := (run + along.length()) * UV_PER_METRE
		run += along.length()
		var wa := Vector3(0.0, a.x, a.y)
		var wb := Vector3(0.0, b.x, b.y)
		var qa := [wa + Vector3(-core, 0, 0), wa + Vector3(core, 0, 0), wb + Vector3(core, 0, 0), wb + Vector3(-core, 0, 0)]
		var quv := [Vector2(u0, -core * UV_PER_METRE), Vector2(u0, core * UV_PER_METRE), Vector2(u1, core * UV_PER_METRE), Vector2(u1, -core * UV_PER_METRE)]
		_quad(tool, qa, quv, out)
		if bevel > 0.0:
			for side: float in [-1.0, 1.0]:
				var edge := [wa + Vector3(side * core, 0, 0), wb + Vector3(side * core, 0, 0),
					Vector3(side * half, ib.x, ib.y), Vector3(side * half, ia.x, ia.y)]
				var e := side * half * UV_PER_METRE
				_quad(tool, edge, [Vector2(u0, e), Vector2(u1, e), Vector2(u1, e + side * 0.01), Vector2(u0, e + side * 0.01)],
					(out + Vector3(side, 0.0, 0.0)).normalized())
	tool.generate_tangents()
	var mesh := tool.commit()
	if not key.is_empty():
		_cache[key] = mesh
	return mesh


## The outline wound counter-clockwise (y up), so "outward" is always to the right of each edge.
static func _counter_clockwise(outline: PackedVector2Array) -> PackedVector2Array:
	var area := 0.0
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		area += a.x * b.y - b.x * a.y
	if area >= 0.0:
		return outline
	var flipped := outline.duplicate()
	flipped.reverse()
	return flipped


## Each corner pulled `amount` inward along its mitre (capped on sharp corners).
static func _inset(shape: PackedVector2Array, amount: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var count := shape.size()
	for i in count:
		var prev := shape[(i - 1 + count) % count]
		var here := shape[i]
		var next := shape[(i + 1) % count]
		var d1 := (here - prev).normalized()
		var d2 := (next - here).normalized()
		var n1 := Vector2(d1.y, -d1.x)
		var n2 := Vector2(d2.y, -d2.x)
		var mitre := (n1 + n2)
		if mitre.length() < 0.001:
			mitre = n1
		mitre = mitre.normalized()
		var reach := amount / maxf(0.35, mitre.dot(n1))
		out.append(here - mitre * reach)
	return out


## One triangle, wound so its front faces `outward` (Godot's front faces are clockwise).
static func _face(tool: SurfaceTool, points: Array, uvs: Array, outward: Vector3) -> void:
	var order := [0, 1, 2]
	var normal: Vector3 = (points[2] - points[0]).cross(points[1] - points[0])
	if normal.dot(outward) < 0.0:
		order = [0, 2, 1]
	var flat: Vector3 = outward if normal.length() < 1e-9 else normal.normalized() * signf(normal.dot(outward))
	for k: int in order:
		tool.set_normal(flat)
		tool.set_uv(uvs[k])
		tool.add_vertex(points[k])


static func _quad(tool: SurfaceTool, points: Array, uvs: Array, outward: Vector3) -> void:
	_face(tool, [points[0], points[1], points[2]], [uvs[0], uvs[1], uvs[2]], outward)
	_face(tool, [points[0], points[2], points[3]], [uvs[0], uvs[2], uvs[3]], outward)


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


## A rope lashing across a row of logs, the way a raft is really bound: two tight
## turns round each log, and two binding turns round the whole bundle pulled snug
## (over a deck laid on the logs, if `top` is given). Logs lie along Z, their
## middles at `xs` (and `y`), all of radius `radius`; the lashing sits at `z`.
static func lash(xs: PackedFloat32Array, radius: float, y: float, z: float, material: Material, top: float = -INF) -> Node3D:
	var root := Node3D.new()
	const ROPE := 0.016
	# Clear of the bark even where a log bows out a little.
	var wrap := radius * 1.04 + 0.02
	var ring := TorusMesh.new()
	ring.inner_radius = wrap - ROPE
	ring.outer_radius = wrap + ROPE
	ring.rings = 18
	ring.ring_segments = 6
	for x in xs:
		for turn in 2:
			var loop := MeshInstance3D.new()
			loop.mesh = ring
			loop.material_override = material
			# The torus lies flat; stand it up round the log, each turn a little on.
			loop.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5).rotated(Vector3.UP, 0.04 * (turn - 0.5)), Vector3(x, y, z + (turn - 0.5) * 0.036))
			root.add_child(loop)
	# Binding turns round the whole bundle: over the top, down the ends, under.
	var left := xs[0] - wrap - 0.01
	var right := xs[xs.size() - 1] + wrap + 0.01
	var high := maxf(y + wrap + 0.02, top + 0.014)
	var low := y - wrap - 0.02
	for turn in 2:
		var dz := z + 0.075 + turn * 0.036
		var corners := [Vector3(right, high, dz), Vector3(left, high, dz), Vector3(left, low, dz), Vector3(right, low, dz), Vector3(right, high, dz)]
		for i in 4:
			var a: Vector3 = corners[i]
			var b: Vector3 = corners[i + 1]
			var seg := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = ROPE
			cylinder.bottom_radius = ROPE
			cylinder.height = a.distance_to(b) + ROPE * 2.0
			cylinder.radial_segments = 6
			cylinder.rings = 1
			seg.mesh = cylinder
			seg.material_override = material
			var up := (b - a).normalized()
			var side := up.cross(Vector3.FORWARD).normalized()
			seg.transform = Transform3D(Basis(side, up, side.cross(up)), (a + b) * 0.5)
			root.add_child(seg)
	return root
