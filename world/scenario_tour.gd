class_name ScenarioTour
extends Node
## --scenario=tour --shot-dir=<absolute folder>: one run that visits every place
## worth judging up close and saves a picture of each to <folder>/<stop>.png.
## Guns and tools in hand, tents and fires at every stage, the castaway camp by
## day and night, terrain edges, trees, the shack, pickups, and a wildfire last
## (it spreads, so nothing after it would look normal).
## --face=<prefix> runs only the stops whose names start with it.

const GUNS := ["m1911", "uzi", "m4", "mossberg", "intervention"]
const TOOLS := ["stone_hatchet", "knife", "machete", "fishing_rod", "torch"]

var world: Node3D
var camp: CampSystems
var island: CampIsland
var player: Player
var dir := ""
var only := ""
var saved := 0
var _cam: Camera3D


func run() -> void:
	world = GameState.world
	camp = world.camp
	island = world.camp_island
	player = GameState.local_player as Player
	dir = GameState.shot_dir
	only = GameState.face
	if dir.is_empty():
		dir = OS.get_user_data_dir().path_join("tour")
	DirAccess.make_dir_recursive_absolute(dir)
	# Nobody at the keyboard: let the scripted inputs through.
	GameState.free_mouse = true
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.near = 0.02
	_cam.far = 3000.0
	world.add_child(_cam)
	_day(0.45)
	world.weather.set_state("clear", true)
	world.weather.set_wind(0.8, 3.0)
	await _model_rack()
	await _item_rack()
	await _guns_in_hand()
	await _guns_on_ground()
	await _tools_in_hand()
	await _tents()
	await _campfires()
	await _castaway()
	await _cave()
	await _terrain()
	await _trees()
	await _shack()
	await _pickups()
	await _wildfire()
	print("[tour] saved %d picture(s) to %s" % [saved, dir])


func _wants(prefix: String) -> bool:
	return only.is_empty() or prefix.begins_with(only) or only.begins_with(prefix)


# --- capture ---------------------------------------------------------------

func _shot(name: String) -> void:
	# No menu may cover a picture, whatever opened it.
	for child in world.get_children():
		if child is Hud and GameState.ui_open:
			(child as Hud)._close_all()
			print("[tour] a panel was open before %s; closed it" % name)
	await RenderingServer.frame_post_draw
	var path := dir.path_join(name + ".png")
	var err := get_viewport().get_texture().get_image().save_png(path)
	if err == OK:
		saved += 1
	print("[tour] %s: %s" % [name, error_string(err)])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _day(fraction: float) -> void:
	GameState.day_offset = fraction - Ocean.time / DayNight.DAY_LENGTH


func _look(eye: Vector3, target: Vector3) -> void:
	_cam.global_transform = Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)
	_cam.make_current()


func _first_person() -> void:
	player.camera.make_current()


func _ground(xz: Vector2) -> Vector3:
	return Vector3(xz.x, island.height_at(xz.x, xz.y), xz.y)


## Stands the player at `at` looking toward `target`.
func _stand(at: Vector3, target: Vector3, pitch: float = 0.0) -> void:
	player.teleport(at)
	player.yaw = atan2(-(target.x - at.x), -(target.z - at.z))
	player.pitch = pitch


func _hold(id: String) -> void:
	var pack := player.survivor.inventory
	if pack.find_first(id).is_empty():
		world.dev.request("give", [id, 1])
	pack.hotbar[0] = null
	ItemMoves.move(pack, int(pack.find_first(id).get("uid", 0)), 0, {"kind": "hotbar", "pack": pack, "index": 0})
	player.survivor.select_slot(0)
	player.survivor.push_inventory()
	player.held_id = id


# --- stops -----------------------------------------------------------------

