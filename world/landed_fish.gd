class_name LandedFish
extends Interactable
## A fish you've just dragged out of the water, flopping on the ground where it
## landed. Kill it first (E), then take it. Left alone it tires and suffocates.
## The host owns it; every peer draws the same fish.

## How long a fish thrashes before it gives up, and how long it lies there after.
const SUFFOCATE_SECONDS := 35.0
const ROT_SECONDS := 300.0

var fish_id := ""
var species := ""
var kg := 0.0
var alive := true
## Seconds since it landed (the host uses this to suffocate and clean it up).
var age := 0.0

var _body: Node3D


func setup(id: String, p_species: String, p_kg: float, pos: Vector3, yaw: float) -> void:
	fish_id = id
	species = p_species
	kg = p_kg
	name = "Fish_" + id
	interact_id = "fish:" + id
	position = pos
	rotation.y = yaw
	collision_layer = Layers.INTERACT
	collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.9, 0.6, 0.9)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)
	_body = Node3D.new()
	add_child(_body)
	var model := ItemModels.build(String(FishTable.get_species(species).get("item", "raw_fish")))
	# Item models stand nose-up; lay this one on its side on the ground.
	model.rotation = Vector3(0.0, 0.0, PI * 0.5)
	model.scale = Vector3.ONE * clampf(0.9 + kg * 0.04, 0.9, 1.7)
	_body.add_child(model)
	text_provider = func(_player: Node) -> String:
		var fish_name := String(FishTable.get_species(species).get("name", "fish")).to_lower()
		if alive:
			return "Kill the %.1f kg %s" % [kg, fish_name]
		return "Take the %.1f kg %s" % [kg, fish_name]


func kill() -> void:
	if not alive:
		return
	alive = false
	_body.position = Vector3.ZERO
	_body.rotation.y = 0.0
	_body.rotation.z = 0.0


func _process(delta: float) -> void:
	age += delta
	if not alive:
		return
	# It thrashes hard at first and weakens as it tires.
	var strength := clampf(1.0 - age / SUFFOCATE_SECONDS, 0.15, 1.0)
	var t := Time.get_ticks_msec() * 0.001
	var beat := sin(t * 7.0) * sin(t * 2.3)
	_body.position.y = absf(beat) * 0.12 * strength
	_body.rotation.y = beat * 0.7 * strength
	_body.rotation.z = sin(t * 9.0) * 0.25 * strength
