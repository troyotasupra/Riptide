class_name DevTools
extends Node
## Developer mode: god mode, spawning items, time of day, weather and wind,
## teleports, sharks, rafts and quick fishing. The host turns it on (menu
## checkbox or --dev); crew members may use it only while the host allows.
## Flying is the player's own (V, or the F1 panel).

const PLACES := {
	"starter": "Starter beach", "shack": "Fishing shack", "castaway_camp": "Castaway camp",
	"reef": "Wreck reef", "crossing": "Open sea",
}
const FISHING_KIT := [["fishing_rod", 1], ["grub", 20], ["cut_bait", 20], ["berries", 10], ["lure", 3], ["jig", 3]]
const GUN_KIT := [["m1911", 1], ["uzi", 1], ["m4", 1], ["mossberg", 1], ["intervention", 1],
	["ammo_45", 50], ["ammo_9mm", 60], ["ammo_556", 60], ["ammo_12ga", 30], ["ammo_408", 20], ["cleaning_kit", 1]]
const ATTACHMENT_KIT := [["red_dot", 1], ["holo_sight", 1], ["prism_3x", 1], ["lpvo_6x", 1], ["sniper_scope", 1],
	["suppressor", 1], ["compensator", 1], ["muzzle_brake", 1], ["vertical_grip", 1], ["angled_grip", 1],
	["bipod", 1], ["extended_mag", 1], ["quickdraw_mag", 1], ["heavy_stock", 1], ["light_stock", 1],
	["folding_stock", 1], ["laser", 1], ["flashlight", 1]]
const RAFT_KIT := [["stone_hatchet", 1], ["oar", 1], ["fiber", 30], ["flint", 4], ["driftwood", 8], ["log", 8], ["rope", 8]]


@rpc("authority", "call_remote", "reliable")
func _set_allowed(value: bool) -> void:
	GameState.dev_mode = value


@rpc("any_peer", "call_local", "reliable")
func request(command: String, args: Array) -> void:
	if not multiplayer.is_server() or not GameState.dev_mode:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	var world := GameState.world
	var player := world.players_root.get_node_or_null(str(sender)) as Player
	if player == null or player.survivor == null:
		return
	var s := player.survivor
	var at := player.world_transform().origin
	match command:
		"give":
			var id: String = args[0] if args.size() > 0 else ""
			if ItemTable.exists(id):
				var count: int = clampi(int(args[1]) if args.size() > 1 else 1, 1, 999)
				_give(player, [[id, count]])
				s.notify("Dev: +%d %s" % [count, ItemTable.display_name(id)])
		"fishing_kit":
			_give(player, FISHING_KIT)
			s.notify("Dev: fishing kit")
		"raft_kit":
			_give(player, RAFT_KIT)
			s.notify("Dev: raft materials")
		"clear_pack":
			s.inventory.clear()
			s.push_inventory()
		"time":
			var t := clampf(float(args[0]), 0.0, 1.0)
			GameState.day_offset += fposmod(t - GameState.time_of_day(), 1.0)
			Net.send_to_ready(world.camp, "_set_day_offset", [GameState.day_offset])
		"weather":
			world.weather.set_state(String(args[0]), args.size() > 1 and bool(args[1]))
			s.notify("Dev: weather → %s" % args[0])
		"wind":
			world.weather.set_wind(float(args[0]), float(args[1]))
		"teleport":
			var place := _place(String(args[0]))
			if place != Vector3.INF:
				player.teleport(place)
		"friendly_fire":
			GameState.world.set_friendly_fire(bool(args[0]))
			for other: Player in GameState.world.players_root.get_children():
				other.survivor.notify("Friendly fire is %s." % ("ON — watch your muzzle" if GameState.friendly_fire else "off"))
		"god":
			s.god = bool(args[0])
			s.notify("Dev: god mode %s" % ("on" if s.god else "off"))
		"heal":
			s.survival.health = Survival.MAX
			s.survival.hunger = Survival.MAX
			s.survival.thirst = Survival.MAX
			s.survival.sickness = 0.0
			s.survival.body_temp = Survival.NORMAL_TEMP
			s.wetness = 0.0
			if s.downed:
				s.bleed_out = 0.0
				world._set_downed_state(player, false)
			s.push_survival()
		"learn_all":
			world.camp.learn(RecipeTable.RECIPES.keys(), s)
		"shark":
			var forward := Vector3(-sin(player.yaw), 0.0, -cos(player.yaw))
			world.sharks.spawn(Vector3(at.x, -2.0, at.z) + forward * 10.0, Vector3(at.x, 0.0, at.z), 14.0)
		"fire":
			# Light the ground a few metres ahead; it spreads from there on its own.
			var ahead := at + Vector3(-sin(player.yaw), 0.0, -cos(player.yaw)) * 6.0
			if world.fire.ignite_at(ahead):
				s.notify("Dev: fire started ahead of you")
			else:
				s.notify("Dev: nothing there will burn — face grass or brush")
		"put_out":
			for cell: Vector2i in world.fire.grid.burning.keys():
				world.fire.grid.burning[cell] = 0.01
			s.notify("Dev: fires out")
		"kill_sharks":
			for shark: Shark in world.sharks.sharks.values():
				shark.hit(9999.0, at)
		"raft":
			var forward := Vector3(-sin(player.yaw), 0.0, -cos(player.yaw))
			var spot := at + forward * 4.0
			world.launch_boat("raft", Transform3D(Basis(Vector3.UP, player.yaw), Vector3(spot.x, 0.4, spot.z)))
		"fast_bites":
			world.fishing.fast_bites = bool(args[0])
			s.notify("Dev: fast bites %s" % ("on" if world.fishing.fast_bites else "off"))


func _give(player: Player, entries: Array) -> void:
	var s := player.survivor
	var dropped: Array = []
	for entry: Array in entries:
		var stack := CampSystems.fresh_stack(entry[0], entry[1])
		var left := s.inventory.add_stack(stack)
		if left > 0:
			var rest := stack.duplicate()
			rest.count = left
			dropped.append(rest)
	if not dropped.is_empty():
		GameState.world.camp.drop_items(player, dropped, "Dev spawn")
	s.push_inventory()


func _place(place: String) -> Vector3:
	var world := GameState.world
	var island: CampIsland = world.camp_island
	match place:
		"starter":
			return world.start_beach_point(0)
		"shack":
			return world.camp.shack_spawn(0)
		"castaway_camp":
			return Vector3(island.camp.x, island.height_at(island.camp.x, island.camp.y) + 1.5, island.camp.y + 3.0)
		"reef":
			return Vector3(island.shipwreck.x, 0.5, island.shipwreck.y) + Vector3(8.0, 0.0, 0.0)
		"crossing":
			var p: Vector2 = island.center * 0.45
			return Vector3(p.x, 0.5, p.y)
	return Vector3.INF
