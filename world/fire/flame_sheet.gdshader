shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// A sheet of fire: one continuous strip of flat-coloured facets whose top edge
// breaks into tongues. The tongues rise and fall, drift along the sheet and lick
// side to side on a wave that runs up them, so the fire flows, while the body
// below stays solid. Sheets from neighbouring patches overlap into one fire.
// The ends taper so the overlaps don't show a seam.
//
// Mesh: UV.x -1..1 across, UV.y 0..1 up; the mesh spans x -1..1 and y 0..1.
// Per instance (MultiMesh custom data): x phase 0..1, y speed, z tongues across, w heat 0..1.

uniform float boost = 1.12;
// Root to tip. Fire by default; a waterfall's splash uses white and pale blues.
uniform vec3 c_root = vec3(1.0, 0.88, 0.5);
uniform vec3 c_low = vec3(1.0, 0.64, 0.1);
uniform vec3 c_mid = vec3(0.97, 0.34, 0.03);
uniform vec3 c_tip = vec3(0.66, 0.08, 0.02);

varying flat vec3 facet;
// How near this vertex is to the tip of its tongue, 0 at the root.
varying float v_up;

vec3 ramp(float k) {
	if (k < 0.12) return mix(c_root, c_low, k / 0.12);
	if (k < 0.48) return mix(c_low, c_mid, (k - 0.12) / 0.36);
	return mix(c_mid, c_tip, (k - 0.48) / 0.52);
}

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

// How tall the sheet stands at `x` (0..1 of full height): tongues along the top.
// Each tongue is a broad rounded mound that draws up into a point: cos-shaped
// hills (round shoulders, no V between them) sharpened only near the top.
float tongue(float u) {
	float hill = 0.5 + 0.5 * cos(u);
	return pow(hill, 1.8);
}

float top_at(float x, float time, float phase, float tongues) {
	float drift = time * 0.35;
	float a = tongue(x * tongues * 3.1416 + drift + phase);
	float b = tongue(x * tongues * 0.83 * 3.1416 - drift * 1.4 + phase * 1.9);
	// Each tongue rises and falls on its own beat.
	float beat_a = 0.7 + 0.3 * sin(time * 2.2 + phase + floor(x * tongues) * 1.7);
	float beat_b = 0.65 + 0.35 * sin(time * 1.6 + phase * 2.0 + x * 2.0);
	// Every so often a tongue shoots up and lets go of the body — fire behaving
	// like burning gas rather than a rippling liquid.
	float tongue_id = floor(x * tongues) + phase * 3.0;
	float rate = 0.5;
	float cycle = time * rate + hash(tongue_id);
	float burst = step(0.62, hash(tongue_id + floor(cycle) * 7.3));
	float k = fract(cycle);
	float spike = burst * smoothstep(0.0, 0.18, k) * smoothstep(1.0, 0.35, k);
	float peaks = max(max(a * beat_a, b * beat_b * 0.85), spike * (0.9 + 0.7 * a));
	float body = 0.4 + 0.06 * sin(time * 2.9 + x * 4.0 + phase);
	float ends = smoothstep(1.05, 0.6, abs(x));
	return (body + (1.0 - body) * peaks) * mix(0.55, 1.0, ends);
}

void vertex() {
	float x = UV.x;
	float t = UV.y;
	float phase = INSTANCE_CUSTOM.x * 6.2832;
	float time = TIME * INSTANCE_CUSTOM.y;
	float tongues = INSTANCE_CUSTOM.z;
	float top = top_at(x, time, phase, tongues);
	float y = t * top;
	// The lick: a sideways wave running up the flames, growing toward the tips, so
	// a tongue bends one way low down and the other way near its point.
	float sway = sin(t * 3.6 - time * 4.2 + x * 2.3 + phase) * 0.11 * t * t;
	sway += sin(t * 7.0 - time * 6.5 + x * 5.0 + phase * 2.0) * 0.025 * t;
	// A little ripple through the sheet, so it isn't a flat card.
	float ripple = sin(x * 6.0 + time * 1.9 + phase) * 0.06 + sin(t * 3.0 - time * 3.0 + x * 4.0) * 0.04 * t;
	VERTEX = vec3(x + sway, y, ripple);

	v_up = t;
	float k = y * 1.12 + (hash(float(VERTEX_ID) + INSTANCE_CUSTOM.x * 97.0) - 0.5) * 0.14 - INSTANCE_CUSTOM.w * 0.04;
	facet = ramp(clamp(k, 0.0, 1.0));
}

void fragment() {
	ALBEDO = facet * boost;
	// The very tips thin out into nothing, so a lick that shoots up breaks away
	// instead of standing there as a solid blade.
	ALPHA = clamp(1.0 - smoothstep(0.72, 1.0, v_up) * 0.85, 0.0, 1.0);
}