## Every bush and plant model in the packs in a row on the beach, for choosing.
func _model_rack() -> void:
	if not _wants("rack_"):
		return
	var files := [["nature/bush_berries.glb", 1.15], ["nature/bush.glb", 1.2], ["nature/bushes.glb", 1.0], ["nature/flower_bushes.glb", 0.9]]
	var inland := (island.center - island.cove).normalized()
	var across := inland.orthogonal()
	var holder := Node3D.new()
	world.add_child(holder)
	var n := 0
	for entry: Array in files:
		for i in ModelLib.part_count(entry[0]):
			var xz: Vector2 = island.cove + inland * 22.0 + across * (n - 4.0) * 1.7
			var model := ModelLib.part(entry[0], i, entry[1])
			holder.add_child(model)
			model.global_position = _ground(xz)
			n += 1
	var middle: Vector2 = island.cove + inland * 22.0
	var eye2: Vector2 = middle - inland * 6.5
	_look(_ground(eye2) + Vector3.UP * 1.8, _ground(middle) + Vector3.UP * 0.5)
	await _wait(0.8)
	await _shot("rack_bushes")
	holder.queue_free()

## The cave behind the waterfall: its doorway from the pool, the hill over it
## (no sign of the cut), and inside by torchlight: the tunnel and the chamber.
func _cave() -> void:
	if not _wants("cave_"):
		return
	var out := -island.cave_dir
	var right := island.cave_dir.orthogonal()
	var mouth := CaveBuild.point(island, 0.0, 0.0)
	var eye := mouth + Vector3(out.x, 0.0, out.y) * 7.0 + Vector3(right.x, 0.0, right.y) * 3.0
	eye.y = maxf(island.height_at(eye.x, eye.z), mouth.y) + 1.7
	_look(eye, mouth + Vector3.UP * 1.6)
	await _wait(0.8)
	await _shot("cave_doorway")
	_look(mouth + Vector3(out.x, 0.0, out.y) * 22.0 + Vector3.UP * 16.0, CaveBuild.room_point(island, Vector3.ZERO) + Vector3.UP * 8.0)
	await _wait(0.5)
	await _shot("cave_hill_over")
	_hold("torch")
	for view: Array in [["cave_tunnel", CaveBuild.point(island, 2.0, 0.0, 0.1), CaveBuild.point(island, 9.0, 0.0, 1.2)],
			["cave_chamber", CaveBuild.room_point(island, Vector3(0.0, 0.1, -4.5)), CaveBuild.room_point(island, Vector3(0.0, 0.8, 1.0))],
			["cave_bodies", CaveBuild.room_point(island, Vector3(-2.5, 0.1, -2.0)), CaveBuild.room_point(island, Vector3(1.0, 0.3, 0.5))]]:
		_stand(view[1], view[2], -0.25)
		_first_person()
		await _wait(1.2)
		await _shot(view[0])
	player.survivor.inventory.hotbar[0] = null
	player.held_id = ""


## The hand-held models, each on its own side-on, filling the frame.
func _item_rack() -> void:
	if not _wants("item_"):
		return
	var stand := player.world_transform().origin + Vector3(0.0, 60.0, 0.0)
	var lamp := DirectionalLight3D.new()
	world.add_child(lamp)
	lamp.global_rotation = Vector3(-0.7, 0.9, 0.0)
	for id: String in ["knife", "machete", "dagger", "bow", "arrow", "outboard_motor", "fishing_rod", "torch", "lighter"]:
		var model := ItemModels.build(id)
		world.add_child(model)
		# Laid along the view, top up: its own +Y to the right, +Z up.
		model.global_transform = Transform3D(Basis(Vector3(0.0, 0.0, 1.0), Vector3(1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0)), stand)
		var box := AABB()
		var first := true
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var b := mesh.global_transform * mesh.get_aabb()
			box = b if first else box.merge(b)
			first = false
		var size := maxf(box.size.x, maxf(box.size.y, 0.05))
		_look(box.get_center() + Vector3(0.0, 0.0, size * 1.25), box.get_center())
		await _wait(0.4)
		await _shot("item_" + id)
		model.queue_free()
	lamp.queue_free()


func _dock_out() -> Array:
	var dock_end: Vector3 = camp.shack.dock_end
	var out: Vector3 = dock_end - Vector3(camp.shack.dock_start)
	out.y = 0.0
	return [dock_end + Vector3.UP * 0.6, out.normalized()]


