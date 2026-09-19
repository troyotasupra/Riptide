class_name ModelLib
extends RefCounted
## Loads the CC0 model files under assets/models (see assets/CREDITS.md) and
## turns them into the shapes the game works in. Pack files often hold several
## models side by side, at 100x scale and lying on their backs; this splits them
## into parts, bakes each part's own transform into its mesh, and re-centres it.
##
##   part_count(path)            how many separate models a file holds
##   part(path, index)           one of them: base on the ground, centred, in metres,
##                               one MeshInstance3D per material, named after it
##                               ("wood", "leaves"...), so trunks and leaves can differ
##   surface_top / base_radius   where a trunk ends, and how thick it is at the ground
##   gun(path, length, muzzle)   a gun laid out the way ItemModels expects:
##                               barrel along +Y, sights up +Z, grip at the origin

const MODELS := "res://assets/models/"

## path -> Array of {"mesh": ArrayMesh, "aabb": AABB} (mesh already in file space)
static var _parts := {}
static var _guns := {}


static func exists(path: String) -> bool:
	return ResourceLoader.exists(MODELS + path)


static func part_count(path: String) -> int:
	return _load(path).size()


## One model from the file: its mesh in metres, resting on y = 0, centred on x/z.
## `height` rescales it to that many metres tall (0 keeps the file's size).
static func part(path: String, index: int, height: float = 0.0) -> Node3D:
	var parts := _load(path)
	var root := Node3D.new()
	if parts.is_empty():
		return root
	var entry: Dictionary = parts[posmod(index, parts.size())]
	var xf := _placement(entry, height)
	for surface: Dictionary in _split(entry):
		var instance := MeshInstance3D.new()
		instance.name = surface.name
		instance.mesh = surface.mesh
		instance.transform = xf
		root.add_child(instance)
	return root


## The MeshInstance3Ds of a part() whose material name contains any of `words`.
static func surfaces_named(model: Node3D, words: Array) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for child in model.find_children("*", "MeshInstance3D", true, false):
		for word: String in words:
			if String(child.name).contains(word):
				found.append(child)
				break
	return found


## The top of the surfaces named with `words` (say a palm's trunk), in part() space:
## the middle of the highest few vertices, where a crown or coconuts belong.
static func surface_top(path: String, index: int, height: float, words: Array) -> Vector3:
	var points := _surface_points(path, index, height, words)
	if points.is_empty():
		return Vector3(0.0, height, 0.0)
	var top := -INF
	for p in points:
		top = maxf(top, p.y)
	var sum := Vector3.ZERO
	var count := 0
	for p in points:
		if p.y > top - 0.25:
			sum += p
			count += 1
	return sum / count


## How far out from the middle the named surfaces reach between `low` and `up`
## metres above the ground (above the root flare, the trunk's own thickness).
static func base_radius(path: String, index: int, height: float, words: Array, up: float = 0.4, low: float = 0.0) -> float:
	var reach := 0.0
	for p in _surface_points(path, index, height, words):
		if p.y < up and p.y >= low:
			reach = maxf(reach, Vector2(p.x, p.z).length())
	return reach if reach > 0.0 else 0.25


static var _points := {}


static func _surface_points(path: String, index: int, height: float, words: Array) -> PackedVector3Array:
	var key := "%s_%d_%.2f_%s" % [path, index, height, ",".join(words)]
	if not _points.has(key):
		_points[key] = _gather_points(path, index, height, words)
	return _points[key]


static func _gather_points(path: String, index: int, height: float, words: Array) -> PackedVector3Array:
	var parts := _load(path)
	var out := PackedVector3Array()
	if parts.is_empty():
		return out
	var entry: Dictionary = parts[posmod(index, parts.size())]
	var xf := _placement(entry, height)
	for surface: Dictionary in _split(entry):
		var named := false
		for word: String in words:
			named = named or String(surface.name).contains(word)
		if named:
			for v: Vector3 in surface.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				out.append(xf * v)
	return out


## Puts a part's base on the ground, centred, `height` tall (0 keeps its size).
static func _placement(entry: Dictionary, height: float) -> Transform3D:
	var box: AABB = entry.aabb
	var scale := height / box.size.y if height > 0.0 else 1.0
	return Transform3D(Basis.from_scale(Vector3.ONE * scale), -Vector3(box.get_center().x, box.position.y, box.get_center().z) * scale)


## A part's mesh cut into one mesh per surface, named after its material, cached.
static func _split(entry: Dictionary) -> Array:
	if entry.has("split"):
		return entry.split
	var out: Array = []
	var mesh: ArrayMesh = entry.mesh
	for i in mesh.get_surface_count():
		var single := ArrayMesh.new()
		single.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(i))
		var material := mesh.surface_get_material(i)
		single.surface_set_material(0, material)
		var name := material.resource_name.to_lower() if material != null and not material.resource_name.is_empty() else "surface%d" % i
		out.append({"mesh": single, "name": name})
	entry["split"] = out
	return out


