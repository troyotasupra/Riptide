class_name ModelLib
extends RefCounted
## Loads the CC0 model files under assets/models (see assets/CREDITS.md) and
## turns them into the shapes the game works in. Pack files often hold several
## models side by side, at 100x scale and lying on their backs; this splits them
## into parts, bakes each part's own transform into its mesh, and re-centres it.
##
##   part_count(path)            how many separate models a file holds
##   part(path, index)           one of them: base on the ground, centred, in metres
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
	var box: AABB = entry.aabb
	var scale := height / box.size.y if height > 0.0 else 1.0
	var instance := MeshInstance3D.new()
	instance.mesh = entry.mesh
	instance.scale = Vector3.ONE * scale
	instance.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * scale
	root.add_child(instance)
	return root


## The part's size in the file (before any `height` rescale).
static func part_size(path: String, index: int) -> Vector3:
	var parts := _load(path)
	return Vector3.ZERO if parts.is_empty() else (parts[posmod(index, parts.size())].aabb as AABB).size


## A gun, `length` metres long, laid out along +Y with its sights up +Z and the
## middle of its grip at the origin. The files lie along X; `muzzle` is +1 or -1
## for which way the barrel points in the file. `grip` is how far along the gun
## (0 = butt, 1 = muzzle) the hand holds it, and returns anchors in `anchors`:
## "muzzle", "rail" (top of the receiver), "grip".
static func gun(path: String, length: float, muzzle: float, grip: float, anchors: Dictionary = {}) -> Node3D:
	var key := "%s_%.3f_%d_%.3f" % [path, length, int(muzzle), grip]
	var root := Node3D.new()
	var parts := _load(path)
	if parts.is_empty():
		return root
	if not _guns.has(key):
		_guns[key] = _layout_gun(parts[0], length, muzzle, grip)
	var laid: Dictionary = _guns[key]
	var instance := MeshInstance3D.new()
	instance.mesh = parts[0].mesh
	instance.transform = laid.xf
	root.add_child(instance)
	for name: String in laid.anchors:
		anchors[name] = laid.anchors[name]
	return root


static func _layout_gun(entry: Dictionary, length: float, muzzle: float, grip: float) -> Dictionary:
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
	return copy
