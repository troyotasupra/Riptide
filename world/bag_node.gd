class_name BagNode
extends Interactable
## A bag of items left in the world — something a crew member dropped, or the
## pack they lost when they blacked out. Search it with interact (F); it disappears once empty.

var bag_id := ""


func setup(id: String, title: String, pos: Vector3) -> void:
	bag_id = id
	name = "Bag_" + id
	interact_id = "bag:" + id
	prompt = "Search %s" % title
	position = pos
	rotation.y = float(hash(id) % 628) / 100.0
	collision_layer = Layers.INTERACT
	collision_mask = 0
	var shape := SphereShape3D.new()
	shape.radius = 0.5
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.15
	add_child(collider)
	var body := CapsuleMesh.new()
	body.radius = 0.16
	body.height = 0.62
	body.radial_segments = 8
	body.rings = 1
	var duffel := MeshInstance3D.new()
	duffel.mesh = body
	duffel.material_override = Props.material("bag", Color(0.26, 0.32, 0.24))
	duffel.rotation.z = PI / 2.0
	duffel.position.y = 0.14
	add_child(duffel)
	var strap := BoxMesh.new()
	strap.size = Vector3(0.05, 0.34, 0.34)
	var strap_instance := MeshInstance3D.new()
	strap_instance.mesh = strap
	strap_instance.material_override = Props.material("bag_strap", Color(0.12, 0.12, 0.12))
	strap_instance.position.y = 0.15
	add_child(strap_instance)
