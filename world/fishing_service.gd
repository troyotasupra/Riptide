class_name FishingService
extends Node
## Host side of fishing. A crew member's cast lands in the water; the host works
## out what's down there for their bait, the spot, the time of day and the
## weather, when it bites and how hard it fights. The angler plays the fight on
## their own machine and reports how it ended; the host checks the timing and
## hands out the fish (or takes the bait, or the lure).

## peer id -> the cast in progress
var casts := {}
## Fish lying on the bank right now: id -> LandedFish
var landed := {}
## Developer mode and tests: bites come within a second.
var fast_bites := false
var _next_id := 1
var _next_fish := 1

## How close you have to be to reach a fish on the ground.
const REACH := 4.5


@rpc("any_peer", "call_local", "reliable")
func request_cast(pos: Vector3, bait_item: String) -> void:
	if not multiplayer.is_server():
		return
	var peer := _sender()
	var world := GameState.world
	var player := world.players_root.get_node_or_null(str(peer)) as Player
	if player == null or player.survivor == null or player.survivor.downed:
		return
	var s := player.survivor
	if player.held_id != "fishing_rod" and s.selected_id() != "fishing_rod":
		return
	var at := player.world_transform().origin
	if Vector2(at.x, at.z).distance_to(Vector2(pos.x, pos.z)) > FishingMath.MAX_CAST + 4.0:
		return
	var seabed: float = world.ground_height(pos.x, pos.z)
	if seabed != -INF and seabed > -0.5:
		s.notify("That's not deep enough to fish.")
		return
	if not FishTable.BAITS.has(bait_item) or s.inventory.count_of(bait_item) <= 0:
		bait_item = ""
	var depth := 99.0 if seabed == -INF else -seabed
	var near_reef: bool = world.camp_island != null and Vector2(pos.x, pos.z).distance_to(world.camp_island.shipwreck) < CampIsland.REEF_RADIUS
	var spot := FishingMath.spot_of(depth, near_reef)
	var band := FishingMath.time_band(DayNight.clock_hours(GameState.time_of_day()))
	var weather: String = world.weather.to_state if world.weather != null else "clear"
	var odds := FishingMath.weights(spot, FishTable.bait_kind(bait_item), band, weather)
	var species := FishingMath.pick(odds, randf())
	var bite := FishingMath.bite_seconds(odds, randf())
	if fast_bites:
		bite = minf(bite, 1.0)
	var kg := FishingMath.roll_kg(species, randf()) if not species.is_empty() else 0.0
	var pull := FishingMath.strength(species, kg) if not species.is_empty() else 0.0
	var shark_at := -1.0
	if spot == "deep" and randf() < FishingMath.SHARK_CHANCE:
		shark_at = randf_range(2.0, 6.0)
	var id := _next_id
	_next_id += 1
	casts[peer] = {"id": id, "at": Ocean.time, "bite": bite, "species": species, "kg": kg, "bait": bait_item, "spot": spot, "shark_at": shark_at, "pos": pos}
	var speed: float = FishTable.get_species(species).get("speed", 1.0)
	var bite_in := bite if bite != INF else 1.0e6
	if peer == multiplayer.get_unique_id():
		_cast_ack(id, bite_in, pull, speed, shark_at, spot)
	else:
		_cast_ack.rpc_id(peer, id, bite_in, pull, speed, shark_at, spot)


@rpc("authority", "call_remote", "reliable")
func _cast_ack(id: int, bite_in: float, pull: float, speed: float, shark_at: float, spot: String) -> void:
	var player := GameState.local_player as Player
	if player != null and player.angler != null:
		player.angler.on_cast_ack(id, bite_in, pull, speed, shark_at, spot)


## How a fight ended: "landed", "snapped", "cut", "escaped", "missed" or "reeled" (brought in early).
@rpc("any_peer", "call_local", "reliable")
func request_result(id: int, outcome: String) -> void:
	if not multiplayer.is_server():
		return
	var peer := _sender()
	var cast: Dictionary = casts.get(peer, {})
	if cast.is_empty() or int(cast.id) != id:
		return
	casts.erase(peer)
	var world := GameState.world
	var player := world.players_root.get_node_or_null(str(peer)) as Player
	if player == null or player.survivor == null:
		return
	var s := player.survivor
	var bait: String = cast.bait
	var species: String = cast.species
	match outcome:
		"landed":
			var elapsed: float = Ocean.time - float(cast.at)
			var needed := float(cast.bite) + (0.3 if fast_bites else FishingMath.MIN_FIGHT_SECONDS)
			if species.is_empty() or elapsed < needed:
				s.notify("The line comes up empty.")
				return
			_use_bait(s, bait, false)
			var info := FishTable.get_species(species)
			var kg: float = cast.kg
			var shark_took := float(cast.shark_at) >= 0.0 and elapsed >= float(cast.bite) + float(cast.shark_at) and randf() < 0.5
			if shark_took:
				# Only the head comes over the side.
				var head := CampSystems.fresh_stack("cut_bait", 2)
				var spare := s.inventory.add_stack(head)
				if spare > 0:
					var rest := head.duplicate()
					rest.count = spare
					world.camp.drop_items(player, [rest], "%s's catch" % player.display_name)
				s.notify("A shark tore your %s away — all you land is the head. (Cut bait ×2)" % String(info.name).to_lower())
			else:
				# It comes out of the water and lands at your feet, still alive.
				spawn_landed(player, species, kg)
				var best := s.log_catch(species, kg)
				s.notify("A %.1f kg %s is flopping at your feet — kill it, then take it.%s"
					% [kg, String(info.name).to_lower(), "  New personal best!" if best else ""])
			world.sfx_at("splash", cast.pos)
		"snapped", "cut":
			_use_bait(s, bait, true)
			s.notify("The line snapped — the fish is gone%s." % (" and so is your lure" if FishTable.bait_reusable(bait) else "") if outcome == "snapped" else "You cut the line.")
		"escaped", "missed":
			if randf() < 0.5:
				_use_bait(s, bait, false)
			s.notify("It got away." if outcome == "escaped" else "Too slow — it spat the hook.")
		_:
			return
	s.push_inventory()


