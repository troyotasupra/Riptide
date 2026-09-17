class_name Player
extends CharacterBody3D
## First-person crew member. The owning peer moves it and streams its state;
## every other peer draws the crew member's full, animated character. Survival,
## belongings and clothing live in the child Survivor node, which the host
## keeps authoritative.
##
## Aboard a boat, the body stands on that boat's still deck proxy (far below
## the world) and is drawn relative to the real, pitching hull. See boat.gd.

const WALK_SPEED := 4.5
const SPRINT_SPEED := 7.0
const CROUCH_SPEED := 2.2
const SWIM_SPEED := 2.8
## Swimming hard, and how fast you sink or rise while diving.
const SWIM_SPRINT := 1.7
const DIVE_SPEED := 2.8
const GROUND_ACCEL := 14.0
const AIR_ACCEL := 2.5
const JUMP_VELOCITY := MovementTuning.JUMP_VELOCITY
const SWIM_JUMP_VELOCITY := MovementTuning.SWIM_JUMP_VELOCITY
const GRAVITY := MovementTuning.GRAVITY
const FALL_MULTIPLIER := MovementTuning.FALL_MULTIPLIER
const EYE_HEIGHT := 1.6
const CROUCH_EYE_HEIGHT := 1.0
const MOUSE_SENSITIVITY := 0.0022
const STICK_LOOK_SPEED := 2.8
const STAMINA_MAX := 100.0
const SPRINT_COST := 16.0
const SWIM_COST := 5.0
const SWIM_JUMP_COST := 10.0
const STAMINA_REGEN := 14.0
## Feet this far under the surface starts swimming; shallower than the exit depth stops it.
const SWIM_DEPTH := 1.3
const SWIM_EXIT_DEPTH := 1.0
const SWIM_FLOAT_DEPTH := MovementTuning.SWIM_FLOAT_DEPTH
const SEND_EVERY_TICKS := 3  # 20 state packets per second
const DECK_EXIT_DROP := 1.5
const DECK_EXIT_MARGIN := 0.8
## Keeps the body clear of the hull's outer edge when it lands on the proxy.
const DECK_EDGE_INSET := 0.4
## Velocity carried across boarding/leaving is clamped so nothing can launch you.
const MAX_TRANSFER_SPEED := 10.0
const STRESS_FLING_SPEED := 12.0
const REMOTE_SMOOTHING := 14.0
const INTERACT_REACH := 3.5
const BUILD_REACH := 7.0
const GIVE_REACH := 3.5
const SWING_TOOLS := ["knife", "machete", "hatchet", "spear"]
const SWING_SECONDS := 0.55
const CRAWL_SPEED := 1.1
const FLY_SPEED := 9.0
## Anything up to this high is stepped over rather than walked into: doorsills,
## kerbs, rocks, the shack's steps.
const STEP_HEIGHT := 0.55
const DOWNED_EYE_HEIGHT := 0.45
## After running out of breath, hard strokes wait until stamina is back to this.
const WINDED_RECOVER := 20.0

var peer_id := 1
var player_id := ""
var display_name := "Sailor"
var look := {}
## slot -> item id, what everyone sees this crew member wearing.
var worn := {}
var is_local := false
## The boat whose deck proxy this body is standing in, or null when in the world.
var platform: Boat = null
var yaw := 0.0
var pitch := 0.0
var stamina := STAMINA_MAX
var swimming := false
## The local crew member's eyes are under the surface.
var underwater := false
var crouching := false
var paddling := false
## 0 resting .. 1 sprinting or swimming hard; drives hunger and thirst on the host.
var exertion := 0.0
var carried_weight_kg := 0.0
var held_id := ""
## What the crosshair is on (local player only).
var focus_id := ""
var focus_text := ""
var give_peer := 0
var give_text := ""

var survivor: Survivor
var camera: Camera3D
var model: CharacterModel
var view_model: ViewModel
var _label: Label3D
var _eye_height := EYE_HEIGHT
var _tick := 0
var _row_boat: Boat = null
var _row_sent := Vector3.ZERO
## 0..1 how hard this crew member is rowing right now (drives the arm animation).
var rowing := 0.0
var _row_resend := 0.0
var _winded := false
## Down at 0 health: crawling and bleeding out until a crewmate revives you.
var downed := false
var bleed_left := 0.0
## Limbs lost to sharks, and the ones with a prosthetic fitted.
var missing_limbs: Array = []
var prosthetics: Array = []
## Developer mode: flying through everything, and god mode's endless stamina.
var flying := false
var _wedged_for := 0.0
var god := false
var angler: Angler
var gun: Gun
## Where the sights have wandered to (radians), and the field of view while aiming.
var aim_offset := Vector2.ZERO
var aim_fov := 0.0
var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _has_target := false
var _remote_speed := 0.0
var _last_remote_pos := Vector3.ZERO
var _step_accum := 0.0
var _was_swimming := false
# Hold-to-gather
var _focus_hold := 0.0
var _hold_id := ""
var _hold_time := 0.0
var _hold_needed := 0.0
var _hold_action := "interact"
var _swing_timer := 0.0
# Building
var _ghost: MeshInstance3D
var _ghost_material: StandardMaterial3D
var _ghost_type := ""
var _ghost_valid := false
var _ghost_position := Vector3.ZERO
var _ghost_yaw := 0.0
var _torch_light: OmniLight3D
# --autopilot test driver and stress statistics
var _auto_phase := 0
var _auto_timer := 0.0
var _auto_heading := 0.0
var _stress_since_contact := 99.0
var _stress_max_speed := 0.0
var _stress_boardings := 0
var _stress_report_timer := 0.0
var _gather_target := ""
var _gather_since := 0.0
var _gather_skip := {}


