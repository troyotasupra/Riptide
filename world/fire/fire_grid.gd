class_name FireGrid
extends RefCounted
## Wildfire on a grid of CELL-metre squares over the whole world. Pure: nothing
## here touches nodes, so it runs the same in tests and on the host.
##
## A cell's `fuel` (0..1) comes from whatever grows there — dry grass and jungle
## burn, sand, rock and water don't. A burning cell burns for a while and, each
## step, may set its eight neighbours alight: likelier with more fuel, downwind,
## and in a stronger wind; rain damps the spread and puts fires out. Burnt ground
## grows back after REGROW_SECONDS. At most MAX_BURNING cells burn at once.

const CELL := 2.0
const MAX_BURNING := 600
## How long a fully-fuelled cell burns.
const BURN_SECONDS := 7.0
## Chance per second that a burning cell lights one full-fuel neighbour in still air.
const SPREAD_RATE := 0.2
const REGROW_SECONDS := 2400.0

const NEIGHBOURS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]

## Callable(Vector2 world xz) -> float fuel 0..1.
var fuel_at: Callable
## cell -> seconds of burning left
var burning := {}
## cell -> the clock time it grows back
var burnt := {}
var _fuel_cache := {}


func _init(fuel_function: Callable = Callable()) -> void:
	fuel_at = fuel_function


static func cell_of(xz: Vector2) -> Vector2i:
	return Vector2i(floori(xz.x / CELL), floori(xz.y / CELL))


static func center_of(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


func fuel(cell: Vector2i) -> float:
	if _fuel_cache.has(cell):
		return _fuel_cache[cell]
	var f := 0.0
	if fuel_at.is_valid():
		f = clampf(float(fuel_at.call(center_of(cell))), 0.0, 1.0)
	_fuel_cache[cell] = f
	return f


## Something (a structure, a tree) adds to or changes what's in a cell.
func set_fuel(cell: Vector2i, value: float) -> void:
	_fuel_cache[cell] = clampf(value, 0.0, 1.0)


func can_burn(cell: Vector2i) -> bool:
	return not burning.has(cell) and not burnt.has(cell) and fuel(cell) > 0.05


## Sets a cell alight; false if it can't burn (nothing there, already burnt, or too many fires).
func ignite(cell: Vector2i) -> bool:
	if not can_burn(cell) or burning.size() >= MAX_BURNING:
		return false
	burning[cell] = BURN_SECONDS * (0.4 + 0.6 * fuel(cell))
	return true


## One step of `dt` seconds. `wind` points where the wind blows, its length in m/s;
## `rain` 0..1. Returns {"lit": [cells], "out": [cells burnt out], "regrown": [cells]}.
func step(dt: float, wind: Vector2, rain: float, now: float, rng: RandomNumberGenerator) -> Dictionary:
	var lit: Array[Vector2i] = []
	var out: Array[Vector2i] = []
	var regrown: Array[Vector2i] = []
	var wind_dir := wind.normalized() if wind.length() > 0.01 else Vector2.ZERO
	var wind_push := clampf(wind.length() / 10.0, 0.0, 2.0)
	var damp := clampf(1.0 - rain * 1.25, 0.0, 1.0)
	for cell: Vector2i in burning.keys():
		var left: float = burning[cell] - dt * (1.0 + rain * 4.0)
		if left <= 0.0:
			burning.erase(cell)
			burnt[cell] = now + REGROW_SECONDS
			out.append(cell)
			continue
		burning[cell] = left
		if damp <= 0.0:
			continue
		for offset: Vector2i in NEIGHBOURS:
			var next := cell + offset
			if not can_burn(next):
				continue
			var along := Vector2(offset).normalized().dot(wind_dir)
			var lean := maxf(0.08, 1.0 + along * wind_push * 1.6)
			var diagonal := 0.7 if offset.x != 0 and offset.y != 0 else 1.0
			var chance := SPREAD_RATE * fuel(next) * lean * diagonal * damp * dt
			if rng.randf() < chance and ignite(next):
				lit.append(next)
	for cell: Vector2i in burnt.keys():
		if now >= burnt[cell]:
			burnt.erase(cell)
			regrown.append(cell)
	return {"lit": lit, "out": out, "regrown": regrown}


## Times saved relative to `now`, so they survive a new clock.
func to_save(now: float) -> Dictionary:
	var fires := []
	for cell: Vector2i in burning:
		fires.append([cell.x, cell.y, burning[cell]])
	var scars := []
	for cell: Vector2i in burnt:
		scars.append([cell.x, cell.y, maxf(0.0, burnt[cell] - now)])
	return {"burning": fires, "burnt": scars}


func from_save(data: Dictionary, now: float) -> void:
	burning.clear()
	burnt.clear()
	for entry: Array in data.get("burning", []):
		burning[Vector2i(int(entry[0]), int(entry[1]))] = float(entry[2])
	for entry: Array in data.get("burnt", []):
		burnt[Vector2i(int(entry[0]), int(entry[1]))] = now + float(entry[2])
