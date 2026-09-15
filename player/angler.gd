class_name Angler
extends Node
## The local crew member's fishing. With the rod selected: hold left click to
## charge a cast and release to throw; watch the bobber, and when it dips, left
## click to strike. Then play the fish — hold to reel, ease off when it pulls
## before the line snaps, don't give it so much slack it throws the hook. Right
## click picks the bait. In deep water a shark may take the fish on your line:
## hold on, or cut the line (F). The host decides what bites and what you land.

enum State { IDLE, CHARGING, FLYING, WAITING, BITE, FIGHT }

const FLY_SECONDS := 0.6

var player: Player
var state := State.IDLE
## The bait on the hook ("" = a bare hook).
var bait_item := ""
var charge := 0.0

var _cast_id := 0
var _bite_in := INF
var _pull := 0.3
var _speed := 1.0
var _shark_at := -1.0
var _spot := ""
var _fight := {}
var _fight_time := 0.0
var _bite_timer := 0.0
var _fly_t := 0.0
var _fly_from := Vector3.ZERO
var _target := Vector3.ZERO
var _in_water := false
var _bobber: Node3D
var _line: MeshInstance3D


func _ready() -> void:
	_bobber = Node3D.new()
	add_child(_bobber)
	# Big and bright enough to watch for a dip at full casting distance.
	for part: Array in [[Color(1.0, 0.18, 0.08), 0.03], [Color(0.97, 0.97, 0.94), -0.03]]:
		var ball := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.085
		sphere.height = 0.1
		ball.mesh = sphere
		ball.material_override = Materials.plain(part[0], 0.4)
		ball.position.y = part[1]
		_bobber.add_child(ball)
	_line = MeshInstance3D.new()
	_line.mesh = Boat._unit_rope()
	_line.material_override = Materials.plain(Color(0.92, 0.92, 0.88), 0.5)
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_line)
	_bobber.visible = false
	_line.visible = false


func holding_rod() -> bool:
	return player != null and player.held_id == "fishing_rod"


## Takes the fishing controls; true when the event was used.
func handle_input(event: InputEvent) -> bool:
	if not holding_rod():
		return false
	if event.is_action_pressed("secondary") and state == State.IDLE:
		_cycle_bait()
		return true
	if event.is_action_pressed("paddle") and state == State.FIGHT:
		_finish("cut")
		return true
	if event.is_action_pressed("primary"):
		match state:
			State.IDLE:
				state = State.CHARGING
				charge = 0.0
			State.WAITING:
				_finish("reeled")
			State.BITE:
				_hook()
		return true
	if event.is_action_released("primary"):
		if state == State.CHARGING:
			_cast()
		return true
	return false


func _process(delta: float) -> void:
	if player == null:
		return
	if state != State.IDLE and (not holding_rod() or player.downed or player.flying):
		_finish("reeled")
	if not bait_item.is_empty() and player.survivor.inventory.count_of(bait_item) <= 0:
		bait_item = ""
	var t := Time.get_ticks_msec() * 0.001
	match state:
		State.CHARGING:
			charge = minf(1.0, charge + delta / FishingMath.CHARGE_SECONDS)
		State.FLYING:
			_fly_t = minf(1.0, _fly_t + delta / FLY_SECONDS)
			var p := _fly_from.lerp(_target, _fly_t)
			p.y += sin(_fly_t * PI) * (1.5 + _fly_from.distance_to(_target) * 0.15)
			_bobber.global_position = p
			if _fly_t >= 1.0:
				_land()
		State.WAITING:
			_bite_in -= delta
			_bobber.global_position = _surface(_target) + Vector3.UP * sin(t * 2.2) * 0.02
			if _bite_in <= 0.0:
				state = State.BITE
				_bite_timer = FishingMath.HOOK_WINDOW
				Sound.play("splash", -4.0)
		State.BITE:
			_bite_timer -= delta
			_bobber.global_position = _surface(_target) - Vector3.UP * (0.08 + 0.08 * sin(t * 30.0))
			if _bite_timer <= 0.0:
				_finish("missed")
		State.FIGHT:
			_play_fish(delta, t)
	_update_line()


func _play_fish(delta: float, t: float) -> void:
	_fight_time += delta
	if _shark_at >= 0.0 and not _fight.shark and _fight_time >= _shark_at:
		_fight.shark = true
		Sound.play("hit", -4.0)
		player.survivor.notified.emit("A shark's on your fish! Hold on — or cut the line (%s)." % Controls.tag("paddle"))
	var reeling := Input.is_action_pressed("primary") and player._controls_active()
	var result := FishingMath.step(_fight, reeling, delta, FishingMath.surge_at(_fight_time, _speed), _pull)
	var tip := _rod_tip()
	var flat := Vector3(tip.x, 0.0, tip.z)
	var toward := Vector3(_target.x, 0.0, _target.z) - flat
	var dir := toward.normalized() if toward.length() > 0.1 else Vector3.FORWARD
	var p := _surface(flat + dir * maxf(float(_fight.distance), 0.5))
	p.y -= 0.08 + sin(t * 17.0) * 0.05
	_bobber.global_position = p
	if not result.is_empty():
		_finish(result)


