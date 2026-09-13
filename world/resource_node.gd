class_name ResourceNode
extends Interactable
## A harvestable prop: a palm, a bush, a stone. Whether it's picked clean is
## decided by the host and mirrored on every peer by ResourceField.

var kind := ""
var depleted := false
var _harvest_parts: Array = []
var _hide_when_depleted := false
var _base_layer := 0


func setup(spot: Dictionary) -> void:
	kind = spot.kind
	interact_id = "res:" + String(spot.id)
	position = spot.pos
	rotation.y = spot.yaw
	var built := Props.build(kind)
	var visual: Node3D = built.root
	visual.scale = Vector3.ONE * float(spot.scale)
	add_child(visual)
	_harvest_parts = built.harvest
	_hide_when_depleted = built.hide_when_depleted
	var collider := CollisionShape3D.new()
	collider.shape = built.shape
	collider.position = built.shape_position
	add_child(collider)
	if not ResourceTable.KINDS.has(kind):
		_base_layer = Layers.WORLD
	elif built.blocks:
		_base_layer = Layers.WORLD | Layers.INTERACT
	else:
		_base_layer = Layers.INTERACT
	collision_layer = _base_layer
	collision_mask = 0


func interact_text(_player: Node) -> String:
	var info: Dictionary = ResourceTable.KINDS.get(kind, {})
	if info.is_empty():
		return ""
	if depleted:
		return info.get("depleted_label", "Nothing left — it will grow back")
	return info.label


func hold_seconds(player: Node) -> float:
	if depleted or player == null or player.survivor == null:
		return 0.0
	return maxf(0.0, ResourceTable.harvest_seconds(kind, player.survivor.inventory.tool_types()))


func set_depleted(value: bool) -> void:
	depleted = value
	for part: Node3D in _harvest_parts:
		part.visible = not value
	if _hide_when_depleted:
		collision_layer = 0 if value else _base_layer
