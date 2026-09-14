class_name StructureTable
extends RefCounted
## Camp structures placed from kits.
##   station: "cook" (needs fuel and fire) or "dry" (no fire)
##   warmth: °C added to the air you feel within warm_radius (fires)
##   shelter: °C added while under it (lean-to, tent) · sleep: can sleep here
##   container: storage slots · footprint: clearance radius when placing
##   stages: a build site — materials added in order, [{"item", "count"}, ...]
##   launches: what the finished build site becomes (hold E to launch it)
##   shore: must be placed on the beach, near open water

const TYPES := {
	"campfire": {"name": "Campfire", "station": "cook", "warmth": 12.0, "warm_radius": 4.5, "footprint": 1.0},
	"lean_to": {"name": "Lean-to", "shelter": 5.0, "warm_radius": 2.0, "footprint": 2.0},
	"tent": {"name": "Tent", "shelter": 8.0, "warm_radius": 2.0, "sleep": true, "footprint": 2.2},
	"drying_rack": {"name": "Drying rack", "station": "dry", "footprint": 1.2},
	"storage_crate": {"name": "Storage crate", "container": [8, 5], "footprint": 1.0},
	"raft_site": {"name": "Raft", "footprint": 2.4, "shore": true, "launches": "raft",
		"stages": [{"item": "log", "count": 6}, {"item": "rope", "count": 3}]},
}

## The highest ground a shore structure can be placed on.
const SHORE_MAX_HEIGHT := 2.4


static func get_type(id: String) -> Dictionary:
	return TYPES.get(id, {})


## The first stage of build site `type` still missing materials, or {} when it's finished.
static func next_stage(type: String, progress: Dictionary) -> Dictionary:
	for stage: Dictionary in TYPES.get(type, {}).get("stages", []):
		if int(progress.get(stage.item, 0)) < int(stage.count):
			return stage
	return {}


static func is_build_site(type: String) -> bool:
	return TYPES.get(type, {}).has("stages")


## 0..1 of the way through every stage.
static func build_fraction(type: String, progress: Dictionary) -> float:
	var need := 0
	var have := 0
	for stage: Dictionary in TYPES.get(type, {}).get("stages", []):
		need += int(stage.count)
		have += mini(int(progress.get(stage.item, 0)), int(stage.count))
	return 1.0 if need == 0 else float(have) / need
