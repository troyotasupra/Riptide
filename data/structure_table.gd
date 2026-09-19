class_name StructureTable
extends RefCounted
## Camp structures placed from kits.
##   station: "cook" (needs fuel and fire) or "dry" (no fire)
##   warmth: °C added to the air you feel within warm_radius (fires)
##   shelter: °C added while under it (lean-to, tent) · sleep: can sleep here
##   container: storage slots · footprint: clearance radius when placing
##   stages: a build site — materials added in order, [{"item", "count"}, ...]
##   launches: what the finished build site becomes (hold F to launch it)
##   shore: must be placed on the beach, near open water
##   hp: how much punishment it takes before it collapses (weapons, fire)
##
## Everything built can be taken down again: dismantling returns DISMANTLE_SHARE
## of what went into it, a collapse only COLLAPSE_SHARE.

const TYPES := {
	"campfire": {"name": "Campfire", "station": "cook", "warmth": 12.0, "warm_radius": 4.5, "footprint": 1.0, "hp": 60.0,
		"stages": [{"item": "stone", "count": 4}, {"item": "wood", "count": 3}]},
	"lean_to": {"name": "Lean-to", "shelter": 5.0, "warm_radius": 2.0, "footprint": 2.0, "hp": 80.0},
	"tent": {"name": "Tent", "shelter": 8.0, "warm_radius": 2.0, "sleep": true, "footprint": 2.2, "hp": 70.0,
		"stages": [{"item": "tarp", "count": 1}, {"item": "rope", "count": 3}]},
	"drying_rack": {"name": "Drying rack", "station": "dry", "footprint": 1.2, "hp": 70.0},
	"storage_crate": {"name": "Storage crate", "container": [8, 5], "footprint": 1.0, "hp": 150.0},
	"raft_site": {"name": "Raft", "footprint": 2.4, "shore": true, "launches": "raft", "hp": 120.0,
		"stages": [{"item": "log", "count": 6}, {"item": "rope", "count": 3}]},
}

const DISMANTLE_SHARE := 0.75
const COLLAPSE_SHARE := 0.25
const DISMANTLE_SECONDS := 3.0

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


## Built and working: every stage done (anything without stages always is).
static func is_finished(type: String, progress: Dictionary) -> bool:
	return next_stage(type, progress).is_empty()


## E on it adds materials (or, once a boat is finished, pushes it off).
static func takes_work(type: String, progress: Dictionary) -> bool:
	return is_build_site(type) and (not is_finished(type, progress) or TYPES[type].has("launches"))


static func max_hp(type: String) -> float:
	return float(TYPES.get(type, {}).get("hp", 80.0))


## The kit item that places `type`.
static func kit_for(type: String) -> String:
	for id: String in ItemTable.ITEMS:
		if String(ItemTable.ITEMS[id].get("places", "")) == type:
			return id
	return ""


## Everything that has gone into it so far: its kit's recipe plus the stages built.
## Groups ("wood") come back as their first member (driftwood).
static func cost(type: String, progress: Dictionary) -> Dictionary:
	var total := {}
	var kit := kit_for(type)
	for recipe_id: String in RecipeTable.RECIPES:
		var recipe: Dictionary = RecipeTable.RECIPES[recipe_id]
		if recipe.makes == kit and not kit.is_empty():
			for need: String in recipe.needs:
				_add(total, need, int(recipe.needs[need]))
			break
	for stage: Dictionary in TYPES.get(type, {}).get("stages", []):
		_add(total, stage.item, mini(int(progress.get(stage.item, 0)), int(stage.count)))
	return total


## What you get back: `share` of each material, rounded down — but a careful
## dismantle always saves at least one of anything that went in.
static func refund(type: String, progress: Dictionary, share: float) -> Dictionary:
	var back := {}
	var spent := cost(type, progress)
	for item: String in spent:
		var n := int(floor(int(spent[item]) * share))
		if share >= DISMANTLE_SHARE and int(spent[item]) > 0:
			n = maxi(n, 1)
		if n > 0:
			back[item] = n
	return back


static func _add(total: Dictionary, need: String, count: int) -> void:
	if count <= 0:
		return
	var item: String = ItemTable.GROUPS[need][0] if ItemTable.GROUPS.has(need) else need
	total[item] = int(total.get(item, 0)) + count
