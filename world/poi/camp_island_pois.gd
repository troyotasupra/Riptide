class_name CampIslandPois
extends RefCounted
## Landmarks on the camp island: the spring and its stream, the castaway camp
## (its fire pit still smouldering), the cave mouth, the
## fishing shack and its dock, and the freighter aground on the reef.

static func build(shape: CampIsland) -> Node3D:
	var root := Node3D.new()
	root.name = "Landmarks"
	root.add_child(_spring(shape))
	root.add_child(_stream(shape))
	root.add_child(_waterfall(shape))
	root.add_child(_castaway_camp(shape))
	root.add_child(CaveBuild.build(shape))
	root.add_child(FishingShack.build(shape))
	root.add_child(FreighterWreck.build(shape))
	return root


static func yaw_toward(from: Vector2, to: Vector2) -> float:
	var d := to - from
	return atan2(-d.x, -d.y)


static func _ground(shape: CampIsland, p: Vector2) -> Vector3:
	return Vector3(p.x, shape.height_at(p.x, p.y), p.y)


static func _mesh(parent: Node3D, mesh: Mesh, color_key: String, color: Color, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = Props.material(color_key, color)
	instance.position = pos
	instance.rotation = rot
	parent.add_child(instance)
	return instance


static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func _cylinder(top: float, bottom: float, height: float, segments: int = 6) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	return m


static func _solid(parent: Node3D, shape: Shape3D, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	body.position = pos
	body.rotation = rot
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	parent.add_child(body)


static func _spring(shape: CampIsland) -> Node3D:
	var spring := Interactable.new()
	spring.name = "Spring"
	spring.interact_id = "spring"
	spring.text_provider = func(player: Node) -> String: return GameState.world.spring_prompt(player)
	spring.collision_layer = Layers.INTERACT
	spring.collision_mask = 0
	var area := CylinderShape3D.new()
	area.radius = CampIsland.POND_RADIUS
	area.height = 2.4
	var collider := CollisionShape3D.new()
	collider.shape = area
	collider.position = Vector3(shape.spring.x, shape.spring_height, shape.spring.y)
	spring.add_child(collider)
	var water := MeshInstance3D.new()
	water.mesh = _pool_mesh(shape, shape.spring, CampIsland.POND_RADIUS * 2.4, shape.spring_height)
	water.material_override = _flow_material("pool", 0.0, 0.0, 0.035, 1.0, true)
	spring.add_child(water)
	return spring


## A water surface that fills a basin. The water spreads out from the middle
## only as far as ground actually holds it, so a pool gets a real shoreline; if
## it would spill past its banks the level is dropped until it sits still.
static func _pool_mesh(shape: CampIsland, center: Vector2, extent: float, level: float) -> ArrayMesh:
	const STEP := 0.4
	var cells := int(ceil(extent * 2.0 / STEP))
	var origin := center - Vector2(extent, extent)
	var filled: Dictionary = {}
	for attempt in 5:
		filled = _flood(shape, origin, cells, STEP, level)
		if not filled.get("spilled", false):
			break
		level -= 0.35
	# Two more rings of cells past the last fully-wet one: the bank rises through
	# them, so the ground hides the square edge and the shoreline follows the terrain.
	var wet: Dictionary = filled.wet.duplicate()
	for ring in 2:
		var grown := wet.duplicate()
		for key: Vector2i in wet:
			for step_to: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
				grown[key + step_to] = true
		wet = grown
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for key: Vector2i in wet:
		var x := origin.x + key.x * STEP
		var z := origin.y + key.y * STEP
		var a := Vector3(x, level, z)
		var b := Vector3(x + STEP, level, z)
		var c := Vector3(x + STEP, level, z + STEP)
		var d := Vector3(x, level, z + STEP)
		for v: Vector3 in [a, b, c, a, c, d]:
			vertices.append(v)
			normals.append(Vector3.UP)
	return _surface(vertices, normals)


## Spreads water out from the middle of the grid, cell by cell, into anywhere the
## ground lies below `level`. "spilled" means it reached the edge of the grid —
## the banks don't hold at that level.
static func _flood(shape: CampIsland, origin: Vector2, cells: int, step: float, level: float) -> Dictionary:
	var wet: Dictionary = {}
	var spilled := false
	var middle := Vector2i(cells / 2, cells / 2)
	var queue: Array[Vector2i] = [middle]
	var seen: Dictionary = {middle: true}
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		var x := origin.x + cell.x * step
		var z := origin.y + cell.y * step
		var dry := false
		for corner: Vector2 in [Vector2(x, z), Vector2(x + step, z), Vector2(x + step, z + step), Vector2(x, z + step)]:
			if shape.height_at(corner.x, corner.y) > level - 0.08:
				dry = true
				break
		if dry:
			continue
		wet[cell] = true
		if cell.x <= 0 or cell.y <= 0 or cell.x >= cells - 1 or cell.y >= cells - 1:
			spilled = true
			continue
		for step_to: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next := cell + step_to
			if not seen.has(next):
				seen[next] = true
				queue.append(next)
	return {"wet": wet, "spilled": spilled}


static func _surface(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array = PackedVector2Array()) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if vertices.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	if uvs.size() == vertices.size():
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## The stream from the pool down to the sea, lying in its carved bed. The stretch
## going over the waterfall is left out, because that water is drawn falling.
static func _stream(shape: CampIsland) -> Node3D:
	const SEGMENTS := 220
	const HALF_WIDTH := 1.1
	var plunge_at := shape.stream_point(CampIsland.FALL_T + CampIsland.FALL_SPAN)
	var stream := Interactable.new()
	stream.name = "Stream"
	stream.interact_id = "stream"
	stream.text_provider = func(player: Node) -> String: return GameState.world.stream_prompt(player)
	stream.collision_layer = Layers.INTERACT
	stream.collision_mask = 0

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var previous_left := Vector3.ZERO
	var previous_right := Vector3.ZERO
	var previous_center := Vector3.ZERO
	var had_previous := false
	var travelled := 0.0
	var previous_travelled := 0.0
	for i in SEGMENTS + 1:
		var t := float(i) / SEGMENTS
		if t > CampIsland.FALL_T and t < CampIsland.FALL_T + CampIsland.FALL_SPAN:
			had_previous = false  # the falling stretch
			continue
		var p := shape.stream_point(t)
		if p.distance_to(plunge_at) < CampIsland.PLUNGE_RADIUS * 0.8:
			had_previous = false  # the plunge pool has its own water
			continue
		var ahead := shape.stream_point(minf(t + 0.01, 1.0)) - shape.stream_point(maxf(t - 0.01, 0.0))
		var side := ahead.normalized().orthogonal() * HALF_WIDTH
		var y: float = shape.stream_bed(t) + 0.3
		var center := Vector3(p.x, y, p.y)
		var left := Vector3(p.x + side.x, y, p.y + side.y)
		var right := Vector3(p.x - side.x, y, p.y - side.y)
		if had_previous:
			travelled += center.distance_to(previous_center)
			# Four quads across with alternating diagonals, so the water rolls in facets.
			const ACROSS := 4
			for c in ACROSS:
				var x0 := -1.0 + 2.0 * c / ACROSS
				var x1 := -1.0 + 2.0 * (c + 1) / ACROSS
				var a0 := previous_left.lerp(previous_right, (x0 + 1.0) * 0.5)
				var a1 := previous_left.lerp(previous_right, (x1 + 1.0) * 0.5)
				var b0 := left.lerp(right, (x0 + 1.0) * 0.5)
				var b1 := left.lerp(right, (x1 + 1.0) * 0.5)
				var quad := [[a0, x0, previous_travelled], [a1, x1, previous_travelled], [b1, x1, travelled], [b0, x0, travelled]]
				var order := [0, 2, 1, 0, 3, 2] if (i + c) % 2 == 0 else [0, 3, 1, 1, 3, 2]
				for k: int in order:
					vertices.append(quad[k][0])
					normals.append(Vector3.UP)
					uvs.append(Vector2(quad[k][1], quad[k][2]))
			# A thin interaction box along each segment so you can drink or fill a canteen.
			var along := center - previous_center
			if along.length() > 0.1:
				var box := BoxShape3D.new()
				box.size = Vector3(HALF_WIDTH * 2.0, 0.8, along.length())
				var collider := CollisionShape3D.new()
				collider.shape = box
				collider.transform = Transform3D(Basis.looking_at(along.normalized(), Vector3.UP), (center + previous_center) * 0.5)
				stream.add_child(collider)
		previous_left = left
		previous_right = right
		previous_center = center
		previous_travelled = travelled
		had_previous = true
	var water := MeshInstance3D.new()
	water.mesh = _surface(vertices, normals, uvs)
	water.material_override = _flow_material("stream", 1.4, 0.07, 0.035, 1.0)
	stream.add_child(water)
	return stream


## The big fall: the stream shoots off the lip and pours down the rock face in
## rolling, faceted water (water_flow.gdshader), a thinner fast strand over the
## top of it; a splash of white water at the foot where it lands (the fire's
## flowing sheets in white and blue), mist, wet boulders either side, and a pool.
static func _waterfall(shape: CampIsland) -> Node3D:
	var node := Node3D.new()
	node.name = "Waterfall"
	var fall: Dictionary = shape.waterfall()
	var top: Vector3 = fall.top
	var foot: Vector3 = fall.foot
	var direction: Vector2 = fall.direction
	var forward := Vector3(direction.x, 0.0, direction.y)
	var across := forward.cross(Vector3.UP).normalized() * CampIsland.STREAM_WIDTH * 0.9

	var path := _fall_path(shape, top, foot, forward)
	# Three curtains one behind another: the body of the fall, a torn veil of
	# strands hanging in front of it, and a wider, slower wash against the rock.
	# Together they have depth instead of reading as one painted ribbon.
	for layer: Array in [
			[1.0, 0.0, _fall_material("fall_body", 7.0, 1.0, 0.55, 20.0)],
			[0.74, 0.18, _fall_material("fall_veil", 9.5, 0.6, 0.3, 34.0)],
			[1.18, -0.12, _fall_material("fall_wash", 5.0, 0.8, 0.45, 13.0)]]:
		var sheet := MeshInstance3D.new()
		sheet.mesh = _fall_sheet(path, across, layer[0], layer[1])
		sheet.material_override = layer[2]
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(sheet)
	# The lip: boulders the stream pours between and over, either side of the fall
	# and a couple breaking the flow right at the edge.
	var lip_rng := RandomNumberGenerator.new()
	lip_rng.seed = hash("lip:%d" % shape.island_seed)
	var side_dir := across.normalized()
	for spot: Array in [[-1.25, 0.1, 1.5], [1.3, -0.1, 1.6], [-2.3, -0.6, 2.0], [2.4, -0.5, 1.9], [-0.45, 0.35, 0.55], [0.55, 0.25, 0.5]]:
		var at := top + side_dir * float(spot[0]) * CampIsland.STREAM_WIDTH + forward * float(spot[1])
		# Sat on the ground where they are, not hung in the air at lip height.
		var size: float = spot[2] * lip_rng.randf_range(0.85, 1.15)
		at.y = shape.height_at(at.x, at.z) - size * 0.3
		_mesh(node, MeshKit.rock(160 + lip_rng.randi() % 8, 0.2, 0.75), "fall_rock", Color(0.36, 0.35, 0.34), at,
			Vector3(lip_rng.randf() * 0.4, lip_rng.randf() * TAU, lip_rng.randf() * 0.4)).scale = Vector3(size * 1.2, size * 0.8, size)
		var stone := SphereShape3D.new()
		stone.radius = size * 0.45
		_solid(node, stone, at)
	# White water boiling up where it lands.
	var splash := FlameSheets.new()
	splash.set_palette([Color(1.0, 1.0, 1.0), Color(0.88, 0.95, 1.0), Color(0.7, 0.86, 0.94), Color(0.55, 0.76, 0.86)], 1.0)
	var landing: Vector3 = path[path.size() - 1]
	var sheets: Array = []
	var width := across.length() * 2.6
	for i in 4:
		sheets.append({"pos": landing, "yaw": atan2(forward.x, forward.z) + i * PI / 4.0, "width": width, "height": 1.1 - i * 0.12, "seed": 900 + i, "heat": 1.0})
	for i in 6:
		var a := i * TAU / 6.0
		sheets.append({"pos": landing + Vector3(cos(a), 0.0, sin(a)) * width * 0.35, "yaw": -a + PI / 2.0, "width": width * 0.5, "height": 0.55, "seed": 910 + i, "heat": 0.5})
	splash.set_sheets(sheets)
	node.add_child(splash)

	var plunge := MeshInstance3D.new()
	plunge.mesh = _pool_mesh(shape, Vector2(foot.x, foot.z), CampIsland.PLUNGE_RADIUS * 2.0, foot.y + 0.3)
	plunge.material_override = _flow_material("pool", 0.0, 0.0, 0.035, 1.0, true)
	node.add_child(plunge)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("waterfall:%d" % shape.island_seed)
	for i in 22:
		var at := top.lerp(foot, rng.randf()) + forward * rng.randf_range(-1.0, 2.5)
		var sideways := across.normalized() * (CampIsland.STREAM_WIDTH * rng.randf_range(1.0, 2.4) * (1.0 if i % 2 == 0 else -1.0))
		var spot := at + sideways
		var size := rng.randf_range(0.9, 2.4)
		# Bedded into the face, not perched on it.
		spot.y = shape.height_at(spot.x, spot.z) - size * 0.55
		_mesh(node, MeshKit.rock(70 + i, 0.4, 0.8), "fall_rock", Color(0.38, 0.37, 0.36), spot,
			Vector3(rng.randf() * 0.4, rng.randf() * TAU, rng.randf() * 0.4)).scale = Vector3(size * 1.3, size, size * 1.1)

	var spray := GPUParticles3D.new()
	spray.name = "Spray"
	spray.amount = 220
	spray.lifetime = 1.4
	spray.position = foot + Vector3.UP * 0.4 + forward * 0.6
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 0.9)
	spray.draw_pass_1 = quad
	spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = CampIsland.STREAM_WIDTH
	process.direction = Vector3.UP
	process.spread = 55.0
	process.initial_velocity_min = 1.0
	process.initial_velocity_max = 3.0
	process.gravity = Vector3(0.0, -3.0, 0.0)
	process.scale_min = 0.5
	process.scale_max = 1.6
	spray.process_material = process
	var mist := StandardMaterial3D.new()
	mist.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist.albedo_color = Color(0.92, 0.96, 1.0, 0.22)
	# A soft round puff, not a square.
	mist.albedo_texture = FireFx._puff()
	mist.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	spray.material_override = mist
	node.add_child(spray)
	return node




## Where the falling water runs: it shoots off the lip on a falling arc, then
## runs down the face a hand's width off the rock, into the pool.
static func _fall_path(shape: CampIsland, top: Vector3, foot: Vector3, forward: Vector3) -> Array[Vector3]:
	const FINE := 600
	const SPACING := 0.3
	var run := Vector2(foot.x - top.x, foot.z - top.z).length() + 1.2
	var start := top + Vector3.UP * 0.25
	var dense: Array[Vector3] = []
	for i in FINE + 1:
		var d := run * float(i) / FINE
		var xz := Vector2(top.x, top.z) + Vector2(forward.x, forward.z) * d
		# Off the lip at about 2.5 m/s, falling under gravity.
		var fall_t := d / 2.5
		var free := start.y - 0.5 * 9.8 * fall_t * fall_t
		var rock := shape.height_at(xz.x, xz.y) + 0.12
		var y := maxf(maxf(free, rock), foot.y + 0.2)
		dense.append(Vector3(xz.x, y, xz.y))
	# Even steps along the water itself, so the drop gets as many facets as the run.
	var path: Array[Vector3] = [dense[0]]
	var since := 0.0
	for i in range(1, dense.size()):
		since += dense[i].distance_to(dense[i - 1])
		if since >= SPACING:
			path.append(dense[i])
			since = 0.0
	if path[path.size() - 1] != dense[dense.size() - 1]:
		path.append(dense[dense.size() - 1])
	return path


## A ribbon down `path`, `width_scale` of the stream's width, spreading as it falls,
## standing `lift` metres off the main sheet. UV.y is metres travelled.
static func _fall_sheet(path: Array[Vector3], across: Vector3, width_scale: float, lift: float) -> ArrayMesh:
	const COLUMNS := 8
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var side := across.normalized()
	var travelled := [0.0]
	for i in range(1, path.size()):
		travelled.append(float(travelled[i - 1]) + path[i].distance_to(path[i - 1]))
	var rows: Array = []
	for i in path.size():
		var ahead := path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]
		var out := ahead.normalized().cross(side).normalized()
		if out.y < 0.0:
			out = -out
		var spread := across.length() * width_scale * (1.0 + 0.35 * float(i) / path.size())
		var row: Array = []
		for c in COLUMNS + 1:
			var x := -1.0 + 2.0 * c / COLUMNS
			row.append([path[i] + side * x * spread + out * lift, out, Vector2(x, travelled[i])])
		rows.append(row)
	for i in rows.size() - 1:
		for c in COLUMNS:
			var quad := [rows[i][c], rows[i][c + 1], rows[i + 1][c + 1], rows[i + 1][c]]
			# Alternate the diagonal, so the facets zigzag like the fire's.
			var order := [0, 2, 1, 0, 3, 2] if (i + c) % 2 == 0 else [0, 3, 1, 1, 3, 2]
			for k: int in order:
				vertices.append(quad[k][0])
				normals.append(quad[k][1])
				uvs.append(quad[k][2])
	return _surface(vertices, normals, uvs)


