class_name WeaponMath
extends RefCounted
## How a gun handles: what its attachments make of it, how wide it shoots, how
## hard it kicks, how long it takes to aim and reload, and when it jams. Pure
## maths so the host, the shooter and the tests all agree.

## Moving spreads your shots this much more (radians at a full run).
const MOVE_SPREAD := 0.03
## Crouching steadies you; being winded doesn't.
const CROUCH_STEADY := 0.7
const WINDED_SPREAD := 0.02
const WINDED_SWAY := 1.6
## Each shot in a burst kicks a little harder than the last, up to this much.
const BURST_CLIMB := 0.07
const BURST_CLIMB_MAX := 2.2
## Sights wander this many degrees at sway 1.0, and breathe at this rate.
const SWAY_DEGREES := 0.55
const SWAY_RATE := 0.9
## Holding your breath steadies the sights this much, for this long.
const HOLD_BREATH_STEADY := 0.12
const HOLD_BREATH_SECONDS := 6.0


## A gun with its attachments fitted: every number the rest of the code needs.
static func stats(weapon_id: String, attachments: Dictionary = {}) -> Dictionary:
	var weapon := WeaponTable.get_weapon(weapon_id)
	if weapon.is_empty():
		return {}
	var out := {
		"id": weapon_id,
		"name": weapon.name,
		"caliber": weapon.caliber,
		"ammo": WeaponTable.ammo_item(weapon_id),
		"damage": float(weapon.damage),
		"pellets": int(weapon.get("pellets", 1)),
		"velocity": float(weapon.velocity),
		"interval": WeaponTable.shot_interval(weapon_id),
		"modes": Array(weapon.modes),
		"manual": WeaponTable.manual_action(weapon_id),
		"mag": int(weapon.mag),
		"chamber": bool(weapon.get("chamber", true)),
		"reload": float(weapon.reload),
		"reload_empty": float(weapon.reload_empty),
		"recoil_up": float(weapon.recoil[0]),
		"recoil_side": float(weapon.recoil[1]),
		"recoil_settle": float(weapon.recoil[2]),
		"sway": float(weapon.sway) * float(weapon.get("sway_scoped", 1.0)),
		"ads": float(weapon.ads),
		"hip_spread": float(weapon.spread[0]),
		"aim_spread": float(weapon.spread[1]),
		"zoom": float(weapon.get("zoom", 1.0)),
		"zoom_min": float(weapon.get("zoom_min", weapon.get("zoom", 1.0))),
		"quiet": float(weapon.get("quiet", 0.0)),
		"wear": WeaponTable.WEAR_PER_SHOT,
		"weight": 0.0,
		"attachments": {},
	}
	for slot: String in attachments:
		var id := String(attachments[slot])
		if id.is_empty() or not AttachmentTable.fits(weapon_id, id):
			continue
		var fitted := AttachmentTable.get_attachment(id)
		out.attachments[slot] = id
		if float(fitted.get("zoom", 1.0)) > out.zoom:
			out.zoom = float(fitted.get("zoom", 1.0))
			out.zoom_min = float(fitted.get("zoom_min", out.zoom))
		out.recoil_up *= float(fitted.get("recoil", 1.0))
		out.recoil_side *= float(fitted.get("recoil", 1.0))
		out.sway *= float(fitted.get("sway", 1.0))
		out.hip_spread *= float(fitted.get("spread", 1.0))
		out.aim_spread *= float(fitted.get("spread", 1.0))
		out.ads *= float(fitted.get("ads", 1.0))
		out.reload *= float(fitted.get("reload", 1.0))
		out.reload_empty *= float(fitted.get("reload", 1.0))
		out.mag += int(fitted.get("mag", 0))
		out.quiet = clampf(out.quiet + float(fitted.get("quiet", 0.0)), -1.0, 1.0)
		out.wear += float(fitted.get("wear", 0.0))
		out.weight += float(fitted.get("weight", 0.0))
	return out


