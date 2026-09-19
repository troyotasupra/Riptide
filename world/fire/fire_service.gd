class_name FireService
extends Node
## Wildfire. The host runs a FireGrid over both islands — grass, jungle, trees and
## anything the crew built can catch, it spreads with the wind, rain puts it out,
## and burnt ground grows back. Every peer draws the nearest burning cells with
## one connected particle fire and darkens burnt ground through the terrain's burn mask.
##
## Fires start from a lit torch or lighter held to dry ground (left click), and
## now and then from a campfire throwing an ember into the grass in a wind.

const STEP_SECONDS := 0.25
const SYNC_SECONDS := 0.5
## How close you must be to set something alight.
const IGNITE_REACH := 3.5
## Damage per second to things in a burning cell.
const STRUCTURE_BURN := 7.0
const PLAYER_BURN := 9.0
## A lit campfire's chance per second, per m/s of wind, of starting a grass fire.
const EMBER_RATE := 0.0009
const RESOURCE_FUEL := {"tree": 1.0, "palm": 0.75, "berry_bush": 0.85, "red_berry_bush": 0.85, "fiber": 0.9, "driftwood": 0.6}

var grid: FireGrid
## Cells as the peers see them (the host's are the grid's own).
var burning_cells := {}
var burnt_cells := {}

var _rng := RandomNumberGenerator.new()
var _step_accum := 0.0
var _sync_accum := 0.0
var _view_accum := 0.0
var _pending_lit: Array = []
var _pending_out: Array = []
var _pending_regrown: Array = []
## cell -> [resource ids], built as the island's props appear.
var _resource_cells := {}
var _indexed := 0
var _wildfire: WildfireFx
var _view_dirty := false
var _mask: Image
var _mask_texture: ImageTexture
var _mask_rect: Rect2
var _mask_dirty := false


func _ready() -> void:
	grid = FireGrid.new(_fuel_at)
	_rng.randomize()
	var reach: float = CampIsland.DISTANCE_FROM_START + CampIsland.RADIUS * 2.0
	_mask_rect = Rect2(-reach, -reach, reach * 2.0, reach * 2.0)
	var texels := int(ceil(reach * 2.0 / FireGrid.CELL))
	_mask = Image.create(texels, texels, false, Image.FORMAT_R8)
	_mask_texture = ImageTexture.create_from_image(_mask)
	TerrainLayers.set_burn_mask(_mask_texture, _mask_rect)
	_wildfire = WildfireFx.new()
	_wildfire.name = "Wildfire"
	add_child(_wildfire)


# --- what burns ----------------------------------------------------------------------

## Fuel in the square around `xz`: the ground cover, or what grows there.
func _fuel_at(xz: Vector2) -> float:
	var world := GameState.world
	if world == null:
		return 0.0
	var h: float = world.ground_height(xz.x, xz.y)
	if h == -INF or h < 0.4:
		return 0.0
	var ground := 0.0
	if world.camp_island != null and xz.distance_to(world.camp_island.center) < CampIsland.RADIUS * 1.5:
		var slope := _slope(xz)
		var biome: CampIsland.Biome = world.camp_island.biome_at(xz.x, xz.y, h)
		match biome:
			CampIsland.Biome.JUNGLE:
				ground = 0.9
			CampIsland.Biome.MEADOW:
				ground = 0.8
			CampIsland.Biome.PALM_COAST:
				ground = 0.55
			CampIsland.Biome.HILLS:
				ground = 0.6 if h < 40.0 else 0.1
		if slope < 0.72:
			ground *= 0.2
	elif h > 1.4:
		ground = 0.7 if _slope(xz) > 0.75 else 0.15
	for id: String in _resources_in(FireGrid.cell_of(xz)):
		var node: ResourceNode = world.resources.nodes.get(id)
		if node != null:
			ground = maxf(ground, float(RESOURCE_FUEL.get(node.kind, 0.0)))
	return ground


func _slope(xz: Vector2) -> float:
	var world := GameState.world
	var e := 1.5
	var dx: float = world.ground_height(xz.x + e, xz.y) - world.ground_height(xz.x - e, xz.y)
	var dz: float = world.ground_height(xz.x, xz.y + e) - world.ground_height(xz.x, xz.y - e)
	return Vector3(-dx, 2.0 * e, -dz).normalized().y


func _resources_in(cell: Vector2i) -> Array:
	var world := GameState.world
	if world == null or world.resources == null:
		return []
	if _indexed != world.resources.nodes.size():
		_resource_cells.clear()
		for id: String in world.resources.nodes:
			var node: Node3D = world.resources.nodes[id]
			var at := FireGrid.cell_of(Vector2(node.global_position.x, node.global_position.z))
			if not _resource_cells.has(at):
				_resource_cells[at] = []
			_resource_cells[at].append(id)
		_indexed = world.resources.nodes.size()
	return _resource_cells.get(cell, [])


