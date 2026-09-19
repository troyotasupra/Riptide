class_name BagNode
extends Interactable
## A bag of items left in the world — something a crew member dropped, or the
## pack they lost when they blacked out. Search it with interact (F); it disappears once empty.

var bag_id := ""


func setup(id: String, title: String, pos: Vector3) -> void:
	bag_id = id
	name = "Bag_" + id
	interact_id = "bag:" + id
	prompt = "Search %s   ·   %s pick it all up" % [title, Controls.tag("rotate")]
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
	var band := TorusMesh.new()
	band.inner_radius = 0.158
	band.outer_radius = 0.175
	band.rings = 16
	band.ring_segments = 6
	for x: float in [-0.14, 0.14]:
		var strap := MeshInstance3D.new()
		strap.mesh = band
		strap.material_override = Props.material("bag_strap", Color(0.12, 0.12, 0.12))
		strap.position = Vector3(x, 0.14, 0.0)
		strap.rotation.z = PI / 2.0
		add_child(strap)
	var handle := TorusMesh.new()
	handle.inner_radius = 0.07
	handle.outer_radius = 0.085
	handle.rings = 12
	handle.ring_segments = 5
	var grip := MeshInstance3D.new()
	grip.mesh = handle
	grip.material_override = Props.material("bag_strap", Color(0.12, 0.12, 0.12))
	grip.position = Vector3(0.0, 0.3, 0.0)
	grip.rotation.x = PI / 2.0
	grip.scale = Vector3(1.0, 1.0, 0.6)
	add_child(grip)
