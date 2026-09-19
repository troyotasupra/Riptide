class_name GunAudio
extends RefCounted
## Gunshots made in code rather than from recordings: every report is built from
## the parts a real one has, sized to the gun.
##   crack  - the supersonic snap: a few milliseconds of bright noise
##   body   - the muzzle blast: noise that rings and darkens as it dies
##   thump  - the low punch you feel: a falling sine
##   tail   - the air and the land giving it back: long, dark, quiet
## A suppressor takes most of the crack and the top off the body. The bow is a
## thrum of the string and the hiss of the arrow.
##
## shot(weapon, suppressed) returns a cached AudioStreamWAV.

const RATE := 44100

## weapon -> [crack, body seconds, body brightness 0..1, thump Hz, thump level, tail seconds, tail level]
const PROFILES := {
	"m1911": [0.85, 0.05, 0.45, 95.0, 0.7, 0.45, 0.22],
	"uzi": [0.7, 0.035, 0.55, 120.0, 0.45, 0.35, 0.18],
	"m4": [1.0, 0.045, 0.75, 85.0, 0.55, 0.7, 0.3],
	"mossberg": [0.8, 0.09, 0.18, 58.0, 1.4, 0.8, 0.32],
	"intervention": [1.0, 0.07, 0.8, 55.0, 1.0, 1.3, 0.42],
}

static var _cache := {}


static func shot(weapon: String, suppressed: bool) -> AudioStreamWAV:
	var key := "%s_%s" % [weapon, suppressed]
	if not _cache.has(key):
		_cache[key] = _bow() if weapon == "bow" else _report(PROFILES.get(weapon, PROFILES.m4), suppressed, hash(key))
	return _cache[key]


## The bullet itself going past: a short, dry supersonic crack and its snap of
## air. Nothing like the muzzle report, and it arrives before it downrange.
static func passby() -> AudioStreamWAV:
	if not _cache.has("passby"):
		var rng := RandomNumberGenerator.new()
		rng.seed = 991
		var length := int(0.09 * RATE)
		var samples := PackedFloat32Array()
		samples.resize(length)
		var low := 0.0
		for i in length:
			var t := float(i) / RATE
			var noise := rng.randf_range(-1.0, 1.0)
			low += (noise - low) * 0.18
			# A hard snap, then the air closing behind it.
			samples[i] = noise * exp(-t / 0.0012) + low * 0.8 * exp(-t / 0.012)
		_cache["passby"] = _wav(samples)
	return _cache["passby"]


static func _report(p: Array, suppressed: bool, seed_value: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var crack: float = p[0] * (0.12 if suppressed else 1.0)
	var body_s: float = p[1] * (0.7 if suppressed else 1.0)
	var bright: float = p[2] * (0.35 if suppressed else 1.0)
	var thump_hz: float = p[3]
	var thump: float = p[4] * (0.5 if suppressed else 1.0)
	var tail_s: float = p[5] * (0.4 if suppressed else 1.0)
	var tail: float = p[6] * (0.35 if suppressed else 1.0)
	var length := int((0.05 + body_s * 4.0 + tail_s) * RATE)
	var samples := PackedFloat32Array()
	samples.resize(length)
	var low := 0.0  # one-pole low-pass state for the body
	var low2 := 0.0  # and a darker one for the tail
	var phase := 0.0
	for i in length:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		# The body darkens as it decays: its low-pass closes over time.
		var cutoff := lerpf(0.05, 0.05 + 0.6 * bright, exp(-t / (body_s * 1.5)))
		low += (noise - low) * cutoff
		low2 += (noise - low2) * 0.02
		var s := 0.0
		s += noise * crack * exp(-t / 0.0025)
		s += low * 2.2 * exp(-t / body_s)
		phase += TAU * thump_hz * (1.0 + 1.5 * exp(-t / 0.01)) / RATE
		s += sin(phase) * thump * exp(-t / 0.07)
		# The tail swells in a moment after the shot and rolls away.
		s += low2 * 5.0 * tail * smoothstep(0.0, 0.03, t) * exp(-t / (tail_s * 0.45))
		samples[i] = s
	if suppressed:
		# The action still cycles: a metallic clack a moment after.
		var at := int(0.012 * RATE)
		for i in int(0.03 * RATE):
			if at + i < length:
				samples[at + i] += sin(i * 0.9) * 0.25 * exp(-float(i) / (0.004 * RATE))
	return _wav(samples)


## The string's thrum and the arrow leaving.
static func _bow() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var length := int(0.45 * RATE)
	var samples := PackedFloat32Array()
	samples.resize(length)
	var low := 0.0
	for i in length:
		var t := float(i) / RATE
		var twang := sin(TAU * 98.0 * t) * 0.6 + sin(TAU * 196.0 * t) * 0.25 + sin(TAU * 311.0 * t) * 0.12
		low += (rng.randf_range(-1.0, 1.0) - low) * 0.15
		samples[i] = twang * exp(-t / 0.06) + low * 0.6 * smoothstep(0.0, 0.02, t) * exp(-t / 0.12)
	return _wav(samples)


## Normalised, soft-clipped 16-bit mono.
static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.001
	for s in samples:
		peak = maxf(peak, absf(s))
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := samples[i] / peak * 1.6
		v = v / (1.0 + absf(v))  # soft clip: loud without harsh digital edges
		bytes.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav
