class_name GrainSim
extends RefCounted
## A falling-grain simulation, the way Noita does fire and water: thousands of
## small grains, each obeying a few simple rules, and everything that looks like
## fire, smoke, spray or running water is those grains behaving.
##
## Pure logic — no scene tree, no rendering — so it can be tested headless. A
## GrainField owns one of these, feeds it the ground under it, and draws the
## grains. Rules, in short:
##   WATER  falls, lands, runs downhill, soaks away, and puts fire out
##   FIRE   rises because it is hot, wanders, cools, and becomes SMOKE
##   SMOKE  rises slowly, leans with the wind and thins out
##   EMBER  is thrown out of a fire, falls, bounces and dies
##   STEAM  is what water and fire make between them: rises fast, gone quickly
##
## Grains are kept in flat arrays and removed by swapping the last one down, so
## a step never allocates.

enum { WATER, FIRE, SMOKE, EMBER, STEAM }

const GRAVITY := 9.8
## How much speed a grain keeps when it lands on the ground.
const BOUNCE := Vector2(0.72, 0.18)  # (along the slope, into it)
## Seconds a grain of each kind lives, at most.
const LIFE := [6.0, 0.55, 2.6, 1.6, 1.4]
## How fast fire and smoke climb (m/s² of lift while they are hot).
const FIRE_LIFT := 4.2
const SMOKE_LIFT := 0.9
const STEAM_LIFT := 2.6
## How wildly fire wanders as it rises.
const SWIRL := 1.9
## Water that lands gives itself up this fast (it soaks in, or joins the pool).
const SOAK := 0.4
## Cell size for grains noticing each other (metres).
const CELL := 0.45

var capacity := 0
var count := 0
var px := PackedFloat32Array()
var py := PackedFloat32Array()
var pz := PackedFloat32Array()
var vx := PackedFloat32Array()
var vy := PackedFloat32Array()
var vz := PackedFloat32Array()
## 1 at birth, 0 at death: fire's heat, smoke's thickness, water's body.
var heat := PackedFloat32Array()
var age := PackedFloat32Array()
var kind := PackedInt32Array()

## Ground under the sim: a square of heights, sampled bilinearly.
var _ground := PackedFloat32Array()
var _ground_origin := Vector2.ZERO
var _ground_step := 0.5
var _ground_cells := 0
## Water level (the sea, a pool) — grains landing in it stop there.
var water_level := -INF
var wind := Vector2.ZERO
## Where fire is right now, so water can find it: cell key -> grains in it.
var _fire_cells := {}
var _time := 0.0
## Grains that turned to steam this step, for the field to hiss about.
var doused := 0


func _init(grain_capacity: int = 2000) -> void:
	capacity = grain_capacity
	px.resize(capacity)
	py.resize(capacity)
	pz.resize(capacity)
	vx.resize(capacity)
	vy.resize(capacity)
	vz.resize(capacity)
	heat.resize(capacity)
	age.resize(capacity)
	kind.resize(capacity)


## The ground the grains land on: `cells` × `cells` heights, `step` apart,
## starting at `origin` (the middle of the first cell).
func set_ground(heights: PackedFloat32Array, origin: Vector2, step: float, cells: int) -> void:
	_ground = heights
	_ground_origin = origin
	_ground_step = step
	_ground_cells = cells