func _ready() -> void:
	collision_layer = Layers.PLAYERS if is_local else 0
	collision_mask = (Layers.WORLD | Layers.BOATS) if is_local else 0
	# Deck riding is handled entirely by the deck proxy (see boat.gd). Never let
	# the physics engine hand us a hull's velocity, or a bobbing raft flings you.
	platform_floor_layers = Layers.WORLD
	platform_wall_layers = 0
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50.0)

	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.9
	add_child(collider)

	survivor = Survivor.new()
	survivor.name = "Survivor"
	survivor.player = self
	add_child(survivor)

	model = CharacterModel.new()
	model.name = "Character"
	model.top_level = true
	model.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(model)
	model.setup(look, worn, GameState.crew_color, GameState.emblem)

	_label = Label3D.new()
	_label.text = display_name
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 40
	_label.pixel_size = 0.006
	_label.outline_size = 8
	_label.top_level = true
	_label.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_label)

	if is_local:
		camera = Camera3D.new()
		camera.top_level = true
		camera.fov = aim_fov if aim_fov > 0.0 else Settings.fov
		camera.near = 0.05
		camera.far = 3000.0
		camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(camera)
		camera.make_current()
		_torch_light = OmniLight3D.new()
		_torch_light.light_color = Color(1.0, 0.7, 0.35)
		_torch_light.light_energy = 1.4
		_torch_light.omni_range = 9.0
		_torch_light.position = Vector3(0.3, -0.2, -0.4)
		_torch_light.visible = false
		camera.add_child(_torch_light)
		view_model = ViewModel.new()
		view_model.name = "ViewModel"
		camera.add_child(view_model)
		gun = Gun.new()
		gun.name = "Gun"
		gun.player = self
		add_child(gun)
		angler = Angler.new()
		angler.name = "Angler"
		angler.player = self
		add_child(angler)
		model.visible = false
		_label.visible = false
		GameState.local_player = self


func _exit_tree() -> void:
	if GameState.local_player == self:
		GameState.local_player = null


func apply_worn(ids: Dictionary) -> void:
	worn = ids.duplicate()
	if model != null:
		model.set_worn(worn)


@rpc("any_peer", "call_remote", "reliable")
func _set_worn(ids: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		apply_worn(ids)


func apply_limbs(missing: Array, fitted: Array) -> void:
	missing_limbs = missing.duplicate()
	prosthetics = fitted.duplicate()
	if model != null:
		model.set_limbs(missing_limbs, prosthetics)


@rpc("any_peer", "call_remote", "reliable")
func _set_limbs(missing: Array, fitted: Array) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		apply_limbs(missing, fitted)


## Developer mode: fly through anything — WASD and look to steer, Space up,
## C down, Shift faster.
func set_flying(value: bool) -> void:
	if value == flying:
		return
	flying = value
	velocity = Vector3.ZERO
	if value:
		if platform != null:
			leave_platform()
		swimming = false
		paddling = false
		_update_row(Vector2.ZERO, false)
		collision_mask = 0
	else:
		collision_mask = Layers.WORLD | Layers.BOATS
	if survivor != null:
		survivor.notified.emit("Flying %s (V)" % ("on — Space up, C down, Shift fast" if value else "off"))


func _fly(delta: float) -> void:
	var active := _controls_active()
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if active else Vector2.ZERO
	var look := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	var wish := look * Vector3(input.x, 0.0, input.y)
	if active:
		wish.y += (1.0 if Input.is_action_pressed("jump") else 0.0) - (1.0 if Input.is_action_pressed("crouch") else 0.0)
	var speed := FLY_SPEED * (4.0 if active and Input.is_action_pressed("sprint") else 1.0)
	velocity = velocity.lerp(wish.limit_length(1.0) * speed, 1.0 - exp(-8.0 * delta))
	global_position += velocity * delta
	rotation.y = yaw
	swimming = false
	crouching = false
	stamina = STAMINA_MAX
	exertion = 0.0
	_update_focus()
	_update_give_target()
	_update_hold(delta)
	_update_placement()


func set_downed(value: bool, seconds: float) -> void:
	downed = value
	bleed_left = seconds
	if value:
		paddling = false


@rpc("any_peer", "call_remote", "reliable")
func _set_downed(value: bool, seconds: float) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		set_downed(value, seconds)


func is_asleep() -> bool:
	return is_local and GameState.world != null and GameState.world.camp != null and GameState.world.camp.local_asleep


## 0..1 progress of the current hold-to-gather, or 0 when not holding.
func hold_fraction() -> float:
	if _hold_id.is_empty() or _hold_needed <= 0.0:
		return 0.0
	return clampf(_hold_time / _hold_needed, 0.0, 1.0)


func is_placing() -> bool:
	return not _ghost_type.is_empty()


func _controls_active() -> bool:
	return not GameState.ui_open and not is_asleep() \
		and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or Controls.using_gamepad or GameState.free_mouse)