func _guns_in_hand() -> void:
	if not _wants("gun_"):
		return
	var spot := _dock_out()
	for id: String in GUNS:
		var weapon: String = ItemTable.get_item(id).get("weapon", id)
		world.dev.request("give", [WeaponTable.ammo_item(weapon), 40])
		_hold(id)
		_stand(spot[0], spot[0] + spot[1] * 10.0, -0.02)
		_first_person()
		await _wait(1.2)
		await _shot("gun_%s_hip" % id)
		Input.action_press("secondary")
		await _wait(1.0)
		await _shot("gun_%s_aimed" % id)
		Input.action_release("secondary")
		await _wait(0.6)
		# One round from the hip: the flash should leave the muzzle, not the eye.
		world.combat.request_shot(-player.camera.global_basis.z, 0.0)
		player.view_model.recoil(0.6)
		await _shot("gun_%s_fire" % id)
		await _wait(0.6)
		var stack := CombatService.held_gun(player)
		stack["ammo"] = 0
		world.combat.request_reload()
		await _wait(0.8)
		await _shot("gun_%s_reload" % id)
		await _wait(4.5)


func _guns_on_ground() -> void:
	if not _wants("guns_ground"):
		return
	var home := camp.shack_spawn(0)
	var inland := (island.center - Vector2(home.x, home.z)).normalized()
	var spot2 := Vector2(home.x, home.z) + inland * 4.0
	var base := _ground(spot2)
	var holder := Node3D.new()
	holder.name = "TourGuns"
	world.add_child(holder)
	for i in GUNS.size():
		var model := ItemModels.build(GUNS[i])
		holder.add_child(model)
		# On its side, barrel along +X, sights toward -Z: how a dropped gun lies.
		var at := base + Vector3(-0.2, 0.0, (i - 2) * 0.32)
		at.y = world.ground_height(at.x, at.z) + 0.035
		model.global_transform = Transform3D(Basis(Vector3.UP, Vector3.RIGHT, Vector3.FORWARD), at)
	_look(base + Vector3(0.0, 1.5, 1.6), base + Vector3(0.1, 0.0, 0.0))
	await _wait(0.8)
	await _shot("guns_ground")
	holder.queue_free()


func _tools_in_hand() -> void:
	if not _wants("tool_"):
		return
	var home := camp.shack_spawn(0)
	var inland := (island.center - Vector2(home.x, home.z)).normalized()
	var at := _ground(Vector2(home.x, home.z) + inland * 6.0) + Vector3.UP * 0.2
	for id: String in TOOLS:
		_hold(id)
		_stand(at, at + Vector3(inland.x, 0.0, inland.y) * 10.0, -0.1)
		_first_person()
		await _wait(1.0)
		await _shot("tool_" + id)
	player.survivor.inventory.hotbar[0] = null
	player.held_id = ""


## A clear, flat-ish spot inland from the cove, `n` metres along a row.
func _site(n: float) -> Vector3:
	var inland := (island.center - island.cove).normalized()
	var xz := island.cove + inland * 30.0 + inland.orthogonal() * n
	return _ground(xz)


func _tents() -> void:
	if not _wants("tent_"):
		return
	var yaw := 0.4
	var facing := Vector3(sin(yaw), 0.0, cos(yaw))
	var side := Vector3(cos(yaw), 0.0, -sin(yaw))
	var stages := [["tent_stage0", {}], ["tent_stage1", {"tarp": 1}], ["tent_done", {"tarp": 1, "rope": 3}]]
	for i in stages.size():
		var base := _site(-12.0 + i * 7.0)
		var id := "tour_tent%d" % i
		camp._spawn_structure(id, "tent", base, yaw)
		camp._apply_progress(id, stages[i][1])
		var name: String = stages[i][0]
		await _wait(0.4)
		_look(base + facing * 4.5 + side * 1.2 + Vector3.UP * 1.6, base + Vector3.UP * 0.6)
		await _wait(0.4)
		await _shot(name + "_front")
		if name == "tent_done":
			_look(base - facing * 4.5 - side * 1.2 + Vector3.UP * 1.6, base + Vector3.UP * 0.6)
			await _wait(0.3)
			await _shot(name + "_back")
			_look(base + facing * 0.5 + Vector3.UP * 0.7, base - facing * 2.0 + Vector3.UP * 0.4)
			await _wait(0.3)
			await _shot(name + "_inside")
			# The dismantle prompt: first person, standing at the door, facing it.
			var door := base + facing * 2.4
			door.y = world.ground_height(door.x, door.z) + 0.1
			_stand(door, base, -0.25)
			_first_person()
			await _wait(1.0)
			await _shot("tent_prompt")