func ground_at(x: float, z: float) -> float:
	if _ground_cells < 2:
		return -INF
	var fx := (x - _ground_origin.x) / _ground_step
	var fz := (z - _ground_origin.y) / _ground_step
	var ix := clampi(int(floor(fx)), 0, _ground_cells - 2)
	var iz := clampi(int(floor(fz)), 0, _ground_cells - 2)
	var tx := clampf(fx - ix, 0.0, 1.0)
	var tz := clampf(fz - iz, 0.0, 1.0)
	var h00 := _ground[iz * _ground_cells + ix]
	var h10 := _ground[iz * _ground_cells + ix + 1]
	var h01 := _ground[(iz + 1) * _ground_cells + ix]
	var h11 := _ground[(iz + 1) * _ground_cells + ix + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


## Which way is downhill here, and how steep (a unit vector in x/z, times slope).
func downhill(x: float, z: float) -> Vector2:
	var step := _ground_step
	var here := ground_at(x, z)
	if here == -INF:
		return Vector2.ZERO
	return Vector2(here - ground_at(x + step, z), here - ground_at(x, z + step)) / step


## Adds one grain. False when the sim is full.
func spawn(grain: int, at: Vector3, velocity: Vector3, strength: float = 1.0) -> bool:
	if count >= capacity:
		return false
	var i := count
	count += 1
	px[i] = at.x
	py[i] = at.y
	pz[i] = at.z
	vx[i] = velocity.x
	vy[i] = velocity.y
	vz[i] = velocity.z
	heat[i] = strength
	age[i] = 0.0
	kind[i] = grain
	return true


func clear() -> void:
	count = 0


## One tick of the world.
func step(dt: float) -> void:
	_time += dt
	doused = 0
	_index_fire()
	var i := 0
	while i < count:
		if _step_grain(i, dt):
			i += 1
		else:
			_remove(i)


func _remove(i: int) -> void:
	count -= 1
	if i == count:
		return
	px[i] = px[count]
	py[i] = py[count]
	pz[i] = pz[count]
	vx[i] = vx[count]
	vy[i] = vy[count]
	vz[i] = vz[count]
	heat[i] = heat[count]
	age[i] = age[count]
	kind[i] = kind[count]


func _index_fire() -> void:
	_fire_cells.clear()
	for i in count:
		if kind[i] != FIRE:
			continue
		var key := _cell_key(px[i], py[i], pz[i])
		_fire_cells[key] = int(_fire_cells.get(key, 0)) + 1


func _cell_key(x: float, y: float, z: float) -> int:
	# Three small integers packed into one, so the dictionary key is cheap.
	var cx := int(floor(x / CELL)) & 0x3FF
	var cy := int(floor(y / CELL)) & 0x3FF
	var cz := int(floor(z / CELL)) & 0x3FF
	return (cx << 20) | (cy << 10) | cz


## True while the grain lives on.
func _step_grain(i: int, dt: float) -> bool:
	var k := kind[i]
	age[i] += dt
	match k:
		FIRE:
			return _step_fire(i, dt)
		WATER:
			return _step_water(i, dt)
		EMBER:
			return _step_ember(i, dt)
		_:
			return _step_air(i, dt, STEAM_LIFT if k == STEAM else SMOKE_LIFT)


func _step_fire(i: int, dt: float) -> bool:
	# Hot gas climbs, and the hotter it is the harder it climbs.
	heat[i] -= dt / LIFE[FIRE]
	if heat[i] <= 0.0:
		# Some of what burns goes up as smoke; the rest is simply spent.
		if randf() > 0.3:
			return false
		kind[i] = SMOKE
		heat[i] = 0.5
		age[i] = 0.0
		vy[i] *= 0.35
		return true
	vy[i] += FIRE_LIFT * heat[i] * dt
	_swirl(i, dt, SWIRL)
	_drag(i, dt, 1.4)
	_advance(i, dt)
	# Fire keeps out of the ground.
	var ground := ground_at(px[i], pz[i])
	if ground != -INF and py[i] < ground:
		py[i] = ground
		vy[i] = absf(vy[i]) * 0.4
	return py[i] > water_level


func _step_water(i: int, dt: float) -> bool:
	vy[i] -= GRAVITY * dt
	_drag(i, dt, 0.25)
	_advance(i, dt)
	# Into a fire: both are spent, and steam comes off.
	if not _fire_cells.is_empty() and _fire_cells.has(_cell_key(px[i], py[i], pz[i])):
		kind[i] = STEAM
		heat[i] = 1.0
		age[i] = 0.0
		vy[i] = absf(vy[i]) * 0.3 + 1.2
		doused += 1
		return true
	if py[i] <= water_level:
		return false  # it has joined the water it fell into
	var ground := ground_at(px[i], pz[i])
	if ground == -INF or py[i] > ground:
		return true
	# Landed: it runs downhill from here, losing itself as it goes.
	py[i] = ground
	var slope := downhill(px[i], pz[i])
	vx[i] = vx[i] * BOUNCE.y + slope.x * GRAVITY * dt * 3.0
	vz[i] = vz[i] * BOUNCE.y + slope.y * GRAVITY * dt * 3.0
	vy[i] = 0.0
	var run := Vector2(vx[i], vz[i])
	if run.length() > 6.0:
		run = run.normalized() * 6.0
		vx[i] = run.x
		vz[i] = run.y
	heat[i] -= SOAK * dt / maxf(0.25, run.length() * 0.35)
	return heat[i] > 0.0 and age[i] < LIFE[WATER]


func _step_ember(i: int, dt: float) -> bool:
	vy[i] -= GRAVITY * dt
	_drag(i, dt, 0.6)
	_advance(i, dt)
	var ground := ground_at(px[i], pz[i])
	if ground != -INF and py[i] < ground:
		py[i] = ground
		vy[i] = -vy[i] * BOUNCE.y
		vx[i] *= BOUNCE.x
		vz[i] *= BOUNCE.x
	heat[i] -= dt / LIFE[EMBER]
	return heat[i] > 0.0 and py[i] > water_level


## Smoke and steam: up, along with the wind, and thinning all the while.
func _step_air(i: int, dt: float, lift: float) -> bool:
	vy[i] += lift * dt
	vx[i] += (wind.x - vx[i]) * dt * 0.7
	vz[i] += (wind.y - vz[i]) * dt * 0.7
	_swirl(i, dt, 0.5)
	_advance(i, dt)
	heat[i] -= dt / LIFE[kind[i]]
	return heat[i] > 0.0


func _advance(i: int, dt: float) -> void:
	px[i] += vx[i] * dt
	py[i] += vy[i] * dt
	pz[i] += vz[i] * dt


func _drag(i: int, dt: float, amount: float) -> void:
	var keep := maxf(0.0, 1.0 - amount * dt)
	vx[i] *= keep
	vz[i] *= keep


## A wandering push, so rising gas curls instead of going straight up.
func _swirl(i: int, dt: float, amount: float) -> void:
	var t := _time * 1.7
	vx[i] += sin(py[i] * 2.1 + t + px[i] * 0.7) * amount * dt
	vz[i] += cos(py[i] * 1.8 - t * 1.13 + pz[i] * 0.6) * amount * dt


## Grains of a kind right now (for tests and for the renderers).
func count_of(grain: int) -> int:
	var total := 0
	for i in count:
		if kind[i] == grain:
			total += 1
	return total