func _unhandled_input(event: InputEvent) -> void:
	if not is_local:
		return
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not GameState.ui_open:
			var sensitivity := MOUSE_SENSITIVITY * Settings.mouse_sensitivity
			yaw -= event.relative.x * sensitivity
			pitch = clampf(pitch - event.relative.y * sensitivity * (-1.0 if Settings.invert_y else 1.0), -1.5, 1.5)
		return
	if event.is_action_pressed("leave"):
		Net.leave_game("You left the session.")
		return
	if is_asleep():
		if (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.pressed:
			GameState.world.camp.rpc_id(1, "request_wake")
			get_viewport().set_input_as_handled()
		return
	if GameState.ui_open:
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not GameState.free_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if not _controls_active():
		return
	if event.is_action_pressed("dev_fly") and GameState.dev_mode:
		set_flying(not flying)
		get_viewport().set_input_as_handled()
		return
	if downed:
		return
	if angler != null and angler.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	# Aboard with an oar, Q or E just takes up the oars — it never drops the oar overboard.
	if not paddling and platform != null and platform.can_paddle and focus_id.is_empty() \
			and (event.is_action_pressed("row_left") or event.is_action_pressed("row_right")) \
			and survivor.inventory.tool_types().has("oar"):
		paddling = true
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("paddle") and platform != null and platform.can_paddle:
		if paddling:
			paddling = false
		elif survivor.inventory.tool_types().has("oar"):
			paddling = true
			if not GameState.hints_shown.has("rowing"):
				GameState.hints_shown["rowing"] = true
				survivor.notified.emit("Rowing: %s strokes the left oar, %s the right — both to go straight. Hold %s to back-row, %s to pull hard, %s to let go." % [
					Controls.tag("row_left"), Controls.tag("row_right"), Controls.tag("move_back"), Controls.tag("sprint"), Controls.tag("paddle")])
		else:
			Sound.play("error", -8.0)
			survivor.notified.emit("You need an oar to row. Carve one from wood and rope (B).")
	elif paddling:
		pass  # while rowing, Q and E are oar strokes rather than drop and interact
	elif event.is_action_pressed("interact") and not focus_id.is_empty():
		_press_interact("interact")
	elif event.is_action_pressed("primary"):
		_press_primary()
	elif event.is_action_pressed("rotate") and is_placing():
		_ghost_yaw += PI / 8.0
	elif event.is_action_pressed("drop"):
		var held = survivor.inventory.hotbar[survivor.selected_slot]
		if held != null:
			Sound.play("drop", -4.0)
			GameState.world.camp.rpc_id(1, "request_drop_item", "", int(held.uid))
	elif event.is_action_pressed("give") and give_peer != 0:
		survivor.request_give(survivor.selected_slot, give_peer)
	elif event.is_action_pressed("hotbar_next"):
		survivor.select_slot(survivor.selected_slot + 1)
	elif event.is_action_pressed("hotbar_prev"):
		survivor.select_slot(survivor.selected_slot - 1)
	else:
		for i in Pack.HOTBAR_SIZE:
			if event.is_action_pressed("hotbar_%d" % (i + 1)):
				survivor.select_slot(i)
				break


func _physics_process(delta: float) -> void:
	if platform != null and not is_instance_valid(platform):
		platform = null
	if is_local:
		_local_physics(delta)
	else:
		_remote_physics(delta)


func _process(delta: float) -> void:
	var target_eye := DOWNED_EYE_HEIGHT if downed else (CROUCH_EYE_HEIGHT if crouching else EYE_HEIGHT)
	if downed:
		bleed_left = maxf(0.0, bleed_left - delta)
	_eye_height = lerpf(_eye_height, target_eye, 1.0 - exp(-10.0 * delta))

	var base := Transform3D.IDENTITY
	if platform != null and is_instance_valid(platform):
		base = platform.get_global_transform_interpolated() * platform.proxy_xf.affine_inverse()
	var world := base * get_global_transform_interpolated()

	if is_local:
		if _controls_active():
			var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
			var speed := STICK_LOOK_SPEED * Settings.stick_sensitivity * delta
			yaw -= stick.x * speed
			pitch = clampf(pitch - stick.y * speed * (-1.0 if Settings.invert_y else 1.0), -1.5, 1.5)
		# Use the live yaw/pitch rather than the physics-tick body rotation so
		# looking around responds every frame.
		var view := Basis(Vector3.UP, yaw + aim_offset.x) * Basis(Vector3.RIGHT, clampf(pitch + aim_offset.y, -1.55, 1.55))
		camera.global_transform = Transform3D(base.basis * view, world.origin + base.basis * Vector3(0.0, _eye_height, 0.0))
		camera.fov = Settings.fov
		_torch_light.visible = ItemTable.get_item(held_id).get("tool", "") == "torch"
		var skin: Color = AppearanceTable.SKIN[int(AppearanceTable.sanitize(look).skin)]
		view_model.refresh("oar" if paddling else held_id, worn.get("torso", ""), skin, GameState.crew_color)
		view_model.rowing = rowing if paddling else 0.0
		view_model.animate(delta, Vector2(velocity.x, velocity.z).length())
		_update_ambience(world.origin)
	else:
		model.global_transform = Transform3D(world.basis, world.origin)
		if downed:
			model.global_transform *= Transform3D(Basis(Vector3.RIGHT, -1.35), Vector3(0.0, 0.28, 0.25))
		model.animate(delta, _remote_speed, swimming, crouching, pitch)
		_label.global_position = world.origin + Vector3.UP * 2.2


## Where this player really is in the world, even while standing in a deck proxy.
func world_transform() -> Transform3D:
	if platform != null:
		return platform.global_transform * platform.proxy_xf.affine_inverse() * global_transform
	return global_transform


## Steps onto `boat` from the world, landing on the surface you touched.
func board(boat: Boat, surface_y: float) -> void:
	var relative_velocity := (velocity - boat.point_velocity(global_position)).limit_length(MAX_TRANSFER_SPEED)
	var local := boat.global_transform.affine_inverse() * global_transform
	var forward := local.basis * Vector3.FORWARD
	yaw = atan2(-forward.x, -forward.z)
	# Land exactly on the surface, inside the hull's edges. Starting even slightly
	# inside the proxy collider makes the physics engine eject you violently.
	var box := boat.hull_aabb
	var deck_position := Vector3(
		clampf(local.origin.x, box.position.x + DECK_EDGE_INSET, box.end.x - DECK_EDGE_INSET),
		surface_y + 0.02,
		clampf(local.origin.z, box.position.z + DECK_EDGE_INSET, box.end.z - DECK_EDGE_INSET))
	platform = boat
	rotation = Vector3(0.0, yaw, 0.0)
	global_position = boat.proxy_xf * deck_position
	velocity = boat.global_basis.inverse() * relative_velocity
	velocity.y = maxf(velocity.y, 0.0)
	reset_physics_interpolation()
	_note_boat_contact()


## Climbs a boarding ladder: straight onto the deck, facing forward.
func climb_aboard(boat: Boat, _ladder: String = "ladder") -> void:
	var landing := Vector3(0.0, boat.deck_top + 0.02, 0.0)
	platform = boat
	swimming = false
	velocity = Vector3.ZERO
	yaw = 0.0
	rotation = Vector3.ZERO
	global_position = boat.proxy_xf * landing
	reset_physics_interpolation()
	_note_boat_contact()


func leave_platform() -> void:
	var boat := platform
	var world_xf := world_transform()
	var forward := world_xf.basis * Vector3.FORWARD
	platform = null
	paddling = false
	yaw = atan2(-forward.x, -forward.z)
	rotation = Vector3(0.0, yaw, 0.0)
	velocity = (boat.global_basis * velocity).limit_length(MAX_TRANSFER_SPEED) \
		+ boat.point_velocity(world_xf.origin).limit_length(MAX_TRANSFER_SPEED)
	global_position = world_xf.origin
	reset_physics_interpolation()
	_note_boat_contact()


## Host: move this crew member somewhere (e.g. respawn). The owner applies it.
func teleport(pos: Vector3) -> void:
	if is_local:
		_apply_teleport(pos)
	else:
		_teleport.rpc_id(peer_id, pos)


## Host: put this crew member aboard a boat at a boat-space position.
func teleport_aboard(boat_name: String, local: Vector3) -> void:
	if is_local:
		_apply_teleport_aboard(boat_name, local)
	else:
		_teleport_aboard.rpc_id(peer_id, boat_name, local)


@rpc("any_peer", "call_remote", "reliable")
func _teleport(pos: Vector3) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		_apply_teleport(pos)


@rpc("any_peer", "call_remote", "reliable")
func _teleport_aboard(boat_name: String, local: Vector3) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		_apply_teleport_aboard(boat_name, local)


func _apply_teleport(pos: Vector3) -> void:
	platform = null
	paddling = false
	swimming = false
	velocity = Vector3.ZERO
	global_position = pos
	reset_physics_interpolation()


func _apply_teleport_aboard(boat_name: String, local: Vector3) -> void:
	var boat: Boat = GameState.find_boat(boat_name)
	if boat == null:
		return
	platform = boat
	paddling = false
	swimming = false
	velocity = Vector3.ZERO
	global_position = boat.proxy_xf * local
	if GameState.face == "bow":
		yaw = 0.0
		rotation.y = 0.0
	reset_physics_interpolation()


# --- local simulation ------------------------------------------------------

func _local_physics(delta: float) -> void:
	held_id = survivor.selected_id()
	if flying:
		_fly(delta)
		_finish_tick()
		return
	if platform == null and _hold_for_ground():
		paddling = false
		_update_row(Vector2.ZERO, false)
		_finish_tick()
		return
	var active := _controls_active()
	var input := Vector2.ZERO
	if active:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if not GameState.autopilot.is_empty():
		input = _autopilot_input(delta)
	if downed or platform == null or not platform.can_paddle or not survivor.inventory.tool_types().has("oar"):
		paddling = false
	var strokes := Vector2.ZERO
	if paddling and active:
		strokes = Vector2(1.0 if Input.is_action_pressed("row_left") else 0.0, 1.0 if Input.is_action_pressed("row_right") else 0.0)
		if Input.is_action_pressed("move_back"):
			strokes = -strokes
	var rowing_now := strokes != Vector2.ZERO
	var power_stroke := rowing_now and Input.is_action_pressed("sprint") and stamina > 0.0 and not _winded
	_update_row(strokes, power_stroke)
	rowing = lerpf(rowing, (1.0 if power_stroke else 0.6) if rowing_now else 0.0, 1.0 - exp(-6.0 * delta))
	if paddling:
		input = Vector2.ZERO

	var world_pos := world_transform().origin
	var depth := Waves.height_at(Vector2(world_pos.x, world_pos.z), Ocean.time) - world_pos.y
	if platform != null:
		swimming = false
	elif swimming:
		swimming = depth > SWIM_EXIT_DEPTH
	else:
		swimming = depth > SWIM_DEPTH
	# The same rule the host uses: your eyes, at standing height, are under the surface.
	underwater = platform == null and depth > EYE_HEIGHT
	if swimming and not _was_swimming:
		Sound.play("splash", -4.0)
	_was_swimming = swimming
	crouching = active and Input.is_action_pressed("crouch") and not swimming

	var moving := input != Vector2.ZERO
	var limb_speed := SharkMath.speed_factor(missing_limbs, prosthetics)
	var sprinting := active and moving and input.y < 0.0 and Input.is_action_pressed("sprint") \
		and not crouching and not swimming and stamina > 0.0 and not downed and limb_speed > 0.8
	var speed := WALK_SPEED
	if swimming:
		speed = SWIM_SPEED * (SWIM_SPRINT if sprinting else 1.0)
	elif crouching:
		speed = CROUCH_SPEED
	elif sprinting:
		speed = SPRINT_SPEED
	speed *= LoadoutMath.speed_multiplier(carried_weight_kg) * limb_speed
	if downed:
		speed = CRAWL_SPEED * (0.6 if swimming else 1.0)

	var drain := LoadoutMath.stamina_drain_multiplier(carried_weight_kg)
	if sprinting:
		stamina -= SPRINT_COST * drain * delta
	elif power_stroke:
		stamina -= RowMath.POWER_STAMINA_COST * drain * delta
	elif swimming and moving:
		stamina -= SWIM_COST * drain * delta * (2.0 if sprinting else 1.0)
	elif rowing_now:
		stamina += RowMath.ROWING_STAMINA_REGEN * delta
	else:
		stamina += STAMINA_REGEN * delta
	stamina = clampf(stamina, 0.0, STAMINA_MAX)
	if god:
		stamina = STAMINA_MAX
	if stamina <= 0.0:
		_winded = true
	elif stamina >= WINDED_RECOVER:
		_winded = false
	if sprinting or power_stroke or (swimming and moving):
		exertion = 1.0
	else:
		exertion = 0.4 if rowing_now else (0.25 if moving else 0.0)

	rotation.y = yaw
	var wish := Basis(Vector3.UP, yaw) * Vector3(input.x, 0.0, input.y) * speed
	var accel := GROUND_ACCEL if (is_on_floor() or swimming) else AIR_ACCEL
	var blend := 1.0 - exp(-accel * delta)
	velocity.x = lerpf(velocity.x, wish.x, blend)
	velocity.z = lerpf(velocity.z, wish.z, blend)

	var jump := (active and not downed and Input.is_action_just_pressed("jump")) or (not GameState.autopilot.is_empty() and swimming)
	if swimming:
		var diving := active and Input.is_action_pressed("crouch")
		var deep := depth > _eye_height + 0.3
		if diving:
			velocity.y = lerpf(velocity.y, -DIVE_SPEED, 1.0 - exp(-5.0 * delta))
		elif deep and Input.is_action_pressed("jump") and active:
			velocity.y = lerpf(velocity.y, DIVE_SPEED, 1.0 - exp(-5.0 * delta))
		else:
			# Float back up to the surface, but never rocket out of a deep dive.
			velocity.y = lerpf(velocity.y, clampf((depth - SWIM_FLOAT_DEPTH) * 3.0, -4.0, 4.0), 1.0 - exp(-4.0 * delta))
		# At the surface, jump is the heave out of the water onto a deck or rock.
		if jump and not deep and stamina > SWIM_JUMP_COST:
			velocity.y = SWIM_JUMP_VELOCITY
			stamina -= SWIM_JUMP_COST
			swimming = false
	elif is_on_floor():
		if jump:
			velocity.y = JUMP_VELOCITY
	else:
		var gravity := GRAVITY * (FALL_MULTIPLIER if velocity.y < 0.0 else 1.0)
		velocity.y -= gravity * delta

	# Walking into a wall zeroes the velocity, so remember where we meant to go.
	var intent := Vector3(velocity.x, 0.0, velocity.z) * delta
	move_and_slide()
	_step_up(intent)

	if platform != null:
		_check_leave_deck()
	else:
		_try_board()
	if GameState.autopilot == "stress":
		_track_stress(delta)
	_check_wedged(delta)
	_footsteps(delta, Vector2(velocity.x, velocity.z).length(), is_on_floor() and not swimming)
	_update_focus()
	_update_give_target()
	_update_hold(delta)
	_update_placement()
	_finish_tick()


## Is the body wedged inside something right now?
func _overlapping() -> bool:
	return test_move(global_transform, Vector3.UP * 0.001, null, 0.001, true)


## Frees a crew member stuck inside terrain or scenery: the nearest clear spot,
## searching around and above them, else the nearest beach. The Esc menu's
## Unstuck button calls this, and a wedged player is freed automatically.
func unstuck() -> void:
	if platform != null:
		leave_platform()
	var world := GameState.world
	var here := global_position
	for radius: float in [0.0, 1.2, 2.5, 4.0, 7.0]:
		var steps := 1 if radius == 0.0 else 8
		for i in steps:
			var angle := TAU * i / float(steps)
			var xz := Vector2(here.x, here.z) + Vector2.from_angle(angle) * radius
			var ground: float = world.ground_height(xz.x, xz.y) if world != null else -INF
			if ground == -INF or ground < 0.2:
				continue  # water, not somewhere to stand
			for up: float in [0.1, 0.6, 1.5, 3.0]:
				var candidate := Vector3(xz.x, ground + up, xz.y)
				if not test_move(Transform3D(global_transform.basis, candidate), Vector3.UP * 0.001, null, 0.001, true):
					_place_at(candidate)
					return
	if world != null:
		_place_at(world.spawn_point(0) + Vector3.UP * 0.5)


func _place_at(position: Vector3) -> void:
	global_position = position
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	if survivor != null:
		survivor.notified.emit("Unstuck.")


## Character bodies slide along anything vertical, so a 15 cm doorsill or a rock
## stops you dead. When a wall blocks us at foot height, try lifting over it:
## up, forward, then back down onto whatever is there.
func _step_up(motion: Vector3) -> void:
	if platform != null or swimming or flying or downed or not is_on_floor():
		return
	if motion.length() < 0.004:
		return
	var from := global_transform
	if not test_move(from, motion):
		return  # the way ahead is clear
	var lift := Vector3.UP * STEP_HEIGHT
	if test_move(from, lift):
		return  # no headroom to step up into
	var lifted := from.translated(lift)
	if test_move(lifted, motion):
		return  # it's a wall, not a step
	var landing := KinematicCollision3D.new()
	if not test_move(lifted.translated(motion), Vector3.DOWN * (STEP_HEIGHT + 0.02), landing):
		return  # a gap, not a step: let the fall happen normally
	if landing.get_normal().y < cos(floor_max_angle):
		return  # the far side is too steep to stand on
	global_position = lifted.origin + motion + Vector3.DOWN * landing.get_travel().length()
	# Keep walking: the wall we just climbed took our speed away.
	velocity.x = motion.x / maxf(get_physics_process_delta_time(), 0.0001)
	velocity.z = motion.z / maxf(get_physics_process_delta_time(), 0.0001)


## Props and terrain build over the first few frames after a world loads, and a
## collider can appear around someone standing there. Anyone left inside solid
## ground for a moment is freed rather than left to wriggle.
func _check_wedged(delta: float) -> void:
	if flying or platform != null or not _overlapping():
		_wedged_for = 0.0
		return
	_wedged_for += delta
	if _wedged_for > 0.75:
		_wedged_for = 0.0
		unstuck()


func _finish_tick() -> void:
	_tick += 1
	if _tick % SEND_EVERY_TICKS == 0:
		_send_state()


## Island terrain loads over a few frames. Never let a player fall through
## ground that hasn't loaded yet, and pop anyone who ends up beneath it back on top.
## Returns true while the player must wait.
func _hold_for_ground() -> bool:
	if GameState.world == null:
		return false
	var ground: float = GameState.world.ground_height(global_position.x, global_position.z)
	if ground == -INF:
		return false
	if global_position.y < ground - 1.0:
		global_position.y = ground + 0.5
		velocity = Vector3.ZERO
		reset_physics_interpolation()
	var from := global_position + Vector3.UP
	var to := Vector3(global_position.x, ground - 2.0, global_position.z)
	var query := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD, [get_rid()])
	if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		velocity = Vector3.ZERO
		return true
	return false


