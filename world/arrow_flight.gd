class_name ArrowFlight
extends Node3D
## An arrow you can see in flight: it follows the same drop and drag as the
## host's projectile (Ballistics), points along its path, and sticks where it
## lands, quivering, then fades after a while. Every peer draws its own.

const STUCK_SECONDS := 25.0

var _velocity := Vector3.ZERO
var _flying := true
var _age := 0.0
var _stuck_for := 0.0
var _quiver := 0.0


static func launch(from: Vector3, velocity: Vector3) -> void:
	var world := GameState.world
	if world == null or DisplayServer.get_name() == "headless":
		return
	var arrow := ArrowFlight.new()
	world.add_child(arrow)
	arrow.global_position = from
	arrow._velocity = velocity
	# The arrow model points along its own +Y; turn that to face along the flight.
	var model := ItemModels.build("arrow")
	model.position = Vector3(0.0, -0.62, 0.0)
	arrow.add_child(model)
	arrow._face(velocity)


func _face(direction: Vector3) -> void:
	if direction.length() < 0.01:
		return
	var y := direction.normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	global_basis = Basis(x, y, x.cross(y))


func _physics_process(delta: float) -> void:
	_age += delta
	if not _flying:
		_stuck_for += delta
		# A short quiver as it bites, then still.
		if _quiver > 0.0:
			_quiver = maxf(0.0, _quiver - delta * 3.0)
			rotation.z += sin(_stuck_for * 60.0) * 0.02 * _quiver
		if _stuck_for > STUCK_SECONDS:
			queue_free()
		return
	var next: Array = Ballistics.step(global_position, _velocity, delta)
	var to: Vector3 = next[0]
	var query := PhysicsRayQueryParameters3D.create(global_position, to, Layers.WORLD | Layers.BOATS | Layers.INTERACT)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		# The head sinks in a hand's width.
		global_position = Vector3(hit.position) - _velocity.normalized() * 0.1
		_flying = false
		_quiver = 1.0
		var body := hit.collider as Node
		if body is Boat or (body is Interactable and String((body as Interactable).interact_id).begins_with("shark:")):
			# Ride along with whatever it struck (a shark, a boat).
			reparent(body, true)
		return
	if to.y < Waves.height_at(Vector2(to.x, to.z), Ocean.time):
		queue_free()
		return
	global_position = to
	_velocity = next[1]
	_face(_velocity)
	if _age > Ballistics.MAX_FLIGHT:
		queue_free()
