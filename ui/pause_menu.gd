class_name PauseMenu
extends PanelContainer
## The in-game menu. The world keeps running (it's co-op), but your character
## stops taking input while it's open.

signal resume_requested
signal settings_requested

var _invite: Label
var _controls: Label


func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(420.0, 0.0)
	add_child(box)
	UiKit.title(box, "Paused", 28)
	_invite = UiKit.label(box, "", true)
	UiKit.button(box, "Resume", func() -> void: resume_requested.emit())
	UiKit.button(box, "Settings", func() -> void: settings_requested.emit())
	UiKit.button(box, "Controls", func() -> void: _controls.visible = not _controls.visible)
	_controls = UiKit.label(box, "")
	_controls.visible = false
	UiKit.button(box, "Save and leave" if multiplayer.is_server() else "Leave crew", func() -> void:
		Net.leave_game("World saved." if multiplayer.is_server() else "You left the crew."))
	UiKit.button(box, "Quit to desktop", func() -> void:
		if Net.is_hosting() and GameState.world != null:
			GameState.world.save_now()
		get_tree().quit())
	visibility_changed.connect(_on_shown)


func _on_shown() -> void:
	if not visible:
		return
	if multiplayer.is_server():
		var addresses: PackedStringArray = []
		for address in IP.get_local_addresses():
			if address.contains(".") and not address.begins_with("127.") and not address.begins_with("169.254."):
				addresses.append(address)
		_invite.text = "Friends join at %s  (port %d). Over the internet, use your Tailscale address — see README." % [", ".join(addresses), Net.port]
	else:
		_invite.text = "Crew: %d/%d" % [Net.roster.size(), Net.MAX_PLAYERS]
	if Controls.using_gamepad:
		_controls.text = "Left stick move · Right stick look · A jump · B crouch · L3 sprint\nX interact (hold to gather) · RT use / swing / build · LT drop in backpack\nY paddle · LB/RB hotbar · D-pad ↑ give · ↓ drop · ← book · → rotate\nView backpack · Menu pause"
	else:
		_controls.text = "WASD move · Mouse look · Space jump · C crouch · Shift sprint (and paddle hard)\nE interact (hold to gather) · Left click use / swing / build · R rotate build\nF paddle · 1–8 or wheel hotbar · Q drop · G give to crewmate\nI backpack · B survival book · F3 debug info · Esc pause"
	UiKit.focus_first(self)