## The part's size in the file (before any `height` rescale).
static func part_size(path: String, index: int) -> Vector3:
	var parts := _load(path)
	return Vector3.ZERO if parts.is_empty() else (parts[posmod(index, parts.size())].aabb as AABB).size


## A gun, `length` metres long, laid out along +Y with its sights up +Z and the
## middle of its grip at the origin. The files lie along X; `muzzle` is +1 or -1
## for which way the barrel points in the file. `grip` is how far along the gun
## (0 = butt, 1 = muzzle) the hand holds it, and returns anchors in `anchors`:
## "muzzle", "rail" (top of the receiver), "grip", and "fore": the underside of the
## handguard, `fore` of the way from the grip to the muzzle, where a left hand holds it.
static func gun(path: String, length: float, muzzle: float, grip: float, anchors: Dictionary = {}, fore: float = 0.5) -> Node3D:
	var key := "%s_%.3f_%d_%.3f_%.3f" % [path, length, int(muzzle), grip, fore]
	var root := Node3D.new()
	var parts := _load(path)
	if parts.is_empty():
		return root
	if not _guns.has(key):
		_guns[key] = _layout_gun(parts[0], length, muzzle, grip, fore)
	var laid: Dictionary = _guns[key]
	var instance := MeshInstance3D.new()
	instance.mesh = parts[0].mesh
	instance.transform = laid.xf
	root.add_child(instance)
	# Real surfaces instead of flat paint: blued and parkerized steel with worn
	# edges, textured polymer, grained wood, a lens that reflects.
	var mesh: Mesh = parts[0].mesh
	for i in mesh.get_surface_count():
		var original := mesh.surface_get_material(i) as StandardMaterial3D
		if original != null:
			instance.set_surface_override_material(i, _gun_material(original.resource_name, original.albedo_color))
	for name: String in laid.anchors:
		anchors[name] = laid.anchors[name]
	return root


static var _gun_materials := {}


## The material for one part of a gun, from the pack's name for it.
static func _gun_material(name: String, color: Color) -> Material:
	var key := "%s_%s" % [name, color.to_html(false)]
	if _gun_materials.has(key):
		return _gun_materials[key]
	var lower := name.to_lower()
	var m: StandardMaterial3D
	if lower.contains("wood"):
		# Oiled walnut: warm brown grain, a soft sheen.
		m = Materials.wood(Color(0.38, 0.22, 0.12) if color.v < 0.3 else Color(0.46, 0.3, 0.17)).duplicate()
		m.roughness = 0.5
	elif lower.contains("glass"):
		m = StandardMaterial3D.new()
		m.albedo_color = Color(0.05, 0.1, 0.16)
		m.metallic = 0.9
		m.roughness = 0.05
		m.rim_enabled = true
		m.rim = 0.6
	elif lower.contains("metal") or lower == "grey":
		# Blued steel: a little brighter than the pack's flat grey, and it catches the light.
		m = Materials.gun_steel(color.lightened(0.06), 0.3).duplicate()
		m.rim_enabled = true
		m.rim = 0.35
		m.rim_tint = 0.6
	else:
		# The black parts: polymer furniture and anodised receivers, matte and grained.
		m = Materials.gun_polymer(color).duplicate()
		m.rim_enabled = true
		m.rim = 0.2
		m.rim_tint = 0.3
	_gun_materials[key] = m
	return m


