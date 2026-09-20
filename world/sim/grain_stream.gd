class_name GrainStream
extends GrainField
## The stream, as water grains. Along the stretch you are standing near, water
## is thrown into the simulation at the top and left to find its own way down:
## it falls, lands on the bed, runs downhill, and soaks away or reaches the sea.
## Further off, where you can't see a grain anyway, the bed's surface carries
## the look on its own.
##
## set_course() takes the stream's middle line, bed height and width.

## How far from the eye grains are worth simulating.
const REACH := 26.0
## Grains a second per metre of stream inside that reach.
const PER_METRE := 70.0
## Only this far apart along the line do we bother spawning.
const SPACING := 0.6

var _course: PackedVector3Array = PackedVector3Array()
var _width := 1.0
var _owed := 0.0


func _init(capacity: int = 2000) -> void:
	super(capacity)


## `points` runs from the pool down to the sea, each already at bed height.
func set_course(points: PackedVector3Array, width: float) -> void:
	_course = points
	_width = width


func _process(delta: float) -> void:
	_feed_course(minf(delta, 0.05))
	super(delta)


func _feed_course(delta: float) -> void:
	if _course.size() < 2:
		return
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		return
	var eye := camera.global_position
	# Spawn along the part of the course near the eye, in proportion to how much
	# of it is there — so walking along the bank doesn't change how full it runs.
	var near: Array[int] = []
	for i in _course.size() - 1:
		if _course[i].distance_to(eye) < REACH:
			near.append(i)
	if near.is_empty():
		return
	var length := float(near.size()) * SPACING
	_owed += length * PER_METRE * delta
	var owed := int(_owed)
	if owed <= 0:
		return
	_owed -= owed
	# Never more than the sim can hold, and leave room for the last lot.
	owed = mini(owed, maxi(0, sim.capacity - sim.count))
	for n in owed:
		var i: int = near[randi() % near.size()]
		var from := _course[i]
		var to := _course[mini(i + 1, _course.size() - 1)]
		var along := (to - from)
		var run := along.length()
		var direction := along / run if run > 0.001 else Vector3.FORWARD
		var side := direction.cross(Vector3.UP).normalized()
		var at := from + along * randf() + side * randf_range(-_width * 0.45, _width * 0.45)
		# It enters already moving the way the stream runs, and a little fast
		# where the bed drops away.
		var speed := 1.4 + maxf(0.0, -direction.y) * 6.0
		sim.spawn(GrainSim.WATER, at + Vector3.UP * 0.12, direction * speed + Vector3.UP * 0.2, 1.0)