func _update_focus() -> void:
	focus_id = ""
	focus_text = ""
	_focus_hold = 0.0
	if camera == null or GameState.ui_open:
		return
	var from := camera.global_position
	var to := from - camera.global_basis.z * INTERACT_REACH
	var query := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD | Layers.INTERACT | Layers.BOATS, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var target := hit.collider as Interactable
	if target == null:
		return
	var text := target.interact_text(self)
	if not text.is_empty():
		focus_id = target.interact_id
		focus_text = text
		_focus_hold = target.hold_seconds(self)


## Finds a crewmate you're looking at, to hand them what you're holding.
func _update_give_target() -> void:
	give_peer = 0
	give_text = ""
	# A downed crewmate in front of you can be revived by holding E.
	if camera != null and GameState.world != null and focus_id.is_empty() and not downed:
		for other: Player in GameState.world.players_root.get_children():
			if other == self or not other.downed:
				continue
			var to := other.world_transform().origin + Vector3.UP * 0.3 - camera.global_position
			if to.length() <= SharkMath.REVIVE_RANGE and (-camera.global_basis.z).dot(to.normalized()) > 0.6:
				focus_id = "revive:%d" % other.peer_id
				focus_text = "Revive %s (hold)" % other.display_name
				_focus_hold = SharkMath.REVIVE_HOLD
				return
	if held_id.is_empty() or camera == null or GameState.world == null or not focus_id.is_empty():
		return
	var from := camera.global_position
	var forward := -camera.global_basis.z
	var best := 0.96
	for other: Player in GameState.world.players_root.get_children():
		if other == self:
			continue
		var to := other.world_transform().origin + Vector3.UP * 1.1 - from
		var distance := to.length()
		if distance > GIVE_REACH or distance < 0.1:
			continue
		var facing := forward.dot(to / distance)
		if facing > best:
			best = facing
			give_peer = other.peer_id
			give_text = "%s Give %s to %s" % [Controls.tag("give"), ItemTable.display_name(held_id), other.display_name]


