class_name Waves
extends RefCounted
## Shared Gerstner wave math. This MUST stay identical to ocean/water.gdshader,
## or boats will float on water that isn't where the player sees it.

const GRAVITY := 9.8

## Each wave: Vector4(dir_x, dir_z, steepness, wavelength_m).
## Sum of steepness * MAX_ROUGHNESS must stay below 1.0 or crests loop over.
const WAVES := [
	Vector4(1.0, 0.0, 0.18, 38.0),
	Vector4(0.7, 0.7, 0.14, 22.0),
	Vector4(-0.3, 0.95, 0.10, 13.0),
	Vector4(0.9, -0.4, 0.06, 7.0),
]

## Sea state: calm around the start island (world origin), rougher further out.
## This is what gates boat tiers — a raft swamps in open water.
const CALM_ROUGHNESS := 0.35
const MAX_ROUGHNESS := 1.6
const ROUGH_DISTANCE := 1500.0  # metres from origin to reach roughness 1.0


static func roughness(xz: Vector2) -> float:
	return clampf(CALM_ROUGHNESS + xz.length() / ROUGH_DISTANCE, CALM_ROUGHNESS, MAX_ROUGHNESS)


## Displacement of the undisturbed surface point at `xz` at time `t`.
static func displacement(xz: Vector2, t: float) -> Vector3:
	var r := roughness(xz)
	var out := Vector3.ZERO
	for w: Vector4 in WAVES:
		var d := Vector2(w.x, w.y).normalized()
		var k := TAU / w.w
		var c := sqrt(GRAVITY / k)
		var a := w.z * r / k
		var f := k * (d.dot(xz) - c * t)
		out.x += d.x * a * cos(f)
		out.y += a * sin(f)
		out.z += d.y * a * cos(f)
	return out


## Water surface height at world position `xz`. Gerstner waves move points
## sideways, so we iterate to find which undisturbed point lands on `xz`.
static func height_at(xz: Vector2, t: float) -> float:
	var p := xz
	for i in 4:
		var disp := displacement(p, t)
		p = xz - Vector2(disp.x, disp.z)
	return displacement(p, t).y


## Approximate surface normal at `xz`, for tilting floating debris.
static func normal_at(xz: Vector2, t: float) -> Vector3:
	const E := 0.5
	var hx := height_at(xz + Vector2(E, 0.0), t) - height_at(xz - Vector2(E, 0.0), t)
	var hz := height_at(xz + Vector2(0.0, E), t) - height_at(xz - Vector2(0.0, E), t)
	return Vector3(-hx, 2.0 * E, -hz).normalized()
