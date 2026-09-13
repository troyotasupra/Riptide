class_name ItemGrid
extends RefCounted
## A Delta Force-style storage grid. Items take up width × height cells and
## can be rotated. Used for pockets, backpacks, chest rigs, chests and bags.
## An item is {"uid": int, "id": String, "count": int, "spoils_at": float,
## ["uses": int], "x": int, "y": int, "rot": bool}.

var width := 1
var height := 1
var items: Array = []


func _init(w: int = 1, h: int = 1) -> void:
	width = w
	height = h


static func new_uid() -> int:
	return (randi() & 0x3fffffff) + 1


## Footprint of `id`, turned sideways when `rot`.
static func footprint(id: String, rot: bool) -> Vector2i:
	var size := ItemTable.size_of(id)
	return Vector2i(size.y, size.x) if rot else size


static func rect_of(item: Dictionary) -> Rect2i:
	return Rect2i(Vector2i(item.x, item.y), footprint(item.id, item.get("rot", false)))


func get_item(uid: int) -> Dictionary:
	for item: Dictionary in items:
		if item.uid == uid:
			return item
	return {}


func item_at(cell: Vector2i) -> Dictionary:
	for item: Dictionary in items:
		if rect_of(item).has_point(cell):
			return item
	return {}


## Items overlapping a footprint of `id` at (x, y), ignoring `ignore_uid`.
func overlapping(id: String, x: int, y: int, rot: bool, ignore_uid: int = 0) -> Array:
	var rect := Rect2i(Vector2i(x, y), footprint(id, rot))
	var hits: Array = []
	for item: Dictionary in items:
		if item.uid != ignore_uid and rect.intersects(rect_of(item)):
			hits.append(item)
	return hits


func in_bounds(id: String, x: int, y: int, rot: bool) -> bool:
	var size := footprint(id, rot)
	return x >= 0 and y >= 0 and x + size.x <= width and y + size.y <= height


func fits(id: String, x: int, y: int, rot: bool, ignore_uid: int = 0) -> bool:
	return in_bounds(id, x, y, rot) and overlapping(id, x, y, rot, ignore_uid).is_empty()


## First free spot for `id`, trying it upright then sideways. Empty if none.
func find_space(id: String) -> Dictionary:
	var size := ItemTable.size_of(id)
	for rot: bool in ([false] if size.x == size.y else [false, true]):
		for y in height:
			for x in width:
				if fits(id, x, y, rot):
					return {"x": x, "y": y, "rot": rot}
	return {}


## Puts a stack at (x, y) — or anywhere it fits when x < 0 — without merging.
## Keeps its uid if it has one. Returns true if placed.
func place(stack: Dictionary, x: int = -1, y: int = -1, rot: bool = false) -> bool:
	if x < 0:
		var spot := find_space(stack.id)
		if spot.is_empty():
			return false
		x = spot.x
		y = spot.y
		rot = spot.rot
	elif not fits(stack.id, x, y, rot, int(stack.get("uid", 0))):
		return false
	var placed := stack.duplicate()
	placed.x = x
	placed.y = y
	placed.rot = rot
	if int(placed.get("uid", 0)) == 0 or not get_item(placed.uid).is_empty():
		placed.uid = new_uid()
	items.append(placed)
	return true


## Tops up matching stacks, then places new stacks wherever they fit.
## Returns how many didn't fit.
func add_stack(stack: Dictionary) -> int:
	var id: String = stack.get("id", "")
	var item := ItemTable.get_item(id)
	var count: int = stack.get("count", 0)
	if item.is_empty() or count <= 0:
		return count
	count = merge_into_stacks(stack)
	var stack_max: int = item.get("stack", 1)
	var first := true
	while count > 0:
		var piece := stack.duplicate()
		piece.count = mini(count, stack_max)
		if not first:
			piece.erase("uid")
		if not place(piece):
			break
		first = false
		count -= piece.count
	return count


