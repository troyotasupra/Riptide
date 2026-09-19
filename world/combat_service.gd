class_name CombatService
extends Node
## Host side of shooting. The host decides whether a shot happens, what it costs
## and what it hits: bullets are real, so each one leaves the muzzle, takes time
## to arrive and falls on the way, and the host walks every one through the
## world. Everyone else sees the flash, the tracer and the splash.

## More bullets than this in the air at once and the oldest stop being tracked.
## Share of a bullet's damage a structure takes.
const STRUCTURE_DAMAGE := 0.3
const MAX_BULLETS := 200
## A shot is allowed a hair early, to be kind about the shooter's lag.
const RATE_SLACK := 0.85
const CLEAR_JAM_SECONDS := 1.4
## How far a tracer is drawn each frame on the peers watching.
const TRACER_LENGTH := 14.0

## peer -> the clock time of their last shot
var _last_shot := {}
## peer -> {"until", "uid", "empty", "jam"}
var _reloading := {}
var _bullets: Array[Dictionary] = []


# --- what a crew member is holding -------------------------------------------------

## The gun in `player`'s hand, or an empty dictionary. The real stack, so writing
## to it changes what they're carrying.
static func held_gun(player: Player) -> Dictionary:
	if player == null or player.survivor == null:
		return {}
	var stack = player.survivor.inventory.hotbar[player.survivor.selected_slot]
	if stack == null or not ItemTable.get_item(String(stack.id)).has("weapon"):
		return {}
	return stack


## Everything about how that gun handles, attachments included.
static func gun_stats(stack: Dictionary) -> Dictionary:
	if stack.is_empty():
		return {}
	var weapon: String = ItemTable.get_item(String(stack.id)).get("weapon", "")
	return WeaponMath.stats(weapon, stack.get("attachments", {}))


## Rounds in the magazine, how many it holds, the fire mode and its condition —
## for the shooter's own HUD.
static func gun_state(stack: Dictionary) -> Dictionary:
	var gun := gun_stats(stack)
	if gun.is_empty():
		return {}
	return {
		"name": gun.name, "ammo": int(stack.get("ammo", 0)), "mag": int(gun.mag),
		"mode": String(stack.get("mode", gun.modes[0])), "condition": float(stack.get("condition", 1.0)),
		"jammed": bool(stack.get("jammed", false)), "round": String(gun.ammo),
	}


# --- shooting ----------------------------------------------------------------------

## A crew member pulls the trigger, looking along `direction` with the sights
## `aim` of the way up (0 from the hip, 1 fully aimed).
@rpc("any_peer", "call_local", "reliable")
func request_shot(direction: Vector3, aim: float) -> void:
	if not multiplayer.is_server():
		return
	var peer := _sender()
	var player := _player(peer)
	if player == null or player.survivor == null or player.survivor.downed:
		return
	var s := player.survivor
	var stack := held_gun(player)
	if stack.is_empty():
		return
	var gun := gun_stats(stack)
	var now: float = Ocean.time
	if _reloading.has(peer) or now - float(_last_shot.get(peer, -99.0)) < float(gun.interval) * RATE_SLACK:
		return
	if bool(stack.get("jammed", false)):
		s.notify("It's jammed — hold R to clear it.")
		return
	if int(stack.get("ammo", 0)) <= 0:
		s.notify("Empty. R to reload.")
		_tell(peer, "_dry_click", [])
		return
	_last_shot[peer] = now
	stack["ammo"] = int(stack.ammo) - 1
	stack["condition"] = WeaponMath.wear_from_shot(gun, float(stack.get("condition", 1.0)))
	if randf() < WeaponMath.jam_chance(float(stack.condition)):
		stack["jammed"] = true
		s.notify("The action jams — hold R to clear it.")
		s.push_inventory()
		return

	# From where the crew member is actually looking: a lean moves the eye sideways.
	var eye := player.world_transform().origin + Vector3.UP * Player.EYE_HEIGHT + player.lean_offset()
	var look := direction.normalized()
	if look.length() < 0.5:
		look = Vector3.FORWARD
	var muzzle := eye + look * 0.45
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	var winded := clampf(1.0 - player.stamina / Player.STAMINA_MAX, 0.0, 1.0)
	var spread := WeaponMath.spread(gun, clampf(aim, 0.0, 1.0), speed, player.crouching, winded)
	var aimed := Ballistics.aim_direction(look, float(gun.velocity), WeaponTable.ZERO_DISTANCE)
	for i in int(gun.pellets):
		var shot := Ballistics.scatter(aimed, spread, randf(), randf())
		_bullets.append({
			"position": muzzle, "velocity": shot * float(gun.velocity), "damage": float(gun.damage),
			"shooter": peer, "life": 0.0, "range": 0.0,
		})
	while _bullets.size() > MAX_BULLETS:
		_bullets.pop_front()
	var quiet := float(gun.quiet)
	_report_shot(muzzle, look, String(gun.id), quiet, peer)
	Net.send_to_ready(self, "_report_shot", [muzzle, look, String(gun.id), quiet, peer])
	s.push_inventory()


