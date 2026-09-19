class_name CampIslandPois
extends RefCounted
## Landmarks on the camp island: the spring and its stream, the castaway camp
## (with its smoke — the landmark you steer the raft by), the cave mouth, the
## fishing shack and its dock, and the shipwreck on the reef.

static func build(shape: CampIsland) -> Node3D:
	var root := Node3D.new()
	root.name = "Landmarks"
	root.add_child(_spring(shape))
	root.add_child(_stream(shape))
	root.add_child(_waterfall(shape))
	root.add_child(_castaway_camp(shape))
	root.add_child(_cave(shape))
	root.add_child(FishingShack.build(shape))
	root.add_child(_shipwreck(shape))
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
	water.material_override = _water_material()
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


static func _surface(vertices: PackedVector3Array, normals: PackedVector3Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if vertices.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## The stream from the pool down to the sea, lying in its carved bed. The stretch
## going over the waterfall is left out, because that water is drawn falling.
static func _stream(shape: CampIsland) -> Node3D:
	const SEGMENTS := 64
	const HALF_WIDTH := 1.1
	var stream := Interactable.new()
	stream.name = "Stream"
	stream.interact_id = "stream"
	stream.text_provider = func(player: Node) -> String: return GameState.world.stream_prompt(player)
	stream.collision_layer = Layers.INTERACT
	stream.collision_mask = 0

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var previous_left := Vector3.ZERO
	var previous_right := Vector3.ZERO
	var previous_center := Vector3.ZERO
	var had_previous := false
	for i in SEGMENTS + 1:
		var t := float(i) / SEGMENTS
		if t > CampIsland.FALL_T and t < CampIsland.FALL_T + CampIsland.FALL_SPAN:
			had_previous = false  # the falling stretch
			continue
		var p := shape.stream_point(t)
		var ahead := shape.stream_point(minf(t + 0.01, 1.0)) - shape.stream_point(maxf(t - 0.01, 0.0))
		var side := ahead.normalized().orthogonal() * HALF_WIDTH
		var y: float = shape.stream_bed(t) + 0.3
		var center := Vector3(p.x, y, p.y)
		var left := Vector3(p.x + side.x, y, p.y + side.y)
		var right := Vector3(p.x - side.x, y, p.y - side.y)
		if had_previous:
			for v: Vector3 in [previous_left, previous_right, left, previous_right, right, left]:
				vertices.append(v)
				normals.append(Vector3.UP)
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
		had_previous = true
	var water := MeshInstance3D.new()
	water.mesh = _surface(vertices, normals)
	water.material_override = _water_material()
	stream.add_child(water)
	return stream


## The big fall: a sheet of running water down the rock face, wet boulders either
## side, a pool to catch it and spray where it lands.
static func _waterfall(shape: CampIsland) -> Node3D:
	var node := Node3D.new()
	node.name = "Waterfall"
	var fall: Dictionary = shape.waterfall()
	var top: Vector3 = fall.top
	var foot: Vector3 = fall.foot
	var direction: Vector2 = fall.direction
	var forward := Vector3(direction.x, 0.0, direction.y)
	var across := forward.cross(Vector3.UP).normalized() * CampIsland.STREAM_WIDTH * 0.9

	# The sheet: leaning out from the brink and spreading as it falls.
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	const STEPS := 10
	for i in STEPS:
		var t0 := float(i) / STEPS
		var t1 := float(i + 1) / STEPS
		var points: Array[Vector3] = []
		for t: float in [t0, t1]:
			var lean := forward * (0.3 + t * 1.1)
			var y := lerpf(top.y + 0.3, foot.y - 0.15, t * t * 0.4 + t * 0.6)
			var spread := 1.0 + t * 0.4
			points.append(Vector3(top.x, y, top.z) + lean - across * spread)
			points.append(Vector3(top.x, y, top.z) + lean + across * spread)
		for triangle: Array in [[0, 1, 2], [1, 3, 2]]:
			for index: int in triangle:
				vertices.append(points[index])
				uvs.append(Vector2(float(index % 2), t1 if index >= 2 else t0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var sheet_mesh := ArrayMesh.new()
	sheet_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var sheet := MeshInstance3D.new()
	sheet.mesh = sheet_mesh
	sheet.material_override = _falling_water_material()
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(sheet)

	var plunge := MeshInstance3D.new()
	plunge.mesh = _pool_mesh(shape, Vector2(foot.x, foot.z), CampIsland.PLUNGE_RADIUS * 2.0, foot.y + 0.3)
	plunge.material_override = _water_material()
	node.add_child(plunge)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("waterfall:%d" % shape.island_seed)
	for i in 22:
		var at := top.lerp(foot, rng.randf()) + forward * rng.randf_range(-1.0, 2.5)
		var sideways := across.normalized() * (CampIsland.STREAM_WIDTH * rng.randf_range(1.0, 2.4) * (1.0 if i % 2 == 0 else -1.0))
		var spot := at + sideways
		spot.y = shape.height_at(spot.x, spot.z) - 0.3
		var size := rng.randf_range(0.9, 2.4)
		_mesh(node, MeshKit.rock(70 + i, 0.4, 0.8), "fall_rock", Color(0.38, 0.37, 0.36), spot,
			Vector3(rng.randf() * 0.4, rng.randf() * TAU, rng.randf() * 0.4)).scale = Vector3(size * 1.3, size, size * 1.1)

	var spray := GPUParticles3D.new()
	spray.name = "Spray"
	spray.amount = 220
	spray.lifetime = 1.4
	spray.position = foot + Vector3.UP * 0.4 + forward * 0.6
	var quad := QuadMesh.new()
	quad.size = Vector2(0.7, 0.7)
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
	mist.albedo_color = Color(0.92, 0.96, 1.0, 0.16)
	mist.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	spray.material_override = mist
	node.add_child(spray)
	return node


static var _falling_water: ShaderMaterial


static func _falling_water_material() -> ShaderMaterial:
	if _falling_water != null:
		return _falling_water
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_disabled, depth_draw_always;

void fragment() {
	// Streaks of water running down the face, breaking up as they fall.
	float run = UV.y * 5.0 + TIME * 1.6;
	float streak = 0.5 + 0.5 * sin(run * 6.2831 + sin(UV.x * 26.0) * 1.7);
	float foam = smoothstep(0.55, 1.0, UV.y);
	ALBEDO = mix(vec3(0.62, 0.78, 0.86), vec3(1.0), clamp(streak * 0.7 + foam * 0.6, 0.0, 1.0));
	ALPHA = clamp(0.72 + foam * 0.25, 0.0, 1.0);
	ROUGHNESS = 0.12;
	SPECULAR = 0.6;
}"""
	_falling_water = ShaderMaterial.new()
	_falling_water.shader = shader
	return _falling_water


static func _water_material() -> StandardMaterial3D:
	var m := Props.material("fresh_water", Color(0.34, 0.66, 0.74, 0.8))
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.1
	return m


## Someone lived here before you. Smoke still curls from the fire pit.
static func _castaway_camp(shape: CampIsland) -> Node3D:
	var node := Node3D.new()
	node.name = "CastawayCamp"
	node.position = _ground(shape, shape.camp)
	node.rotation.y = yaw_toward(shape.camp, shape.center)
	var wood := Color(0.45, 0.36, 0.26)
	# The castaway's tent itself is a real structure (CampSystems seeds it), so the
	# crew can sleep in it or take it apart; this is just the camp around it.
	for i in 9:
		var a := i * TAU / 9.0
		var stone := _mesh(node, MeshKit.rock(60 + i % 6, 0.3, 0.7), "ring_stone", Color(0.45, 0.44, 0.42), Vector3(cos(a) * 0.8, 0.07, 2.6 + sin(a) * 0.8), Vector3(0.0, a * 1.7, 0.1))
		stone.scale = Vector3(0.3, 0.2, 0.26) * (0.85 + 0.3 * absf(sin(i * 3.7)))
	var ash := _mesh(node, MeshKit.rock(70, 0.1, 0.25), "charcoal", Color(0.14, 0.12, 0.11), Vector3(0.0, 0.0, 2.6))
	ash.scale = Vector3(1.1, 0.25, 1.1)
	for i in 3:
		var a := i * TAU / 3.0 + 0.4
		var burnt := _mesh(node, MeshKit.branch(120 + i, 0.8, 0.05, 0.04, 0.03, 5), "charcoal", Color(0.1, 0.08, 0.07), Vector3(cos(a) * 0.35, 0.05, 2.6 + sin(a) * 0.35))
		burnt.rotation = Vector3(0.0, -a, PI / 2.0 - 0.25)
	# The log the machete is stuck in.
	_mesh(node, _cylinder(0.22, 0.25, 0.7), "old_wood", wood, Vector3(2.1, 0.35, 2.0))
	var smoke := _smoke()
	# The tall landmark column starts above head height, so it doesn't fog the camp itself.
	smoke.position = Vector3(0.0, 4.0, 2.6)
	node.add_child(smoke)
	# Still smouldering: low flames in the pit.
	var fire := FireFx.new()
	fire.size = 0.55
	fire.intensity = 0.7
	fire.position = Vector3(0.0, 0.08, 2.6)
	node.add_child(fire)
	return node


## Where the castaway's tent stands (world space), facing its fire pit.
static func castaway_tent_spot(shape: CampIsland) -> Vector3:
	return _ground(shape, shape.camp)


static func _smoke() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	# A tall column — the landmark you row toward from the starter island.
	particles.amount = 56
	particles.lifetime = 20.0
	particles.preprocess = 20.0
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 6.0
	process.initial_velocity_min = 3.8
	process.initial_velocity_max = 5.0
	process.gravity = Vector3(0.3, 0.1, 0.12)
	process.scale_min = 2.5
	process.scale_max = 7.0
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(3.0, 3.0)
	var puff := StandardMaterial3D.new()
	puff.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	puff.billboard_keep_scale = true
	puff.albedo_color = Color(0.80, 0.80, 0.80, 0.35)
	puff.albedo_texture = _soft_puff_texture()
	puff.roughness = 1.0
	quad.material = puff
	particles.draw_pass_1 = quad
	particles.visibility_aabb = AABB(Vector3(-60.0, -5.0, -60.0), Vector3(120.0, 130.0, 120.0))
	return particles


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


static func _cave(shape: CampIsland) -> Node3D:
	var node := Node3D.new()
	node.name = "CaveMouth"
	node.position = _ground(shape, shape.cave)
	node.rotation.y = yaw_toward(shape.cave, shape.center)
	_mesh(node, _box(Vector3(3.2, 3.0, 1.0)), "cave_dark", Color(0.03, 0.03, 0.03), Vector3(0.0, 1.5, 0.2))
	var boulder := SphereMesh.new()
	boulder.radius = 1.6
	boulder.height = 3.2
	boulder.radial_segments = 6
	boulder.rings = 3
	for spot: Vector3 in [Vector3(-2.6, 1.2, 0.6), Vector3(2.6, 1.2, 0.6), Vector3(-1.4, 3.6, 0.8), Vector3(1.4, 3.6, 0.8), Vector3(0.0, 4.2, 0.9)]:
		_mesh(node, boulder, "boulder", Color(0.47, 0.45, 0.43), spot, Vector3(0.4, spot.x, 0.0))
		var rock := SphereShape3D.new()
		rock.radius = 1.5
		_solid(node, rock, spot)
	return node


static func _shipwreck(shape: CampIsland) -> Node3D:
	var node := Node3D.new()
	node.name = "Shipwreck"
	node.position = _ground(shape, shape.shipwreck) + Vector3(0.0, 1.2, 0.0)
	node.rotation = Vector3(0.1, shape.island_seed % 628 / 100.0, 0.5)
	_mesh(node, _box(Vector3(6.0, 4.0, 22.0)), "wreck_wood", Color(0.30, 0.22, 0.15), Vector3.ZERO)
	_mesh(node, _cylinder(0.25, 0.3, 9.0), "wreck_mast", Color(0.25, 0.19, 0.13), Vector3(0.0, 5.5, -3.0), Vector3(0.0, 0.0, 0.6))
	var hull := BoxShape3D.new()
	hull.size = Vector3(6.0, 4.0, 22.0)
	_solid(node, hull, Vector3.ZERO)
	return node
