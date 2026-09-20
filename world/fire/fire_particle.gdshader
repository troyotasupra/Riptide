shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_opaque;
// One speck of fire: a tiny solid billboarded square. Fire is made of hard
// pixels, not glow, so nothing here is additive or soft-edged — a speck is
// either there or it isn't, and it shrinks to nothing at the end of its life.
//
// Its colour is read from where it is in the flame, not from its age: white
// hot in the heart of the body, yellow round that, orange at the edge, and
// dull orange once it is clear of the fire altogether.

uniform vec3 fire_origin;
// The width of the body to colour from its middle outward. A negative width
// means there is no single middle — a hillside of wildfire — and the colour is
// taken from how much life the speck has left instead.
uniform float fire_width = 0.5;
uniform vec3 core_colour : source_color = vec3(1.0, 0.99, 0.86);
uniform vec3 body_colour : source_color = vec3(1.0, 0.79, 0.28);
uniform vec3 edge_colour : source_color = vec3(0.98, 0.58, 0.13);
uniform vec3 rim_colour : source_color = vec3(0.82, 0.36, 0.06);

varying flat vec3 speck;

void vertex() {
	// Where this speck actually is, before the billboard turns it to face us.
	vec3 at = MODEL_MATRIX[3].xyz;
	// COLOR.a falls away over the speck's life, which stands in for cooling.
	float cooled = 1.0 - COLOR.a;
	float from_core = cooled;
	if (fire_width > 0.0) {
		float out_from_middle = length(at.xz - fire_origin.xz) / fire_width;
		float up = clamp((at.y - fire_origin.y) / max(fire_width * 2.4, 0.2), 0.0, 1.4);
		from_core = out_from_middle * 0.8 + up * 0.7 + cooled * 0.3;
	}
	from_core = clamp(from_core, 0.0, 1.0);
	if (from_core < 0.18) {
		speck = core_colour;
	} else if (from_core < 0.42) {
		speck = mix(core_colour, body_colour, (from_core - 0.18) / 0.24);
	} else if (from_core < 0.7) {
		speck = mix(body_colour, edge_colour, (from_core - 0.42) / 0.28);
	} else {
		speck = mix(edge_colour, rim_colour, (from_core - 0.7) / 0.3);
	}

	// Billboard, keeping the size the particle system gave us.
	mat4 facing = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = facing * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	ALBEDO = speck;
}
