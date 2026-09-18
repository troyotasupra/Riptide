extends "res://tests/test_case.gd"

const Kit = preload("res://world/mesh_kit.gd")

const SHAPES := [
	# A convex slab, drawn clockwise.
	[Vector2(0.0, 0.0), Vector2(0.0, 0.1), Vector2(0.2, 0.12), Vector2(0.22, 0.0)],
	# A pistol-grip L, drawn counter-clockwise.
	[Vector2(-0.01, -0.1), Vector2(0.04, -0.1), Vector2(0.06, 0.0), Vector2(0.2, 0.0), Vector2(0.2, 0.04), Vector2(0.0, 0.04)],
]


## Every triangle's front face (Godot: clockwise) must look out of the solid, so
## you never see into a part from outside.
func test_extruded_faces_point_out() -> void:
	for n in SHAPES.size():
		var outline := PackedVector2Array(SHAPES[n])
		for flip: bool in [false, true]:
			var drawn := outline.duplicate()
			if flip:
				drawn.reverse()
			var mesh := Kit.extrude(drawn, 0.03)
			var arrays := mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var inward := 0
			var mismatched := 0
			for i in range(0, vertices.size(), 3):
				var a := vertices[i]
				var b := vertices[i + 1]
				var c := vertices[i + 2]
				var front := (c - a).cross(b - a)
				if front.length() < 1e-10:
					continue
				front = front.normalized()
				if front.dot(normals[i]) < 0.5:
					mismatched += 1
				var middle := (a + b + c) / 3.0
				var probe := middle + front * 0.004
				var inside_width := absf(probe.x) < 0.015
				var inside_shape := Geometry2D.is_point_in_polygon(Vector2(probe.y, probe.z), outline)
				if inside_width and inside_shape:
					inward += 1
			check(inward == 0, "shape %d (%s) has %d inward faces" % [n, "flipped" if flip else "as drawn", inward])
			check(mismatched == 0, "shape %d normals agree with the faces" % n)
			check(arrays[Mesh.ARRAY_TEX_UV] != null and (arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size() == vertices.size(), "shape %d has UVs" % n)
