extends "res://tests/test_case.gd"

const Sim = preload("res://world/sim/grain_sim.gd")


## A flat floor at y = 0, 16 m across, unless a slope is asked for.
static func _flat(sim, tilt: float = 0.0) -> void:
	var cells := 33
	var step := 0.5
	var heights := PackedFloat32Array()
	heights.resize(cells * cells)
	for z in cells:
		for x in cells:
			heights[z * cells + x] = (x * step - 8.0) * tilt
	sim.set_ground(heights, Vector2(-8.0, -8.0), step, cells)


static func _run(sim, seconds: float) -> void:
	for i in int(seconds / 0.05):
		sim.step(0.05)


func test_water_falls_lands_and_runs_downhill() -> void:
	var sim = Sim.new(64)
	_flat(sim, -0.25)  # tilted down toward +x
	sim.spawn(Sim.WATER, Vector3(0.0, 3.0, 0.0), Vector3.ZERO)
	_run(sim, 0.8)
	check(sim.count == 1, "the drop is still going")
	check(sim.py[0] <= sim.ground_at(sim.px[0], sim.pz[0]) + 0.05, "it fell to the ground")
	var landed_x: float = sim.px[0]
	_run(sim, 0.6)
	check(sim.count == 0 or sim.px[0] > landed_x + 0.05, "and ran off downhill (%.2f -> %.2f)" % [landed_x, sim.px[0] if sim.count > 0 else landed_x])


func test_water_soaks_away_instead_of_piling_up() -> void:
	var sim = Sim.new(64)
	_flat(sim)
	sim.spawn(Sim.WATER, Vector3(0.0, 0.5, 0.0), Vector3.ZERO)
	_run(sim, Sim.LIFE[Sim.WATER] + 1.0)
	check(sim.count == 0, "a drop on flat ground is gone in the end")


func test_fire_rises_cools_and_turns_to_smoke() -> void:
	var sim = Sim.new(64)
	_flat(sim)
	sim.spawn(Sim.FIRE, Vector3(0.0, 0.1, 0.0), Vector3.ZERO)
	_run(sim, 0.4)
	check(sim.count == 1 and sim.kind[0] == Sim.FIRE, "it's still burning")
	check(sim.py[0] > 0.15, "and it has climbed (%.2f m)" % sim.py[0])
	# Some of what burns goes up as smoke and the rest is spent, so try a crowd.
	for i in 40:
		sim.spawn(Sim.FIRE, Vector3(0.0, 0.1, 0.0), Vector3.ZERO)
	_run(sim, Sim.LIFE[Sim.FIRE] + 0.2)
	check(sim.count_of(Sim.FIRE) == 0, "the flames are spent")
	check(sim.count_of(Sim.SMOKE) > 0, "and some of it went up as smoke")
	check(sim.count_of(Sim.SMOKE) < 40, "though not all of it")


func test_smoke_leans_with_the_wind() -> void:
	var sim = Sim.new(64)
	_flat(sim)
	sim.wind = Vector2(3.0, 0.0)
	sim.spawn(Sim.SMOKE, Vector3(0.0, 1.0, 0.0), Vector3.ZERO)
	_run(sim, 1.0)
	check(sim.count == 1 and sim.px[0] > 0.5, "it has drifted downwind (%.2f m)" % sim.px[0])


func test_water_puts_fire_out_and_makes_steam() -> void:
	var sim = Sim.new(64)
	_flat(sim)
	for i in 6:
		sim.spawn(Sim.FIRE, Vector3(0.0, 0.5, 0.0), Vector3.ZERO)
	sim.spawn(Sim.WATER, Vector3(0.0, 0.62, 0.0), Vector3(0.0, -1.0, 0.0))
	sim.step(0.05)
	check(sim.doused > 0, "the water hit the fire")
	check(sim.count_of(Sim.STEAM) > 0, "and came off as steam")


func test_an_ember_falls_and_bounces_before_it_dies() -> void:
	var sim = Sim.new(64)
	_flat(sim)
	sim.spawn(Sim.EMBER, Vector3(0.0, 2.0, 0.0), Vector3(1.0, 0.0, 0.0))
	_run(sim, 0.7)
	check(sim.count == 1 and sim.py[0] >= -0.01, "it stays on top of the ground")
	_run(sim, Sim.LIFE[Sim.EMBER])
	check(sim.count == 0, "and it goes out")


func test_the_sim_fills_up_rather_than_growing_forever() -> void:
	var sim = Sim.new(8)
	_flat(sim)
	var made := 0
	for i in 20:
		if sim.spawn(Sim.FIRE, Vector3.ZERO, Vector3.UP):
			made += 1
	check(made == 8 and sim.count == 8, "it takes what it has room for and no more")
