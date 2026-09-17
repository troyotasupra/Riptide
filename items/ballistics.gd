class_name Ballistics
extends RefCounted
## Bullets in flight. They are not instant: a round takes time to arrive and
## falls on the way, so at distance you lead a moving target and hold over a
## still one. Pure maths, so the host's shots and the tests agree.

const GRAVITY := 9.8
## Air drag, as a fraction of speed lost per metre travelled. Small, but it
## matters over a few hundred metres.
const DRAG := 0.0009
## Bullets give up after this far or this long, whichever comes first.
const MAX_RANGE := 900.0
const MAX_FLIGHT := 4.0


## Moves a bullet on by `dt`, returning where it got to and how fast it's going.
static func step(position: Vector3, velocity: Vector3, dt: float) -> Array:
	var speed := velocity.length()
	var slowed := velocity * maxf(0.0, 1.0 - DRAG * speed * dt)
	slowed.y -= GRAVITY * dt
	return [position + slowed * dt, slowed]


## Roughly how long a round takes to cover `distance` (drag included).
static func flight_time(distance: float, muzzle_speed: float) -> float:
	if muzzle_speed <= 0.0:
		return INF
	# Speed decays with distance; integrating gives this.
	var loss := DRAG * distance
	if loss < 0.001:
		return distance / muzzle_speed
	return (exp(loss) - 1.0) / (DRAG * muzzle_speed)


## How far a round falls over `distance` if the barrel is level.
static func drop(distance: float, muzzle_speed: float) -> float:
	var t := flight_time(distance, muzzle_speed)
	return 0.5 * GRAVITY * t * t


## How far above the line of sight the barrel sits so the round arrives on the
## crosshair at `zero_distance`.
static func zero_pitch(muzzle_speed: float, zero_distance: float) -> float:
	var t := flight_time(zero_distance, muzzle_speed)
	if t == INF or zero_distance <= 0.0:
		return 0.0
	return atan2(0.5 * GRAVITY * t * t, zero_distance)


## The way the barrel actually points when the sights are on `look`: the same
## direction, tipped up by the zero.
static func aim_direction(look: Vector3, muzzle_speed: float, zero_distance: float) -> Vector3:
	var pitch := zero_pitch(muzzle_speed, zero_distance)
	if pitch == 0.0:
		return look.normalized()
	var flat := Vector3(look.x, 0.0, look.z)
	if flat.length() < 0.001:
		return look.normalized()
	var side := flat.normalized().cross(Vector3.UP)
	return look.normalized().rotated(side.normalized(), pitch).normalized()


## Nudges a shot off the sights by up to `spread` radians. `roll` and `turn`
## are 0..1, so a shot can be replayed exactly.
static func scatter(direction: Vector3, spread: float, roll: float, turn: float) -> Vector3:
	if spread <= 0.0:
		return direction.normalized()
	var forward := direction.normalized()
	var side := forward.cross(Vector3.UP)
	if side.length() < 0.001:
		side = forward.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := side.cross(forward).normalized()
	# Square-rooted so shots cluster toward the middle rather than the rim.
	var angle := spread * sqrt(clampf(roll, 0.0, 1.0))
	var around := turn * TAU
	var offset := side * cos(around) * angle + up * sin(around) * angle
	return (forward + offset).normalized()
