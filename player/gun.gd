class_name Gun
extends Node
## The local crew member's shooting. Left click fires, right click brings the
## sights up, R reloads (or clears a jam), X switches fire mode. Sighted in
## through a variable optic, Z and X turn the power down and up instead. The gun kicks
## your aim up and you ride it back down; sighted in, the sights wander until you
## hold your breath. The host decides what the bullets actually hit.

## How much of each kick comes back on its own — the rest you fight.
const RECOVER_SHARE := 0.72
const RECOVER_RATE := 6.0
## A burst counts as over after this long without a shot.
const BURST_GAP := 0.35
## Holding your breath is worth this many seconds before you have to let go.
const BREATH_SECONDS := WeaponMath.HOLD_BREATH_SECONDS
const BREATH_REFILL := 0.35

var player: Player
## 0 from the hip, 1 fully on the sights.
var aim := 0.0
## Rounds left in the magazine of whatever is in hand, as the host last said.
var reloading := false

var _recovery := Vector2.ZERO
var _reload_left := 0.0
var _reload_seconds := 0.0
var _clearing := false
var _shots := 0
var _since_shot := 99.0
var _breath := 1.0
var _holding_breath := false
var _trigger_held := false
var _time := 0.0
var _base_fov := 0.0
## Each gun's scope power as its owner last set it: uid -> power.
var _powers := {}

## Sights this far up count as looking through them (the lens picture shows).
const SIGHTED := 0.9


func holding_gun() -> bool:
	return player != null and not stack().is_empty()


## The gun in hand right now, straight out of the pack.
func stack() -> Dictionary:
	return CombatService.held_gun(player)


func gun() -> Dictionary:
	return CombatService.gun_stats(stack())


## Takes the shooting controls; true when the event was used.
func handle_input(event: InputEvent) -> bool:
	if not holding_gun() or player.downed or player.swimming:
		return false
	if event.is_action_pressed("primary"):
		_trigger_held = true
		_try_shot()
		return true
	if event.is_action_released("primary"):
		_trigger_held = false
		return true
	if event.is_action_pressed("secondary"):
		return true  # aiming is held, handled in _process
	# Through a variable optic, Z / X turn the power (they don't dismantle or switch mode).
	if aim >= SIGHTED and variable_optic() and (event.is_action_pressed("zoom_in") or event.is_action_pressed("zoom_out")):
		var fitted := gun()
		var now := magnification()
		var next := WeaponMath.step_zoom(now, 1 if event.is_action_pressed("zoom_in") else -1, float(fitted.zoom_min), float(fitted.zoom))
		_powers[int(stack().get("uid", 0))] = next
		if next != now:
			Sound.play("click", -16.0)
		return true
	if aim >= SIGHTED and variable_optic() and (event.is_action("zoom_in") or event.is_action("zoom_out")):
		return true
	if event.is_action_pressed("rotate"):
		_request_reload()
		return true
	if event.is_action_pressed("fire_mode"):
		GameState.world.combat.rpc_id(1, "request_fire_mode")
		Sound.play("click", -12.0)
		return true
	return false


func _process(delta: float) -> void:
	if player == null:
		return
	_time += delta
	_since_shot += delta
	if _since_shot > BURST_GAP:
		_shots = 0
	_recover(delta)
	if _reload_left > 0.0:
		_reload_left = maxf(0.0, _reload_left - delta)
		reloading = _reload_left > 0.0
	if not holding_gun():
		_reset()
		return
	var fitted := gun()
	var active := player._controls_active() and not player.downed and not player.swimming
	var wanting := active and Input.is_action_pressed("secondary")
	var speed := WeaponMath.ads_seconds(fitted, player.carried_weight_kg)
	aim = move_toward(aim, 1.0 if wanting else 0.0, delta / maxf(0.05, speed))
	_holding_breath = wanting and active and Input.is_action_pressed("sprint") and _breath > 0.0
	if _holding_breath:
		_breath = maxf(0.0, _breath - delta / BREATH_SECONDS)
	else:
		_breath = minf(1.0, _breath + delta * BREATH_REFILL)
	_update_sights(fitted, delta)
	if _trigger_held and String(stack().get("mode", "semi")) == "auto":
		_try_shot()


## The sights wander, and a scope pulls the world in.
func _update_sights(fitted: Dictionary, _delta: float) -> void:
	var winded := clampf(1.0 - player.stamina / Player.STAMINA_MAX, 0.0, 1.0)
	var hold := 1.0 if _holding_breath else 0.0
	var wander := WeaponMath.sway_at(fitted, _time, aim, hold, winded)
	player.aim_offset = Vector2(deg_to_rad(wander.x), deg_to_rad(wander.y))
	if _base_fov <= 0.0:
		_base_fov = Settings.fov
	# Bringing the sights up narrows the view only a touch, as your eye focuses
	# down the gun; a scope's magnification is in the lens picture (ScopeView),
	# at the power it's set to, never zoomed in as you raise it.
	player.aim_fov = lerpf(Settings.fov, Settings.fov * 0.88, aim)