## Tops up existing stacks of the same item; returns what's left.
func merge_into_stacks(stack: Dictionary) -> int:
	var count: int = stack.count
	if stack.has("uses"):
		return count
	var stack_max: int = ItemTable.get_item(stack.id).get("stack", 1)
	for item: Dictionary in items:
		if count <= 0:
			break
		if item.id == stack.id and not item.has("uses") and item.count < stack_max:
			var moved := mini(count, stack_max - int(item.count))
			item.count += moved
			var spoils: float = stack.get("spoils_at", 0.0)
			if spoils > 0.0 and item.spoils_at > 0.0:
				item.spoils_at = minf(item.spoils_at, spoils)
			count -= moved
	return count


## Removes up to `count` of item `uid` (all of it when count <= 0) and returns
## the removed stack without its position. Empty if there's no such item.
func take(uid: int, count: int = 0) -> Dictionary:
	for i in items.size():
		var item: Dictionary = items[i]
		if item.uid != uid:
			continue
		var taken := item.duplicate()
		taken.erase("x")
		taken.erase("y")
		taken.erase("rot")
		if count <= 0 or count >= int(item.count):
			items.remove_at(i)
		else:
			taken.count = count
			taken.uid = new_uid()
			item.count -= count
		return taken
	return {}


## Moves item `uid` to (x, y) within this grid. True if it moved.
func move(uid: int, x: int, y: int, rot: bool) -> bool:
	var item := get_item(uid)
	if item.is_empty() or not fits(item.id, x, y, rot, uid):
		return false
	item.x = x
	item.y = y
	item.rot = rot
	return true


## Moves half of a stack to the first free spot. True if it split.
func split(uid: int) -> bool:
	var item := get_item(uid)
	if item.is_empty() or int(item.count) < 2 or find_space(item.id).is_empty():
		return false
	var half := take(uid, int(item.count) / 2)
	return place(half)


func count_of(id: String) -> int:
	var total := 0
	for item: Dictionary in items:
		if item.id == id:
			total += int(item.count)
	return total


## Removes `count` of `id`; returns how many it couldn't find.
func remove(id: String, count: int) -> int:
	var i := items.size() - 1
	while i >= 0 and count > 0:
		var item: Dictionary = items[i]
		if item.id == id:
			var taken := mini(count, int(item.count))
			item.count -= taken
			count -= taken
			if item.count <= 0:
				items.remove_at(i)
		i -= 1
	return count


func total_weight() -> float:
	var weight := 0.0
	for item: Dictionary in items:
		weight += float(ItemTable.get_item(item.id).get("weight", 0.0)) * int(item.count)
	return weight


func spoil_expired(now: float) -> bool:
	var changed := false
	for item: Dictionary in items:
		if item.spoils_at > 0.0 and now >= item.spoils_at and item.id != "spoiled_food":
			var id: String = item.id
			var rot: bool = item.get("rot", false)
			item.id = "spoiled_food"
			item.spoils_at = 0.0
			# Spoiled food is 1×1; shrinking never collides.
			if footprint(id, rot) != footprint("spoiled_food", false):
				item.rot = false
			changed = true
	return changed


func shift_times(delta: float) -> void:
	for item: Dictionary in items:
		if item.spoils_at > 0.0:
			item.spoils_at += delta


func is_empty() -> bool:
	return items.is_empty()


func to_dict() -> Dictionary:
	return {"w": width, "h": height, "items": items.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	width = int(data.get("w", width))
	height = int(data.get("h", height))
	items.clear()
	for raw in data.get("items", []):
		if raw is Dictionary and ItemTable.exists(raw.get("id", "")):
			var item: Dictionary = raw.duplicate()
			item.uid = int(item.get("uid", new_uid()))
			item.count = int(item.count)
			item.x = int(item.x)
			item.y = int(item.y)
			item.rot = bool(item.get("rot", false))
			if item.has("uses"):
				item.uses = int(item.uses)
			items.append(item)
