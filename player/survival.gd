class_name Survival
extends RefCounted
## Pure survival state and rules: hunger, thirst, body temperature, health.
## No nodes here, so it runs on the host and in headless tests alike.

const MAX := 100.0
const NORMAL_TEMP := 37.0
const HYPOTHERMIA_TEMP := 33.0
const HYPERTHERMIA_TEMP := 40.0

const HUNGER_PER_SEC := MAX / 2400.0  # full to empty in 40 minutes
const THIRST_PER_SEC := MAX / 1500.0  # full to empty in 25 minutes
const EXERTION_DRAIN := 1.0           # sprinting/swimming multiplies drain by up to this much extra

const COMFORT_MIN_ENV := 18.0  # below this air temperature the body cools
const COMFORT_MAX_ENV := 24.0  # above this, heavy gear overheats you
const COLD_FACTOR := 0.4       # degrees of body temp lost per degree of cold, unprotected
const HEAT_FACTOR := 0.8       # degrees gained per degree of heat, fully insulated
const TEMP_CHANGE_RATE := 0.05 # fraction of the gap to equilibrium closed per second

## A full lungful lasts this long under water; you get it back three times as
## fast at the surface, and drown once it's gone.
const BREATH_SECONDS := 45.0
const BREATH_RECOVER := 3.0
const DROWN_DAMAGE := 6.0

const STARVING_DAMAGE := 1.0
const TEMP_DAMAGE := 1.5
const REGEN_PER_SEC := 0.5
## While sick: hunger and thirst drain this many times faster, a little health
## trickles away, and nothing regenerates.
const SICK_DRAIN := 2.0
const SICK_DAMAGE := 0.15

var health := MAX
var hunger := MAX
var thirst := MAX
var body_temp := NORMAL_TEMP
## Air left in your lungs, 0..MAX.
var breath := MAX
## Seconds of sickness left (food poisoning, bad water).
var sickness := 0.0


## Body temperature the player settles at in `env_temp_c` air with `insulation` 0..1.
static func equilibrium_temp(env_temp_c: float, insulation: float) -> float:
	insulation = clampf(insulation, 0.0, 1.0)
	var cold := maxf(0.0, COMFORT_MIN_ENV - env_temp_c) * COLD_FACTOR * (1.0 - insulation)
	var heat := maxf(0.0, env_temp_c - COMFORT_MAX_ENV) * HEAT_FACTOR * insulation
	return NORMAL_TEMP - cold + heat


## Advance by `dt` seconds. `env_temp_c` already includes night, biome and
## wetness; `exertion` 0..1 is how hard the player is working.
func tick(dt: float, env_temp_c: float, insulation: float, exertion: float) -> void:
	var sick := sickness > 0.0
	var drain := (1.0 + clampf(exertion, 0.0, 1.0) * EXERTION_DRAIN) * (SICK_DRAIN if sick else 1.0)
	sickness = maxf(0.0, sickness - dt)
	hunger = maxf(0.0, hunger - HUNGER_PER_SEC * drain * dt)
	thirst = maxf(0.0, thirst - THIRST_PER_SEC * drain * dt)

	var target := equilibrium_temp(env_temp_c, insulation)
	body_temp += (target - body_temp) * minf(1.0, TEMP_CHANGE_RATE * dt)

	var damage := 0.0
	if hunger <= 0.0:
		damage += STARVING_DAMAGE
	if thirst <= 0.0:
		damage += STARVING_DAMAGE
	if body_temp < HYPOTHERMIA_TEMP or body_temp > HYPERTHERMIA_TEMP:
		damage += TEMP_DAMAGE
	if sick:
		damage += SICK_DAMAGE

	if damage > 0.0:
		health = maxf(0.0, health - damage * dt)
	elif hunger > 50.0 and thirst > 50.0:
		health = minf(MAX, health + REGEN_PER_SEC * dt)


## Advance breath by `dt`: underwater it runs down and then you drown; at the
## surface it comes back quickly.
func breathe(dt: float, underwater: bool) -> void:
	if underwater:
		breath = maxf(0.0, breath - MAX / BREATH_SECONDS * dt)
		if breath <= 0.0:
			health = maxf(0.0, health - DROWN_DAMAGE * dt)
	else:
		breath = minf(MAX, breath + MAX / BREATH_SECONDS * BREATH_RECOVER * dt)


func make_sick(seconds: float) -> void:
	sickness = maxf(sickness, seconds)


func heal(amount: float) -> void:
	health = minf(MAX, health + amount)


func eat(amount: float) -> void:
	hunger = minf(MAX, hunger + amount)


func drink(amount: float) -> void:
	thirst = minf(MAX, thirst + amount)


func take_damage(amount: float) -> void:
	health = maxf(0.0, health - amount)


func is_dead() -> bool:
	return health <= 0.0


func to_dict() -> Dictionary:
	return {"health": health, "hunger": hunger, "thirst": thirst, "body_temp": body_temp, "sickness": sickness, "breath": breath}


func from_dict(d: Dictionary) -> void:
	health = d.get("health", MAX)
	hunger = d.get("hunger", MAX)
	thirst = d.get("thirst", MAX)
	body_temp = d.get("body_temp", NORMAL_TEMP)
	sickness = d.get("sickness", 0.0)
	breath = d.get("breath", MAX)
