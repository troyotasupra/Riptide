class_name PickupNode
extends Interactable
## A one-off item lying in the world (the machete, a key, a torn page).
## Once someone takes it, it's gone for the whole crew.

var pickup_id := ""


func setup(id: String, label: String, item_id: String, pos: Vector3, yaw: float) -> void:
	pickup_id = id
	name = "Pickup_" + id
	interact_id = "pickup:" + id
	prompt = label
	position = pos
	rotation.y = yaw
	collision_layer = Layers.INTERACT
	collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.7, 0.4, 0.7)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)
	match item_id:
		"machete":
			_box(Vector3(0.05, 0.02, 0.55), Vector3(0.0, 0.0, -0.1), "blade", Color(0.78, 0.80, 0.82), Vector3(0.5, 0.0, 0.0))
			_box(Vector3(0.05, 0.05, 0.16), Vector3(0.0, -0.13, 0.22), "handle", Color(0.15, 0.12, 0.10), Vector3(0.5, 0.0, 0.0))
		"compartment_key":
			_box(Vector3(0.03, 0.01, 0.08), Vector3.ZERO, "brass", Color(0.8, 0.65, 0.25))
		"journal":
			_box(Vector3(0.18, 0.04, 0.25), Vector3.ZERO, "journal_cover", Color(0.35, 0.22, 0.12))
		_:
			_box(Vector3(0.2, 0.005, 0.28), Vector3.ZERO, "page", Color(0.90, 0.87, 0.78), Vector3(0.0, 0.4, 0.0))


func _box(size: Vector3, pos: Vector3, key: String, color: Color, rot: Vector3 = Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = Props.material(key, color)
	visual.position = pos
	visual.rotation = rot
	add_child(visual)
