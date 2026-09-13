class_name Survivor
extends Node
## A crew member's survival state, belongings and clothing.
##
## The host owns the truth: it ticks hunger, thirst and body temperature,
## applies eating, wearing, moving items, dropping and giving, and pushes
## snapshots to the owning peer. The owner displays them and sends requests.

signal inventory_changed
signal survival_changed
signal notified(message: String)
## Owner side: open a readable note, or the survival book.
signal note_requested(note_id: String)
signal book_requested

const TICK_SECONDS := 0.25
const PUSH_SECONDS := 0.5
const SPOIL_CHECK_SECONDS := 5.0
const DRY_OFF_SECONDS := 120.0
## Near a fire or in shelter you dry off this many times faster.
const WARM_DRYING := 4.0
const GIVE_RANGE := 4.5

var player: Player
var survival := Survival.new()
var inventory := Pack.new()
var equipment := Equipment.new()
var wetness := 0.0
## Air temperature this crew member feels, for the HUD.
var air_temp := 0.0
var warmth := 0.0
var selected_slot := 0

var _tick_accum := 0.0
var _push_accum := 0.0
var _spoil_accum := 0.0


func _ready() -> void:
	# Test runs: log what reaches the owning player so co-op flows can be checked from logs.
	if player.is_local and not GameState.autopilot.is_empty():
		notified.connect(func(message: String) -> void: print("[notify] %s: %s" % [player.display_name, message]))
		inventory_changed.connect(_log_inventory)


func _log_inventory() -> void:
	var parts: PackedStringArray = []
	for stack: Dictionary in inventory.all_stacks():
		parts.append("%s x%d" % [stack.id, stack.count])
	print("[inventory] %s: %s (hunger %.0f, thirst %.0f, health %.0f)" % [
		player.display_name, ", ".join(parts), survival.hunger, survival.thirst, survival.health])


func total_weight() -> float:
	return inventory.total_weight() + equipment.weight()


func camp() -> CampSystems:
	return GameState.world.camp if GameState.world != null else null


## Host only: advance survival for this crew member.
func host_tick(delta: float) -> void:
	_tick_accum += delta
	if _tick_accum < TICK_SECONDS:
		return
	var dt := _tick_accum
	_tick_accum = 0.0
	warmth = camp().warmth_for(player) if camp() != null else 0.0
	if player.swimming:
		wetness = 1.0
	else:
		var drying := WARM_DRYING if warmth >= 5.0 else 1.0
		wetness = maxf(0.0, wetness - dt * drying / DRY_OFF_SECONDS)
	air_temp = EnvironmentTemp.felt_temp(DayNight.daylight(GameState.time_of_day()), wetness, player.swimming, warmth)
	survival.tick(dt, air_temp, equipment.insulation(), player.exertion)
	_spoil_accum += dt
	if _spoil_accum >= SPOIL_CHECK_SECONDS:
		_spoil_accum = 0.0
		if inventory.spoil_expired(Ocean.time):
			notify("Some of your food has spoiled.")
			push_inventory()
	_push_accum += dt
	if _push_accum >= PUSH_SECONDS:
		_push_accum = 0.0
		push_survival()


func push_survival() -> void:
	if player.is_local:
		survival_changed.emit()
		return
	var data := survival.to_dict()
	data["air"] = air_temp
	data["wet"] = wetness
	data["warmth"] = warmth
	_set_survival.rpc_id(player.peer_id, data)


## Host: send belongings to the owner, and what they're wearing to everyone.
func push_inventory() -> void:
	player.carried_weight_kg = total_weight()
	var ids := equipment.ids()
	player.apply_worn(ids)
	Net.send_to_ready(player, "_set_worn", [ids])
	if player.is_local:
		inventory_changed.emit()
	else:
		_set_inventory.rpc_id(player.peer_id, {"pack": inventory.to_dict(), "worn": equipment.to_dict()})


## Host → owner: a short message on their screen.
func notify(message: String) -> void:
	if player.is_local:
		notified.emit(message)
	else:
		_notify.rpc_id(player.peer_id, message)


