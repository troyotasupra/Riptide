class_name ResourceField
extends Node3D
## Every harvestable prop on the camp island. Spots come from Scatter (identical
## on every peer); the host decides what gets picked and when it grows back,
## and only those changes cross the network.

const BUILD_PER_FRAME := 60
const REGROW_CHECK_SECONDS := 1.0

## id -> ResourceNode
var nodes := {}
## id -> regrow time on the ocean clock
var depleted := {}

var _pending: Array[Dictionary] = []
var _regrow_accum := 0.0


func populate(shape: CampIsland) -> void:
	_pending = Scatter.generate(shape)
	print("[resources] %d props to place" % _pending.size())


func _process(delta: float) -> void:
	for i in mini(BUILD_PER_FRAME, _pending.size()):
		var spot: Dictionary = _pending.pop_back()
		var node := ResourceNode.new()
		node.setup(spot)
		add_child(node)
		nodes[spot.id] = node
		if depleted.has(spot.id):
			node.set_depleted(true)
	_regrow_accum += delta
	if _regrow_accum >= REGROW_CHECK_SECONDS:
		_regrow_accum = 0.0
		if multiplayer.is_server():
			_regrow_due()


## Host only: `survivor` gathers from prop `id`.
func harvest(survivor: Survivor, id: String) -> void:
	var node: ResourceNode = nodes.get(id)
	if node == null:
		return
	var info: Dictionary = ResourceTable.KINDS.get(node.kind, {})
	if info.is_empty():
		return
	if depleted.has(id):
		survivor.notify(info.get("depleted_label", "Nothing left here yet."))
		return
	var yields: Array = info.get("yields", [])
	if yields.is_empty():
		survivor.notify(info.get("needs", "You can't gather that yet."))
		return
	var gained: PackedStringArray = []
	var full := false
	for entry: Array in yields:
		var count := randi_range(entry[1], entry[2])
		var left := survivor.inventory.add(entry[0], count, Ocean.time)
		if count - left > 0:
			gained.append("+%d %s" % [count - left, ItemTable.display_name(entry[0])])
		full = full or left > 0
	if full:
		survivor.notify("Your pack is full.")
	if gained.is_empty():
		return
	var regrow_at: float = Ocean.time + float(info.get("respawn", 600.0))
	_apply(id, regrow_at)
	Net.send_to_ready(self, "_sync_one", [id, regrow_at])
	survivor.notify("  ".join(gained))
	survivor.push_inventory()


func sync_to(peer_id: int) -> void:
	_sync_all.rpc_id(peer_id, depleted)


func _regrow_due() -> void:
	var now: float = Ocean.time
	var due: Array[String] = []
	for id: String in depleted:
		if now >= depleted[id]:
			due.append(id)
	for id in due:
		_apply(id, 0.0)
		Net.send_to_ready(self, "_sync_one", [id, 0.0])


func _apply(id: String, regrow_at: float) -> void:
	if regrow_at > 0.0:
		depleted[id] = regrow_at
	else:
		depleted.erase(id)
	var node: ResourceNode = nodes.get(id)
	if node != null:
		node.set_depleted(regrow_at > 0.0)


@rpc("authority", "call_remote", "reliable")
func _sync_one(id: String, regrow_at: float) -> void:
	_apply(id, regrow_at)


@rpc("authority", "call_remote", "reliable")
func _sync_all(all: Dictionary) -> void:
	for id: String in depleted.keys():
		_apply(id, 0.0)
	for id: String in all:
		_apply(id, all[id])
