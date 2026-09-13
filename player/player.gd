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
const SWING_TOOLS := ["knife", "machete", "hatchet"]
const SWING_SECONDS := 0.55

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
var _paddle_boat: Boat = null
var _paddle_sent := Vector2.ZERO
var _paddle_sprint_sent := false
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
		camera.fov = Settings.fov
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
	if event.is_action_pressed("paddle") and platform != null and platform.can_paddle:
		paddling = not paddling
	elif event.is_action_pressed("interact") and not focus_id.is_empty():
		_press_interact("interact")
	elif event.is_action_pressed("primary"):
		_press_primary()
	elif event.is_action_pressed("rotate") and is_placing():
		_ghost_yaw += PI / 8.0
	elif event.is_action_pressed("drop"):
		survivor.request_drop(survivor.selected_slot)
	elif event.is_action_pressed("give") and give_peer != 0:
		survivor.request_give(survivor.selected_slot, give_peer)
	elif event.is_action_pressed("hotbar_next"):
		survivor.select_slot(survivor.selected_slot + 1)
	elif event.is_action_pressed("hotbar_prev"):
		survivor.select_slot(survivor.selected_slot - 1)
	else:
		for i in Inventory.HOTBAR_SIZE:
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
	var target_eye := CROUCH_EYE_HEIGHT if crouching else EYE_HEIGHT
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
		var view := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
		camera.global_transform = Transform3D(base.basis * view, world.origin + base.basis * Vector3(0.0, _eye_height, 0.0))
		camera.fov = Settings.fov
		_torch_light.visible = ItemTable.get_item(held_id).get("tool", "") == "torch"
		var skin: Color = AppearanceTable.SKIN[int(AppearanceTable.sanitize(look).skin)]
		view_model.refresh(held_id, worn.get("torso", ""), skin, GameState.crew_color)
		view_model.animate(delta, Vector2(velocity.x, velocity.z).length())
		_update_ambience(world.origin)
	else:
		model.global_transform = Transform3D(world.basis, world.origin)
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
func climb_aboard(boat: Boat) -> void:
	var landing := Sailboat.LADDER_LANDING if boat is Sailboat else Vector3(0.0, boat.deck_top + 0.02, 0.0)
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
	if platform == null and _hold_for_ground():
		_finish_tick()
		return
	var active := _controls_active()
	var input := Vector2.ZERO
	if active:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if not GameState.autopilot.is_empty():
		input = _autopilot_input(delta)
	if platform == null or not platform.can_paddle:
		paddling = false
	var paddle_sprint := paddling and input != Vector2.ZERO and Input.is_action_pressed("sprint") and stamina > 0.0
	_update_paddle(input if paddling else Vector2.ZERO, paddle_sprint)
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
	if swimming and not _was_swimming:
		Sound.play("splash", -4.0)
	_was_swimming = swimming
	crouching = active and Input.is_action_pressed("crouch") and not swimming

	var moving := input != Vector2.ZERO
	var sprinting := active and moving and input.y < 0.0 and Input.is_action_pressed("sprint") \
		and not crouching and not swimming and stamina > 0.0
	var speed := WALK_SPEED
	if swimming:
		speed = SWIM_SPEED
	elif crouching:
		speed = CROUCH_SPEED
	elif sprinting:
		speed = SPRINT_SPEED
	speed *= LoadoutMath.speed_multiplier(carried_weight_kg)

	var drain := LoadoutMath.stamina_drain_multiplier(carried_weight_kg)
	if sprinting or paddle_sprint:
		stamina -= SPRINT_COST * drain * delta
	elif swimming and moving:
		stamina -= SWIM_COST * drain * delta
	else:
		stamina += STAMINA_REGEN * delta
	stamina = clampf(stamina, 0.0, STAMINA_MAX)
	if sprinting or paddle_sprint or (swimming and moving):
		exertion = 1.0
	else:
		exertion = 0.25 if moving or paddling else 0.0

	rotation.y = yaw
	var wish := Basis(Vector3.UP, yaw) * Vector3(input.x, 0.0, input.y) * speed
	var accel := GROUND_ACCEL if (is_on_floor() or swimming) else AIR_ACCEL
	var blend := 1.0 - exp(-accel * delta)
	velocity.x = lerpf(velocity.x, wish.x, blend)
	velocity.z = lerpf(velocity.z, wish.z, blend)

	var jump := (active and Input.is_action_just_pressed("jump")) or (not GameState.autopilot.is_empty() and swimming)
	if swimming:
		velocity.y = lerpf(velocity.y, (depth - SWIM_FLOAT_DEPTH) * 3.0, 1.0 - exp(-4.0 * delta))
		if jump and stamina > SWIM_JUMP_COST:
			velocity.y = SWIM_JUMP_VELOCITY
			stamina -= SWIM_JUMP_COST
			swimming = false
	elif is_on_floor():
		if jump:
			velocity.y = JUMP_VELOCITY
	else:
		var gravity := GRAVITY * (FALL_MULTIPLIER if velocity.y < 0.0 else 1.0)
		velocity.y -= gravity * delta

	move_and_slide()

	if platform != null:
		_check_leave_deck()
	else:
		_try_board()
	if GameState.autopilot == "stress":
		_track_stress(delta)
	_footsteps(delta, Vector2(velocity.x, velocity.z).length(), is_on_floor() and not swimming)
	_update_focus()
	_update_give_target()
	_update_hold(delta)
	_update_placement()
	_finish_tick()


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
	if focus_id.ends_with(":ladder"):
		var boat: Boat = GameState.find_boat(focus_id.split(":")[1])
		if boat != null:
			climb_aboard(boat)
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
		if focus_id.begins_with("res:"):
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
	_ghost_valid = hit.normal.y > 0.8 and ground > 0.3 and hit.collider is StaticBody3D and not (hit.collider is Interactable)
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


func _update_paddle(input: Vector2, sprint: bool) -> void:
	var boat := platform if paddling else null
	if boat != _paddle_boat:
		if _paddle_boat != null and is_instance_valid(_paddle_boat):
			_paddle_boat.set_paddle_input.rpc_id(1, Vector2.ZERO, false)
		_paddle_boat = boat
		_paddle_sent = Vector2.ZERO
		_paddle_sprint_sent = false
	if boat != null and (input != _paddle_sent or sprint != _paddle_sprint_sent):
		boat.set_paddle_input.rpc_id(1, input, sprint)
		_paddle_sent = input
		_paddle_sprint_sent = sprint


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
	if platform is Sailboat and global_position.y - platform.proxy_xf.origin.y < Sailboat.DECK_Y - 0.2:
		level = 0.35
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
		for i in Inventory.HOTBAR_SIZE:
			var slot = survivor.inventory.slots[i]
			if slot != null and ItemTable.get_item(slot.id).get("category", "") == "food":
				survivor.select_slot(i)
				survivor.use_selected()
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
