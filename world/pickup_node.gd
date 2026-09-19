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
	# The same model you'd hold, laid on its side and resting on the ground.
	var model := ItemModels.build(item_id)
	var pivot := Node3D.new()
	add_child(pivot)
	pivot.add_child(model)
	# Item models stand nose-up; tip the tall ones over (pages and keys already lie flat).
	var upright := _bounds_in(pivot)
	if upright.size.y > maxf(upright.size.x, upright.size.z):
		pivot.rotation = Vector3(0.0, 0.0, PI * 0.5)
	var bounds := _bounds_in(pivot)
	pivot.position = Vector3(-bounds.get_center().x, -bounds.position.y + 0.01, -bounds.get_center().z)


## The model's bounding box in this node's space.
func _bounds_in(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var local := _relative(mesh_instance) * mesh_instance.mesh.get_aabb()
		box = local if first else box.merge(local)
		first = false
	return box


## A child's transform relative to this node, before the node is in the tree.
func _relative(node: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var at: Node = node
	while at != null and at != self:
		if at is Node3D:
			t = (at as Node3D).transform * t
		at = at.get_parent()
	return t
