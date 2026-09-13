class_name Equipment
extends RefCounted
## What a crew member is wearing. Each slot holds one inventory stack (or
## nothing). Worn clothing sets warmth; worn gear adds weight and armour. The
## visible character is built from `ids()`.

const SLOTS := ["head", "torso", "vest", "legs", "feet", "back"]
const SLOT_NAMES := {"head": "Head", "torso": "Torso", "vest": "Vest", "legs": "Legs", "feet": "Feet", "back": "Back"}
## Everyone washes up wearing this.
const STARTING_OUTFIT := ["tshirt", "shorts", "sandals", "satchel"]

var worn := {}


static func slot_for(id: String) -> String:
	return ItemTable.get_item(id).get("slot", "")


## Puts `stack` on. Returns whatever was in that slot before (empty if nothing).
func wear(stack: Dictionary) -> Dictionary:
	var slot := slot_for(stack.get("id", ""))
	if slot.is_empty():
		return {}
	var previous: Dictionary = worn.get(slot, {})
	var one := stack.duplicate()
	one.count = 1
	if int(one.get("uid", 0)) == 0:
		one.uid = ItemGrid.new_uid()  # so worn gear can be dragged like anything else
	worn[slot] = one
	return previous


func take_off(slot: String) -> Dictionary:
	var stack: Dictionary = worn.get(slot, {})
	worn.erase(slot)
	return stack


func is_wearing(slot: String) -> bool:
	return worn.has(slot)


## 0..1 protection from the cold, layered with diminishing returns.
func insulation() -> float:
	var pieces: Array = []
	for stack: Dictionary in worn.values():
		pieces.append(float(ItemTable.get_item(stack.id).get("insulation", 0.0)))
	return LoadoutMath.combined_insulation(pieces)


func weight() -> float:
	var total := 0.0
	for stack: Dictionary in worn.values():
		total += float(ItemTable.get_item(stack.id).get("weight", 0.0))
	return total


## Armour class of the piece protecting `slot` ("head" or "vest"), 0 if none.
func armor(slot: String) -> int:
	var stack: Dictionary = worn.get(slot, {})
	return 0 if stack.is_empty() else int(ItemTable.get_item(stack.id).get("armor", 0))


## slot -> item id, for building the visible character.
func ids() -> Dictionary:
	var out := {}
	for slot: String in worn:
		out[slot] = worn[slot].id
	return out


func to_dict() -> Dictionary:
	return worn.duplicate(true)


func from_dict(data: Variant) -> void:
	worn.clear()
	if not data is Dictionary:
		return
	for slot: String in data:
		var stack = data[slot]
		if SLOTS.has(slot) and stack is Dictionary and slot_for(stack.get("id", "")) == slot:
			worn[slot] = stack.duplicate()