## Reload, or clear a jam — the same key does both.
@rpc("any_peer", "call_local", "reliable")
func request_reload() -> void:
	if not multiplayer.is_server():
		return
	var peer := _sender()
	var player := _player(peer)
	if player == null or player.survivor == null or _reloading.has(peer):
		return
	var s := player.survivor
	var stack := held_gun(player)
	if stack.is_empty():
		return
	var gun := gun_stats(stack)
	var now: float = Ocean.time
	if bool(stack.get("jammed", false)):
		_reloading[peer] = {"until": now + CLEAR_JAM_SECONDS, "uid": int(stack.get("uid", 0)), "jam": true, "empty": false}
		_tell(peer, "_reload_started", [CLEAR_JAM_SECONDS, true])
		return
	var in_mag := int(stack.get("ammo", 0))
	if in_mag >= int(gun.mag):
		return
	if s.inventory.count_of(String(gun.ammo)) <= 0:
		s.notify("No %s left." % ItemTable.display_name(String(gun.ammo)).to_lower())
		return
	var empty := in_mag <= 0
	var seconds := WeaponMath.reload_seconds(gun, empty)
	_reloading[peer] = {"until": now + seconds, "uid": int(stack.get("uid", 0)), "jam": false, "empty": empty}
	_tell(peer, "_reload_started", [seconds, false])


## Switch between the fire modes a gun has.
@rpc("any_peer", "call_local", "reliable")
func request_fire_mode() -> void:
	if not multiplayer.is_server():
		return
	var player := _player(_sender())
	var stack := held_gun(player)
	if stack.is_empty():
		return
	var gun := gun_stats(stack)
	var mode := WeaponMath.next_mode(gun, String(stack.get("mode", gun.modes[0])))
	stack["mode"] = mode
	player.survivor.notify("%s — %s" % [gun.name, _mode_name(mode)])
	player.survivor.push_inventory()