func _press_interact(action: String) -> void:
	if focus_id.ends_with(":ladder") or focus_id.ends_with(":ladder_port"):
		var bits := focus_id.split(":")
		var boat: Boat = GameState.find_boat(bits[1])
		if boat != null:
			climb_aboard(boat, bits[bits.size() - 1])
		return
	if _focus_hold > 0.0:
		_hold_id = focus_id
		_hold_time = 0.0
		_hold_needed = _focus_hold
		_hold_action = action
		_swing_timer = 0.0
		GameState.world.rpc_id(1, "begin_interact", focus_id)
		return
	GameState.world.rpc_id(1, "request_interact", focus_id, survivor.selected_slot)


func _press_primary() -> void:
	if is_placing():
		_confirm_place()
		return
	var tool: String = ItemTable.get_item(held_id).get("tool", "")
	if SWING_TOOLS.has(tool):
		if focus_id.begins_with("shark:"):
			_swing(tool)
			GameState.world.sharks.rpc_id(1, "request_strike", focus_id.substr(6))
		elif focus_id.begins_with("res:"):
			_press_interact("primary")
		else:
			_swing(tool)
			if not GameState.hints_shown.has(held_id):
				GameState.hints_shown[held_id] = true
				survivor.notified.emit(ItemTable.get_item(held_id).get("hint", ""))
		return
	survivor.use_selected()


