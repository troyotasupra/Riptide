class_name StructureTable
extends RefCounted
## Camp structures placed from kits.
##   station: "cook" (needs fuel and fire) or "dry" (no fire)
##   warmth: °C added to the air you feel within warm_radius (fires)
##   shelter: °C added while under it (lean-to, tent) · sleep: can sleep here
##   container: storage slots · footprint: clearance radius when placing

const TYPES := {
	"campfire": {"name": "Campfire", "station": "cook", "warmth": 12.0, "warm_radius": 4.5, "footprint": 1.0},
	"lean_to": {"name": "Lean-to", "shelter": 5.0, "warm_radius": 2.0, "footprint": 2.0},
	"tent": {"name": "Tent", "shelter": 8.0, "warm_radius": 2.0, "sleep": true, "footprint": 2.2},
	"drying_rack": {"name": "Drying rack", "station": "dry", "footprint": 1.2},
	"storage_crate": {"name": "Storage crate", "container": [8, 5], "footprint": 1.0},
}


static func get_type(id: String) -> Dictionary:
	return TYPES.get(id, {})
