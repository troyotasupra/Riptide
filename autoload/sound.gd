extends Node
## Sound effects and ambience. Named sets pick a random variation each time,
## with a little pitch wobble so repeats don't sound mechanical.
## Sounds are CC0: Kenney (audio/sfx) and "Sea and river wave sounds" from OpenGameArt.

const SETS := {
	"step_grass": ["footstep_grass_000", "footstep_grass_001", "footstep_grass_002", "footstep_grass_003", "footstep_grass_004"],
	"step_sand": ["footstep_carpet_000", "footstep_carpet_001", "footstep_carpet_002", "footstep_carpet_003", "footstep_carpet_004"],
	"step_wood": ["footstep_wood_000", "footstep_wood_001", "footstep_wood_002", "footstep_wood_003", "footstep_wood_004"],
	"chop": ["chop", "impactWood_medium_000", "impactWood_medium_001", "impactWood_medium_002"],
	"tree_fall": ["impactWood_heavy_000"],
	"cut": ["knifeSlice", "knifeSlice2"],
	"swing": ["drawKnife1"],
	"pickup": ["handleSmallLeather", "handleSmallLeather2"],
	"cloth": ["cloth1", "cloth2", "cloth3"],
	"drop": ["dropLeather"],
	"click": ["click_001"],
	"select": ["select_001"],
	"open": ["open_001"],
	"close": ["close_001"],
	"error": ["error_001"],
	"craft": ["confirmation_001"],
	"book_open": ["bookOpen"],
	"page": ["bookFlip1"],
	"book_close": ["bookClose"],
	"latch": ["metalLatch"],
	"pot": ["metalPot1"],
	"creak": ["creak1", "creak2", "creak3"],
	"chest": ["doorOpen_1"],
	"hit": ["impactPunch_medium_000", "impactPunch_medium_001"],
	"splash": ["impactSoft_heavy_000"],
	"stone": ["impactMining_000", "impactMining_001"],
	"thud": ["drop_001"],
}
const OCEAN_LOOP := "res://audio/ambience/ocean_waves.mp3"

var _streams := {}
var _ambience: AudioStreamPlayer


func _ready() -> void:
	for key: String in SETS:
		var loaded: Array[AudioStream] = []
		for file: String in SETS[key]:
			var path := "res://audio/sfx/%s.ogg" % file
			if ResourceLoader.exists(path):
				loaded.append(load(path))
		_streams[key] = loaded
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "Ambience"
	if ResourceLoader.exists(OCEAN_LOOP):
		var stream = load(OCEAN_LOOP)
		if stream is AudioStreamMP3:
			stream.loop = true
		_ambience.stream = stream
	add_child(_ambience)


func start_ambience() -> void:
	if _ambience.stream != null and not _ambience.playing:
		_ambience.play()


func stop_ambience() -> void:
	_ambience.stop()


## Makes the sea louder near the water and quieter inland or below deck.
func set_ambience_level(level: float) -> void:
	_ambience.volume_db = linear_to_db(clampf(level, 0.02, 1.0))


func play(set_name: String, volume_db: float = 0.0, pitch_jitter: float = 0.08) -> void:
	var stream := _pick(set_name)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "SFX"
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func play_at(set_name: String, position: Vector3, volume_db: float = 0.0, pitch_jitter: float = 0.08) -> void:
	var stream := _pick(set_name)
	var root := get_tree().current_scene
	if stream == null or root == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = "SFX"
	player.volume_db = volume_db
	player.max_distance = 45.0
	player.unit_size = 4.0
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.finished.connect(player.queue_free)
	root.add_child(player)
	player.global_position = position
	player.play()


func _pick(set_name: String) -> AudioStream:
	var options: Array = _streams.get(set_name, [])
	return null if options.is_empty() else options[randi() % options.size()]
