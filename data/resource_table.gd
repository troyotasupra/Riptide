class_name ResourceTable
extends RefCounted
## What each harvestable prop gives, how long it takes, and when it comes back.
##   yields: [[item_id, min, max], ...]   respawn: seconds on the ocean clock
##   seconds: how long to hold E by hand (0 = instant)
##   tool_speed: {tool type: speed multiplier} — the best tool you carry counts
##   needs: shown when it can't be gathered yet (e.g. no hatchet)
## Kinds not listed here (like "rock") are scenery.

const KINDS := {
	"palm": {"label": "Shake the palm for coconuts", "depleted_label": "No coconuts left up there", "yields": [["coconut", 1, 2]], "respawn": 600.0, "seconds": 1.0},
	"tree": {"label": "Tree", "needs": "You'll need a hatchet to fell this.", "yields": []},
	"berry_bush": {"label": "Pick berries", "depleted_label": "Picked clean", "yields": [["berries", 3, 6]], "respawn": 420.0, "seconds": 1.5},
	"red_berry_bush": {"label": "Pick red berries", "depleted_label": "Picked clean", "yields": [["red_berries", 3, 6]], "respawn": 420.0, "seconds": 1.5},
	"fiber": {"label": "Cut plant fiber", "yields": [["fiber", 2, 4]], "respawn": 300.0, "seconds": 3.0, "tool_speed": {"knife": 2.0, "machete": 6.0}},
	"stone": {"label": "Pick up stone", "yields": [["stone", 1, 1]], "respawn": 900.0},
	"flint": {"label": "Pick up flint", "yields": [["flint", 1, 1]], "respawn": 900.0},
	"driftwood": {"label": "Pick up driftwood", "yields": [["driftwood", 1, 2]], "respawn": 900.0},
}


## How long gathering `kind` takes for someone carrying these tool types.
static func harvest_seconds(kind: String, tools: Array) -> float:
	var info: Dictionary = KINDS.get(kind, {})
	var base: float = info.get("seconds", 0.0)
	var speeds: Dictionary = info.get("tool_speed", {})
	var best := 1.0
	for tool in tools:
		best = maxf(best, float(speeds.get(tool, 1.0)))
	return base / best
