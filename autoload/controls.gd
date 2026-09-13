extends Node
## Registers input actions in code so every binding lives in one readable place.

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
	"inventory": [KEY_I],
	"book": [KEY_B],
	"rotate": [KEY_R],
	"pause": [KEY_ESCAPE],
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


static func _bind(action: String, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_add_event(action, event)
