extends "res://tests/test_case.gd"

const Audio = preload("res://autoload/gun_audio.gd")


static func _samples(wav: AudioStreamWAV) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var data := wav.data
	for i in range(0, data.size() - 1, 2):
		out.append(data.decode_s16(i) / 32000.0)
	return out


## Loudness (RMS) between two times, in seconds.
static func _rms(s: PackedFloat32Array, from: float, to: float) -> float:
	var a := int(from * Audio.RATE)
	var b := mini(int(to * Audio.RATE), s.size())
	var sum := 0.0
	for i in range(a, b):
		sum += s[i] * s[i]
	return sqrt(sum / maxf(1.0, b - a))


## How bright a stretch is: sign changes per second (noise-like crack is high).
static func _brightness(s: PackedFloat32Array, from: float, to: float) -> float:
	var a := int(from * Audio.RATE)
	var b := mini(int(to * Audio.RATE), s.size())
	var crossings := 0
	for i in range(a + 1, b):
		if (s[i] >= 0.0) != (s[i - 1] >= 0.0):
			crossings += 1
	return crossings / maxf(to - from, 0.001)


func test_a_shot_hits_hard_and_dies_away() -> void:
	for weapon: String in Audio.PROFILES:
		var s := _samples(Audio.shot(weapon, false))
		check(_rms(s, 0.0, 0.01) > _rms(s, 0.2, 0.3) * 4.0, "%s: the report is sharp, then falls away" % weapon)
		check(_rms(s, 0.0, 0.01) > 0.2, "%s: and it's loud" % weapon)


func test_a_suppressor_takes_the_crack() -> void:
	for weapon: String in ["m4", "m1911", "uzi"]:
		var loud := _samples(Audio.shot(weapon, false))
		var quiet := _samples(Audio.shot(weapon, true))
		check(_brightness(quiet, 0.0, 0.006) < _brightness(loud, 0.0, 0.006), "%s: suppressed is duller at the crack" % weapon)
		check(quiet.size() < loud.size(), "%s: and its tail is shorter" % weapon)


func test_calibres_sound_different() -> void:
	var rifle := Audio.shot("intervention", false)
	var pistol := Audio.shot("m1911", false)
	var shotgun := _samples(Audio.shot("mossberg", false))
	var smg := _samples(Audio.shot("uzi", false))
	check(rifle.data.size() > pistol.data.size(), "the .408 rolls on longer than the .45")
	check(_brightness(shotgun, 0.02, 0.08) < _brightness(smg, 0.02, 0.08), "the 12 gauge booms lower than the 9 mm")


func test_a_round_going_past_is_a_crack_not_a_boom() -> void:
	var past := _samples(Audio.passby())
	var shot := _samples(Audio.shot("m4", false))
	check(past.size() < int(0.12 * Audio.RATE), "it's over in a moment")
	check(_brightness(past, 0.0, 0.01) > _brightness(shot, 0.02, 0.05), "and it's a sharp snap, not the muzzle's boom")
	check(_rms(past, 0.0, 0.003) > _rms(past, 0.05, 0.08) * 6.0, "with nothing rolling on behind it")


func test_the_bow_is_not_a_gunshot() -> void:
	var bow := _samples(Audio.shot("bow", false))
	check(bow.size() < int(0.5 * Audio.RATE), "the bow is a short thrum")
	check(_brightness(bow, 0.0, 0.05) < _brightness(_samples(Audio.shot("m4", false)), 0.0, 0.05), "with no crack")
