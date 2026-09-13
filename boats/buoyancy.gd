class_name Buoyancy
extends RefCounted
## Per-probe buoyancy: a spring toward the water surface plus damping against
## the *water's* vertical motion. Damping against world velocity makes a hull
## lag behind a rising swell until the wave washes over the deck.

const GRAVITY := 9.8
const DEFAULT_FLOAT_DEPTH := 0.12    ## draft at rest, metres
const DEFAULT_DAMPING_RATIO := 0.6   ## fraction of critical damping
const MAX_SPRING_RATIO := 4.0        ## a deeply dunked probe pushes at most 4x its share
const WATER_VELOCITY_DT := 0.05      ## time step for estimating water vertical velocity


## Upward force (N) on one probe.
##   depth: how far below the surface the probe is (<= 0 means out of the water)
##   water_vy / probe_vy: vertical velocities of the surface and of the probe
##   support: the weight (N) this probe carries at rest
static func probe_force(depth: float, water_vy: float, probe_vy: float, support: float,
		float_depth: float = DEFAULT_FLOAT_DEPTH, damping_ratio: float = DEFAULT_DAMPING_RATIO) -> float:
	if depth <= 0.0:
		return 0.0
	var spring := support * minf(depth / float_depth, MAX_SPRING_RATIO)
	var omega := sqrt(GRAVITY / float_depth)
	var damping := 2.0 * damping_ratio * (support / GRAVITY) * omega
	var immersion := minf(depth / float_depth, 1.0)
	var damp := clampf(-(probe_vy - water_vy) * damping * immersion, -2.0 * support, 2.0 * support)
	return spring + damp


## Vertical velocity of the water surface at `xz`, by finite difference.
static func water_vertical_velocity(xz: Vector2, t: float) -> float:
	return (Waves.height_at(xz, t) - Waves.height_at(xz, t - WATER_VELOCITY_DT)) / WATER_VELOCITY_DT
