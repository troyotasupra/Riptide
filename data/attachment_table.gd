class_name AttachmentTable
extends RefCounted
## What you can bolt onto a gun, and what it costs you. Every one is an item you
## can find or build, and every one trades something away.
##
##   slot: optic | muzzle | underbarrel | magazine | stock | laser
##   fits: weapon ids, or empty for anything with that slot
##   zoom: magnification for optics (1 = none, and only optics above 1 get a real lens)
##   recoil / sway / spread / ads / reload: multipliers on the gun's own numbers
##   mag: extra rounds · quiet: how much of the noise it swallows (1 = silent)
##   wear: extra fouling per shot (a suppressor runs dirty)
##   weight: kg added to what you carry

const ATTACHMENTS := {
	# --- optics ---
	"red_dot": {"name": "Red dot", "slot": "optic", "zoom": 1.0, "ads": 0.95, "spread": 0.85, "weight": 0.12},
	"holo_sight": {"name": "Holographic sight", "slot": "optic", "zoom": 1.0, "ads": 1.0, "spread": 0.8, "weight": 0.18},
	"prism_3x": {"name": "3× prism", "slot": "optic", "zoom": 3.0, "ads": 1.15, "spread": 0.75, "sway": 1.1, "weight": 0.3},
	"lpvo_6x": {"name": "1–6× LPVO", "slot": "optic", "zoom": 6.0, "ads": 1.25, "spread": 0.7, "sway": 1.15, "weight": 0.42},
	"sniper_scope": {"name": "Sniper scope", "slot": "optic", "zoom": 10.0, "ads": 1.4, "spread": 0.6, "sway": 1.25,
		"fits": ["intervention", "m4"], "weight": 0.6},
	# --- muzzle ---
	"compensator": {"name": "Compensator", "slot": "muzzle", "recoil": 0.78, "weight": 0.1},
	"muzzle_brake": {"name": "Muzzle brake", "slot": "muzzle", "recoil": 0.65, "quiet": -0.25, "weight": 0.16},
	"suppressor": {"name": "Suppressor", "slot": "muzzle", "recoil": 0.9, "quiet": 0.8, "ads": 1.1, "wear": 0.0012, "weight": 0.45},
	# --- underbarrel ---
	"vertical_grip": {"name": "Vertical grip", "slot": "underbarrel", "recoil": 0.85, "ads": 1.05, "weight": 0.14},
	"angled_grip": {"name": "Angled grip", "slot": "underbarrel", "recoil": 0.93, "ads": 0.9, "weight": 0.11},
	"bipod": {"name": "Bipod", "slot": "underbarrel", "recoil": 0.7, "sway": 0.7, "ads": 1.2, "weight": 0.5},
	# --- magazine ---
	"extended_mag": {"name": "Extended magazine", "slot": "magazine", "mag": 10, "reload": 1.15, "weight": 0.25},
	"quickdraw_mag": {"name": "Quickdraw magazine", "slot": "magazine", "reload": 0.75, "weight": 0.08},
	# --- stock ---
	"light_stock": {"name": "Light stock", "slot": "stock", "ads": 0.85, "recoil": 1.12, "weight": 0.1},
	"heavy_stock": {"name": "Heavy stock", "slot": "stock", "recoil": 0.8, "sway": 0.85, "ads": 1.15, "weight": 0.55},
	"folding_stock": {"name": "Folding stock", "slot": "stock", "ads": 0.92, "sway": 1.05, "weight": 0.2},
	# --- rail ---
	"laser": {"name": "Laser", "slot": "laser", "spread": 0.8, "weight": 0.07},
	"flashlight": {"name": "Flashlight", "slot": "laser", "weight": 0.12},
}

## What each multiplier does when it isn't given.
const DEFAULTS := {"zoom": 1.0, "recoil": 1.0, "sway": 1.0, "spread": 1.0, "ads": 1.0, "reload": 1.0,
	"mag": 0, "quiet": 0.0, "wear": 0.0, "weight": 0.0}


static func get_attachment(id: String) -> Dictionary:
	return ATTACHMENTS.get(id, {})


static func exists(id: String) -> bool:
	return ATTACHMENTS.has(id)


## Can `attachment_id` go on `weapon_id`? It has to have the slot, and the
## attachment has to be happy on that gun.
static func fits(weapon_id: String, attachment_id: String) -> bool:
	var attachment := get_attachment(attachment_id)
	if attachment.is_empty():
		return false
	var weapon := WeaponTable.get_weapon(weapon_id)
	if weapon.is_empty() or not Array(weapon.get("slots", [])).has(attachment.slot):
		return false
	var only: Array = attachment.get("fits", [])
	return only.is_empty() or only.has(weapon_id)


## Everything that will go on `weapon_id`, in slot order.
static func for_weapon(weapon_id: String) -> Array[String]:
	var out: Array[String] = []
	for slot: String in WeaponTable.get_weapon(weapon_id).get("slots", []):
		for id: String in ATTACHMENTS:
			if ATTACHMENTS[id].slot == slot and fits(weapon_id, id):
				out.append(id)
	return out
