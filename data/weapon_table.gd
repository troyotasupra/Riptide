class_name WeaponTable
extends RefCounted
## The guns, in one readable table. Nothing here touches the engine, so the
## handling maths can be checked in headless tests.
##
##   caliber: which rounds it eats (they never interchange)
##   damage: per bullet at the muzzle · pellets: more than one for buckshot
##   velocity: muzzle speed in m/s — bullets take time to arrive and drop on the way
##   rpm: rounds per minute while the trigger is down (bolt and pump guns cycle by hand)
##   modes: "semi", "auto", "bolt", "pump" — the first is what it starts on
##   mag: rounds in a fresh magazine · reload / reload_empty: seconds, the longer one
##     when the chamber ran dry · chamber: keeps one up the spout on a tactical reload
##   recoil: [up per shot, sideways per shot, how fast it settles]
##   sway: how much the sights wander unaided · ads: seconds to bring them up
##   spread: radians of cone from the hip, and aimed
##   slots: what you can fit to it (see AttachmentTable)

const CALIBERS := {
	"45acp": {"name": ".45 ACP", "item": "ammo_45"},
	"9mm": {"name": "9mm", "item": "ammo_9mm"},
	"556": {"name": "5.56", "item": "ammo_556"},
	"12ga": {"name": "12 gauge", "item": "ammo_12ga"},
	"408": {"name": ".408", "item": "ammo_408"},
}

const WEAPONS := {
	"m1911": {
		"name": "M1911", "caliber": "45acp", "damage": 36.0, "velocity": 253.0, "rpm": 400.0,
		"modes": ["semi"], "mag": 7, "reload": 2.1, "reload_empty": 2.8, "chamber": true,
		"recoil": [1.5, 0.5, 9.0], "sway": 1.0, "ads": 0.20, "spread": [0.032, 0.004],
		"slots": ["optic", "muzzle", "laser"],
	},
	"uzi": {
		"name": "Uzi", "caliber": "9mm", "damage": 25.0, "velocity": 340.0, "rpm": 600.0,
		"modes": ["auto", "semi"], "mag": 32, "reload": 2.4, "reload_empty": 3.1, "chamber": true,
		"recoil": [1.1, 0.7, 7.5], "sway": 1.15, "ads": 0.24, "spread": [0.045, 0.007],
		"slots": ["optic", "muzzle", "magazine", "stock", "laser"],
	},
	"m4": {
		"name": "M4", "caliber": "556", "damage": 38.0, "velocity": 880.0, "rpm": 750.0,
		"modes": ["auto", "semi"], "mag": 30, "reload": 2.6, "reload_empty": 3.4, "chamber": true,
		"recoil": [1.3, 0.45, 8.0], "sway": 1.0, "ads": 0.28, "spread": [0.038, 0.0025],
		"slots": ["optic", "muzzle", "underbarrel", "magazine", "stock", "laser"],
	},
	"mossberg": {
		"name": "Mossberg", "caliber": "12ga", "damage": 13.0, "pellets": 9, "velocity": 400.0, "rpm": 75.0,
		"modes": ["pump"], "mag": 5, "reload": 0.7, "reload_empty": 0.9, "chamber": false,
		"recoil": [3.4, 0.9, 6.0], "sway": 1.25, "ads": 0.32, "spread": [0.075, 0.045],
		"slots": ["optic", "muzzle", "stock", "laser"],
	},
	"intervention": {
		"name": "Intervention", "caliber": "408", "damage": 125.0, "velocity": 910.0, "rpm": 45.0,
		"modes": ["bolt"], "mag": 5, "reload": 3.4, "reload_empty": 4.0, "chamber": false,
		"recoil": [5.5, 1.0, 5.0], "sway": 1.5, "ads": 0.45, "spread": [0.09, 0.0008],
		# Its scope is part of the gun (and the model): no optic slot to fit another.
		"zoom": 10.0, "sway_scoped": 1.25,
		"slots": ["muzzle", "underbarrel", "magazine", "stock"],
	},
}

## Guns are sighted in at this range: aim at something this far off and the
## bullet arrives where the sights say.
const ZERO_DISTANCE := 60.0
## A gun in perfect nick still jams once in a long while; a neglected one much more.
const JAM_BASE := 0.0008
const JAM_WORN := 0.06
## Condition below this counts as neglected, and jams climb from there.
const CONDITION_NEGLECTED := 0.45
## Cleaning a gun costs a rag and brings it back to this.
const CLEANED_CONDITION := 1.0
## Every shot wears a gun a little; a suppressor fouls it faster.
const WEAR_PER_SHOT := 0.0016


static func get_weapon(id: String) -> Dictionary:
	return WEAPONS.get(id, {})


static func exists(id: String) -> bool:
	return WEAPONS.has(id)


## The ammunition item a gun eats, e.g. "ammo_556".
static func ammo_item(id: String) -> String:
	var caliber: String = WEAPONS.get(id, {}).get("caliber", "")
	return String(CALIBERS.get(caliber, {}).get("item", ""))


## Seconds between shots with the trigger held down.
static func shot_interval(id: String) -> float:
	var rpm: float = WEAPONS.get(id, {}).get("rpm", 300.0)
	return 60.0 / maxf(1.0, rpm)


## Does this gun work its own action, or do you have to?
static func manual_action(id: String) -> bool:
	var modes: Array = WEAPONS.get(id, {}).get("modes", [])
	return modes.has("bolt") or modes.has("pump")
