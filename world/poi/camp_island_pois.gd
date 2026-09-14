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
	spring.position = Vector3(shape.spring.x, shape.spring_height - 0.2, shape.spring.y)
	var area := CylinderShape3D.new()
	area.radius = CampIsland.POND_RADIUS
	area.height = 1.2
	var collider := CollisionShape3D.new()
	collider.shape = area
	spring.add_child(collider)
	var water := MeshInstance3D.new()
	water.mesh = _cylinder(CampIsland.POND_RADIUS * 0.95, CampIsland.POND_RADIUS * 0.95, 0.05, 14)
	water.material_override = _water_material()
	spring.add_child(water)
	return spring


static func _stream(shape: CampIsland) -> Node3D:
	const SEGMENTS := 48
	const HALF_WIDTH := 1.6
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
	for i in SEGMENTS + 1:
		var t := float(i) / SEGMENTS
		var p := shape.stream_point(t)
		var ahead := shape.stream_point(minf(t + 0.01, 1.0)) - shape.stream_point(maxf(t - 0.01, 0.0))
		var side := ahead.normalized().orthogonal() * HALF_WIDTH
		var y := shape.height_at(p.x, p.y) + 0.3
		var center := Vector3(p.x, y, p.y)
		var left := Vector3(p.x + side.x, y, p.y + side.y)
		var right := Vector3(p.x - side.x, y, p.y - side.y)
		if i > 0:
			for v: Vector3 in [previous_left, previous_right, left, previous_right, right, left]:
				vertices.append(v)
				normals.append(Vector3.UP)
			# A thin interaction box along each segment so you can drink or fill a canteen.
			var along := center - previous_center
			if along.length() > 0.1:
				var box := BoxShape3D.new()
				box.size = Vector3(HALF_WIDTH * 2.0, 0.6, along.length())
				var collider := CollisionShape3D.new()
				collider.shape = box
				collider.transform = Transform3D(Basis.looking_at(along.normalized(), Vector3.UP), (center + previous_center) * 0.5)
				stream.add_child(collider)
		previous_left = left
		previous_right = right
		previous_center = center
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var water := MeshInstance3D.new()
	water.mesh = mesh
	water.material_override = _water_material()
	stream.add_child(water)
	return stream


static func _water_material() -> StandardMaterial3D:
	var m := Props.material("fresh_water", Color(0.22, 0.52, 0.62, 0.82))
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
	for x: float in [-1.1, 1.1]:
		_mesh(node, _cylinder(0.06, 0.08, 2.0), "old_wood", wood, Vector3(x, 1.0, -1.0), Vector3(0.0, 0.0, 0.1 * x))
	_mesh(node, _box(Vector3(2.6, 0.06, 2.3)), "old_tarp", Color(0.42, 0.48, 0.40), Vector3(0.0, 1.2, 0.0), Vector3(-0.75, 0.0, 0.08))
	for i in 8:
		var a := i * TAU / 8.0
		_mesh(node, _box(Vector3(0.28, 0.2, 0.22)), "ring_stone", Color(0.45, 0.44, 0.42), Vector3(cos(a) * 0.85, 0.1, 2.6 + sin(a) * 0.85), Vector3(0.0, a, 0.0))
	_mesh(node, _cylinder(0.08, 0.08, 1.0), "charcoal", Color(0.12, 0.10, 0.09), Vector3(0.0, 0.1, 2.6), Vector3(0.0, 0.6, PI / 2.0))
	# The log the machete is stuck in.
	_mesh(node, _cylinder(0.22, 0.25, 0.7), "old_wood", wood, Vector3(1.4, 0.35, 1.8))
	var smoke := _smoke()
	smoke.position = Vector3(0.0, 0.3, 2.6)
	node.add_child(smoke)
	return node


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