## Fit an attachment from the pack onto the gun in hand (or take one off, when
## `attachment_uid` is 0 and `slot` says which).
@rpc("any_peer", "call_local", "reliable")
func request_fit(slot: String, attachment_uid: int) -> void:
	if not multiplayer.is_server():
		return
	var player := _player(_sender())
	var stack := held_gun(player)
	if stack.is_empty():
		return
	var s := player.survivor
	var weapon: String = ItemTable.get_item(String(stack.id)).get("weapon", "")
	var fitted: Dictionary = Dictionary(stack.get("attachments", {})).duplicate()
	if attachment_uid == 0:
		var taken := String(fitted.get(slot, ""))
		if taken.is_empty():
			return
		fitted.erase(slot)
		stack["attachments"] = fitted
		if s.inventory.add(taken, 1, Ocean.time) > 0:
			GameState.world.camp.drop_items(player, [CampSystems.fresh_stack(taken, 1)], "%s's kit" % player.display_name)
		s.notify("Took the %s off." % ItemTable.display_name(taken).to_lower())
		s.push_inventory()
		return
	var attachment := s.inventory.get_stack(attachment_uid)
	if attachment.is_empty():
		return
	var id := String(attachment.get("id", ""))
	var kind := String(ItemTable.get_item(id).get("attachment", ""))
	if kind.is_empty() or not AttachmentTable.fits(weapon, kind):
		s.notify("That doesn't fit this gun.")
		return
	var replacing := String(fitted.get(AttachmentTable.get_attachment(kind).slot, ""))
	fitted[AttachmentTable.get_attachment(kind).slot] = kind
	stack["attachments"] = fitted
	s.inventory.take(attachment_uid, 1)
	if not replacing.is_empty():
		s.inventory.add(replacing, 1, Ocean.time)
	stack["ammo"] = mini(int(stack.get("ammo", 0)), int(gun_stats(stack).mag))
	s.notify("Fitted the %s." % ItemTable.display_name(id).to_lower())
	s.push_inventory()


## Clean the gun in hand with a cleaning kit from the pack.
@rpc("any_peer", "call_local", "reliable")
func request_clean() -> void:
	if not multiplayer.is_server():
		return
	var player := _player(_sender())
	var stack := held_gun(player)
	if stack.is_empty():
		return
	var s := player.survivor
	var kit := s.inventory.find_first("cleaning_kit")
	if kit.is_empty():
		s.notify("You need a cleaning kit.")
		return
	if float(stack.get("condition", 1.0)) > 0.98:
		s.notify("It's already clean.")
		return
	stack["condition"] = WeaponTable.CLEANED_CONDITION
	kit["uses"] = int(kit.get("uses", 1)) - 1
	if int(kit.uses) <= 0:
		s.inventory.take(int(kit.uid))
		s.notify("Cleaned — and the kit is used up.")
	else:
		s.notify("Cleaned and oiled.")
	s.push_inventory()


func forget(peer_id: int) -> void:
	_last_shot.erase(peer_id)
	_reloading.erase(peer_id)


# --- the host's world ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_finish_reloads()
	_step_bullets(delta)


func _finish_reloads() -> void:
	var now: float = Ocean.time
	for peer: int in _reloading.keys():
		var job: Dictionary = _reloading[peer]
		if now < float(job.until):
			continue
		_reloading.erase(peer)
		var player := _player(peer)
		if player == null or player.survivor == null:
			continue
		var s := player.survivor
		var stack := s.inventory.get_stack(int(job.uid))
		if stack.is_empty():
			stack = held_gun(player)
		if stack.is_empty():
			continue
		if bool(job.get("jam", false)):
			stack["jammed"] = false
			s.notify("Cleared.")
			s.push_inventory()
			continue
		var gun := gun_stats(stack)
		var wanted := int(gun.mag) - int(stack.get("ammo", 0))
		# A round stays chambered on guns that keep one, so a topped-up magazine is one more.
		if bool(gun.chamber) and int(stack.get("ammo", 0)) > 0:
			wanted = mini(wanted + 1, int(gun.mag) + 1 - int(stack.get("ammo", 0)))
		var have := s.inventory.count_of(String(gun.ammo))
		var loaded := mini(wanted, have)
		if loaded <= 0:
			continue
		s.inventory.remove(String(gun.ammo), loaded)
		stack["ammo"] = int(stack.get("ammo", 0)) + loaded
		s.push_inventory()
		GameState.world.sfx_at("latch", player.world_transform().origin)