func _swing(tool: String) -> void:
	view_model.swing()
	Sound.play("chop" if tool == "hatchet" and focus_id.begins_with("res:") else ("cut" if focus_id.begins_with("res:") else "swing"), -6.0)
	Net.send_to_ready(self, "_net_swing")


func _update_hold(delta: float) -> void:
	if _hold_id.is_empty():
		return
	var holding := Input.is_action_pressed(_hold_action) or not GameState.autopilot.is_empty()
	if focus_id != _hold_id or not holding:
		_hold_id = ""
		return
	_hold_time += delta
	_swing_timer -= delta
	if _swing_timer <= 0.0:
		_swing_timer = SWING_SECONDS
		var tool: String = ItemTable.get_item(held_id).get("tool", "")
		if _hold_action == "primary" and SWING_TOOLS.has(tool):
			_swing(tool)
		else:
			Sound.play("cloth", -10.0)
	if _hold_time >= _hold_needed:
		GameState.world.rpc_id(1, "request_interact", _hold_id, survivor.selected_slot)
		_hold_id = ""


## Shows a build preview while a structure kit is selected in the hotbar.
func _update_placement() -> void:
	var type: String = ItemTable.get_item(held_id).get("places", "")
	if GameState.ui_open or platform != null:
		type = ""
	if type != _ghost_type:
		_ghost_type = type
		_rebuild_ghost()
	if type.is_empty():
		return
	var from := camera.global_position
	var to := from - camera.global_basis.z * BUILD_REACH
	var query := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_ghost.visible = false
		_ghost_valid = false
		return
	_ghost_position = hit.position
	var ground: float = GameState.world.ground_height(_ghost_position.x, _ghost_position.z)
	_ghost_valid = hit.normal.y > 0.8 and ground > 0.3 and hit.collider is StaticBody3D and not (hit.collider is Interactable) \
		and (not StructureTable.get_type(type).get("shore", false) or ground <= StructureTable.SHORE_MAX_HEIGHT)
	_ghost.visible = true
	_ghost.global_transform = Transform3D(Basis(Vector3.UP, _ghost_yaw), _ghost_position + Vector3(0.0, 0.4, 0.0))
	_ghost_material.albedo_color = Color(0.3, 1.0, 0.4, 0.35) if _ghost_valid else Color(1.0, 0.3, 0.25, 0.35)


