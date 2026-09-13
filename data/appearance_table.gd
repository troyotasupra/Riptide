class_name AppearanceTable
extends RefCounted
## Everything a player can choose about how they look, plus crew colours and
## emblems. A "look" is a small Dictionary of option indices, so it is cheap to
## send over the network and safe to clamp when it arrives.

const SKIN := [
	Color(0.98, 0.85, 0.74), Color(0.94, 0.76, 0.62), Color(0.84, 0.64, 0.48), Color(0.72, 0.52, 0.36),
	Color(0.57, 0.39, 0.25), Color(0.42, 0.28, 0.18), Color(0.30, 0.20, 0.13),
]
const HAIR_COLORS := [
	Color(0.07, 0.06, 0.05), Color(0.24, 0.15, 0.09), Color(0.44, 0.29, 0.15), Color(0.70, 0.53, 0.30),
	Color(0.90, 0.80, 0.55), Color(0.56, 0.21, 0.10), Color(0.60, 0.60, 0.60), Color(0.92, 0.92, 0.90),
]
const EYE_COLORS := [Color(0.25, 0.15, 0.08), Color(0.33, 0.52, 0.24), Color(0.25, 0.45, 0.72), Color(0.45, 0.45, 0.48)]
const CREW_COLORS := [
	Color(0.78, 0.18, 0.16), Color(0.94, 0.53, 0.12), Color(0.93, 0.80, 0.22), Color(0.24, 0.56, 0.28),
	Color(0.16, 0.52, 0.66), Color(0.18, 0.28, 0.62), Color(0.48, 0.24, 0.58), Color(0.14, 0.14, 0.16),
	Color(0.90, 0.90, 0.88),
]

const BODIES := ["Masculine", "Feminine"]
const BUILDS := ["Slim", "Average", "Broad"]
const HEIGHTS := ["Short", "Below average", "Average", "Above average", "Tall"]
const FACES := ["Round", "Square", "Narrow"]
const HAIR_STYLES := ["Bald", "Buzz cut", "Short", "Swept back", "Long", "Ponytail", "Mohawk", "Bun"]
const BEARDS := ["None", "Stubble", "Goatee", "Full beard", "Moustache"]
const CREW_COLOR_NAMES := ["Red", "Orange", "Yellow", "Green", "Teal", "Navy", "Purple", "Black", "White"]
const EMBLEMS := ["None", "Star", "Anchor", "Skull", "Wave", "Compass", "Diamond", "Chevron"]

## key -> [label, option names or colour count]
const FIELDS := [
	["body", "Body", BODIES],
	["build", "Build", BUILDS],
	["height", "Height", HEIGHTS],
	["skin", "Skin tone", 7],
	["face", "Face", FACES],
	["eyes", "Eye colour", 4],
	["hair", "Hair", HAIR_STYLES],
	["hair_color", "Hair colour", 8],
	["beard", "Facial hair", BEARDS],
]

const DEFAULT_LOOK := {"body": 0, "build": 1, "height": 2, "skin": 2, "face": 0, "eyes": 0, "hair": 2, "hair_color": 1, "beard": 0}


static func option_count(key: String) -> int:
	for field: Array in FIELDS:
		if field[0] == key:
			return field[2] if field[2] is int else (field[2] as Array).size()
	return 0


static func option_name(key: String, index: int) -> String:
	for field: Array in FIELDS:
		if field[0] == key:
			return String(field[2][index]) if field[2] is Array else "%d" % (index + 1)
	return ""


## Clamps anything received from the network or a file into valid options.
static func sanitize(look: Variant) -> Dictionary:
	var clean := DEFAULT_LOOK.duplicate()
	if look is Dictionary:
		for key: String in DEFAULT_LOOK:
			if look.has(key):
				clean[key] = clampi(int(look[key]), 0, option_count(key) - 1)
	return clean


static func height_scale(look: Dictionary) -> float:
	return 0.92 + 0.04 * int(look.get("height", 2))


static func crew_color(index: int) -> Color:
	return CREW_COLORS[clampi(index, 0, CREW_COLORS.size() - 1)]