## Host: dress a brand-new crew member.
func give_starting_outfit() -> void:
	for id: String in Equipment.STARTING_OUTFIT:
		equipment.wear({"id": id, "count": 1, "spoils_at": 0.0})
	refresh_storage()


## Host: rebuild the rig and backpack grids after a gear change. Whatever no
## longer fits moves elsewhere in the pack, or is dropped at the player's feet.
func refresh_storage() -> void:
	var dropped: Array = []
	for stack: Dictionary in inventory.configure(equipment.ids()):
		var left := inventory.add_stack(stack)
		if left > 0:
			var rest := stack.duplicate()
			rest.count = left
			dropped.append(rest)
	_drop_overflow(dropped)


func _drop_overflow(stacks: Array) -> void:
	if stacks.is_empty() or camp() == null:
		return
	camp().drop_items(player, stacks, "%s's dropped items" % player.display_name)
	notify("Not everything fits — the rest is at your feet.")


## Spoil times are stored relative to the clock so they survive a restart.
func to_save(now: float) -> Dictionary:
	var copy := Pack.new()
	copy.from_dict(inventory.to_dict())
	copy.shift_times(-now)
	return {"pack": copy.to_dict(), "survival": survival.to_dict(), "worn": equipment.to_dict(), "name": player.display_name}


func from_save(data: Dictionary, now: float) -> void:
	equipment.from_dict(data.get("worn", {}))
	inventory = Pack.new()
	if data.has("pack"):
		inventory.from_dict(data.pack)
		inventory.shift_times(now)
	# If a grid got smaller since the save (or its gear didn't load), re-home what
	# was in it rather than losing it; anything left over is dropped once in the world.
	var leftover: Array = []
	for stack: Dictionary in inventory.configure(equipment.ids()):
		var left := inventory.add_stack(stack)
		if left > 0:
			var rest := stack.duplicate()
			rest.count = left
			leftover.append(rest)
	if not leftover.is_empty():
		_drop_overflow.call_deferred(leftover)
	survival.from_dict(data.get("survival", {}))
	player.carried_weight_kg = total_weight()


# --- owner side ------------------------------------------------------------

func select_slot(index: int) -> void:
	selected_slot = wrapi(index, 0, Pack.HOTBAR_SIZE)
	inventory_changed.emit()


func selected_id() -> String:
	var slot = inventory.hotbar[selected_slot]
	return "" if slot == null else slot.id


## Left click with a hotbar item.
func use_selected() -> void:
	var slot = inventory.hotbar[selected_slot]
	if slot == null:
		return
	if ItemTable.category(slot.id) == "placeable":
		return  # placing is handled by the player's build preview
	use_item(int(slot.uid))


## Uses any carried item (from the hotbar or the inventory screen).
func use_item(uid: int) -> void:
	var stack := inventory.get_stack(uid)
	if stack.is_empty():
		return
	var item := ItemTable.get_item(stack.id)
	match item.get("category", ""):
		"note":
			Sound.play("book_open")
			note_requested.emit(item.note)
			return
		"placeable":
			notified.emit("Put it on your hotbar, select it, and left click to build.")
			return
		"book":
			Sound.play("book_open")
			book_requested.emit()
		"wearable":
			Sound.play("cloth")
		"food", "drink", "medical", "page", "chart":
			pass
		_:
			if item.has("hint"):
				notified.emit(item.hint)
			return
	_request_use.rpc_id(1, uid)


func request_take_off(slot: String) -> void:
	Sound.play("cloth")
	_request_take_off.rpc_id(1, slot)


