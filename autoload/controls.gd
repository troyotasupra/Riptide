extends Node
## Registers every input action in code — keyboard, mouse and gamepad — so all
## bindings live in one readable place. Also tracks whether the player is on a
## controller right now, so prompts can show the right buttons.

signal device_changed(gamepad: bool)

const KEYS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"crouch": [KEY_C, KEY_CTRL],
	"interact": [KEY_E],
	"paddle": [KEY_F],
	"row_left": [KEY_Q],
	"row_right": [KEY_E],
	"inventory": [KEY_TAB],
	"book": [KEY_B],
	"rotate": [KEY_R],
	"drop": [KEY_Q],
	"give": [KEY_G],
	"pause": [KEY_ESCAPE],
	"debug": [KEY_F3],
	"dev_menu": [KEY_F1],
	"dev_fly": [KEY_V],
	"leave": [KEY_F10],
	"hotbar_1": [KEY_1],
	"hotbar_2": [KEY_2],
	"hotbar_3": [KEY_3],
	"hotbar_4": [KEY_4],
	"hotbar_5": [KEY_5],
	"hotbar_6": [KEY_6],
	"hotbar_7": [KEY_7],
	"hotbar_8": [KEY_8],
}

const MOUSE := {
	"primary": [MOUSE_BUTTON_LEFT],
	"secondary": [MOUSE_BUTTON_RIGHT],
	"hotbar_next": [MOUSE_BUTTON_WHEEL_DOWN],
	"hotbar_prev": [MOUSE_BUTTON_WHEEL_UP],
}

const PAD_BUTTONS := {
	"jump": [JOY_BUTTON_A],
	"interact": [JOY_BUTTON_X],
	"crouch": [JOY_BUTTON_B],
	"paddle": [JOY_BUTTON_Y],
	"sprint": [JOY_BUTTON_LEFT_STICK],
	"inventory": [JOY_BUTTON_BACK],
	"book": [JOY_BUTTON_DPAD_LEFT],
	"rotate": [JOY_BUTTON_DPAD_RIGHT],
	"give": [JOY_BUTTON_DPAD_UP],
	"drop": [JOY_BUTTON_DPAD_DOWN],
	"pause": [JOY_BUTTON_START],
	"hotbar_next": [JOY_BUTTON_RIGHT_SHOULDER],
	"hotbar_prev": [JOY_BUTTON_LEFT_SHOULDER],
}

## action -> [axis, direction]
const PAD_AXES := {
	"move_forward": [JOY_AXIS_LEFT_Y, -1.0],
	"move_back": [JOY_AXIS_LEFT_Y, 1.0],
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"look_up": [JOY_AXIS_RIGHT_Y, -1.0],
	"look_down": [JOY_AXIS_RIGHT_Y, 1.0],
	"look_left": [JOY_AXIS_RIGHT_X, -1.0],
	"look_right": [JOY_AXIS_RIGHT_X, 1.0],
	"primary": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
	"secondary": [JOY_AXIS_TRIGGER_LEFT, 1.0],
	"row_left": [JOY_AXIS_TRIGGER_LEFT, 1.0],
	"row_right": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
}

const KEY_LABELS := {
	"interact": "E", "primary": "LMB", "secondary": "RMB", "jump": "Space", "paddle": "F", "sprint": "Shift",
	"row_left": "Q", "row_right": "E", "move_back": "S",
	"crouch": "C", "rotate": "R", "inventory": "Tab", "book": "B", "drop": "Q", "give": "G", "pause": "Esc",
	"hotbar": "1–8",
}
const PAD_LABELS := {
	"interact": "X", "primary": "RT", "secondary": "LT", "jump": "A", "paddle": "Y", "sprint": "L3",
	"row_left": "LT", "row_right": "RT", "move_back": "Stick ↓",
	"crouch": "B", "rotate": "D-pad →", "inventory": "View", "book": "D-pad ←", "drop": "D-pad ↓",
	"give": "D-pad ↑", "pause": "Menu", "hotbar": "LB/RB",
}

var using_gamepad := false


func _enter_tree() -> void:
	for action: String in KEYS:
		for key: int in KEYS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key as Key
			_bind(action, event)
	for action: String in MOUSE:
		for button: int in MOUSE[action]:
			var event := InputEventMouseButton.new()
			event.button_index = button as MouseButton
			_bind(action, event)
	for action: String in PAD_BUTTONS:
		for button: int in PAD_BUTTONS[action]:
			var event := InputEventJoypadButton.new()
			event.button_index = button as JoyButton
			_bind(action, event)
	for action: String in PAD_AXES:
		var event := InputEventJoypadMotion.new()
		event.axis = PAD_AXES[action][0] as JoyAxis
		event.axis_value = PAD_AXES[action][1]
		_bind(action, event)
	# Tab opens the inventory; don't let Godot's focus navigation swallow it first.
	for event: InputEvent in InputMap.action_get_events("ui_focus_next"):
		if event is InputEventKey and (event.keycode == KEY_TAB or event.physical_keycode == KEY_TAB):
			InputMap.action_erase_event("ui_focus_next", event)


static func _bind(action: String, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_add_event(action, event)


func set_deadzone(value: float) -> void:
	for action: String in PAD_AXES:
		InputMap.action_set_deadzone(action, clampf(value, 0.05, 0.9))


## "[E]" on keyboard, "[X]" on a controller.
func tag(action: String) -> String:
	var labels := PAD_LABELS if using_gamepad else KEY_LABELS
	return "[%s]" % labels.get(action, action)


func _input(event: InputEvent) -> void:
	var gamepad := using_gamepad
	if event is InputEventJoypadButton and event.pressed:
		gamepad = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		gamepad = true
	elif (event is InputEventKey and event.pressed) or event is InputEventMouseButton:
		gamepad = false
	elif event is InputEventMouseMotion and event.relative.length() > 3.0:
		gamepad = false
	if gamepad != using_gamepad:
		using_gamepad = gamepad
		device_changed.emit(gamepad)
