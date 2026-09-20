shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_opaque;
// A tongue of flame, not a spark. Each particle is a fair-sized billboard, and
// a crowd of them overlaps into one connected body of fire — which is the whole
// point: you should never be able to pick out a single one.
//
// The shape is a flame tongue (broad at the root, drawn to a point), eaten into
// by noise that climbs through it, so the edges tear and flicker the way fire
// does. Everything is snapped to a grid first, so the tongue and its torn edges
// come out as hard blocks rather than a soft glow.
//
// Colour runs from white-hot in the thick of it, through yellow and orange, to
// dull red where it is thinnest and about to go.

// How big a block is, as a fraction of the particle. Smaller = finer pixels.
uniform float pixel = 0.055;
// How fast the noise climbs through the flame.
uniform float churn = 1.6;
uniform vec3 core_colour : source_color = vec3(1.0, 0.98, 0.84);
uniform vec3 body_colour : source_color = vec3(1.0, 0.78, 0.25);
uniform vec3 edge_colour : source_color = vec3(0.99, 0.51, 0.09);
uniform vec3 rim_colour : source_color = vec3(0.79, 0.24, 0.04);

varying float v_life;
varying vec3 v_seed;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
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
	// COLOR.a runs 1 at birth to 0 at death: how much of this tongue is left.
	v_life = COLOR.a;
	// Every particle gets its own noise, so no two tongues are the same.
	v_seed = MODEL_MATRIX[3].xyz;
	// Billboard, upright: a flame tongue points up, it doesn't tumble.
	mat4 facing = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = facing * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	// Snap to blocks first: everything below is worked out per block, so the
	// tongue and its torn edges are made of hard pixels.
	vec2 uv = (floor(UV / pixel) + 0.5) * pixel;
	float up = clamp(uv.y, 0.0, 1.0);

	// The tongue: wide at the root, drawn to a point at the top.
	float half_width = mix(0.52, 0.06, pow(up, 0.65));
	float across = (uv.x - 0.5) / half_width;
	float body = 1.0 - clamp(across * across + pow(up, 2.2) * 0.55, 0.0, 1.0);

	// Noise climbing through it eats the edges away, so the flame tears and
	// licks instead of sitting there as a smooth shape.
	float wobble = fract(dot(floor(v_seed * 37.0), vec3(0.13, 0.31, 0.71)));
	vec2 flow = vec2(uv.x * 5.0 + wobble * 19.0, uv.y * 3.2 - TIME * churn + wobble * 7.0);
	float torn = value_noise(flow) * 0.65 + value_noise(flow * 2.7 + 5.0) * 0.35;

	// Older tongues are eaten away faster, so they thin out and vanish.
	float thickness = body * (0.55 + 0.75 * torn) - (1.0 - v_life) * 0.55;
	if (thickness < 0.06) {
		discard;
	}

	// Thick and low is white hot; thin and high is the dull red of the tips.
	float heat = clamp(thickness * 1.5 + (1.0 - up) * 0.55 + v_life * 0.25, 0.0, 1.4);
	vec3 colour;
	if (heat > 1.0) {
		colour = mix(body_colour, core_colour, clamp((heat - 1.0) / 0.4, 0.0, 1.0));
	} else if (heat > 0.62) {
		colour = mix(edge_colour, body_colour, (heat - 0.62) / 0.38);
	} else {
		colour = mix(rim_colour, edge_colour, clamp(heat / 0.62, 0.0, 1.0));
	}
	ALBEDO = colour;
}
