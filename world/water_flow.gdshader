shader_type spatial;
render_mode cull_disabled;
// Running water in flat-coloured facets, the same way the fire is drawn: waves
// roll along the surface in the direction it flows, lifting and dropping the
// facets, and foam streaks ride down with them, white on blue-green, one colour
// per facet. Used for the waterfall, the stream and (with `still`) the pools.
//
// Flowing meshes carry UV.x -1..1 across and UV.y = metres along the flow.
// Still water uses world x/z instead and just shivers.

// The same colours and clarity as the sea, so fresh water and salt water read
// as one substance: you see the bottom through it, and it deepens to blue as
// the bottom falls away.
uniform vec3 deep : source_color = vec3(0.04, 0.26, 0.40);
uniform vec3 shallow : source_color = vec3(0.30, 0.60, 0.62);
uniform float clarity = 6.0;
uniform float min_opacity = 0.3;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec3 foam : source_color = vec3(0.90, 0.96, 1.0);
// Metres per second along the flow.
uniform float speed = 3.0;
// 0..1: how much of the surface is white water.
uniform float foam_amount = 0.3;
uniform float ripple = 0.05;
uniform float alpha = 1.0;
uniform bool still = false;

varying flat float facet_light;
varying flat float facet_white;

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
		// Foam comes on over a band rather than switching, so a facet can be
		// half white water instead of a sheet of paper.
		white = smoothstep(1.0 - foam_amount - 0.12, 1.0 - foam_amount + 0.06, band * 0.85 + hash(vec2(float(VERTEX_ID), lane)) * 0.3);
	}
	VERTEX += NORMAL * wave * ripple;
	float light = 0.5 + 0.25 * wave + (hash(world.xz * 7.0) - 0.5) * 0.25;
	facet_light = clamp(light, 0.0, 1.0);
	facet_white = white;
}

void fragment() {
	// Seen from underneath (a pool from below the surface), light the face you
	// are actually looking at instead of leaving it black.
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
	// How deep the water is along this line of sight, exactly as the sea works
	// it out: shallow water shows the bottom, deep water closes up.
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float raw = texture(depth_tex, SCREEN_UV).r;
	vec4 below = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	float column = max(-below.z / below.w + VERTEX.z, 0.0);
	float under = column * max(facing, 0.12);

	vec3 colour = mix(shallow, deep, smoothstep(0.6, 14.0, under));
	// The facets keep their own light, so the surface still reads as flat planes.
	colour *= 0.82 + 0.36 * facet_light;
	ALBEDO = mix(colour, foam, facet_white);

	float murk = clamp(under / max(clarity, 0.5), 0.0, 1.0);
	float body = mix(min_opacity, 1.0, pow(murk, 1.4));
	float grazing = 0.45 * pow(1.0 - facing, 3.0);
	// White water is white water: you can't see through it.
	ALPHA = clamp(max(max(body, grazing), facet_white) * alpha, 0.0, 1.0);
	ROUGHNESS = 0.18;
	SPECULAR = 0.55;
}