func _rebuild_ghost() -> void:
	if _ghost == null:
		_ghost = MeshInstance3D.new()
		_ghost.top_level = true
		_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ghost.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		_ghost_material = StandardMaterial3D.new()
		_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ghost.material_override = _ghost_material
		add_child(_ghost)
	_ghost.visible = false
	if _ghost_type.is_empty():
		return
	var footprint: float = StructureTable.get_type(_ghost_type).get("footprint", 1.0)
	var box := BoxMesh.new()
	box.size = Vector3(footprint * 1.6, 0.8, footprint * 1.6)
	_ghost.mesh = box


func _confirm_place() -> void:
	if not _ghost_valid:
		Sound.play("error", -6.0)
		survivor.notified.emit("You can't build there — find flat, dry ground.")
		return
	GameState.world.camp.rpc_id(1, "request_place", survivor.selected_slot, _ghost_position, _ghost_yaw)


func _try_board() -> void:
	if not is_on_floor():
		return
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var boat := collision.get_collider() as Boat
		if boat == null or collision.get_normal().y < 0.5:
			continue
		var contact := boat.global_transform.affine_inverse() * collision.get_position()
		if boat.contains_local_point(contact, 0.0, 0.0) and contact.y > boat.hull_aabb.position.y + 0.1:
			board(boat, contact.y)
			return


func _check_leave_deck() -> void:
	var local := global_position - platform.proxy_xf.origin
	if not platform.contains_local_point(local, DECK_EXIT_MARGIN, DECK_EXIT_DROP):
		leave_platform()


## Sends this crew member's oar strokes to the host when they change.
func _update_row(strokes: Vector2, power: bool) -> void:
	var boat := platform if paddling else null
	var state := Vector3(strokes.x, strokes.y, 1.0 if power else 0.0)
	if boat != _row_boat:
		if _row_boat != null and is_instance_valid(_row_boat):
			_row_boat.set_row_input.rpc_id(1, 0.0, 0.0, false)
		_row_boat = boat
		_row_sent = Vector3.ZERO
	# Resend held strokes now and then, in case the host hadn't seen us aboard yet.
	_row_resend += get_physics_process_delta_time()
	if boat != null and (state != _row_sent or (state != Vector3.ZERO and _row_resend > 1.0)):
		_row_resend = 0.0
		boat.set_row_input.rpc_id(1, strokes.x, strokes.y, power)
		_row_sent = state


func _send_state() -> void:
	var boat_name := ""
	var pos := global_position
	if platform != null:
		boat_name = String(platform.name)
		pos -= platform.proxy_xf.origin
	Net.send_to_ready(self, "_net_state", [boat_name, pos, yaw, pitch, crouching, swimming, exertion, held_id])


# --- sound -------------------------------------------------------------------

func _footsteps(delta: float, horizontal_speed: float, grounded: bool) -> void:
	if not grounded or horizontal_speed < 0.6:
		return
	_step_accum += horizontal_speed * delta
	var stride := 1.7 if horizontal_speed < 5.0 else 2.2
	if _step_accum < stride:
		return
	_step_accum = 0.0
	var surface := _surface()
	if is_local:
		Sound.play(surface, -12.0 if crouching else -8.0)
	else:
		Sound.play_at(surface, world_transform().origin, -4.0)


func _surface() -> String:
	if platform != null or GameState.world == null:
		return "step_wood"
	var p := world_transform().origin
	var ground: float = GameState.world.ground_height(p.x, p.z)
	if ground == -INF or p.y - ground > 0.6:
		return "step_wood"
	return "step_sand" if ground < 2.6 else "step_grass"


## The sea is loud at the shore and on deck, quiet inland and below deck.
func _update_ambience(at: Vector3) -> void:
	var level := 1.0
	if platform == null and GameState.world != null and GameState.world.camp.in_shack(at):
		level = 0.4
	elif platform == null and GameState.world != null:
		var ground: float = GameState.world.ground_height(at.x, at.z)
		if ground != -INF:
			level = lerpf(1.0, 0.3, clampf((ground - 2.0) / 18.0, 0.0, 1.0))
	Sound.set_ambience_level(level)


# --- test drivers (--autopilot=board | stress | gather) ----------------------

