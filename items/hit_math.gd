class_name HitMath
extends RefCounted
## Whether a bullet's flight this tick passes through somebody.
##
## Bodies are treated as an upright capsule standing on their feet. Players
## aboard a boat walk on a deck proxy far below the world, so their physics
## body is nowhere near where they look — bullets are checked against this
## instead of against physics shapes.

## Shoulders-and-chest width of a standing person, and where a hit counts as
## the head (measured up from the feet).
const BODY_RADIUS := 0.32
const STANDING_HEIGHT := 1.78
const CROUCH_HEIGHT := 1.2
const HEAD_FROM_TOP := 0.26
## What a head hit multiplies a bullet's damage by.
const HEAD_MULTIPLIER := 2.5


## How far along the segment a->b the bullet first touches the body, or -1.0.
## `feet` is the ground point, `height` the standing height.
static func along_segment(a: Vector3, b: Vector3, feet: Vector3, height: float, radius: float = BODY_RADIUS) -> float:
	var travel := b - a
	var length := travel.length()
	if length < 0.0001:
		return -1.0
	# Work in the horizontal plane first: a standing body is a vertical column.
	# Everything below is in fractions of the segment.
	var to_body := feet - a
	var flat_travel := Vector2(travel.x, travel.z)
	var flat_to := Vector2(to_body.x, to_body.z)
	var flat_length := flat_travel.length()
	var closest := 0.0
	if flat_length < 0.0001:
		# Straight up or down: it's inside the column or it isn't.
		if flat_to.length() > radius:
			return -1.0
	else:
		var along := flat_to.dot(flat_travel) / (flat_length * flat_length)
		var miss := (flat_to - flat_travel * along).length()
		if miss > radius:
			return -1.0
		# Back up to where the column is first entered, not where it's nearest.
		closest = along - sqrt(maxf(radius * radius - miss * miss, 0.0)) / flat_length
	if closest > 1.0:
		return -1.0
	closest = maxf(closest, 0.0)
	var y := a.y + travel.y * closest
	# Inside the column: is it between the feet and the top of the head?
	if y < feet.y - 0.1 or y > feet.y + height:
		return -1.0
	return closest * length


## True if a hit that high up the body is a head shot.
static func is_head(hit_y: float, feet_y: float, height: float) -> bool:
	return hit_y > feet_y + height - HEAD_FROM_TOP


## Damage a bullet does to a body, given where it struck.
static func damage_for(base: float, hit_y: float, feet_y: float, height: float) -> float:
	return base * (HEAD_MULTIPLIER if is_head(hit_y, feet_y, height) else 1.0)