static func _layout_gun(entry: Dictionary, length: float, muzzle: float, grip: float, fore: float) -> Dictionary:
	var mesh: ArrayMesh = entry.mesh
	var box: AABB = entry.aabb
	var s := length / box.size.x
	# File X (muzzle-ward) -> our +Y, file Y (up) -> our +Z, file Z -> our X.
	var basis := Basis(Vector3(0.0, muzzle, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(muzzle, 0.0, 0.0)).scaled(Vector3.ONE * s)
	var along_min := box.position.x if muzzle > 0.0 else box.end.x
	var butt := along_min
	var grip_x := lerpf(butt, butt + muzzle * box.size.x, grip)
	# The grip hangs below the receiver: find the lowest geometry near that point.
	var vertices := _vertices(mesh)
	var grip_low := INF
	var grip_high := -INF
	var top := -INF
	var muzzle_y := 0.0
	var muzzle_count := 0
	var front := box.end.x if muzzle > 0.0 else box.position.x
	for v in vertices:
		if absf(v.x - grip_x) < box.size.x * 0.04:
			grip_low = minf(grip_low, v.y)
			grip_high = maxf(grip_high, v.y)
		if absf(v.x - lerpf(butt, front, 0.45)) < box.size.x * 0.15:
			top = maxf(top, v.y)
		if absf(v.x - front) < box.size.x * 0.015:
			muzzle_y += v.y
			muzzle_count += 1
	if grip_low == INF:
		grip_low = box.position.y
		grip_high = box.end.y
	muzzle_y = muzzle_y / muzzle_count if muzzle_count > 0 else box.get_center().y
	# The handguard's underside: the lowest geometry there that is still close under
	# the barrel, so bipod legs and magazines hanging lower don't count.
	var fore_x := lerpf(grip_x, front, fore)
	var fore_low := INF
	var reach := 0.09 / s
	for v in vertices:
		if absf(v.x - fore_x) < box.size.x * 0.03 and v.y > muzzle_y - reach:
			fore_low = minf(fore_low, v.y)
	if fore_low == INF:
		fore_low = muzzle_y - 0.03 / s
	# Hold it a third of the way up the grip.
	var origin_file := Vector3(grip_x, lerpf(grip_low, grip_high, 0.3), box.get_center().z)
	var xf := Transform3D(basis, -(basis * origin_file))
	var to_ours := func(p: Vector3) -> Vector3: return xf * p
	return {
		"xf": xf,
		"anchors": {
			"muzzle": to_ours.call(Vector3(front, muzzle_y, box.get_center().z)),
			"rail": to_ours.call(Vector3(lerpf(butt, front, 0.45), top, box.get_center().z)),
			"grip": Vector3.ZERO,
			"fore": to_ours.call(Vector3(fore_x, fore_low, box.get_center().z)),
		},
	}


static func _vertices(mesh: ArrayMesh) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in mesh.get_surface_count():
		out.append_array(mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX])
	return out


## Every MeshInstance3D in the file, with its node transform baked into a copy
## of the mesh, so each part stands alone in metres with y up.
static func _load(path: String) -> Array:
	if _parts.has(path):
		return _parts[path]
	var out: Array = []
	var full := MODELS + path
	if ResourceLoader.exists(full):
		var scene: PackedScene = load(full)
		var root := scene.instantiate()
		_collect(root, Transform3D.IDENTITY, out)
		root.free()
	_parts[path] = out
	return out


static func _collect(node: Node, parent_xf: Transform3D, out: Array) -> void:
	var xf := parent_xf
	if node is Node3D:
		xf = parent_xf * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var baked := _bake((node as MeshInstance3D).mesh, xf)
		# Sets are laid out side by side far from the origin: keep only rotation and scale.
		out.append({"mesh": baked, "aabb": baked.get_aabb()})
	for child in node.get_children():
		_collect(child, xf, out)


static func _bake(mesh: Mesh, xf: Transform3D) -> ArrayMesh:
	var keep := Transform3D(xf.basis, Vector3.ZERO)
	var baked := ArrayMesh.new()
	for i in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(i)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for v in vertices.size():
			vertices[v] = keep * vertices[v]
		arrays[Mesh.ARRAY_VERTEX] = vertices
		if arrays[Mesh.ARRAY_NORMAL] != null:
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var nb := keep.basis.inverse().transposed()
			for n in normals.size():
				normals[n] = (nb * normals[n]).normalized()
			arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TANGENT] = null
		baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var material := mesh.surface_get_material(i)
		if material != null:
			baked.surface_set_material(i, _tuned(material))
	return baked


## Pack materials pulled toward the island's palette (multiplied into albedo).
const TINTS := {"bush_leaves": Color(0.62, 0.74, 0.5)}


## The packs' flat colours are plastic-shiny; give them a matte, painted look.
static func _tuned(material: Material) -> Material:
	var standard := material as StandardMaterial3D
	if standard == null:
		return material
	var copy: StandardMaterial3D = standard.duplicate()
	var name := standard.resource_name.to_lower()
	if name.contains("metal") or name == "black" or name.contains("glass"):
		copy.metallic = 0.35
		copy.roughness = 0.45 if not name.contains("glass") else 0.1
		copy.metallic_specular = 0.6
	else:
		copy.roughness = maxf(copy.roughness, 0.75)
		copy.metallic_specular = 0.35
	if copy.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or copy.albedo_texture != null:
		copy.cull_mode = BaseMaterial3D.CULL_DISABLED
	if TINTS.has(name):
		copy.albedo_color *= TINTS[name]
	# Leaf and flower cards: cut out cleanly, no sorting, lit from both sides.
	for word: String in ["leaves", "leaf", "flower", "petal"]:
		if name.contains(word) and copy.albedo_texture != null:
			copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			copy.alpha_scissor_threshold = 0.45
			copy.cull_mode = BaseMaterial3D.CULL_DISABLED
			break
	return copy