func _campfires() -> void:
	if not _wants("fire_"):
		return
	var stages := [["fire_stage0", {}], ["fire_stage1", {"stone": 4}], ["fire_unlit", {"stone": 4, "wood": 3}]]
	for i in stages.size():
		var base := _site(12.0 + i * 5.0)
		var id := "tour_fire%d" % i
		camp._spawn_structure(id, "campfire", base, 0.0)
		camp._apply_progress(id, stages[i][1])
		await _wait(0.3)
		_look(base + Vector3(1.6, 1.4, 1.6), base + Vector3.UP * 0.2)
		await _wait(0.3)
		await _shot(stages[i][0])
	var lit_id := "tour_fire2"
	var ring: CookStation = camp.stations["struct:" + lit_id]
	ring.add_fuel(400.0)
	ring.light()
	camp._broadcast_station("struct:" + lit_id)
	var at := _site(22.0)
	await _wait(2.0)
	_look(at + Vector3(0.9, 0.9, 0.9), at + Vector3.UP * 0.35)
	await _shot("fire_lit_close")
	_look(at + Vector3(3.0, 1.7, 3.0), at + Vector3.UP * 0.4)
	await _shot("fire_lit_day")
	_day(0.9)
	await _wait(1.5)
	await _shot("fire_lit_night")
	_day(0.45)
	await _wait(0.5)


func _castaway() -> void:
	if not _wants("castaway"):
		return
	var yaw := CampIslandPois.yaw_toward(island.camp, island.center)
	var basis := Basis(Vector3.UP, yaw)
	var at := _ground(island.camp)
	_look(at + basis * Vector3(3.2, 1.7, 5.8), at + basis * Vector3(0.0, 0.6, 0.8))
	await _wait(1.0)
	await _shot("castaway_day")
	_look(at + basis * Vector3(0.0, 1.7, -7.0), at + basis * Vector3(0.0, 0.6, 0.0))
	await _wait(0.5)
	await _shot("castaway_day_back")
	_day(0.95)
	_look(at + basis * Vector3(3.2, 1.7, 5.8), at + basis * Vector3(0.0, 0.6, 0.8))
	await _wait(1.5)
	await _shot("castaway_night")
	_day(0.45)
	await _wait(0.5)


