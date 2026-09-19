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
	# SFX exists by now (Settings loads first); the shot buses feed it.
	setup_acoustics()
	# Build the gunshots up front, one a frame, so the first shot never hitches.
	for weapon: String in GunAudio.PROFILES.keys() + ["bow"]:
		for suppressed: bool in [false, true]:
			(func() -> void: GunAudio.shot(weapon, suppressed)).call_deferred()
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


# --- gunshots: where you hear them from ----------------------------------------
# Every shot is placed in the world and reaches you the way sound does: late by
# the distance it travelled, duller the further it went, muffled through walls
# and hills, and coloured by where you are standing — a tight, hard slap inside
# the shack, a long rumbling reverb in the cave, open air with echoes rolling
# back off the land outside.

const SPEED_OF_SOUND := 343.0
## Buses shots can go through (made by setup_acoustics).
const OPEN := "Shot_Open"
const MUFFLED := "Shot_Muffled"
const ROOM := "Shot_Room"
const CAVE := "Shot_Cave"


## Makes the buses: each sends to SFX, with its own filter or reverb.
func setup_acoustics() -> void:
	var specs := {
		OPEN: [],
		MUFFLED: [_lowpass(700.0)],
		ROOM: [_reverb(0.25, 0.35, 0.3, 0.9)],
		CAVE: [_reverb(0.95, 0.55, 0.55, 0.6), _lowpass(5000.0)],
	}
	for bus: String in specs:
		if AudioServer.get_bus_index(bus) != -1:
			continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus)
		AudioServer.set_bus_send(index, "SFX")
		for effect: AudioEffect in specs[bus]:
			AudioServer.add_bus_effect(index, effect)


static func _lowpass(hz: float) -> AudioEffectLowPassFilter:
	var f := AudioEffectLowPassFilter.new()
	f.cutoff_hz = hz
	return f


static func _reverb(room: float, damping: float, wet: float, dry: float) -> AudioEffectReverb:
	var r := AudioEffectReverb.new()
	r.room_size = room
	r.damping = damping
	r.wet = wet
	r.dry = dry
	r.spread = 0.8
	r.predelay_msec = 12.0 if room < 0.5 else 40.0
	return r


## A shot from `weapon` at `at`: `quiet` 0..1 (a suppressor). How far it carries
## depends on the gun; the listener is the camera.
func play_shot(weapon: String, at: Vector3, quiet: float) -> void:
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d() if viewport != null else null
	var root := get_tree().current_scene
	if camera == null or root == null:
		return
	var ear := camera.global_position
	var distance := ear.distance_to(at)
	var suppressed := quiet > 0.4
	var reach := (150.0 if suppressed else (1200.0 if weapon == "intervention" else 700.0)) if weapon != "bow" else 40.0
	if distance > reach:
		return
	var here := _where(ear)
	var blocked := _occluded(ear, at)
	var bus := CAVE if here == "cave" else (ROOM if here == "room" else OPEN)
	if blocked or distance > 250.0:
		bus = MUFFLED
	var level := -2.0 - 14.0 * clampf(quiet, 0.0, 1.0) - (8.0 if blocked else 0.0)
	var stream := GunAudio.shot(weapon, suppressed)
	var delay := distance / SPEED_OF_SOUND
	_after(delay, func() -> void: _emit(stream, at, level, bus, reach))
	# Outdoors a loud shot comes back off the hills, later and darker.
	if here == "open" and not suppressed and weapon != "bow":
		for k in 2:
			var echo := delay + randf_range(0.35, 0.9) * (k + 1)
			_after(echo, func() -> void: _emit(stream, at, level - 13.0 - k * 5.0, MUFFLED, reach))


func _emit(stream: AudioStream, at: Vector3, level: float, bus: String, reach: float) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = bus
	player.volume_db = level
	player.max_distance = reach
	player.unit_size = reach / 18.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.pitch_scale = 1.0 + randf_range(-0.04, 0.04)
	player.finished.connect(player.queue_free)
	root.add_child(player)
	player.global_position = at
	player.play()


func _after(seconds: float, what: Callable) -> void:
	if seconds < 0.01:
		what.call()
	else:
		get_tree().create_timer(seconds).timeout.connect(what)


## Where the listener is: "room" (inside the shack), "cave", or "open".
func _where(ear: Vector3) -> String:
	var world := GameState.world
	if world == null:
		return "open"
	if world.camp != null and world.camp.in_shack(ear):
		return "room"
	if world.camp_island != null and world.camp_island.in_cave(Vector2(ear.x, ear.z), -0.5) and ear.y < world.camp_island.cave_floor + 4.0:
		return "cave"
	return "open"


## Is there something solid between the shot and the ear (a wall, a hill)?
func _occluded(ear: Vector3, at: Vector3) -> bool:
	var world := GameState.world
	if world == null or ear.distance_to(at) < 1.5:
		return false
	var query := PhysicsRayQueryParameters3D.create(ear, at + (ear - at).normalized() * 0.6, Layers.WORLD)
	if GameState.local_player != null:
		query.exclude = [(GameState.local_player as Player).get_rid()]
	return not world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _pick(set_name: String) -> AudioStream:
	var options: Array = _streams.get(set_name, [])
	return null if options.is_empty() else options[randi() % options.size()]
