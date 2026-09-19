class_name Pack
extends RefCounted
## Everything a crew member carries: an 8-slot hotbar (any item fits a slot)
## plus storage grids — pockets always, a chest rig and a backpack when the
## gear they wear provides them.

const HOTBAR_SIZE := 8
const POCKETS := Vector2i(5, 2)
const GRID_ORDER := ["pockets", "rig", "backpack"]
const GRID_NAMES := {"pockets": "Pockets", "rig": "Chest rig", "backpack": "Backpack"}
## Which worn slot provides each optional grid.
const GRID_SOURCES := {"rig": "vest", "backpack": "back"}

var hotbar: Array = []
var grids := {}


func _init() -> void:
	hotbar.resize(HOTBAR_SIZE)
	grids["pockets"] = ItemGrid.new(POCKETS.x, POCKETS.y)


func grid(name: String) -> ItemGrid:
	return grids.get(name)


func grid_names() -> Array:
	return GRID_ORDER.filter(func(name: String) -> bool: return grids.has(name))


## Rebuilds the rig and backpack grids from what's worn. Items that no longer
## fit come back in the returned list for the caller to re-home.
func configure(worn_ids: Dictionary) -> Array:
	var displaced: Array = []
	for name: String in GRID_SOURCES:
		var size: Array = ItemTable.STORAGE.get(worn_ids.get(GRID_SOURCES[name], ""), [])
		var old: ItemGrid = grids.get(name)
		if size.is_empty():
			if old != null:
				displaced.append_array(_strip(old.items))
				grids.erase(name)
			continue
		if old != null and old.width == size[0] and old.height == size[1]:
			continue
		var fresh := ItemGrid.new(size[0], size[1])
		if old != null:
			for item: Dictionary in old.items:
				if not fresh.place(item, item.x, item.y, item.rot):
					displaced.append(_strip([item])[0])
		grids[name] = fresh
	return displaced


static func _strip(list: Array) -> Array:
	var out: Array = []
	for item: Dictionary in list:
		var copy := item.duplicate()
		copy.erase("x")
		copy.erase("y")
		copy.erase("rot")
		out.append(copy)
	return out


## Adds `count` fresh `id`. Returns how many didn't fit.
func add(id: String, count: int, now: float = 0.0) -> int:
	var item := ItemTable.get_item(id)
	if item.is_empty() or count <= 0:
		return count
	var spoil: float = item.get("spoil", 0.0)
	var stack := {"id": id, "count": count, "spoils_at": now + spoil if spoil > 0.0 else 0.0}
	if item.has("uses"):
		stack["uses"] = int(item.uses)
	return add_stack(stack)


## Tops up matching stacks anywhere, then fills pockets → rig → backpack →
## empty hotbar slots. Returns how many didn't fit.
func add_stack(stack: Dictionary) -> int:
	var id: String = stack.get("id", "")
	var item := ItemTable.get_item(id)
	var count: int = stack.get("count", 0)
	if item.is_empty() or count <= 0:
		return count
	var remaining := stack.duplicate()
	var stack_max: int = item.get("stack", 1)
	if not stack.has("uses"):
		for slot in hotbar:
			if remaining.count > 0 and slot != null and slot.id == id and not slot.has("uses") and int(slot.count) < stack_max:
				var moved := mini(int(remaining.count), stack_max - int(slot.count))
				slot.count += moved
				remaining.count -= moved
		for name: String in grid_names():
			if remaining.count > 0:
				remaining.count = grids[name].merge_into_stacks(remaining)
	for name: String in grid_names():
		if remaining.count <= 0:
			break
		remaining.count = grids[name].add_stack(remaining)
	for i in HOTBAR_SIZE:
		if remaining.count <= 0:
			break
		if hotbar[i] == null:
			var piece := remaining.duplicate()
			piece.count = mini(int(remaining.count), stack_max)
			piece.uid = ItemGrid.new_uid()
			hotbar[i] = piece
			remaining.count -= piece.count
	return int(remaining.count)


## Adds to storage grids only (never the hotbar). Returns how many didn't fit.
func add_to_storage(stack: Dictionary) -> int:
	var remaining := stack.duplicate()
	for name: String in grid_names():
		if remaining.count > 0:
			remaining.count = grids[name].merge_into_stacks(remaining)
	for name: String in grid_names():
		if remaining.count > 0:
			remaining.count = grids[name].add_stack(remaining)
	return int(remaining.count)


## The first stack of `id` anywhere (hotbar first), as a live reference. Empty if none.
func find_first(id: String) -> Dictionary:
	var index := hotbar_index_of(id)
	if index >= 0:
		return hotbar[index]
	for name: String in grid_names():
		for item: Dictionary in grids[name].items:
			if item.id == id:
				return item
	return {}


func count_of(id: String) -> int:
	var total := 0
	for slot in hotbar:
		if slot != null and slot.id == id:
			total += int(slot.count)
	for g: ItemGrid in grids.values():
		total += g.count_of(id)
	return total