# --- host --------------------------------------------------------------------------

## A crew member holds a lit torch or lighter to the ground at `point`.
@rpc("any_peer", "call_local", "reliable")
func request_ignite(point: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var world := GameState.world
	var peer := multiplayer.get_remote_sender_id()
	if peer == 0:
		peer = multiplayer.get_unique_id()
	var player := world.players_root.get_node_or_null(str(peer)) as Player
	if player == null or player.survivor == null:
		return
	var tool := String(ItemTable.get_item(player.held_id).get("tool", ""))
	if tool != "torch" and tool != "lighter":
		return
	if player.world_transform().origin.distance_to(point) > IGNITE_REACH + 1.0:
		return
	var cell := FireGrid.cell_of(Vector2(point.x, point.z))
	if grid.burnt.has(cell):
		player.survivor.notify("It's already burnt black.")
		return
	if not ignite_at(point):
		player.survivor.notify("Nothing here will catch — try dry grass or brush.")
		return
	player.survivor.notify("The grass catches.")


## Host: set the ground at `point` alight. False if nothing there will burn.
func ignite_at(point: Vector3) -> bool:
	var cell := FireGrid.cell_of(Vector2(point.x, point.z))
	var lit := grid.ignite_patch(cell)
	for each in lit:
		_pending_lit.append(each)
		_on_lit(each)
	return not lit.is_empty()


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_host_tick(delta)
	_view_accum += delta
	if _view_accum >= 0.5:
		_view_accum = 0.0
		_update_view()
	if _mask_dirty:
		_mask_dirty = false
		_mask_texture.update(_mask)


func _host_tick(delta: float) -> void:
	var world := GameState.world
	if world == null or world.weather == null:
		return
	_step_accum += delta
	while _step_accum >= STEP_SECONDS:
		_step_accum -= STEP_SECONDS
		var wind: Vector2 = Vector2.from_angle(world.weather.wind_angle) * world.weather.wind_speed
		var rain := float(world.weather.current.get("rain", 0.0))
		var changes := grid.step(STEP_SECONDS, wind, rain, Ocean.time, _rng)
		for cell: Vector2i in changes.lit:
			_on_lit(cell)
		_pending_lit.append_array(changes.lit)
		_pending_out.append_array(changes.out)
		_pending_regrown.append_array(changes.regrown)
		_burn_what_stands_in_fire(STEP_SECONDS)
		_campfire_embers(STEP_SECONDS, wind, rain)
	_sync_accum += delta
	if _sync_accum >= SYNC_SECONDS:
		_sync_accum = 0.0
		if not (_pending_lit.is_empty() and _pending_out.is_empty() and _pending_regrown.is_empty()):
			var lit := _pack(_pending_lit)
			var out := _pack(_pending_out)
			var regrown := _pack(_pending_regrown)
			_apply_changes(lit, out, regrown)
			Net.send_to_ready(self, "_apply_changes", [lit, out, regrown])
			_pending_lit.clear()
			_pending_out.clear()
			_pending_regrown.clear()


## A cell catches: whatever grows there is burnt away until it grows back.
func _on_lit(cell: Vector2i) -> void:
	var world := GameState.world
	for id: String in _resources_in(cell):
		var node: ResourceNode = world.resources.nodes.get(id)
		if node != null and RESOURCE_FUEL.has(node.kind) and not world.resources.depleted.has(id):
			world.resources.burn(id, FireGrid.REGROW_SECONDS)


func _burn_what_stands_in_fire(dt: float) -> void:
	var world := GameState.world
	var rain := float(world.weather.current.get("rain", 0.0))
	for id: String in world.camp.structures.keys():
		var entry: Dictionary = world.camp.structures.get(id, {})
		if not entry.get("burning", false):
			continue
		if rain > 0.5:
			world.camp.set_structure_burning(id, false)
			continue
		world.camp.damage_structure(id, STRUCTURE_BURN * dt, "fire")
		# A burning hut lights the grass around it.
		if _rng.randf() < dt * 0.3:
			var pos: Vector3 = entry.pos
			ignite_at(pos + Vector3(_rng.randf_range(-2.0, 2.0), 0.0, _rng.randf_range(-2.0, 2.0)))
	if grid.burning.is_empty():
		return
	for id: String in world.camp.structures.keys():
		var entry: Dictionary = world.camp.structures.get(id, {})
		if entry.is_empty():
			continue
		var pos: Vector3 = entry.pos
		# Once it catches it keeps burning until it's gone or the rain puts it out.
		if not entry.get("burning", false) and _near_fire(Vector2(pos.x, pos.z), float(StructureTable.get_type(entry.type).get("footprint", 1.0)) * 0.6):
			world.camp.set_structure_burning(id, true)
	for player: Player in world.players_root.get_children():
		if player.survivor == null or player.survivor.downed:
			continue
		var at := player.world_transform().origin
		var ground: float = world.ground_height(at.x, at.z)
		if ground == -INF or at.y - ground > 1.5:
			continue
		if grid.burning.has(FireGrid.cell_of(Vector2(at.x, at.z))):
			player.survivor.survival.take_damage(PLAYER_BURN * dt)
			if _rng.randf() < dt * 0.5:
				player.survivor.notify("You're burning — get out of the fire!")


func _near_fire(xz: Vector2, radius: float) -> bool:
	var reach := int(ceil(radius / FireGrid.CELL))
	var center := FireGrid.cell_of(xz)
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var cell := center + Vector2i(dx, dz)
			if grid.burning.has(cell) and FireGrid.center_of(cell).distance_to(xz) <= radius + FireGrid.CELL * 0.7:
				return true
	return false


## Wind can carry an ember from a lit campfire into the grass beside it.
func _campfire_embers(dt: float, wind: Vector2, rain: float) -> void:
	if rain > 0.2 or wind.length() < 3.0:
		return
	var world := GameState.world
	for id: String in world.camp.structures:
		var entry: Dictionary = world.camp.structures[id]
		if entry.type != "campfire":
			continue
		var station: CookStation = world.camp.stations.get("struct:" + id)
		if station == null or not station.lit:
			continue
		if _rng.randf() >= EMBER_RATE * wind.length() * dt:
			continue
		var downwind: Vector2 = Vector2(entry.pos.x, entry.pos.z) + wind.normalized() * _rng.randf_range(1.2, 2.4)
		if ignite_at(Vector3(downwind.x, 0.0, downwind.y)):
			world.camp._notify_crew("Sparks from the campfire caught the grass!")


func sync_to(peer_id: int) -> void:
	_sync_all.rpc_id(peer_id, _pack(grid.burning.keys()), _pack(grid.burnt.keys()))


func to_save(now: float) -> Dictionary:
	return grid.to_save(now)


func from_save(data: Dictionary, now: float) -> void:
	grid.from_save(data, now)
	_sync_all(_pack(grid.burning.keys()), _pack(grid.burnt.keys()))


# --- every peer ----------------------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _apply_changes(lit: PackedInt32Array, out: PackedInt32Array, regrown: PackedInt32Array) -> void:
	for cell in _unpack(lit):
		burning_cells[cell] = true
		_paint(cell, 0.45)
	for cell in _unpack(out):
		burning_cells.erase(cell)
		burnt_cells[cell] = true
		_paint(cell, 1.0)
	for cell in _unpack(regrown):
		burnt_cells.erase(cell)
		_paint(cell, 0.0)


@rpc("authority", "call_remote", "reliable")
func _sync_all(fires: PackedInt32Array, scars: PackedInt32Array) -> void:
	for cell: Vector2i in burning_cells.keys() + burnt_cells.keys():
		_paint(cell, 0.0)
	burning_cells.clear()
	burnt_cells.clear()
	for cell in _unpack(fires):
		burning_cells[cell] = true
		_paint(cell, 0.45)
	for cell in _unpack(scars):
		burnt_cells[cell] = true
		_paint(cell, 1.0)


func _paint(cell: Vector2i, value: float) -> void:
	var at := Vector2(cell) * FireGrid.CELL - _mask_rect.position
	var x := int(at.x / FireGrid.CELL)
	var y := int(at.y / FireGrid.CELL)
	if x < 0 or y < 0 or x >= _mask.get_width() or y >= _mask.get_height():
		return
	_mask.set_pixel(x, y, Color(value, 0.0, 0.0))
	_mask_dirty = true
	_view_dirty = true


## One particle system for the whole fire, fed from every burning cell.
func _update_view() -> void:
	if not _view_dirty:
		return
	_view_dirty = false
	var world := GameState.world
	var ground := func(xz: Vector2) -> float:
		var h: float = world.ground_height(xz.x, xz.y) if world != null else 0.0
		return maxf(h, 0.0)
	_wildfire.set_cells(burning_cells.keys(), ground, grid.fuel)


static func _pack(cells: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for cell: Vector2i in cells:
		out.append(cell.x)
		out.append(cell.y)
	return out


static func _unpack(data: PackedInt32Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in range(0, data.size() - 1, 2):
		out.append(Vector2i(data[i], data[i + 1]))
	return out