## The optic's power right now (1 without a magnifying optic).
func magnification() -> float:
	var fitted := gun()
	var high := float(fitted.get("zoom", 1.0))
	if high <= 1.0:
		return 1.0
	var low := float(fitted.get("zoom_min", high))
	var uid := int(stack().get("uid", 0))
	if not _powers.has(uid):
		# A fresh scope starts in the middle of its range.
		_powers[uid] = WeaponMath.step_zoom((low + high) * 0.5, 0, low, high)
	return clampf(float(_powers[uid]), low, high)


func variable_optic() -> bool:
	var fitted := gun()
	return float(fitted.get("zoom", 1.0)) > float(fitted.get("zoom_min", fitted.get("zoom", 1.0))) + 0.01


## The power the lens picture shows now: the set power once sighted in, else none.
func sight_picture() -> float:
	return magnification() if holding_gun() and aim >= SIGHTED else 1.0


func _try_shot() -> void:
	if not holding_gun() or reloading:
		return
	var held := stack()
	var fitted := gun()
	if not player._controls_active() or player.downed or player.swimming:
		return
	if _since_shot < float(fitted.interval):
		return
	if bool(held.get("jammed", false)):
		Sound.play("click", -6.0)
		_since_shot = 0.0
		return
	if int(held.get("ammo", 0)) <= 0:
		Sound.play("click", -6.0)
		_since_shot = 0.0
		return
	_since_shot = 0.0
	var direction := -player.camera.global_basis.z
	GameState.world.combat.rpc_id(1, "request_shot", direction, aim)
	# Kick now rather than waiting on the host, so it feels like your own gun.
	var kick := WeaponMath.recoil_kick(fitted, _shots, randf())
	_shots += 1
	_kick(kick * lerpf(1.0, 0.75, aim))
	player.view_model.recoil(0.4 + 0.5 * clampf(float(fitted.recoil_up) / 4.0, 0.0, 1.0))


func _kick(amount: Vector2) -> void:
	player.pitch = clampf(player.pitch + deg_to_rad(amount.y), -1.5, 1.5)
	player.yaw = wrapf(player.yaw + deg_to_rad(amount.x), -PI, PI)
	_recovery += amount * RECOVER_SHARE


func _recover(delta: float) -> void:
	if _recovery.length() < 0.0005 or player == null:
		return
	var give := _recovery * (1.0 - exp(-RECOVER_RATE * delta))
	player.pitch = clampf(player.pitch - deg_to_rad(give.y), -1.5, 1.5)
	player.yaw = wrapf(player.yaw - deg_to_rad(give.x), -PI, PI)
	_recovery -= give


func _request_reload() -> void:
	if reloading:
		return
	GameState.world.combat.rpc_id(1, "request_reload")


## The host tells us a reload (or clearing a jam) has started.
func on_reload_started(seconds: float, clearing: bool) -> void:
	_reload_left = seconds
	_reload_seconds = maxf(0.01, seconds)
	reloading = true
	_clearing = clearing
	Sound.play("cloth" if not clearing else "latch", -8.0)


func _reset() -> void:
	aim = 0.0
	_trigger_held = false
	_holding_breath = false
	if player != null:
		player.aim_offset = Vector2.ZERO
		player.aim_fov = 0.0


## How far through the reload (0..1), or -1 when not reloading.
func reload_progress() -> float:
	return 1.0 - _reload_left / _reload_seconds if reloading and _reload_seconds > 0.0 else -1.0


func clearing_jam() -> bool:
	return reloading and _clearing


## What the HUD shows about the gun in hand ("" when you aren't holding one).
func hud_text() -> String:
	if not holding_gun():
		return ""
	var state := CombatService.gun_state(stack())
	if state.is_empty():
		return ""
	if reloading:
		return "%s   %s…" % [state.name, "clearing the jam" if _clearing else "reloading"]
	if bool(state.jammed):
		return "%s   JAMMED — %s to clear" % [state.name, Controls.tag("rotate")]
	var line := "%s   %d / %d   %s" % [state.name, int(state.ammo), int(state.mag), CombatService._mode_name(String(state.mode))]
	if magnification() > 1.0:
		line += "   ·   %s×" % String.num(magnification(), 1).trim_suffix(".0")
		if aim >= SIGHTED and variable_optic():
			line += " (%s / %s)" % [Controls.tag("zoom_out"), Controls.tag("zoom_in")]
	if float(state.condition) < WeaponTable.CONDITION_NEGLECTED:
		line += "   ·   fouled, clean it"
	if _holding_breath:
		line += "   ·   holding breath"
	return line
