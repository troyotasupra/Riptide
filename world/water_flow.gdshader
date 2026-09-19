shader_type spatial;
render_mode cull_disabled, depth_draw_always;
// Running water in flat-coloured facets, the same way the fire is drawn: waves
// roll along the surface in the direction it flows, lifting and dropping the
// facets, and foam streaks ride down with them, white on blue-green, one colour
// per facet. Used for the waterfall, the stream and (with `still`) the pools.
//
// Flowing meshes carry UV.x -1..1 across and UV.y = metres along the flow.
// Still water uses world x/z instead and just shivers.

uniform vec3 deep : source_color = vec3(0.14, 0.45, 0.52);
uniform vec3 shallow : source_color = vec3(0.38, 0.70, 0.74);
uniform vec3 foam : source_color = vec3(0.90, 0.96, 1.0);
// Metres per second along the flow.
uniform float speed = 3.0;
// 0..1: how much of the surface is white water.
uniform float foam_amount = 0.3;
uniform float ripple = 0.05;
uniform float alpha = 0.85;
uniform bool still = false;

varying flat vec3 facet;
varying flat float facet_alpha;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME;
	float wave;
	float white;
	if (still) {
		vec2 p = world.xz;
		wave = sin(p.x * 1.9 + t * 1.2) * 0.5 + sin(p.y * 2.3 - t * 1.05) * 0.5 + sin((p.x + p.y) * 3.1 + t * 1.7) * 0.3;
		white = 0.0;
	} else {
		float along = UV.y;
		float across = UV.x;
		// Rolling waves carried down by the flow, crossing each other a little.
		wave = sin(along * 2.1 - t * speed * 2.1 + across * 1.4) + 0.55 * sin(along * 4.7 - t * speed * 4.7 * 0.93 - across * 2.6);
		// Foam streaks: lanes across the flow, each with bands that ride down it.
		float lane = floor((across + 1.0) * 3.5);
		float band = 0.5 + 0.5 * sin(along * 1.1 - t * speed * 1.1 + hash(vec2(lane, 3.0)) * 6.2832 + sin(across * 5.0 + along * 0.4) * 1.2);
		white = step(1.0 - foam_amount, band * 0.85 + hash(vec2(float(VERTEX_ID), lane)) * 0.3);
	}
	VERTEX += NORMAL * wave * ripple;
	float light = 0.5 + 0.25 * wave + (hash(world.xz * 7.0) - 0.5) * 0.25;
	vec3 body = mix(deep, shallow, clamp(light, 0.0, 1.0));
	facet = mix(body, foam, white);
	facet_alpha = mix(alpha, 1.0, white * 0.8);
}

void fragment() {
	ALBEDO = facet;
	ALPHA = facet_alpha;
	ROUGHNESS = 0.18;
	SPECULAR = 0.55;
}