## The cone a shot can land in, in radians. `aim` is 0 from the hip to 1 fully
## on the sights, `speed` is how fast you're moving, `winded` 0..1.
static func spread(gun: Dictionary, aim: float, speed: float, crouching: bool, winded: float) -> float:
	var base := lerpf(float(gun.hip_spread), float(gun.aim_spread), clampf(aim, 0.0, 1.0))
	var moving := MOVE_SPREAD * clampf(speed / 5.0, 0.0, 1.0) * lerpf(1.0, 0.45, clampf(aim, 0.0, 1.0))
	var total := base + moving + WINDED_SPREAD * clampf(winded, 0.0, 1.0)
	if crouching:
		total *= CROUCH_STEADY
	return maxf(0.0, total)


## Where the sights wander to at `time`, in degrees (x across, y up). Holding
## your breath pulls it in; `hold` is 0..1 of the breath you have left to give.
static func sway_at(gun: Dictionary, time: float, aim: float, hold: float, winded: float) -> Vector2:
	var amount := SWAY_DEGREES * float(gun.sway) * lerpf(1.0, 0.55, clampf(aim, 0.0, 1.0))
	amount *= lerpf(1.0, WINDED_SWAY, clampf(winded, 0.0, 1.0))
	amount *= lerpf(1.0, HOLD_BREATH_STEADY, clampf(hold, 0.0, 1.0))
	var t := time * SWAY_RATE
	return Vector2(sin(t * 1.3) * 0.6 + sin(t * 0.47) * 0.4, sin(t * 0.9) * 0.5 + sin(t * 0.31) * 0.5) * amount


## The kick from one shot, in degrees: x sideways, y up. `shots` is how many
## have gone already without a break, `roll` 0..1 decides which way it throws.
static func recoil_kick(gun: Dictionary, shots: int, roll: float) -> Vector2:
	var climb := minf(1.0 + shots * BURST_CLIMB, BURST_CLIMB_MAX)
	var up := float(gun.recoil_up) * climb
	var side := float(gun.recoil_side) * climb * (roll * 2.0 - 1.0)
	return Vector2(side, up)


## How much of the kick is still on the sights after `dt`.
static func settle(offset: Vector2, gun: Dictionary, dt: float) -> Vector2:
	return offset * exp(-float(gun.recoil_settle) * dt)


## Seconds to bring the sights up (or put them down).
static func ads_seconds(gun: Dictionary, carried_kg: float) -> float:
	return float(gun.ads) * (1.0 + clampf(carried_kg / 60.0, 0.0, 0.5))


## The powers a variable optic clicks through, low to high.
const ZOOM_STEPS: Array[float] = [1.0, 1.5, 2.0, 3.0, 4.0, 5.0, 6.0, 8.0, 10.0, 12.0]


## The next power up (`dir` 1) or down (-1) from `now`, kept within the optic's range.
static func step_zoom(now: float, dir: int, low: float, high: float) -> float:
	var steps: Array[float] = []
	for power in ZOOM_STEPS:
		if power >= low - 0.01 and power <= high + 0.01:
			steps.append(power)
	if steps.is_empty():
		return high
	var index := 0
	for i in steps.size():
		if absf(steps[i] - now) < absf(steps[index] - now):
			index = i
	return steps[clampi(index + dir, 0, steps.size() - 1)]


static func reload_seconds(gun: Dictionary, empty: bool) -> float:
	return float(gun.reload_empty if empty else gun.reload)


## The chance a round fails to go off. A cared-for gun almost never does; a
## neglected one starts to bite. `condition` is 1 fresh, 0 ruined.
static func jam_chance(condition: float) -> float:
	var wear := clampf((WeaponTable.CONDITION_NEGLECTED - clampf(condition, 0.0, 1.0)) / WeaponTable.CONDITION_NEGLECTED, 0.0, 1.0)
	return WeaponTable.JAM_BASE + WeaponTable.JAM_WORN * wear * wear


## Condition after firing a round.
static func wear_from_shot(gun: Dictionary, condition: float) -> float:
	return clampf(condition - float(gun.wear), 0.0, 1.0)


## How far a gun can be heard, in metres.
static func loudness(gun: Dictionary) -> float:
	var base := 240.0 + float(gun.damage) * 1.6
	return base * clampf(1.0 - float(gun.quiet), 0.15, 1.4)


## What the next fire mode is, wrapping round the list.
static func next_mode(gun: Dictionary, mode: String) -> String:
	var modes: Array = gun.modes
	if modes.size() <= 1:
		return String(modes[0]) if not modes.is_empty() else mode
	var index := modes.find(mode)
	return String(modes[(index + 1) % modes.size()])
