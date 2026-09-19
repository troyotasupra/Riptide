class_name FlameSheets
extends MultiMeshInstance3D
## Sheets of fire drawn in one go (flame_sheet.gdshader makes the tongues flow).
## Laid in crossed pairs and overlapping their neighbours, they make one solid,
## connected fire with no gaps, from any side.
##
## set_sheets(list): each entry {"pos": Vector3 (middle of the base), "yaw": radians,
## "width": m across, "height": m, "seed": int, "heat": 0..1}.

const COLUMNS := 24
const ROWS := 9
## Below the base, so a sheet on uneven ground never shows a floating bottom edge.
const SKIRT := 0.25

static var _mesh: ArrayMesh
static var _material: ShaderMaterial


func _init() -> void:
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = sheet_mesh()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Recolours these sheets (root, low, mid, tip), e.g. white water for a splash.
func set_palette(colors: Array, boost: float = 1.0) -> void:
	var m: ShaderMaterial = sheet_mesh().surface_get_material(0).duplicate()
	for i in 4:
		var c: Color = colors[i]
		m.set_shader_parameter(["c_root", "c_low", "c_mid", "c_tip"][i], Vector3(c.r, c.g, c.b))
	m.set_shader_parameter("boost", boost)
	material_override = m


func set_sheets(list: Array) -> void:
	multimesh.instance_count = list.size()
	var box := AABB()
	for i in list.size():
		var entry: Dictionary = list[i]
		var pos: Vector3 = entry.pos
		var width: float = entry.width
		var height: float = entry.height
		var rng := RandomNumberGenerator.new()
		rng.seed = int(entry.get("seed", i))
		var basis := Basis(Vector3.UP, float(entry.get("yaw", 0.0))) * Basis.from_scale(Vector3(width * 0.5, height + SKIRT, 1.0))
		multimesh.set_instance_transform(i, Transform3D(basis, pos - Vector3.UP * SKIRT))
		# About one tongue for every 90 cm across: broad flames with body, not spikes.
		var tongues := maxf(1.2, width / 0.9)
		multimesh.set_instance_custom_data(i, Color(rng.randf(), rng.randf_range(0.85, 1.2), tongues, float(entry.get("heat", 0.5))))
		var reach := AABB(pos - Vector3(width, SKIRT + 0.5, width) * 0.6, Vector3(width * 1.2, height + SKIRT + 1.0, width * 1.2))
		box = reach if i == 0 else box.merge(reach)
	custom_aabb = box if not list.is_empty() else AABB()


## A strip COLUMNS wide and ROWS tall; UV.x runs -1..1 across, UV.y 0..1 up.
static func sheet_mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	for row in ROWS:
		for col in COLUMNS:
			var x0 := -1.0 + 2.0 * col / COLUMNS
			var x1 := -1.0 + 2.0 * (col + 1) / COLUMNS
			var y0 := float(row) / ROWS
			var y1 := float(row + 1) / ROWS
			var quad := [Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]
			# Alternate the diagonal, so the facets zigzag rather than stripe.
			var order := [0, 1, 2, 0, 2, 3] if (row + col) % 2 == 0 else [0, 1, 3, 1, 2, 3]
			for k: int in order:
				var p: Vector2 = quad[k]
				vertices.append(Vector3(p.x, p.y, 0.0))
				uvs.append(p)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_material = ShaderMaterial.new()
	_material.shader = load("res://world/fire/flame_sheet.gdshader")
	_mesh.surface_set_material(0, _material)
	return _mesh
