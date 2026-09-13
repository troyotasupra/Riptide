class_name LoadoutMath
extends RefCounted
## How carried gear turns into movement and warmth. Dressing down to be quicker
## falls straight out of these curves — there is no special "light mode".

const FREE_WEIGHT_KG := 8.0     # carry this much with no penalty
const HEAVY_WEIGHT_KG := 40.0   # fully kitted: plates, helmet, rifle, pack
const MIN_SPEED_MULT := 0.6     # at HEAVY_WEIGHT_KG and beyond
const STAMINA_DRAIN_PER_KG := 1.0 / 25.0


static func speed_multiplier(weight_kg: float) -> float:
	var over := clampf((weight_kg - FREE_WEIGHT_KG) / (HEAVY_WEIGHT_KG - FREE_WEIGHT_KG), 0.0, 1.0)
	return lerpf(1.0, MIN_SPEED_MULT, over)


static func stamina_drain_multiplier(weight_kg: float) -> float:
	return 1.0 + maxf(0.0, weight_kg - FREE_WEIGHT_KG) * STAMINA_DRAIN_PER_KG


## Insulation from worn pieces combines with diminishing returns, so stacking
## layers helps but never makes you fully immune to arctic water.
static func combined_insulation(pieces: Array) -> float:
	var exposed := 1.0
	for value in pieces:
		exposed *= 1.0 - clampf(float(value), 0.0, 0.95)
	return 1.0 - exposed
