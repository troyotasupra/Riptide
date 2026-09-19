class_name Stairs
extends RefCounted
## Steps up to a doorway or a dock that you can't fail to climb: the treads you
## see sit over one smooth, invisible ramp at a walkable slope, so a player walks
## straight up it however the ground under it falls away. Each tread reaches down
## to the ground, so none of them floats. Every raised entrance uses these.
##
##   Stairs.build(parent, top, out, width, ground, tread_mat, side_mat)
##     top:    world point at the middle of the top edge (the doorsill, the dock's end)
##     out:    horizontal direction the stairs run down, away from the door
##     ground: Callable(x, z) -> ground height there

## The ramp's slope: comfortably under the player's 50° floor limit.
const SLOPE := deg_to_rad(30.0)
## How high one tread rises.
const RISE := 0.19
## The ramp runs this far on past where it meets the ground, into it, so there's
## no lip at the bottom either.
const OVERRUN := 0.4


## Adds the stairs to `parent` (which must sit at the world origin) and returns
## how far they run out from `top`. Nothing is added if the ground already meets `top`.
static func build(parent: Node3D, top: Vector3, out: Vector3, width: float, ground: Callable, tread_mat: Material, side_mat: Material = null) -> float:
	out.y = 0.0
	out = out.normalized()
	# Walk out until the ramp meets the ground.
	var run := 0.0
	var step := 0.05
	while run < 12.0:
		var p := top + out * run
		var ramp_y := top.y - run * tan(SLOPE)
		if ramp_y <= float(ground.call(p.x, p.z)) + 0.02:
			break
		run += step
	if run < 0.1:
		return 0.0
	var bottom := top + out * run - Vector3.UP * run * tan(SLOPE)
	var along := (bottom - top).normalized()
	var length := top.distance_to(bottom)

	# The ramp: a thin slab whose top face runs from the sill to the ground.
	var body := StaticBody3D.new()
	body.name = "StairRamp"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var slab := BoxShape3D.new()
	slab.size = Vector3(width, 0.1, length + OVERRUN)
	var collider := CollisionShape3D.new()
	collider.shape = slab
	var right := out.cross(Vector3.UP).normalized()
	var up := right.cross(along).normalized()
	if up.y < 0.0:
		up = -up
	var basis := Basis(right, up, -along).orthonormalized()
	var middle := top.lerp(bottom, 0.5) + along * OVERRUN * 0.5 - up * 0.05
	collider.transform = Transform3D(basis, middle)
	body.add_child(collider)
	parent.add_child(body)

	# The treads, each reaching down to the ground beneath it.
	var rise := top.y - bottom.y
	var count := maxi(1, ceili(rise / RISE))
	var tread_depth := run / count
	for i in count:
		var z := tread_depth * (i + 0.5)
		var p := top + out * z
		var tread_top := top.y - rise * float(i + 1) / count + rise / count * 0.5
		var under := float(ground.call(p.x, p.z))
		var height := maxf(0.06, tread_top - under + 0.15)
		var box := BoxMesh.new()
		box.size = Vector3(width, height, tread_depth + 0.04)
		var visual := MeshInstance3D.new()
		visual.mesh = box
		visual.material_override = tread_mat if side_mat == null else side_mat
		visual.transform = Transform3D(Basis.looking_at(out, Vector3.UP), Vector3(p.x, tread_top - height * 0.5, p.z))
		parent.add_child(visual)
		# A lighter tread board on top of each step.
		if side_mat != null:
			var board := BoxMesh.new()
			board.size = Vector3(width + 0.04, 0.05, tread_depth + 0.06)
			var top_board := MeshInstance3D.new()
			top_board.mesh = board
			top_board.material_override = tread_mat
			top_board.transform = Transform3D(Basis.looking_at(out, Vector3.UP), Vector3(p.x, tread_top + 0.01, p.z))
			parent.add_child(top_board)
	return run
