class_name ModifyPanel
extends PanelContainer
## Working on a gun: every slot it has, what's on it now, and what you're
## carrying that would fit. Right-click a gun in the inventory → Modify.
##
## The host still decides: every change goes through CombatService.request_fit,
## which checks the gun, the slot and the attachment all over again.

## Plain names for the slots, in the order a gun is read down.
const SLOT_NAMES := {
	"optic": "Optic", "muzzle": "Muzzle", "underbarrel": "Under the barrel",
	"magazine": "Magazine", "stock": "Stock", "laser": "Side rail",
}

var _rows: VBoxContainer
var _title: Label
var _gun_uid := 0
var _survivor: Survivor


func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(420.0, 0.0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	_title = UiKit.title(box, "Modify")
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 10)
	box.add_child(_rows)
	UiKit.button(box, "Close", close)


func close() -> void:
	visible = false
	_gun_uid = 0


## Show the work bench for the gun `uid` in `survivor`'s pack.
func open_for(survivor: Survivor, uid: int) -> void:
	_survivor = survivor
	_gun_uid = uid
	refresh()


## Rebuild from what the gun and the pack hold right now (called again whenever
## the host sends the pack back, so fitting something redraws the list).
func refresh() -> void:
	if _survivor == null or _gun_uid == 0:
		return
	var stack := _survivor.inventory.get_stack(_gun_uid)
	if stack.is_empty():
		close()
		return
	var weapon: String = ItemTable.get_item(String(stack.id)).get("weapon", "")
	var gun: Dictionary = WeaponTable.WEAPONS.get(weapon, {})
	if gun.is_empty():
		close()
		return
	visible = true
	var fitted: Dictionary = stack.get("attachments", {})
	_title.text = "Modify — %s" % String(gun.get("name", ItemTable.display_name(String(stack.id))))
	for child in _rows.get_children():
		child.queue_free()
	var slots: Array = gun.get("slots", [])
	if slots.is_empty():
		UiKit.label(_rows, "Nothing fits this one.", true)
		return
	for slot: String in slots:
		_slot_row(slot, weapon, String(fitted.get(slot, "")))


func _slot_row(slot: String, weapon: String, fitted_id: String) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	_rows.add_child(row)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	row.add_child(head)
	UiKit.label(head, String(SLOT_NAMES.get(slot, slot.capitalize())))
	if fitted_id.is_empty():
		UiKit.label(head, "— empty", true)
	else:
		UiKit.label(head, ItemTable.display_name(fitted_id), true)
		UiKit.button(head, "Take off", func() -> void: _fit(slot, 0))
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 6)
	row.add_child(choices)
	var offered := false
	for held: Dictionary in _carried():
		var id := String(held.id)
		var kind: String = ItemTable.get_item(id).get("attachment", "")
		if kind.is_empty() or kind == fitted_id or not AttachmentTable.fits(weapon, kind):
			continue
		if String(AttachmentTable.get_attachment(kind).get("slot", "")) != slot:
			continue
		offered = true
		var uid := int(held.uid)
		UiKit.button(choices, "Fit %s" % ItemTable.display_name(id), func() -> void: _fit(slot, uid))
	if not offered and fitted_id.is_empty():
		UiKit.label(choices, "nothing in your pack fits here", true)


## Every stack in the pack, hotbar and grids alike.
func _carried() -> Array:
	var out: Array = []
	for stack in _survivor.inventory.hotbar:
		if stack != null:
			out.append(stack)
	for area: String in _survivor.inventory.grids:
		out.append_array(_survivor.inventory.grids[area].items)
	return out


func _fit(slot: String, attachment_uid: int) -> void:
	Sound.play("latch", -6.0)
	GameState.world.combat.rpc_id(1, "request_fit", slot, attachment_uid, _gun_uid)