func on_cast_ack(id: int, bite_in: float, pull: float, speed: float, shark_at: float, spot: String) -> void:
	if state != State.WAITING or _cast_id != 0:
		return
	_cast_id = id
	_bite_in = bite_in
	_pull = pull
	_speed = speed
	_shark_at = shark_at
	_spot = spot


func _cast() -> void:
	var camera := player.camera
	var forward := -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var from := _rod_tip()
	_target = Vector3(from.x, 0.0, from.z) + forward * lerpf(FishingMath.MIN_CAST, FishingMath.MAX_CAST, charge)
	var ground: float = GameState.world.ground_height(_target.x, _target.z)
	_in_water = ground == -INF or ground < -0.5
	_target.y = Waves.height_at(Vector2(_target.x, _target.z), Ocean.time) if _in_water else ground + 0.05
	_fly_from = from
	_fly_t = 0.0
	state = State.FLYING
	Sound.play("swing", -8.0)


func _land() -> void:
	if not _in_water:
		player.survivor.notified.emit("That landed on dry ground — cast out over deeper water.")
		state = State.IDLE
		return
	Sound.play("splash", -14.0)
	state = State.WAITING
	_cast_id = 0
	_bite_in = INF
	GameState.world.fishing.rpc_id(1, "request_cast", _target, bait_item)


func _hook() -> void:
	var tip := _rod_tip()
	var distance := Vector2(tip.x, tip.z).distance_to(Vector2(_target.x, _target.z))
	_fight = FishingMath.new_fight(maxf(distance, 3.0))
	_fight_time = 0.0
	state = State.FIGHT
	Sound.play("splash", -6.0)


func _finish(outcome: String) -> void:
	if _cast_id != 0:
		GameState.world.fishing.rpc_id(1, "request_result", _cast_id, outcome)
	match outcome:
		"landed":
			Sound.play("pickup", -2.0)
		"snapped":
			Sound.play("error", -4.0)
		"cut":
			Sound.play("cut", -6.0)
	state = State.IDLE
	_cast_id = 0
	_fight = {}
	charge = 0.0


func _cycle_bait() -> void:
	var options: Array[String] = [""]
	for id: String in FishTable.BAITS:
		if player.survivor.inventory.count_of(id) > 0:
			options.append(id)
	bait_item = options[(options.find(bait_item) + 1) % options.size()]
	Sound.play("click", -10.0)


## The tip of the rod in your hand (ItemModels' rod is 1.27 m from grip to tip).
func _rod_tip() -> Vector3:
	if player.view_model != null:
		var tip := player.view_model.held_point(Vector3(0.0, 1.27, 0.0))
		if tip != Vector3.INF:
			return tip
	return player.camera.global_transform * Vector3(0.35, 0.35, -1.25)


func _surface(p: Vector3) -> Vector3:
	return Vector3(p.x, Waves.height_at(Vector2(p.x, p.z), Ocean.time), p.z)


func _update_line() -> void:
	var show := state in [State.FLYING, State.WAITING, State.BITE, State.FIGHT]
	_bobber.visible = show
	_line.visible = show
	if show:
		_line.global_transform = Boat._rope_transform(_rod_tip(), _bobber.global_position, 0.004)


## What the HUD shows about fishing right now ("" when not holding the rod).
func hud_text() -> String:
	if not holding_rod():
		return ""
	var bait := "bare hook" if bait_item.is_empty() else "%s ×%d" % [ItemTable.display_name(bait_item), player.survivor.inventory.count_of(bait_item)]
	match state:
		State.IDLE:
			return "%s hold to cast   ·   %s bait: %s" % [Controls.tag("primary"), Controls.tag("secondary"), bait]
		State.CHARGING:
			return "Cast  " + _bar(charge)
		State.WAITING:
			return "Waiting for a bite on %s%s…   (%s reel in)" % [bait, "" if _spot.is_empty() else " · " + _spot, Controls.tag("primary")]
		State.BITE:
			return "!!  STRIKE — %s  !!" % Controls.tag("primary")
		State.FIGHT:
			var text := "%s hold to reel · ease off when it pulls\nTension %s   Line %.0f m" % [Controls.tag("primary"), _bar(float(_fight.tension)), float(_fight.distance)]
			if _fight.get("shark", false):
				text += "\nSHARK ON THE LINE — %s cut it loose" % Controls.tag("paddle")
			return text
	return ""


static func _bar(value: float) -> String:
	var filled := clampi(roundi(value * 10.0), 0, 10)
	return "▰".repeat(filled) + "▱".repeat(10 - filled)
