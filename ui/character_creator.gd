class_name CharacterCreator
extends PanelContainer
## Make your character: body, face, skin, hair, facial hair, and the crew
## colour and emblem you fly when you host. A live, turning preview shows the
## result in different outfits. Saved to your profile.

signal closed

const OUTFITS := {
	"Starting clothes": {"torso": "tshirt", "legs": "shorts", "feet": "sandals"},
	"Cold weather": {"torso": "wool_sweater", "legs": "cargo_pants", "feet": "hiking_boots", "head": "wool_beanie"},
	"Kitted out": {"torso": "rain_jacket", "legs": "cargo_pants", "feet": "hiking_boots", "head": "combat_helmet", "vest": "plate_carrier", "back": "daypack"},
}

var _model: CharacterModel
var _values := {}
var _outfit := 0


func _ready() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	add_child(row)

	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(340.0, 480.0)
	container.stretch = true
	row.add_child(container)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.10, 0.22, 0.30)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.75, 0.8)
	environment.ambient_light_energy = 0.6
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	viewport.add_child(world_environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40.0, -30.0, 0.0)
	viewport.add_child(light)
	var camera := Camera3D.new()
	camera.fov = 40.0
	viewport.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 1.2, 3.4), Vector3(0.0, 0.95, 0.0))
	_model = CharacterModel.new()
	viewport.add_child(_model)

	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 4)
	controls.custom_minimum_size = Vector2(380.0, 0.0)
	row.add_child(controls)
	UiKit.title(controls, "Your character")
	for field: Array in AppearanceTable.FIELDS:
		_stepper(controls, field[1], field[0], AppearanceTable.option_count(field[0]))
	UiKit.title(controls, "Your crew (when you host)", 18)
	_stepper(controls, "Crew colour", "crew_color", AppearanceTable.CREW_COLORS.size())
	_stepper(controls, "Emblem", "emblem", AppearanceTable.EMBLEMS.size())
	UiKit.title(controls, "Preview", 18)
	_stepper(controls, "Outfit", "outfit", OUTFITS.size())
	UiKit.button(controls, "Save character", close)
	visibility_changed.connect(func() -> void:
		if visible:
			_load_from_profile()
			UiKit.focus_first(controls))


func close() -> void:
	Profile.save_profile()
	Sound.play("craft", -6.0)
	visible = false
	closed.emit()


func _process(delta: float) -> void:
	if visible and _model != null:
		_model.rotation.y += delta * 0.5
		_model.animate(delta, 0.0, false, false, 0.0)


func _load_from_profile() -> void:
	for key: String in AppearanceTable.DEFAULT_LOOK:
		_set_value(key, Profile.look[key])
	_set_value("crew_color", Profile.crew_color)
	_set_value("emblem", Profile.emblem)
	_set_value("outfit", _outfit)
	_refresh_model()


func _stepper(parent: Control, text: String, key: String, count: int) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(120.0, 0.0)
	row.add_child(label)
	var left := Button.new()
	left.text = "‹"
	left.custom_minimum_size = Vector2(36.0, 30.0)
	row.add_child(left)
	var value := Label.new()
	value.custom_minimum_size = Vector2(150.0, 0.0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value)
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(22.0, 22.0)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(swatch)
	var right := Button.new()
	right.text = "›"
	right.custom_minimum_size = Vector2(36.0, 30.0)
	row.add_child(right)
	_values[key] = {"index": 0, "count": count, "label": value, "swatch": swatch}
	left.pressed.connect(func() -> void: _step(key, -1))
	right.pressed.connect(func() -> void: _step(key, 1))


func _step(key: String, direction: int) -> void:
	Sound.play("click", -8.0)
	_set_value(key, wrapi(int(_values[key].index) + direction, 0, int(_values[key].count)))
	if AppearanceTable.DEFAULT_LOOK.has(key):
		Profile.look[key] = _values[key].index
	elif key == "crew_color":
		Profile.crew_color = _values[key].index
	elif key == "emblem":
		Profile.emblem = _values[key].index
	elif key == "outfit":
		_outfit = _values[key].index
	_refresh_model()


func _set_value(key: String, index: int) -> void:
	var entry: Dictionary = _values[key]
	entry.index = index
	var swatch: ColorRect = entry.swatch
	swatch.visible = key in ["skin", "hair_color", "eyes", "crew_color"]
	match key:
		"skin":
			swatch.color = AppearanceTable.SKIN[index]
			entry.label.text = "Tone %d" % (index + 1)
		"hair_color":
			swatch.color = AppearanceTable.HAIR_COLORS[index]
			entry.label.text = "Shade %d" % (index + 1)
		"eyes":
			swatch.color = AppearanceTable.EYE_COLORS[index]
			entry.label.text = "Colour %d" % (index + 1)
		"crew_color":
			swatch.color = AppearanceTable.CREW_COLORS[index]
			entry.label.text = AppearanceTable.CREW_COLOR_NAMES[index]
		"emblem":
			entry.label.text = AppearanceTable.EMBLEMS[index]
		"outfit":
			entry.label.text = OUTFITS.keys()[index]
		_:
			entry.label.text = AppearanceTable.option_name(key, index)


func _refresh_model() -> void:
	_model.setup(Profile.look, OUTFITS.values()[_outfit], Profile.crew_color, Profile.emblem)
