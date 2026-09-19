class_name ResourceNode
extends Interactable
## A harvestable prop: a palm, a bush, a stone. Whether it's picked clean is
## decided by the host and mirrored on every peer by ResourceField.

var kind := ""
var depleted := false
var _harvest_parts: Array = []
var _hide_when_depleted := false
var _charred: Array = []
var _leaves: Array = []
var _burnt_keep: Array = []
var _felled: Array = []
var _base_layer := 0


func setup(spot: Dictionary) -> void:
	kind = spot.kind
	interact_id = "res:" + String(spot.id)
	position = spot.pos
	rotation.y = spot.yaw
	var built := Props.build(kind, hash(spot.id))
	var visual: Node3D = built.root
	visual.scale = Vector3.ONE * float(spot.scale)
	add_child(visual)
	_harvest_parts = built.harvest
	_hide_when_depleted = built.hide_when_depleted
	_charred = built.get("charred", [])
	_leaves = built.get("leaves", [])
	_burnt_keep = built.get("burnt_keep", [])
	_felled = built.get("felled", [])
	for part: Node3D in _felled:
		part.visible = false
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


## Picked clean, felled, or (`burnt`) taken by fire: then trunks stay up, charred
## and bare, instead of showing a cut stump.
func set_depleted(value: bool, burnt: bool = false) -> void:
	depleted = value
	var charred := value and burnt and not _charred.is_empty()
	for part: Node3D in _harvest_parts:
		part.visible = not value or (charred and _burnt_keep.has(part))
	for leaf: Node3D in _leaves:
		leaf.visible = not charred
	for part: Node3D in _felled:
		part.visible = value and not charred
	for mesh: MeshInstance3D in _charred:
		mesh.material_override = Materials.charred() if charred else null
	if _hide_when_depleted:
		collision_layer = 0 if value else _base_layer
