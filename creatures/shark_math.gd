class_name SharkMath
extends RefCounted
## Shark, downed and lost-limb rules, kept free of engine singletons so tests can check them.

const MAX_HEALTH := 90.0
const CRUISE_SPEED := 2.6
const CHASE_SPEED := 6.2
const TURN_RATE := 1.7
const AGGRO_RANGE := 24.0
const GIVE_UP_RANGE := 40.0
const BITE_RANGE := 1.9
const BITE_COOLDOWN := 2.8
const BITE_DAMAGE := 24.0
## Seabed higher than this is too shallow: sharks turn back, and swimmers there are safe.
const SHALLOWS := -2.2
const FLEE_SECONDS := 3.0
const RESPAWN_SECONDS := 300.0
const CARCASS_SECONDS := 25.0
const LOOT := [["raw_shark_meat", 3]]

const WEAPON_DAMAGE := {"spear": 32.0, "machete": 24.0, "hatchet": 18.0, "knife": 15.0}
const STRIKE_REACH := 3.6
const STRIKE_COOLDOWN := 0.45

## Bites within BITE_WINDOW seconds before a limb goes — fewer if you're already down.
const LIMB_BITES := 4
const LIMB_BITES_DOWNED := 2
const BITE_WINDOW := 60.0
const LIMBS := ["leg_r", "arm_l", "leg_l", "arm_r"]
const LIMB_NAMES := {"leg_l": "left leg", "leg_r": "right leg", "arm_l": "left arm", "arm_r": "right arm"}

## Downed: bleed out unless a crewmate revives you (faster alone — nobody's coming).
const DOWNED_SECONDS := 60.0
const DOWNED_SOLO_SECONDS := 6.0
const REVIVE_HEALTH := 30.0
const REVIVE_RANGE := 2.8
const REVIVE_HOLD := 3.0


## Can a shark go after someone? Only people in the water (swimming, or downed
## and floating), never anyone aboard a boat, and never in the shallows.
static func is_prey(swimming: bool, aboard: bool, downed_in_water: bool, seabed: float) -> bool:
	return (swimming or downed_in_water) and not aboard and seabed < SHALLOWS


## Damage a strike does with `tool`, weakened by a missing arm.
static func weapon_damage(tool: String, arm_strength: float = 1.0) -> float:
	return float(WEAPON_DAMAGE.get(tool, 0.0)) * arm_strength


## Does the bite that brings recent bites to `recent` cost a limb?
static func costs_limb(recent: int, downed: bool) -> bool:
	return recent >= (LIMB_BITES_DOWNED if downed else LIMB_BITES)


## The limb a shark takes; `roll` 0..1 picks among the ones still attached. "" if none are left.
static func limb_to_lose(missing: Array, roll: float) -> String:
	var attached: Array = LIMBS.filter(func(limb: String) -> bool: return not missing.has(limb))
	if attached.is_empty():
		return ""
	return attached[clampi(int(roll * attached.size()), 0, attached.size() - 1)]


## Walking and swimming speed from missing legs and fitted peg legs.
static func speed_factor(missing: Array, prosthetics: Array) -> float:
	var factor := 1.0
	for leg: String in ["leg_l", "leg_r"]:
		if missing.has(leg):
			factor *= 0.9 if prosthetics.has(leg) else 0.55
	return factor


## Strength of strikes and oar strokes from missing arms and fitted hooks.
static func arm_factor(missing: Array, prosthetics: Array) -> float:
	var factor := 1.0
	for arm: String in ["arm_l", "arm_r"]:
		if missing.has(arm):
			factor *= 0.85 if prosthetics.has(arm) else 0.6
	return factor


## Which missing limb a prosthetic of kind `fits` ("leg" or "arm") would go on. "" if none needs it.
static func prosthetic_limb(fits: String, missing: Array, prosthetics: Array) -> String:
	for limb: String in LIMBS:
		if limb.begins_with(fits) and missing.has(limb) and not prosthetics.has(limb):
			return limb
	return ""
