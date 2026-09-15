class_name FishingMath
extends RefCounted
## Fishing rules, free of engine singletons so tests can check them: what bites
## where and when, how long a bite takes, and the fight on the line — hold to
## reel (tension climbs), ease off (tension falls but the fish runs). Too much
## tension snaps the line; too much slack, or letting it run too far, loses it.

const SHORE_DEPTH := 3.5
const REEF_DEPTH := 14.0
const MIN_CAST := 4.0
const MAX_CAST := 22.0
const CHARGE_SECONDS := 1.1
const HOOK_WINDOW := 1.3
const REEL_SPEED := 4.0
## Tension added per second while reeling, before the fish's own pull.
const TENSION_REEL := 0.06
## How fast a fish takes line while you ease off, per unit of pull.
const RUN_SPEED := 1.4
const TENSION_EASE := 0.9
const SLACK_ESCAPE := 3.0
const LAND_DISTANCE := 1.2
## The fish gets away if it runs this much further out than where it was hooked.
const ESCAPE_EXTRA := 10.0
## Chance in deep water that a shark goes for the fish on your line, and how much harder it pulls.
const SHARK_CHANCE := 0.14
const SHARK_PULL := 2.4
## A landed catch must have been on the line at least this long (the host checks).
const MIN_FIGHT_SECONDS := 1.0


## "shore", "reef" or "deep" from the water depth under the bobber.
static func spot_of(water_depth: float, near_reef: bool) -> String:
	if water_depth < SHORE_DEPTH:
		return "shore"
	if near_reef or water_depth < REEF_DEPTH:
		return "reef"
	return "deep"


static func time_band(clock_hours: float) -> String:
	if clock_hours >= 5.0 and clock_hours < 8.0:
		return "dawn"
	if clock_hours >= 8.0 and clock_hours < 17.0:
		return "day"
	if clock_hours >= 17.0 and clock_hours < 20.0:
		return "dusk"
	return "night"


## How likely each species is to take `bait_kind` at `spot` in `band` and `weather`. Zero-odds species are left out.
static func weights(spot: String, bait_kind: String, band: String, weather: String) -> Dictionary:
	var out := {}
	for id: String in FishTable.SPECIES:
		var s: Dictionary = FishTable.SPECIES[id]
		var w := float(s.habitats.get(spot, 0.0)) * float(s.baits.get(bait_kind, 0.0)) \
			* float(s.times.get(band, 1.0)) * float(s.weather.get(weather, 1.0))
		if w > 0.0:
			out[id] = w
	return out


static func pick(odds: Dictionary, roll: float) -> String:
	var total := 0.0
	for id: String in odds:
		total += float(odds[id])
	if total <= 0.0:
		return ""
	var target := clampf(roll, 0.0, 0.9999) * total
	for id: String in odds:
		target -= float(odds[id])
		if target < 0.0:
			return id
	return odds.keys().back()


## Seconds until something bites; hungrier water (more total odds) bites sooner. INF if nothing will.
static func bite_seconds(odds: Dictionary, roll: float) -> float:
	var total := 0.0
	for id: String in odds:
		total += float(odds[id])
	if total <= 0.0:
		return INF
	return lerpf(4.0, 14.0, clampf(roll, 0.0, 1.0)) / clampf(0.4 + total * 0.25, 0.5, 2.5)


## Weight of a catch: most are small for their kind, a few are monsters.
static func roll_kg(species: String, roll: float) -> float:
	var kg: Array = FishTable.SPECIES[species].kg
	return lerpf(float(kg[0]), float(kg[1]), roll * roll)


## How hard a fish pulls: its species' fight, stronger the bigger it is.
static func strength(species: String, kg: float) -> float:
	var s: Dictionary = FishTable.SPECIES[species]
	var size := inverse_lerp(float(s.kg[0]), float(s.kg[1]), kg)
	return float(s.fight) * lerpf(0.75, 1.15, clampf(size, 0.0, 1.0))


## A fresh fight, the fish `distance` metres out.
static func new_fight(distance: float) -> Dictionary:
	return {"distance": distance, "start": distance, "tension": 0.25, "slack": 0.0, "shark": false}


## Advances a fight by `dt`. `surge` 0..~1.3 is how hard the fish is pulling right now.
## Returns "" while it goes on, or "landed", "snapped" or "escaped".
static func step(fight: Dictionary, reeling: bool, dt: float, surge: float, pull_strength: float) -> String:
	var pull := pull_strength * maxf(0.0, surge) * (SHARK_PULL if fight.get("shark", false) else 1.0)
	var tension: float = fight.tension
	var distance: float = fight.distance
	if reeling:
		tension += (TENSION_REEL + pull * 0.9) * dt
		distance += (-REEL_SPEED * (1.0 - 0.5 * tension) + pull * 1.2) * dt
	else:
		tension += (-TENSION_EASE + pull * 0.25) * dt
		distance += pull * RUN_SPEED * dt
	fight.tension = clampf(tension, 0.0, 1.2)
	fight.distance = distance
	fight.slack = float(fight.slack) + dt if fight.tension < 0.04 else 0.0
	if fight.tension >= 1.0:
		return "snapped"
	if distance >= float(fight.start) + ESCAPE_EXTRA or float(fight.slack) >= SLACK_ESCAPE:
		return "escaped"
	if distance <= LAND_DISTANCE:
		return "landed"
	return ""


## The rhythm of a fish's pull at `time` into the fight.
static func surge_at(time: float, speed: float) -> float:
	return clampf(0.55 + 0.45 * sin(time * speed * 3.1) + 0.3 * sin(time * speed * 7.3 + 1.7), 0.0, 1.3)
