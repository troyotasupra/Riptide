class_name ItemMoves
extends RefCounted
## The one set of rules for moving items by drag and drop — between hotbar
## slots, pack grids and container grids — so the host applies exactly what
## the UI previews. A place is {"kind": "hotbar", "pack": Pack, "index": i}
## or {"kind": "grid", "grid": ItemGrid, "x": x, "y": y, "rot": bool}.

## Moves `count` of item `uid` (all when count <= 0) from `source` (a Pack or
## ItemGrid holding it) to `target`. Merges onto a matching stack, swaps with
## a single occupant when moving a whole stack, and undoes everything if the
## item can't land. Returns true if anything moved.
static func move(source: Object, uid: int, count: int, target: Dictionary) -> bool:
	var origin := _origin(source, uid)
	if origin.is_empty():
		return false
	var whole: bool = count <= 0 or count >= int(origin.stack.count)
	var piece := _take(source, uid, count)
	if piece.is_empty():
		return false

	if target.kind == "hotbar":
		var pack: Pack = target.pack
		var index: int = target.index
		if index < 0 or index >= Pack.HOTBAR_SIZE:
			_restore(source, origin, piece)
			return false
		var occupant = pack.hotbar[index]
		if occupant == null:
			pack.hotbar[index] = piece
			return true
		if _can_merge(occupant, piece):
			var left := _merge(occupant, piece)
			if left.is_empty():
				return true
			_restore(source, origin, left)
			return int(left.count) != int(piece.count)
		if whole:
			pack.hotbar[index] = piece
			if _put_back(source, origin, occupant):
				return true
			pack.hotbar[index] = occupant
		_restore(source, origin, piece)
		return false

	var grid: ItemGrid = target.grid
	var x: int = target.x
	var y: int = target.y
	var rot: bool = target.rot
	if not grid.in_bounds(piece.id, x, y, rot):
		_restore(source, origin, piece)
		return false
	var hits := grid.overlapping(piece.id, x, y, rot)
	if hits.is_empty():
		grid.place(piece, x, y, rot)
		return true
	if hits.size() == 1 and _can_merge(hits[0], piece):
		var left := _merge(hits[0], piece)
		if left.is_empty():
			return true
		_restore(source, origin, left)
		return int(left.count) != int(piece.count)
	if whole and hits.size() == 1:
		# Swap: the occupant leaves, this lands, the occupant goes where this was.
		var occupant: Dictionary = grid.take(int(hits[0].uid))
		if grid.fits(piece.id, x, y, rot):
			grid.place(piece, x, y, rot)
			if _put_back(source, origin, occupant):
				return true
			grid.take(int(piece.uid))
		grid.place(occupant, int(hits[0].x), int(hits[0].y), bool(hits[0].get("rot", false)))
	_restore(source, origin, piece)
	return false


## Sends item `uid` anywhere it fits in `destination` (a Pack or ItemGrid).
## Returns true if anything moved; whatever doesn't fit stays behind.
static func quick_move(source: Object, uid: int, destination: Object) -> bool:
	var origin := _origin(source, uid)
	if origin.is_empty():
		return false
	var piece := _take(source, uid, 0)
	var left: int = destination.add_stack(piece)
	if left <= 0:
		return true
	var rest := piece.duplicate()
	rest.count = left
	_restore(source, origin, rest)
	return left != int(piece.count)


static func _can_merge(a: Dictionary, b: Dictionary) -> bool:
	return a.id == b.id and not a.has("uses") and not b.has("uses") \
		and int(a.count) < int(ItemTable.get_item(a.id).get("stack", 1))


## Adds `piece` onto `into`; returns what's left over (empty if all of it fit).
static func _merge(into: Dictionary, piece: Dictionary) -> Dictionary:
	var stack_max: int = ItemTable.get_item(into.id).get("stack", 1)
	var moved := mini(int(piece.count), stack_max - int(into.count))
	into.count += moved
	var spoils: float = piece.get("spoils_at", 0.0)
	if spoils > 0.0 and into.spoils_at > 0.0:
		into.spoils_at = minf(into.spoils_at, spoils)
	if moved >= int(piece.count):
		return {}
	var left := piece.duplicate()
	left.count = int(piece.count) - moved
	return left


static func _origin(source: Object, uid: int) -> Dictionary:
	if source is Pack:
		var where: Dictionary = source.locate(uid)
		if where.is_empty():
			return {}
		var stack: Dictionary = source.get_stack(uid)
		where.stack = stack.duplicate()
		return where
	var item: Dictionary = source.get_item(uid)
	return {} if item.is_empty() else {"area": "grid", "stack": item.duplicate()}


static func _take(source: Object, uid: int, count: int) -> Dictionary:
	return source.take(uid, count)


static func _grid_of(source: Object, origin: Dictionary) -> ItemGrid:
	return source if source is ItemGrid else source.grid(origin.area)


## Returns `piece` to where it came from: merged back onto what's left of its
## stack, or into its old cells, or anywhere in that area as a last resort.
static func _restore(source: Object, origin: Dictionary, piece: Dictionary) -> void:
	if piece.is_empty():
		return
	var stack: Dictionary = origin.stack
	if origin.area == "hotbar":
		var slot = source.hotbar[origin.index]
		if slot == null:
			source.hotbar[origin.index] = piece
		elif slot.id == piece.id:
			slot.count += int(piece.count)
		else:
			source.add_stack(piece)
		return
	var grid := _grid_of(source, origin)
	var remaining = grid.get_item(int(stack.uid))
	if not remaining.is_empty() and remaining.id == piece.id:
		remaining.count += int(piece.count)
	elif not grid.place(piece, int(stack.x), int(stack.y), bool(stack.get("rot", false))):
		if source.add_stack(piece) > 0:
			push_warning("ItemMoves: couldn't restore %s" % piece.id)


## Puts a swapped-out occupant where the moving item used to be, or failing
## that anywhere free on the same side of the move. False if it can't.
static func _put_back(source: Object, origin: Dictionary, occupant: Dictionary) -> bool:
	if origin.area == "hotbar":
		if source.hotbar[origin.index] == null:
			source.hotbar[origin.index] = occupant
			return true
		return _place_anywhere(source, occupant)
	var grid := _grid_of(source, origin)
	var stack: Dictionary = origin.stack
	if grid.place(occupant, int(stack.x), int(stack.y), bool(stack.get("rot", false))):
		return true
	if grid.place(occupant, int(stack.x), int(stack.y), not bool(stack.get("rot", false))):
		return true
	return _place_anywhere(source, occupant)


## Places a whole stack (keeping its uid) in any free cells of `source`.
static func _place_anywhere(source: Object, occupant: Dictionary) -> bool:
	if source is ItemGrid:
		return source.place(occupant)
	for name: String in source.grid_names():
		if source.grid(name).place(occupant):
			return true
	return false