func forget(peer_id: int) -> void:
	casts.erase(peer_id)


## Host: put a landed fish on the ground just in front of `player`.
func spawn_landed(player: Player, species: String, kg: float) -> void:
	var at := player.world_transform().origin
	var forward := Vector3(-sin(player.yaw), 0.0, -cos(player.yaw))
	var spot := at + forward * 1.3
	spot.y = _footing(spot, at.y)
	var id := "f%d" % _next_fish
	_next_fish += 1
	_add_landed(id, species, kg, spot, player.yaw + PI * 0.5)
	Net.send_to_ready(self, "_add_landed", [id, species, kg, spot, player.yaw + PI * 0.5])


## Whatever the fish comes to rest on: a deck or dock underfoot, else the ground.
func _footing(spot: Vector3, fallback: float) -> float:
	var space := GameState.world.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 2.0, spot + Vector3.DOWN * 3.0, Layers.WORLD | Layers.BOATS)
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		return float(hit.position.y) + 0.12
	var ground: float = GameState.world.ground_height(spot.x, spot.z)
	return (ground + 0.12) if ground != -INF else fallback


## Host: a crew member reaches for a landed fish — the first go kills it, the second takes it.
func interact_landed(s: Survivor, id: String, at: Vector3) -> void:
	var fish: LandedFish = landed.get(id)
	if fish == null or at.distance_to(fish.global_position) > REACH:
		return
	var info := FishTable.get_species(fish.species)
	var fish_name := String(info.get("name", "fish")).to_lower()
	if fish.alive:
		fish.kill()
		Net.send_to_ready(self, "_kill_landed", [id])
		GameState.world.sfx_at("cut", fish.global_position)
		s.notify("You kill the %s." % fish_name)
		return
	var stack := CampSystems.fresh_stack(String(info.get("item", "raw_fish")), 1)
	var left := s.inventory.add_stack(stack)
	if left > 0:
		s.notify("No room in your pack for the %s." % fish_name)
		return
	s.push_inventory()
	s.notify("Took the %.1f kg %s." % [fish.kg, fish_name])
	remove_landed(id)


func remove_landed(id: String) -> void:
	_remove_landed(id)
	Net.send_to_ready(self, "_remove_landed", [id])


## Fish left on the bank tire out, die and eventually spoil away.
func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	for id: String in landed.keys():
		var fish: LandedFish = landed[id]
		if fish == null or not is_instance_valid(fish):
			landed.erase(id)
			continue
		if fish.alive and fish.age > LandedFish.SUFFOCATE_SECONDS:
			fish.kill()
			Net.send_to_ready(self, "_kill_landed", [id])
		elif fish.age > LandedFish.ROT_SECONDS:
			remove_landed(id)


## A joining crew member sees the fish already lying about.
func sync_to(peer_id: int) -> void:
	for id: String in landed:
		var fish: LandedFish = landed[id]
		_add_landed.rpc_id(peer_id, id, fish.species, fish.kg, fish.global_position, fish.rotation.y)
		if not fish.alive:
			_kill_landed.rpc_id(peer_id, id)


@rpc("authority", "call_remote", "reliable")
func _add_landed(id: String, species: String, kg: float, pos: Vector3, yaw: float) -> void:
	if landed.has(id):
		return
	var fish := LandedFish.new()
	fish.setup(id, species, kg, pos, yaw)
	GameState.world.add_child(fish)
	landed[id] = fish


@rpc("authority", "call_remote", "reliable")
func _kill_landed(id: String) -> void:
	var fish: LandedFish = landed.get(id)
	if fish != null and is_instance_valid(fish):
		fish.kill()


@rpc("authority", "call_remote", "reliable")
func _remove_landed(id: String) -> void:
	var fish: LandedFish = landed.get(id)
	landed.erase(id)
	if fish != null and is_instance_valid(fish):
		fish.queue_free()


## Natural bait is used up by a catch; lures and jigs only go when the line does.
static func _use_bait(s: Survivor, bait: String, line_lost: bool) -> void:
	if bait.is_empty():
		return
	if FishTable.bait_reusable(bait) and not line_lost:
		return
	s.inventory.remove(bait, 1)


func _sender() -> int:
	var sender := multiplayer.get_remote_sender_id()
	return sender if sender != 0 else multiplayer.get_unique_id()