## "board": walk to the raft and stay aboard.
## "stress": loop forever — board, stand, walk off an edge, swim away, come back.
func _autopilot_input(delta: float) -> Vector2:
	if GameState.autopilot == "gather":
		return _gather_input(delta)
	var raft: Boat = GameState.find_boat("Raft")
	if raft == null:
		return Vector2.ZERO
	_auto_timer += delta
	match _auto_phase:
		0:  # approach the raft
			if platform != null:
				_auto_phase = 1
				_auto_timer = 0.0
				return Vector2.ZERO
			var to_raft := raft.global_position - world_transform().origin
			yaw = atan2(-to_raft.x, -to_raft.z)
			return Vector2(0.0, -1.0)
		1:  # stand on deck
			if GameState.autopilot == "stress" and _auto_timer > 1.5:
				_auto_phase = 2
				_auto_timer = 0.0
				_auto_heading = randf() * TAU
			return Vector2.ZERO
		2:  # walk off an edge
			if platform == null:
				_auto_phase = 3
				_auto_timer = 0.0
				return Vector2.ZERO
			yaw = _auto_heading
			return Vector2(0.0, -1.0)
		3:  # swim away briefly, then head back
			if _auto_timer > 2.0:
				_auto_phase = 0
				_auto_timer = 0.0
			return Vector2(0.0, -1.0)
	return Vector2.ZERO


## "gather": walk to the nearest harvestable prop, look at it, hold E; eat now and then.
func _gather_input(delta: float) -> Vector2:
	_auto_timer += delta
	_auto_heading += delta
	var field = GameState.world.resources if GameState.world != null else null
	if field == null:
		return Vector2.ZERO
	if _auto_heading > 8.0:
		_auto_heading = 0.0
		for stack: Dictionary in survivor.inventory.all_stacks():
			if ItemTable.category(stack.id) == "food":
				survivor.use_item(int(stack.uid))
				break
	var here := world_transform().origin
	var best: ResourceNode = null
	var best_distance := INF
	for node: ResourceNode in field.nodes.values():
		if node.depleted or ResourceTable.harvest_seconds(node.kind, survivor.inventory.tool_types()) < 0.0 \
				or ResourceTable.KINDS.get(node.kind, {}).get("yields", []).is_empty() or _gather_skip.has(node.interact_id):
			continue
		var distance := here.distance_to(node.global_position)
		if distance < best_distance:
			best = node
			best_distance = distance
	if best == null:
		return Vector2.ZERO
	# Give up on anything we can't reach or target within 10 seconds.
	if best.interact_id != _gather_target:
		_gather_target = best.interact_id
		_gather_since = 0.0
	_gather_since += delta
	if _gather_since > 10.0:
		_gather_skip[best.interact_id] = true
		print("[gather] %s gave up on %s" % [display_name, best.interact_id])
		return Vector2.ZERO
	var to := best.global_position - here
	var flat := Vector2(to.x, to.z).length()
	yaw = atan2(-to.x, -to.z)
	pitch = -atan2(EYE_HEIGHT - to.y - 0.4, flat)
	if focus_id == best.interact_id and _hold_id.is_empty() and _auto_timer > 1.0:
		_auto_timer = 0.0
		_press_interact("interact")
		return Vector2.ZERO
	return Vector2(0.0, -1.0) if flat > 1.6 else Vector2.ZERO


func _note_boat_contact() -> void:
	_stress_since_contact = 0.0
	_stress_boardings += 1


func _track_stress(delta: float) -> void:
	if platform == null:
		for i in get_slide_collision_count():
			if get_slide_collision(i).get_collider() is Boat:
				_stress_since_contact = 0.0
	_stress_since_contact += delta
	if _stress_since_contact < 0.5:
		# Falling off a deck is legitimate; a fling is a sideways or upward launch.
		var horizontal := Vector2(velocity.x, velocity.z).length()
		_stress_max_speed = maxf(_stress_max_speed, horizontal)
		if horizontal > STRESS_FLING_SPEED or velocity.y > SWIM_JUMP_VELOCITY + 1.0:
			print("[stress] FLING peer %d horizontal %.1f up %.1f m/s (%s)" % [
				peer_id, horizontal, velocity.y, "aboard" if platform != null else "in world"])
	_stress_report_timer += delta
	if _stress_report_timer >= 5.0:
		_stress_report_timer = 0.0
		print("[stress] peer %d transfers %d, max horizontal speed near a hull %.2f m/s" % [
			peer_id, _stress_boardings, _stress_max_speed])


# --- remote copy -----------------------------------------------------------

@rpc("authority", "call_remote", "unreliable_ordered")
func _net_state(boat_name: String, pos: Vector3, p_yaw: float, p_pitch: float, p_crouching: bool, p_swimming: bool, p_exertion: float, p_held: String) -> void:
	var boat: Boat = GameState.find_boat(boat_name)
	var target := pos if boat == null else boat.proxy_xf.origin + pos
	if boat != platform or not _has_target:
		platform = boat
		global_position = target
		_last_remote_pos = target
		yaw = p_yaw
		reset_physics_interpolation()
	_target_pos = target
	_target_yaw = p_yaw
	pitch = p_pitch
	crouching = p_crouching
	if p_swimming and not swimming:
		Sound.play_at("splash", world_transform().origin, -2.0)
	swimming = p_swimming
	exertion = p_exertion
	held_id = p_held
	model.set_held(p_held)
	_has_target = true


@rpc("authority", "call_remote", "unreliable")
func _net_swing() -> void:
	model.swing()


func _remote_physics(delta: float) -> void:
	if not _has_target:
		return
	var blend := 1.0 - exp(-REMOTE_SMOOTHING * delta)
	global_position = global_position.lerp(_target_pos, blend)
	yaw = lerp_angle(yaw, _target_yaw, blend)
	rotation.y = yaw
	var moved := global_position - _last_remote_pos
	_last_remote_pos = global_position
	var speed := Vector2(moved.x, moved.z).length() / maxf(delta, 0.001)
	_remote_speed = lerpf(_remote_speed, speed, 1.0 - exp(-10.0 * delta))
	_footsteps(delta, _remote_speed, not swimming)