func request_give(slot: int, target_peer: int) -> void:
	if inventory.hotbar[slot] != null:
		_request_give.rpc_id(1, slot, target_peer)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _set_survival(data: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	survival.from_dict(data)
	air_temp = data.get("air", 0.0)
	wetness = data.get("wet", 0.0)
	warmth = data.get("warmth", 0.0)
	survival_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func _set_inventory(data: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	inventory.from_dict(data.get("pack", {}))
	equipment.from_dict(data.get("worn", {}))
	player.carried_weight_kg = total_weight()
	inventory_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func _notify(message: String) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		notified.emit(message)


# --- host side: requests from the owner ------------------------------------

@rpc("any_peer", "call_local", "reliable")
func _request_use(uid: int) -> void:
	if not multiplayer.is_server() or not _sender_owns_me():
		return
	var stack := inventory.get_stack(uid)
	if stack.is_empty():
		return
	var item := ItemTable.get_item(stack.id)
	match item.get("category", ""):
		"food", "drink":
			_consume(uid, item)
		"medical":
			if survival.health >= Survival.MAX:
				notify("You're not hurt.")
				return
			inventory.take(uid, 1)
			survival.heal(item.get("heal", 0.0))
			notify("You patch yourself up.")
			push_inventory()
			push_survival()
		"page":
			inventory.take(uid, 1)
			push_inventory()
			camp().learn(item.get("teaches", []), self)
		"book":
			camp().learn(RecipeTable.STARTING, self)
		"chart":
			camp().read_chart(self)
		"wearable":
			wear(uid)


func _consume(uid: int, item: Dictionary) -> void:
	var empties_to: String = item.get("empties_to", "")
	if empties_to.is_empty():
		inventory.take(uid, 1)
	else:
		var stack := inventory.get_stack(uid)
		stack.id = empties_to
		stack.count = 1
		stack.spoils_at = 0.0
	survival.eat(item.get("food", 0.0))
	survival.drink(item.get("water", 0.0))
	var verb := "Drank" if item.get("category", "") == "drink" else "Ate"
	if item.has("sickness") and randf() < float(item.get("sick_chance", 1.0)):
		survival.make_sick(item.sickness)
		notify("%s %s... and your stomach turns. You're sick." % [verb, String(item.name).to_lower()])
	else:
		notify("%s %s" % [verb, String(item.name).to_lower()])
	push_inventory()
	push_survival()


## Host: puts on carried item `uid`; what it replaces goes into the pack.
func wear(uid: int) -> bool:
	var stack := inventory.get_stack(uid)
	if stack.is_empty() or ItemTable.category(stack.id) != "wearable":
		return false
	var piece := inventory.take(uid, 1)
	var previous := equipment.wear(piece)
	refresh_storage()
	if not previous.is_empty() and inventory.add_stack(previous) > 0:
		_drop_overflow([previous])
	notify("Now wearing: %s" % ItemTable.display_name(piece.id))
	push_inventory()
	return true


## Host: takes off what's in `slot` into the pack (or onto the ground if full).
func take_off(slot: String) -> void:
	if not equipment.is_wearing(slot):
		return
	var stack := equipment.take_off(slot)
	refresh_storage()
	if inventory.add_stack(stack) > 0:
		_drop_overflow([stack])
	push_inventory()


@rpc("any_peer", "call_local", "reliable")
func _request_take_off(slot: String) -> void:
	if multiplayer.is_server() and _sender_owns_me():
		take_off(slot)


@rpc("any_peer", "call_local", "reliable")
func _request_give(slot: int, target_peer: int) -> void:
	if not multiplayer.is_server() or not _sender_owns_me():
		return
	if slot < 0 or slot >= Pack.HOTBAR_SIZE or inventory.hotbar[slot] == null:
		return
	var target := GameState.world.players_root.get_node_or_null(str(target_peer)) as Player
	if target == null or target == player:
		return
	if target.world_transform().origin.distance_to(player.world_transform().origin) > GIVE_RANGE:
		notify("Get closer to hand that over.")
		return
	var stack: Dictionary = inventory.hotbar[slot]
	var piece := inventory.take(int(stack.uid))
	var given: int = piece.count
	var left := target.survivor.inventory.add_stack(piece)
	if left > 0:
		var rest := piece.duplicate()
		rest.count = left
		inventory.add_stack(rest)
		given -= left
	if given <= 0:
		notify("%s has no room for that." % target.display_name)
		return
	notify("Gave %s ×%d to %s" % [ItemTable.display_name(piece.id), given, target.display_name])
	target.survivor.notify("%s gave you %s ×%d" % [player.display_name, ItemTable.display_name(piece.id), given])
	push_inventory()
	target.survivor.push_inventory()


func _sender_owns_me() -> bool:
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	return sender == player.peer_id
