class_name Inventory
extends RefCounted
## Pure inventory rules, used for a crew member's pack (8 hotbar slots then 16
## backpack slots) and for chests, lockers and crates of any size.
## A slot is null or {"id": String, "count": int, "spoils_at": float, ["uses": int]}
## (spoils_at is on the ocean clock; 0 means the item never spoils).

const HOTBAR_SIZE := 8
const BACKPACK_SIZE := 16
const SIZE := HOTBAR_SIZE + BACKPACK_SIZE

var slots: Array = []


func _init(size: int = SIZE) -> void:
	slots.resize(size)


## Adds `count` fresh `id`, topping up existing stacks first. Returns what didn't fit.
func add(id: String, count: int, now: float = 0.0) -> int:
	var item := ItemTable.get_item(id)
	if item.is_empty() or count <= 0:
		return count
	var spoil: float = item.get("spoil", 0.0)
	var stack := {"id": id, "count": count, "spoils_at": now + spoil if spoil > 0.0 else 0.0}
	if item.has("uses"):
		stack["uses"] = int(item.uses)
	return add_stack(stack)


## Adds an existing stack (keeping its spoil time and uses). Returns the count that didn't fit.
func add_stack(stack: Dictionary) -> int:
	var id: String = stack.get("id", "")
	var item := ItemTable.get_item(id)
	var count: int = stack.get("count", 0)
	if item.is_empty() or count <= 0:
		return count
	var stack_max: int = item.get("stack", 1)
	var spoils_at: float = stack.get("spoils_at", 0.0)
	var has_uses := stack.has("uses")
	if not has_uses:
		for slot in slots:
			if count <= 0:
				break
			if slot != null and slot.id == id and not slot.has("uses") and slot.count < stack_max:
				var moved := mini(count, stack_max - slot.count)
				slot.count += moved
				if spoils_at > 0.0 and slot.spoils_at > 0.0:
					slot.spoils_at = minf(slot.spoils_at, spoils_at)
				count -= moved
	for i in slots.size():
		if count <= 0:
			break
		if slots[i] == null:
			var moved := mini(count, stack_max)
			var placed := {"id": id, "count": moved, "spoils_at": spoils_at}
			if has_uses:
				placed["uses"] = int(stack.uses)
			slots[i] = placed
			count -= moved
	return count


func count_of(id: String) -> int:
	var total := 0
	for slot in slots:
		if slot != null and slot.id == id:
			total += slot.count
	return total


func first_slot_of(id: String) -> int:
	for i in slots.size():
		if slots[i] != null and slots[i].id == id:
			return i
	return -1


## Tool types carried, e.g. ["knife", "lighter"].
func tool_types() -> Array[String]:
	var tools: Array[String] = []
	for slot in slots:
		if slot != null:
			var tool: String = ItemTable.get_item(slot.id).get("tool", "")
			if not tool.is_empty() and not tools.has(tool):
				tools.append(tool)
	return tools


## Removes `count` of `id` across stacks. Removes nothing and returns false if short.
func remove(id: String, count: int) -> bool:
	if count_of(id) < count:
		return false
	for i in slots.size():
		if count <= 0:
			break
		var slot = slots[i]
		if slot != null and slot.id == id:
			var taken := mini(count, slot.count)
			slot.count -= taken
			count -= taken
			if slot.count <= 0:
				slots[i] = null
	return true


## Takes up to `count` from one slot; returns the taken stack (empty if nothing).
func take_from_slot(index: int, count: int = 1) -> Dictionary:
	if index < 0 or index >= slots.size() or slots[index] == null:
		return {}
	var slot: Dictionary = slots[index]
	var taken := slot.duplicate()
	taken.count = mini(count, slot.count)
	slot.count -= taken.count
	if slot.count <= 0:
		slots[index] = null
	return taken


## Moves a stack onto another slot: merges matching items, otherwise swaps.
func move(from: int, to: int) -> void:
	var size := slots.size()
	if from == to or from < 0 or to < 0 or from >= size or to >= size or slots[from] == null:
		return
	var source: Dictionary = slots[from]
	var target = slots[to]
	if target != null and target.id == source.id and not source.has("uses") and not target.has("uses"):
		var stack_max: int = ItemTable.get_item(source.id).get("stack", 1)
		var moved := mini(source.count, stack_max - target.count)
		target.count += moved
		if source.spoils_at > 0.0 and target.spoils_at > 0.0:
			target.spoils_at = minf(target.spoils_at, source.spoils_at)
		source.count -= moved
		if source.count <= 0:
			slots[from] = null
	else:
		slots[from] = target
		slots[to] = source


## Turns anything past its spoil time into spoiled food. Returns true if anything rotted.
func spoil_expired(now: float) -> bool:
	var changed := false
	for i in slots.size():
		var slot = slots[i]
		if slot != null and slot.spoils_at > 0.0 and now >= slot.spoils_at and slot.id != "spoiled_food":
			slots[i] = {"id": "spoiled_food", "count": slot.count, "spoils_at": 0.0}
			changed = true
	return changed


## Moves every spoil time by `delta` — used to store them relative to the clock in saves.
func shift_times(delta: float) -> void:
	for slot in slots:
		if slot != null and slot.spoils_at > 0.0:
			slot.spoils_at += delta


func total_weight() -> float:
	var weight := 0.0
	for slot in slots:
		if slot != null:
			weight += float(ItemTable.get_item(slot.id).get("weight", 0.0)) * slot.count
	return weight


func is_empty() -> bool:
	for slot in slots:
		if slot != null:
			return false
	return true


func to_dict() -> Dictionary:
	return {"slots": slots.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	var size := slots.size()
	slots = Array(data.get("slots", [])).duplicate(true)
	slots.resize(size)
	for slot in slots:
		if slot != null:
			slot.count = int(slot.count)
			if slot.has("uses"):
				slot.uses = int(slot.uses)
