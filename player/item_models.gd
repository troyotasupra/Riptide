class_name ItemModels
extends RefCounted
## Small low-poly models of items held in the hand. Every model has its grip at
## the origin and points along +Y (blade, barrel, handle end).

static func build(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Held_" + id
	match id:
		"knife":
			_box(root, Vector3(0.03, 0.1, 0.03), Vector3(0.0, 0.0, 0.0), "grip", Color(0.12, 0.10, 0.09))
			_box(root, Vector3(0.008, 0.15, 0.032), Vector3(0.0, 0.12, 0.0), "steel", Color(0.78, 0.80, 0.82))
		"machete":
			_box(root, Vector3(0.035, 0.12, 0.035), Vector3.ZERO, "grip", Color(0.12, 0.10, 0.09))
			_box(root, Vector3(0.01, 0.46, 0.06), Vector3(0.0, 0.3, 0.008), "steel", Color(0.72, 0.74, 0.76))
		"stone_hatchet":
			_box(root, Vector3(0.035, 0.46, 0.035), Vector3(0.0, 0.15, 0.0), "handle", Color(0.50, 0.36, 0.22))
			_box(root, Vector3(0.05, 0.08, 0.17), Vector3(0.0, 0.35, -0.05), "flint_head", Color(0.30, 0.30, 0.33))
			_box(root, Vector3(0.045, 0.05, 0.05), Vector3(0.0, 0.35, 0.0), "rope_wrap", Color(0.72, 0.64, 0.48))
		"torch":
			_box(root, Vector3(0.035, 0.46, 0.035), Vector3(0.0, 0.15, 0.0), "handle", Color(0.40, 0.29, 0.18))
			var flame := CylinderMesh.new()
			flame.top_radius = 0.0
			flame.bottom_radius = 0.06
			flame.height = 0.16
			flame.radial_segments = 5
			var flame_instance := MeshInstance3D.new()
			flame_instance.mesh = flame
			var glow := StandardMaterial3D.new()
			glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			glow.albedo_color = Color(1.0, 0.6, 0.15)
			flame_instance.material_override = glow
			flame_instance.position.y = 0.46
			root.add_child(flame_instance)
		"canteen", "canteen_clean", "canteen_dirty":
			_cylinder(root, 0.055, 0.2, Vector3(0.0, 0.04, 0.0), "canteen", Color(0.34, 0.40, 0.30))
			_cylinder(root, 0.02, 0.04, Vector3(0.0, 0.16, 0.0), "cap", Color(0.15, 0.15, 0.15))
		"lighter":
			_box(root, Vector3(0.022, 0.06, 0.035), Vector3.ZERO, "lighter", Color(0.80, 0.18, 0.15))
		"fishing_rod":
			_cylinder(root, 0.012, 1.3, Vector3(0.0, 0.55, 0.0), "rod", Color(0.25, 0.22, 0.20))
			_cylinder(root, 0.03, 0.05, Vector3(0.0, 0.05, 0.03), "reel", Color(0.60, 0.60, 0.62))
		"spear":
			_cylinder(root, 0.02, 1.6, Vector3(0.0, 0.45, 0.0), "handle", Color(0.50, 0.36, 0.22))
			_box(root, Vector3(0.02, 0.12, 0.05), Vector3(0.0, 1.3, 0.0), "flint_head", Color(0.30, 0.30, 0.33))
		"pistol", "flare_gun":
			var body := Color(0.13, 0.13, 0.14) if id == "pistol" else Color(0.95, 0.45, 0.10)
			_box(root, Vector3(0.03, 0.19, 0.045), Vector3(0.0, 0.07, -0.03), "gun_" + id, body)
			_box(root, Vector3(0.028, 0.045, 0.1), Vector3(0.0, -0.01, 0.03), "gun_grip_" + id, body.darkened(0.3))
		"survival_book", "logbook", "journal", "sea_chart", "book_page_shelter", "book_page_camp":
			var cover := Color(0.20, 0.35, 0.25) if id == "survival_book" else Color(0.40, 0.26, 0.14)
			if id.begins_with("book_page") or id == "sea_chart":
				cover = Color(0.88, 0.84, 0.72)
			_box(root, Vector3(0.14, 0.2, 0.03), Vector3(0.0, 0.08, 0.0), "cover_" + id, cover)
		"coconut":
			_sphere(root, 0.08, Vector3(0.0, 0.06, 0.0), "coconut", Color(0.38, 0.26, 0.14))
		"raw_fish", "cooked_fish", "dried_fish":
			var fish := Color(0.55, 0.62, 0.68) if id == "raw_fish" else Color(0.62, 0.42, 0.22)
			_box(root, Vector3(0.05, 0.22, 0.03), Vector3(0.0, 0.08, 0.0), "fish_" + id, fish)
		"raw_meat", "cooked_meat", "dried_meat":
			var meat := Color(0.70, 0.22, 0.22) if id == "raw_meat" else Color(0.45, 0.25, 0.14)
			_box(root, Vector3(0.08, 0.12, 0.05), Vector3(0.0, 0.05, 0.0), "meat_" + id, meat)
		_:
			var category := ItemTable.category(id)
			var color := Color(0.62, 0.55, 0.45)
			if category == "food":
				color = Color(0.45, 0.30, 0.55)
			elif category == "placeable":
				color = Color(0.50, 0.40, 0.30)
			_box(root, Vector3(0.09, 0.09, 0.09), Vector3(0.0, 0.04, 0.0), "held_" + category, color)
	return root


static func _box(parent: Node3D, size: Vector3, pos: Vector3, key: String, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_add(parent, mesh, pos, key, color)


static func _cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, key: String, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 6
	mesh.rings = 1
	_add(parent, mesh, pos, key, color)


static func _sphere(parent: Node3D, radius: float, pos: Vector3, key: String, color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 7
	mesh.rings = 4
	_add(parent, mesh, pos, key, color)


static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, key: String, color: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = Props.material("item_" + key, color)
	instance.position = pos
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