static var _flow_materials := {}


## One curtain of the fall (waterfall.gdshader): how fast it runs, how solid the
## sheet is, how much of it is still whole at the lip, and how many strands it
## pulls apart into.
static func _fall_material(key: String, speed: float, body: float, lip: float, strands: float) -> ShaderMaterial:
	if _flow_materials.has(key):
		return _flow_materials[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://world/waterfall.gdshader")
	m.set_shader_parameter("speed", speed)
	m.set_shader_parameter("body", body)
	m.set_shader_parameter("lip_opacity", lip)
	m.set_shader_parameter("strands", strands)
	_flow_materials[key] = m
	return m


## The faceted water material (water_flow.gdshader), one per use.
static func _flow_material(key: String, speed: float, foam: float, ripple: float, alpha: float, still: bool = false) -> ShaderMaterial:
	if _flow_materials.has(key):
		return _flow_materials[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://world/water_flow.gdshader")
	m.set_shader_parameter("speed", speed)
	m.set_shader_parameter("foam_amount", foam)
	m.set_shader_parameter("ripple", ripple)
	m.set_shader_parameter("alpha", alpha)
	m.set_shader_parameter("still", still)
	_flow_materials[key] = m
	return m


## Someone lived here before you. Smoke still curls from the fire pit.
static func _castaway_camp(shape: CampIsland) -> Node3D:
	var node := Node3D.new()
	node.name = "CastawayCamp"
	node.position = _ground(shape, shape.camp)
	node.rotation.y = yaw_toward(shape.camp, shape.center)
	var wood := Color(0.45, 0.36, 0.26)
	# The camp's ground isn't flat: sit everything on the ground right under it.
	var basis := Basis(Vector3.UP, node.rotation.y)
	var ground := func(p: Vector3) -> Vector3:
		var w: Vector3 = node.position + basis * p
		return Vector3(p.x, p.y + shape.height_at(w.x, w.z) - node.position.y, p.z)
	# The castaway's tent itself is a real structure (CampSystems seeds it), so the
	# crew can sleep in it or take it apart; this is just the camp around it.
	for i in 9:
		var a := i * TAU / 9.0
		var stone := _mesh(node, MeshKit.rock(60 + i % 6, 0.3, 0.7), "ring_stone", Color(0.45, 0.44, 0.42), ground.call(Vector3(cos(a) * 0.8, 0.07, 2.6 + sin(a) * 0.8)), Vector3(0.0, a * 1.7, 0.1))
		stone.scale = Vector3(0.3, 0.2, 0.26) * (0.85 + 0.3 * absf(sin(i * 3.7)))
	var ash := _mesh(node, MeshKit.rock(70, 0.1, 0.25), "charcoal", Color(0.14, 0.12, 0.11), ground.call(Vector3(0.0, 0.0, 2.6)))
	ash.scale = Vector3(1.1, 0.25, 1.1)
	for i in 3:
		var a := i * TAU / 3.0 + 0.4
		var burnt := _mesh(node, MeshKit.branch(120 + i, 0.8, 0.05, 0.04, 0.03, 5), "charcoal", Color(0.1, 0.08, 0.07), ground.call(Vector3(cos(a) * 0.35, 0.05, 2.6 + sin(a) * 0.35)))
		burnt.rotation = Vector3(0.0, -a, PI / 2.0 - 0.25)
	# The log the machete is stuck in.
	_mesh(node, _cylinder(0.22, 0.25, 0.7), "old_wood", wood, ground.call(Vector3(2.1, 0.35, 2.0)))
	# Still smouldering: low flames in the pit.
	var fire := FireFx.new()
	fire.size = 0.55
	fire.intensity = 0.7
	fire.position = ground.call(Vector3(0.0, 0.08, 2.6))
	node.add_child(fire)
	return node


## Back from the fire pit, so its door stands a safe few metres off the flames.
const TENT_BACK := 2.0


## Where the castaway's tent stands (world space), facing its fire pit.
static func castaway_tent_spot(shape: CampIsland) -> Vector3:
	var back := Basis(Vector3.UP, yaw_toward(shape.camp, shape.center)) * Vector3(0.0, 0.0, -TENT_BACK)
	return _ground(shape, shape.camp + Vector2(back.x, back.z))


## A soft round puff, so smoke particles don't render as hard squares.
static func _soft_puff_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture
