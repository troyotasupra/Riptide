shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
// The foam on a plunge pool: where the fall lands the water is beaten white,
// and rings of froth ride outward from the impact and break up as they go.
// Drawn on a flat disc lying on the pool, fading to nothing at its rim.
//
// The mesh is a disc of radius 1 in its own space; UV is (-1..1, -1..1).

uniform float speed = 0.5;
uniform vec3 foam_colour : source_color = vec3(0.97, 0.99, 1.0);
// How much of the middle is solid white water.
uniform float boil = 0.32;

varying vec2 v_uv;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	v_uv = UV * 2.0 - 1.0;
}

void fragment() {
	float r = length(v_uv);
	if (r > 1.0) {
		discard;
	}
	float angle = atan(v_uv.y, v_uv.x);
	float t = TIME * speed;
	// Rings riding outward, wobbling as they go and losing themselves at the rim.
	float rings = noise2(vec2(angle * 2.4, r * 5.0 - t * 3.0));
	float churn = noise2(vec2(angle * 5.1 + 9.0, r * 9.0 - t * 4.5));
	float pattern = rings * 0.6 + churn * 0.5;
	// Solid white where it lands, breaking into streaks and gone by the edge.
	float middle = 1.0 - smoothstep(0.0, boil + 0.12, r);
	float band = smoothstep(0.45, 0.9, pattern) * (1.0 - smoothstep(boil, 1.0, r));
	float foam = clamp(middle + band, 0.0, 1.0);
	ALBEDO = foam_colour;
	ALPHA = foam * (1.0 - smoothstep(0.82, 1.0, r));
	ROUGHNESS = 0.8;
	SPECULAR = 0.3;
}
