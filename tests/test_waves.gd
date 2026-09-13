extends "res://tests/test_case.gd"

const WavesScript = preload("res://ocean/waves.gd")


func test_height_matches_displaced_surface() -> void:
	# The undisturbed point we solve for must actually land back on the query position.
	for xz: Vector2 in [Vector2.ZERO, Vector2(12.5, -40.0), Vector2(700.0, 300.0)]:
		for t: float in [0.0, 3.7, 125.0]:
			var p := xz
			for i in 4:
				var step := WavesScript.displacement(p, t)
				p = xz - Vector2(step.x, step.z)
			var d := WavesScript.displacement(p, t)
			var landed := p + Vector2(d.x, d.z)
			near(landed.distance_to(xz), 0.0, 0.05, "surface solve at %s t=%s" % [xz, t])
			near(WavesScript.height_at(xz, t), d.y, 0.0001, "height_at agrees with solve")


func test_heights_bounded_by_amplitudes() -> void:
	var max_amp := 0.0
	for w: Vector4 in WavesScript.WAVES:
		max_amp += w.z * WavesScript.MAX_ROUGHNESS / (TAU / w.w)
	for i in 200:
		var xz := Vector2(i * 37.0 - 3000.0, i * 11.0 - 900.0)
		var h := WavesScript.height_at(xz, i * 0.73)
		check(absf(h) <= max_amp + 0.001, "height %.3f exceeds bound %.3f" % [h, max_amp])


func test_sea_rougher_further_out() -> void:
	var near_start := WavesScript.roughness(Vector2(20.0, 0.0))
	var mid := WavesScript.roughness(Vector2(0.0, 600.0))
	var far := WavesScript.roughness(Vector2(3000.0, 3000.0))
	check(near_start < mid and mid < far, "roughness should grow with distance")
	near(far, WavesScript.MAX_ROUGHNESS, 0.0001, "roughness clamps at max")


func test_no_looping_crests() -> void:
	var total := 0.0
	for w: Vector4 in WavesScript.WAVES:
		total += w.z * WavesScript.MAX_ROUGHNESS
	check(total < 1.0, "summed steepness %.3f must stay below 1.0" % total)


func test_deterministic() -> void:
	var a := WavesScript.height_at(Vector2(55.0, 81.0), 42.0)
	var b := WavesScript.height_at(Vector2(55.0, 81.0), 42.0)
	check(a == b, "same inputs give same height")