func _terrain() -> void:
	if not _wants("terrain_"):
		return
	# The first grass inland from the cove: beach behind, grass ahead.
	var inland := (island.center - island.cove).normalized()
	var edge := island.cove
	for step in 200:
		var p := island.cove + inland * float(step)
		var h := island.height_at(p.x, p.y)
		if island.biome_at(p.x, p.y, h) != CampIsland.Biome.BEACH and h > 0.5:
			edge = p
			break
	var edge_at := _ground(edge)
	var across := Vector3(inland.orthogonal().x, 0.0, inland.orthogonal().y)
	_look(edge_at - Vector3(inland.x, 0.0, inland.y) * 6.0 + across * 3.0 + Vector3.UP * 1.7, edge_at + Vector3(inland.x, 0.0, inland.y) * 4.0)
	await _wait(0.8)
	await _shot("terrain_beach_edge")
	_look(edge_at + Vector3.UP * 12.0 - Vector3(inland.x, 0.0, inland.y) * 8.0, edge_at)
	await _wait(0.5)
	await _shot("terrain_beach_edge_above")
	# Jungle floor: the first jungle point found on a ring round the centre.
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	for attempt in 600:
		var p := island.center + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(40.0, 200.0)
		var h := island.height_at(p.x, p.y)
		if island.biome_at(p.x, p.y, h) == CampIsland.Biome.JUNGLE:
			var here := _ground(p)
			_look(here + Vector3(0.0, 1.7, 0.0), here + Vector3(4.0, 0.2, 3.0))
			await _wait(0.8)
			await _shot("terrain_jungle")
			break
	var fall: Dictionary = island.waterfall()
	var foot: Vector3 = fall.foot
	var top: Vector3 = fall.top
	var out := Vector3(float(fall.direction.x), 0.0, float(fall.direction.y))
	var side := out.cross(Vector3.UP)
	_look(foot + out * 26.0 + side * 10.0 + Vector3.UP * 9.0, top.lerp(foot, 0.55))
	await _wait(0.8)
	await _shot("terrain_waterfall")
	_look(foot + out * 8.0 + side * 3.0 + Vector3.UP * 2.0, foot + Vector3.UP * 1.0)
	await _wait(0.5)
	await _shot("terrain_plunge_pool")
	_look(foot + side * 30.0 + out * 6.0 + Vector3.UP * 4.0, top.lerp(foot, 0.3))
	await _wait(0.5)
	await _shot("terrain_cliff")
	var from_hill := (island.spring - island.hill).normalized()
	var eye := island.spring + from_hill * 15.0
	_look(Vector3(eye.x, island.spring_height + 7.0, eye.y), Vector3(island.spring.x, island.spring_height, island.spring.y))
	await _wait(0.5)
	await _shot("terrain_spring")
	var near := island.spring + from_hill * 4.0
	_look(Vector3(near.x, island.spring_height + 1.7, near.y), Vector3(island.spring.x, island.spring_height, island.spring.y))
	await _wait(0.5)
	await _shot("terrain_spring_close")


func _nearest(kind: String, from: Vector3) -> ResourceNode:
	var best: ResourceNode = null
	for node: ResourceNode in world.resources.nodes.values():
		if node.kind == kind and not node.depleted and (best == null or node.global_position.distance_to(from) < best.global_position.distance_to(from)):
			best = node
	return best


func _trees() -> void:
	if not _wants("tree_"):
		return
	var home := camp.shack_spawn(0)
	# [kind, name, distance out, eye height, target height]
	for view: Array in [["tree", "tree_close", 4.0, 1.7, 2.5], ["tree", "tree_under", 1.3, 1.5, 6.0], ["tree", "tree_mid", 12.0, 1.7, 3.5],
			["palm", "tree_palm_close", 4.0, 1.7, 3.0], ["palm", "tree_palm_top", 3.0, 8.5, 5.8], ["palm", "tree_palm_mid", 12.0, 1.7, 3.5],
			["berry_bush", "tree_bush", 2.0, 1.4, 0.5], ["fiber", "tree_fiber", 1.6, 1.3, 0.3], ["stone", "tree_stone", 1.4, 1.2, 0.1],
			["driftwood", "tree_driftwood", 2.0, 1.4, 0.1]]:
		var node := _nearest(view[0], home)
		if node == null:
			print("[tour] no %s to look at" % view[0])
			continue
		var p := node.global_position
		var out := Vector3(p.x - home.x, 0.0, p.z - home.z).normalized()
		var side := out.cross(Vector3.UP)
		var d: float = view[2]
		var eye := p + out * d + side * d * 0.3 + Vector3.UP * float(view[3])
		var ground: float = world.ground_height(eye.x, eye.z)
		if ground != -INF:
			eye.y = maxf(eye.y, ground + 0.4)
		_look(eye, p + Vector3.UP * float(view[4]) - out * 0.3)
		await _wait(0.6)
		await _shot(view[1])
	# The island from the water, far enough to see the treeline as a whole.
	var out2 := Vector2.from_angle(island.cove_bearing)
	var sea := island.cove + out2 * 120.0
	_look(Vector3(sea.x, 6.0, sea.y), _ground(island.cove + (island.center - island.cove) * 0.4) + Vector3.UP * 6.0)
	await _wait(1.0)
	await _shot("tree_far_from_sea")


func _shack() -> void:
	if not _wants("shack"):
		return
	var xf: Transform3D = camp.shack.xf
	for view: Array in [["shack_door", Vector3(0.0, 1.5, -5.0), Vector3(0.0, 0.6, 0.5)],
			["shack_dock", Vector3(14.0, 5.5, -29.0), Vector3(4.5, 0.4, -18.0)],
			["shack_inside", Vector3(0.3, 1.6, -1.6), Vector3(-0.6, 0.6, 1.5)],
			["shack_inside_back", Vector3(-0.4, 1.6, 1.4), Vector3(0.4, 0.8, -1.8)],
			["shack_back", Vector3(3.0, 2.0, 6.0), Vector3(0.0, 1.2, 0.0)],
			["shack_steps_side", Vector3(4.5, 0.8, -3.6), Vector3(0.0, 0.0, -3.0)]]:
		_look(xf * Vector3(view[1]), xf * Vector3(view[2]))
		await _wait(0.6)
		await _shot(view[0])
	var dock_start: Vector3 = camp.shack.dock_start
	var dock_dir: Vector3 = (Vector3(camp.shack.dock_end) - dock_start).normalized()
	var across := dock_dir.cross(Vector3.UP)
	_look(dock_start - dock_dir * 1.5 + across * 5.0 + Vector3.UP * 0.5, dock_start - dock_dir * 1.5)
	await _wait(0.4)
	await _shot("shack_dock_steps_side")


func _pickups() -> void:
	if not _wants("pickup_"):
		return
	for id: String in ["machete", "page_shelter", "page_prosthetics"]:
		var node: Node3D = camp.pickup_nodes.get(id)
		if node == null or not node.visible:
			print("[tour] pickup %s isn't there" % id)
			continue
		var p := node.global_position
		_look(p + Vector3(0.6, 0.7, 0.6), p)
		await _wait(0.5)
		await _shot("pickup_" + id)
	var home := camp.shack_spawn(0)
	var inland := (island.center - Vector2(home.x, home.z)).normalized()
	var bag_at := _ground(Vector2(home.x, home.z) + inland * 8.0) + Vector3.UP * 0.05
	camp.drop_loot(bag_at, [{"id": "stone", "count": 3, "spoils_at": 0.0}], "Tour bag")
	await _wait(0.5)
	_look(bag_at + Vector3(1.0, 1.1, 1.0), bag_at)
	await _wait(0.4)
	await _shot("pickup_bag")


func _wildfire() -> void:
	if not _wants("wildfire"):
		return
	var fire: FireService = world.fire
	var meadow := island.center
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	for attempt in 400:
		var probe: Vector2 = island.center + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(30.0, 190.0)
		if fire.grid.fuel(FireGrid.cell_of(probe)) > 0.75:
			meadow = probe
			break
	world.weather.set_wind(0.0, 7.0)
	fire.ignite_at(Vector3(meadow.x, 0.0, meadow.y))
	# It creeps now: give it time to become a fire front worth looking at.
	await _wait(45.0)
	var at := _ground(meadow)
	for view: Array in [["wildfire_2m", 2.0, 1.6], ["wildfire_15m", 15.0, 4.0], ["wildfire_60m", 60.0, 14.0]]:
		var d: float = view[1]
		var eye := at + Vector3(-d * 0.8, 0.0, d * 0.6)
		eye.y = maxf(world.ground_height(eye.x, eye.z), 0.0) + float(view[2])
		_look(eye, at + Vector3.UP * 0.8)
		await _wait(0.5)
		await _shot(view[0])
	_day(0.95)
	await _wait(1.0)
	var night_eye := at + Vector3(-12.0, 0.0, 9.0)
	night_eye.y = maxf(world.ground_height(night_eye.x, night_eye.z), 0.0) + 3.5
	_look(night_eye, at + Vector3.UP * 0.8)
	await _wait(0.5)
	await _shot("wildfire_night")
	_day(0.45)
	await _wait(30.0)
	_look(at + Vector3(-4.0, 2.2, 3.0), at)
	await _wait(0.5)
	await _shot("wildfire_burnt_ground")
	_look(at + Vector3(-14.0, 18.0, 10.0), at)
	await _wait(0.3)
	await _shot("wildfire_burnt_above")