func _step_bullets(delta: float) -> void:
	if _bullets.is_empty():
		return
	var space := GameState.world.get_world_3d().direct_space_state
	var still_flying: Array[Dictionary] = []
	for bullet: Dictionary in _bullets:
		var next: Array = Ballistics.step(bullet.position, bullet.velocity, delta)
		var to: Vector3 = next[0]
		var travelled: float = (to - Vector3(bullet.position)).length()
		bullet.life = float(bullet.life) + delta
		bullet.range = float(bullet.range) + travelled
		var query := PhysicsRayQueryParameters3D.create(bullet.position, to,
			Layers.WORLD | Layers.BOATS | Layers.INTERACT)
		var hit := space.intersect_ray(query)
		# Crew are checked by hand: aboard a boat their physics body is on a
		# deck proxy miles below, nowhere near where they're drawn.
		var person := _first_person_hit(bullet, to)
		if not person.is_empty() and (hit.is_empty() or Vector3(bullet.position).distance_to(person.at) <= Vector3(bullet.position).distance_to(hit.position)):
			_hit_person(person, bullet)
			continue
		if not hit.is_empty():
			_hit_something(hit, bullet)
			continue
		var surface := Waves.height_at(Vector2(to.x, to.z), Ocean.time)
		if to.y < surface and Vector3(bullet.position).y >= surface:
			_splash(Vector3(to.x, surface, to.z))
			continue
		bullet.position = to
		bullet.velocity = next[1]
		if float(bullet.life) < Ballistics.MAX_FLIGHT and float(bullet.range) < Ballistics.MAX_RANGE:
			still_flying.append(bullet)
	_bullets = still_flying


## The nearest crew member this leg of the flight passes through, if any.
func _first_person_hit(bullet: Dictionary, to: Vector3) -> Dictionary:
	var world := GameState.world
	if world == null:
		return {}
	var from: Vector3 = bullet.position
	var best := {}
	var best_distance := INF
	for player: Player in world.players_root.get_children():
		if player.peer_id == int(bullet.shooter) or player.survivor == null or player.survivor.god:
			continue
		var feet := player.world_transform().origin
		var height := HitMath.CROUCH_HEIGHT if player.crouching or player.downed else HitMath.STANDING_HEIGHT
		var along := HitMath.along_segment(from, to, feet, height)
		if along < 0.0 or along >= best_distance:
			continue
		best_distance = along
		best = {"player": player, "at": from + (to - from).normalized() * along, "feet": feet, "height": height}
	return best


## Host: a round goes into a crew member (or is waved through by the rules).
func _hit_person(person: Dictionary, bullet: Dictionary) -> void:
	var world := GameState.world
	var player: Player = person.player
	var at: Vector3 = person.at
	_impact(at, "flesh")
	Net.send_to_ready(self, "_impact", [at, "flesh"])
	world.sfx_at("hit", at)
	if not GameState.friendly_fire:
		var shooter := _player(int(bullet.shooter))
		if shooter != null and shooter.survivor != null:
			shooter.survivor.notify("That round went into %s. (Friendly fire is off.)" % player.display_name)
		return
	var s := player.survivor
	var damage := HitMath.damage_for(float(bullet.damage), at.y, float(person.feet.y), float(person.height))
	s.survival.take_damage(damage)
	s.notify("You're hit!")
	s.push_survival()


func _hit_something(hit: Dictionary, bullet: Dictionary) -> void:
	var world := GameState.world
	var at: Vector3 = hit.position
	var collider: Object = hit.collider
	var damage: float = bullet.damage
	var target := collider as Interactable
	if target != null:
		var id: String = target.interact_id
		if id.begins_with("shark:") and world.sharks != null:
			var shark: Shark = world.sharks.sharks.get(id.substr(6))
			if shark != null and shark.state != "dead":
				shark.hit(damage, at)
				world.sfx_at("hit", at)
				_impact(at, "flesh")
				Net.send_to_ready(self, "_impact", [at, "flesh"])
				var shooter := _player(int(bullet.shooter))
				if shooter != null and shooter.survivor != null and shark.state == "dead":
					shooter.survivor.notify("The shark goes still.")
				return
		if id.begins_with("struct:") and world.camp != null:
			# Bullets chew through canvas and planks, slowly.
			world.camp.damage_structure(id.substr(7), damage * STRUCTURE_DAMAGE, "shot")
		if id.begins_with("fish:") and world.fishing != null:
			var fish: LandedFish = world.fishing.landed.get(id.substr(5))
			if fish != null and fish.alive:
				fish.kill()
				Net.send_to_ready(world.fishing, "_kill_landed", [fish.fish_id])
				world.sfx_at("hit", at)
			_impact(at, "flesh")
			Net.send_to_ready(self, "_impact", [at, "flesh"])
			return
	_impact(at, "dirt")
	Net.send_to_ready(self, "_impact", [at, "dirt"])


