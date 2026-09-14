class_name ResourceTable
extends RefCounted
## What each harvestable prop gives, how long it takes, and when it comes back.
##   yields: [[item_id, min, max], ...]   respawn: seconds on the ocean clock
##   seconds: how long to hold E (or swing a tool) by hand (0 = instant)
##   tool_speed: {tool type: speed multiplier} — the best tool you carry counts
##   requires: a tool type you must carry at all (the tree needs a hatchet)
## Kinds not listed here (like "rock") are scenery.

const KINDS := {
	"palm": {"label": "Shake the palm for coconuts", "depleted_label": "No coconuts left up there", "yields": [["coconut", 1, 2]], "respawn": 600.0, "seconds": 1.0},
	"tree": {"label": "Chop the tree", "depleted_label": "Just a stump now — it'll grow back", "needs": "You'll need a stone hatchet to fell this — make one from wood, flint and rope (B).", "requires": "hatchet", "yields": [["log", 2, 3]], "respawn": 700.0, "seconds": 4.0},
	"berry_bush": {"label": "Pick berries", "depleted_label": "Picked clean", "yields": [["berries", 3, 6]], "respawn": 420.0, "seconds": 1.5, "tool_speed": {"knife": 1.5, "machete": 2.0}},
	"red_berry_bush": {"label": "Pick red berries", "depleted_label": "Picked clean", "yields": [["red_berries", 3, 6]], "respawn": 420.0, "seconds": 1.5, "tool_speed": {"knife": 1.5, "machete": 2.0}},
	"fiber": {"label": "Cut plant fiber", "depleted_label": "Cut back — it'll grow again soon", "yields": [["fiber", 3, 4]], "respawn": 240.0, "seconds": 3.0, "tool_speed": {"knife": 2.0, "machete": 6.0}},
	"stone": {"label": "Pick up stone", "yields": [["stone", 1, 1]], "respawn": 900.0},
	"flint": {"label": "Pick up flint", "yields": [["flint", 1, 1]], "respawn": 900.0},
	"driftwood": {"label": "Pick up driftwood", "yields": [["driftwood", 1, 2]], "respawn": 900.0},
}


## How long gathering `kind` takes for someone carrying these tool types,
## or -1 if they lack a tool it requires.
static func harvest_seconds(kind: String, tools: Array) -> float:
	var info: Dictionary = KINDS.get(kind, {})
	var required: String = info.get("requires", "")
	if not required.is_empty() and not tools.has(required):
		return -1.0
	var base: float = info.get("seconds", 0.0)
	var speeds: Dictionary = info.get("tool_speed", {})
	var best := 1.0
	for tool in tools:
		best = maxf(best, float(speeds.get(tool, 1.0)))
	return base / best
