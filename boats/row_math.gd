class_name RowMath
extends RefCounted
## Rowing with a left and a right oar, kept free of engine singletons so tests
## can check it. Q strokes the left oar and E the right; both together (or
## alternating) drive straight ahead, one alone turns the boat away from it.
## A crew member sitting well to one side works only that side's oar, so two
## rowers can share a boat — one to port, one to starboard.

## Metres off the centreline before a rower counts as sitting on one side.
const SIDE_SEAT := 0.35
## A hard stroke (Shift) pulls this much harder...
const POWER := 1.7
## ...and costs this much stamina a second. Plain rowing is free and even lets
## you catch your breath, just slower than resting.
const POWER_STAMINA_COST := 4.5
const ROWING_STAMINA_REGEN := 8.0
## Oars from every rower together can't pull harder than this each.
const MAX_OAR := 2.2


## One rower's (left, right) oar effort from their strokes and where they sit.
## `left` / `right` are -1..1 (negative back-rows).
static func oars_for(left: float, right: float, seat_x: float) -> Vector2:
	left = clampf(left, -1.0, 1.0)
	right = clampf(right, -1.0, 1.0)
	if seat_x < -SIDE_SEAT:
		return Vector2(clampf(left + right, -1.0, 1.0), 0.0)
	if seat_x > SIDE_SEAT:
		return Vector2(0.0, clampf(left + right, -1.0, 1.0))
	return Vector2(left, right)


## (forward thrust, turn) from the summed oar efforts. Turn is positive
## counter-clockwise seen from above: a left-oar stroke alone turns right.
static func thrust(oars: Vector2) -> Vector2:
	var l := clampf(oars.x, -MAX_OAR, MAX_OAR)
	var r := clampf(oars.y, -MAX_OAR, MAX_OAR)
	return Vector2((l + r) * 0.5, (r - l) * 0.5)


## Seconds of hard rowing a full stamina bar buys.
static func power_seconds(stamina_max: float) -> float:
	return stamina_max / POWER_STAMINA_COST