func _splash(at: Vector3) -> void:
	_impact(at, "water")
	Net.send_to_ready(self, "_impact", [at, "water"])


# --- what everyone sees and hears ---------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _report_shot(muzzle: Vector3, direction: Vector3, weapon_id: String, quiet: float, shooter: int = 0) -> void:
	# The bullet leaves from the eye line, but what you see comes out of the gun:
	# your own view-model muzzle, or the muzzle of the gun in a crewmate's hands.
	var shown := _visible_muzzle(shooter)
	if shown != Vector3.INF:
		muzzle = shown
	if WeaponTable.WEAPONS.get(weapon_id, {}).get("kind", "") == "bow":
		# A bow: the thrum of the string and an arrow you can watch fly. No flash.
		Sound.play_shot("bow", muzzle, 0.0)
		ArrowFlight.launch(muzzle, direction.normalized() * float(WeaponTable.WEAPONS[weapon_id].velocity))
		return
	Sound.play_shot(weapon_id, muzzle, quiet)
	# Anyone the round goes past hears it crack by, ahead of the report.
	if shooter != multiplayer.get_unique_id():
		Sound.play_passby(muzzle, direction.normalized(), float(WeaponTable.WEAPONS.get(weapon_id, {}).get("velocity", 0.0)), quiet)
	Effects.tracer(muzzle, muzzle + direction.normalized() * TRACER_LENGTH)
	Effects.muzzle_flash(muzzle, direction.normalized(), 1.0 - clampf(quiet, 0.0, 0.8))


func _visible_muzzle(shooter: int) -> Vector3:
	var player := _player(shooter) if shooter != 0 and GameState.world != null else null
	if player == null:
		return Vector3.INF
	if player == GameState.local_player and player.view_model != null:
		return player.view_model.muzzle_point()
	if player.model != null:
		return player.model.held_muzzle()
	return Vector3.INF


@rpc("authority", "call_remote", "reliable")
func _impact(at: Vector3, kind: String) -> void:
	Effects.impact(at, kind)
	if kind == "water":
		Sound.play_at("splash", at, -12.0)
	elif kind == "dirt":
		Sound.play_at("stone", at, -8.0)


@rpc("authority", "call_remote", "reliable")
func _dry_click() -> void:
	Sound.play("click", -6.0)


@rpc("authority", "call_remote", "reliable")
func _reload_started(seconds: float, clearing: bool) -> void:
	var player := GameState.local_player as Player
	if player != null and player.gun != null:
		player.gun.on_reload_started(seconds, clearing)


static func _mode_name(mode: String) -> String:
	return {"auto": "automatic", "semi": "semi-automatic", "bolt": "bolt action", "pump": "pump action", "single": "one arrow"}.get(mode, mode)


func _tell(peer: int, method: String, args: Array) -> void:
	if peer == multiplayer.get_unique_id():
		callv(method, args)
	else:
		callv("rpc_id", [peer, method] + args)


func _player(peer: int) -> Player:
	return GameState.world.players_root.get_node_or_null(str(peer)) as Player


func _sender() -> int:
	var sender := multiplayer.get_remote_sender_id()
	return sender if sender != 0 else multiplayer.get_unique_id()