## Removes `count` of `id` (storage first, hotbar last). False, removing nothing, if short.
func remove(id: String, count: int) -> bool:
	if count_of(id) < count:
		return false
	for name: String in grid_names():
		count = grids[name].remove(id, count)
	for i in range(HOTBAR_SIZE - 1, -1, -1):
		var slot = hotbar[i]
		if count > 0 and slot != null and slot.id == id:
			var taken := mini(count, int(slot.count))
			slot.count -= taken
			count -= taken
			if slot.count <= 0:
				hotbar[i] = null
	return true


func hotbar_index_of(id: String) -> int:
	for i in HOTBAR_SIZE:
		if hotbar[i] != null and hotbar[i].id == id:
			return i
	return -1


## Where item `uid` is: {"area": "hotbar", "index": i} or {"area": grid name}. Empty if missing.
func locate(uid: int) -> Dictionary:
	for i in HOTBAR_SIZE:
		if hotbar[i] != null and int(hotbar[i].uid) == uid:
			return {"area": "hotbar", "index": i}
	for name: String in grid_names():
		if not grids[name].get_item(uid).is_empty():
			return {"area": name}
	return {}


func get_stack(uid: int) -> Dictionary:
	var where := locate(uid)
	if where.is_empty():
		return {}
	return hotbar[where.index] if where.area == "hotbar" else grids[where.area].get_item(uid)


## Removes up to `count` of item `uid` (all when count <= 0). Empty if missing.
func take(uid: int, count: int = 0) -> Dictionary:
	var where := locate(uid)
	if where.is_empty():
		return {}
	if where.area != "hotbar":
		return grids[where.area].take(uid, count)
	var slot: Dictionary = hotbar[where.index]
	var taken := slot.duplicate()
	if count <= 0 or count >= int(slot.count):
		hotbar[where.index] = null
	else:
		taken.count = count
		taken.uid = ItemGrid.new_uid()
		slot.count -= count
	return taken


## Every stack carried, without positions (for dropping everything on death).
func all_stacks() -> Array:
	var out: Array = []
	for slot in hotbar:
		if slot != null:
			out.append(slot.duplicate())
	for g: ItemGrid in grids.values():
		out.append_array(_strip(g.items))
	return out


func clear() -> void:
	hotbar.fill(null)
	for g: ItemGrid in grids.values():
		g.items.clear()


func is_empty() -> bool:
	for slot in hotbar:
		if slot != null:
			return false
	for g: ItemGrid in grids.values():
		if not g.is_empty():
			return false
	return true


func tool_types() -> Array[String]:
	var tools: Array[String] = []
	for stack: Dictionary in all_stacks():
		var tool: String = ItemTable.get_item(stack.id).get("tool", "")
		if not tool.is_empty() and not tools.has(tool):
			tools.append(tool)
	return tools


func total_weight() -> float:
	var weight := 0.0
	for slot in hotbar:
		if slot != null:
			weight += float(ItemTable.get_item(slot.id).get("weight", 0.0)) * int(slot.count) + float(slot.get("load", 0.0))
	for g: ItemGrid in grids.values():
		weight += g.total_weight()
	return weight


func spoil_expired(now: float) -> bool:
	var changed := false
	for slot in hotbar:
		if slot != null and slot.spoils_at > 0.0 and now >= slot.spoils_at and slot.id != "spoiled_food":
			slot.id = "spoiled_food"
			slot.spoils_at = 0.0
			changed = true
	for g: ItemGrid in grids.values():
		changed = g.spoil_expired(now) or changed
	return changed


func shift_times(delta: float) -> void:
	for slot in hotbar:
		if slot != null and slot.spoils_at > 0.0:
			slot.spoils_at += delta
	for g: ItemGrid in grids.values():
		g.shift_times(delta)


func to_dict() -> Dictionary:
	var out := {}
	for name: String in grids:
		out[name] = grids[name].to_dict()
	return {"hotbar": hotbar.duplicate(true), "grids": out}


func from_dict(data: Dictionary) -> void:
	hotbar = Array(data.get("hotbar", [])).duplicate(true)
	hotbar.resize(HOTBAR_SIZE)
	for i in HOTBAR_SIZE:
		var slot = hotbar[i]
		if slot is Dictionary and ItemTable.exists(slot.get("id", "")):
			slot.count = int(slot.count)
			slot.uid = int(slot.get("uid", ItemGrid.new_uid()))
			if slot.has("uses"):
				slot.uses = int(slot.uses)
		else:
			hotbar[i] = null
	grids.clear()
	var saved: Dictionary = data.get("grids", {})
	for name: String in GRID_ORDER:
		if saved.has(name):
			var g := ItemGrid.new()
			g.from_dict(saved[name])
			grids[name] = g
	if not grids.has("pockets"):
		grids["pockets"] = ItemGrid.new(POCKETS.x, POCKETS.y)
