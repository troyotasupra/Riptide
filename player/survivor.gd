class_name Survivor
extends Node
## A crew member's survival state and belongings.
##
## The host owns the truth: it ticks hunger, thirst and body temperature,
## applies eating, drinking and harvesting, and pushes snapshots to the owning
## peer. The owner only displays them and sends requests ("use slot 3").

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

var player: Player
var survival := Survival.new()
var inventory := Inventory.new()
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
	for slot in inventory.slots:
		if slot != null:
			parts.append("%s x%d" % [slot.id, slot.count])
	print("[inventory] %s: %s (hunger %.0f, thirst %.0f, health %.0f)" % [
		player.display_name, ", ".join(parts), survival.hunger, survival.thirst, survival.health])


## Host only: advance survival for this crew member.
func host_tick(delta: float) -> void:
	_tick_accum += delta
	if _tick_accum < TICK_SECONDS:
		return
	var dt := _tick_accum
	_tick_accum = 0.0
	var camp: CampSystems = GameState.world.camp if GameState.world != null else null
	warmth = camp.warmth_for(player) if camp != null else 0.0
	if player.swimming:
		wetness = 1.0
	else:
		var drying := WARM_DRYING if warmth >= 5.0 else 1.0
		wetness = maxf(0.0, wetness - dt * drying / DRY_OFF_SECONDS)
	air_temp = EnvironmentTemp.felt_temp(DayNight.daylight(GameState.time_of_day()), wetness, player.swimming, warmth)
	survival.tick(dt, air_temp, LoadoutMath.combined_insulation([]), player.exertion)
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


func push_inventory() -> void:
	player.carried_weight_kg = inventory.total_weight()
	if player.is_local:
		inventory_changed.emit()
	else:
		_set_inventory.rpc_id(player.peer_id, inventory.to_dict())


## Host → owner: a short message on their screen.
func notify(message: String) -> void:
	if player.is_local:
		notified.emit(message)
	else:
		_notify.rpc_id(player.peer_id, message)


## Spoil times are stored relative to the clock so they survive a restart.
func to_save(now: float) -> Dictionary:
	var copy := Inventory.new()
	copy.from_dict(inventory.to_dict())
	copy.shift_times(-now)
	return {"inventory": copy.to_dict(), "survival": survival.to_dict()}


func from_save(data: Dictionary, now: float) -> void:
	inventory.from_dict(data.get("inventory", {}))
	inventory.shift_times(now)
	survival.from_dict(data.get("survival", {}))
	player.carried_weight_kg = inventory.total_weight()


# --- owner side ------------------------------------------------------------

func select_slot(index: int) -> void:
	selected_slot = wrapi(index, 0, Inventory.HOTBAR_SIZE)
	inventory_changed.emit()


func use_selected() -> void:
	var slot = inventory.slots[selected_slot]
	if slot == null:
		return
	var item := ItemTable.get_item(slot.id)
	match item.get("category", ""):
		"note":
			note_requested.emit(item.note)
			return
		"placeable":
			return  # placing is handled by the player's build preview
		"book":
			book_requested.emit()
	_request_use.rpc_id(1, selected_slot)


func move_item(from: int, to: int) -> void:
	_request_move.rpc_id(1, from, to)


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
	inventory.from_dict(data)
	player.carried_weight_kg = inventory.total_weight()
	inventory_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func _notify(message: String) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		notified.emit(message)


# --- host side: requests from the owner ------------------------------------

@rpc("any_peer", "call_local", "reliable")
func _request_use(slot: int) -> void:
	if not multiplayer.is_server() or not _sender_owns_me():
		return
	if slot < 0 or slot >= Inventory.HOTBAR_SIZE or inventory.slots[slot] == null:
		return
	var id: String = inventory.slots[slot].id
	var item := ItemTable.get_item(id)
	var item_name := String(item.get("name", id)).to_lower()
	var camp: CampSystems = GameState.world.camp
	match item.get("category", ""):
		"food", "drink":
			_consume(slot, item)
		"medical":
			if survival.health >= Survival.MAX:
				notify("You're not hurt.")
				return
			inventory.take_from_slot(slot, 1)
			survival.heal(item.get("heal", 0.0))
			notify("You patch yourself up.")
			push_inventory()
			push_survival()
		"page":
			inventory.take_from_slot(slot, 1)
			push_inventory()
			camp.learn(item.get("teaches", []), self)
		"book":
			camp.learn(RecipeTable.STARTING, self)
		"chart":
			camp.read_chart(self)
		"note", "placeable":
			pass
		_:
			notify("You can't use the %s yet." % item_name)


func _consume(slot: int, item: Dictionary) -> void:
	var empties_to: String = item.get("empties_to", "")
	if empties_to.is_empty():
		inventory.take_from_slot(slot, 1)
	else:
		inventory.slots[slot] = {"id": empties_to, "count": 1, "spoils_at": 0.0}
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


@rpc("any_peer", "call_local", "reliable")
func _request_move(from: int, to: int) -> void:
	if not multiplayer.is_server() or not _sender_owns_me():
		return
	inventory.move(from, to)
	push_inventory()


func _sender_owns_me() -> bool:
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	return sender == player.peer_id
