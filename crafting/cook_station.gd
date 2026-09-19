class_name CookStation
extends RefCounted
## Pure rules for anything that transforms food over time: campfires and the
## galley stove ("cook" — needs fuel and a lit fire), drying racks ("dry") and
## compost bins ("compost": spoiled food rots down to soil).
## Slots hold {"id": input, "result": output, "done_at": ocean clock time}.

const SLOTS := 3
const COOK_SECONDS := 25.0
const DRY_SECONDS := 240.0
const COMPOST_SECONDS := 600.0
const MAX_FUEL := 600.0

var mode := "cook"
var fuel := 0.0
var lit := false
var slots: Array = []


func _init(p_mode: String = "cook") -> void:
	mode = p_mode
	slots.resize(SLOTS)


func needs_fire() -> bool:
	return mode == "cook"


## What this station turns `id` into, or "" if it can't.
func result_for(id: String) -> String:
	var item := ItemTable.get_item(id)
	if mode == "dry":
		return item.get("dries_to", "")
	if mode == "compost":
		return item.get("composts_to", "")
	return item.get("cooks_to", item.get("boils_to", ""))


func add_fuel(seconds: float) -> bool:
	if not needs_fire() or fuel >= MAX_FUEL:
		return false
	fuel = minf(MAX_FUEL, fuel + seconds)
	return true


func light() -> bool:
	if not needs_fire() or lit or fuel <= 0.0:
		return false
	lit = true
	return true


func has_free_slot() -> bool:
	return slots.has(null)


## Puts one `id` on to cook or dry. False if it can't go on right now.
func start(id: String, now: float) -> bool:
	var result := result_for(id)
	if result.is_empty() or (needs_fire() and not lit):
		return false
	var index := slots.find(null)
	if index == -1:
		return false
	var duration := COOK_SECONDS if mode == "cook" else (COMPOST_SECONDS if mode == "compost" else DRY_SECONDS)
	slots[index] = {"id": id, "result": result, "done_at": now + duration}
	return true


## Burns fuel; an unlit fire pauses whatever is on it.
func tick(delta: float) -> void:
	if not needs_fire():
		return
	if lit:
		fuel -= delta
		if fuel <= 0.0:
			fuel = 0.0
			lit = false
	if not lit:
		for slot in slots:
			if slot != null:
				slot.done_at += delta


func has_done(now: float) -> bool:
	for slot in slots:
		if slot != null and now >= slot.done_at:
			return true
	return false


func is_busy() -> bool:
	for slot in slots:
		if slot != null:
			return true
	return false


## Removes and returns the finished results.
func take_done(now: float) -> Array[String]:
	var done: Array[String] = []
	for i in SLOTS:
		var slot = slots[i]
		if slot != null and now >= slot.done_at:
			done.append(slot.result)
			slots[i] = null
	return done


## Times are stored relative to `now` so they survive a save and a new clock.
func to_dict(now: float) -> Dictionary:
	var saved: Array = []
	for slot in slots:
		saved.append(null if slot == null else {"id": slot.id, "result": slot.result, "remaining": maxf(0.0, slot.done_at - now)})
	return {"mode": mode, "fuel": fuel, "lit": lit, "slots": saved}


func from_dict(data: Dictionary, now: float) -> void:
	mode = data.get("mode", mode)
	fuel = data.get("fuel", 0.0)
	lit = data.get("lit", false)
	slots.clear()
	slots.resize(SLOTS)
	var saved: Array = data.get("slots", [])
	for i in mini(SLOTS, saved.size()):
		var slot = saved[i]
		if slot != null:
			slots[i] = {"id": slot.id, "result": slot.result, "done_at": now + float(slot.remaining)}
