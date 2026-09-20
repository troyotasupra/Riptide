shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
// A real fall, top to bottom. Water leaves the lip smooth and green — you can
// still see the rock through it — then, as it accelerates, it stretches into
// long vertical strands, pulls apart into ribbons with daylight between them,
// and by the foot is all white, aerated water. The edges fray into spray, and
// everything runs downward fast.
//
// The curtain mesh carries UV.x -1..1 across the fall and UV.y = metres down
// from the lip, so the shader knows how far this bit of water has fallen.

// Metres a second the pattern runs down (the water itself accelerates below).
uniform float speed = 7.0;
// Where the sheet starts to break up, and where it's wholly white water.
uniform float aerate_start = 1.0;
uniform float aerate_full = 7.0;
// How many strands the sheet pulls apart into across its width.
uniform float strands = 22.0;
uniform vec3 clear_water : source_color = vec3(0.30, 0.60, 0.62);
uniform vec3 white_water : source_color = vec3(0.96, 0.98, 1.0);
// How solid the water is where it leaves the lip.
uniform float lip_opacity = 0.5;
// 1 for the main curtain; a thin torn veil in front of it uses less.
uniform float body = 1.0;

varying vec2 v_uv;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Smooth noise, stretched down the fall so it reads as streaks, not blobs.
float streak_noise(vec2 p) {
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
	v_uv = UV;
}

void fragment() {
	// The curtain is drawn from both sides; light it from whichever side you see.
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
	float across = v_uv.x;
	float down = max(v_uv.y, 0.0);
	float t = TIME;
	// Water speeds up as it falls, so the streaks stretch and run faster.
	float fallen = sqrt(max(down, 0.05));
	float run = t * speed * (0.6 + fallen * 0.5);

	// Strands run the length of the fall: the pattern is squeezed hard across
	// and stretched hard down, and read smoothly so it never blocks up.
	float side = (across * 0.5 + 0.5) * strands;
	float long_streak = streak_noise(vec2(side * 0.6, down * 0.11 - run * 0.14));
	float fine = streak_noise(vec2(side * 1.7 + 11.0, down * 0.34 - run * 0.5));
	float threads = streak_noise(vec2(side * 3.4 + 29.0, down * 0.9 - run * 1.1));

	// How far gone it is: smooth and green at the lip, all froth at the foot.
	float aerated = smoothstep(aerate_start, aerate_full, down);
	// At the lip the water is whole and green; the froth only builds as it falls.
	float froth = clamp((long_streak * 0.4 + fine * 0.5 + threads * 0.35 - 0.25) * (0.2 + 0.8 * aerated) + aerated * 0.7, 0.0, 1.0);
	vec3 colour = mix(clear_water, white_water, froth);
	// The very top is glassy, with the light coming through it.
	colour = mix(colour * 1.05, colour, aerated);
	ALBEDO = colour;

	// The sheet tears apart as it falls: gaps open between the strands, and the
	// outsides fray away into spray.
	float gaps = smoothstep(0.34, 0.66, long_streak * 0.55 + fine * 0.5 + threads * 0.32);
	// Even before it whitens the sheet is uneven, and lower down the rock
	// shows between the strands.
	float torn = mix(0.82 + 0.18 * gaps, gaps, aerated * 0.95);
	// The outside edge wanders, and tears as it goes down — never a ruled line.
	float wander = streak_noise(vec2(sign(across) * 3.0, down * 0.22 - run * 0.2)) * 0.18;
	float edge = 1.0 - smoothstep(0.6 + wander, 1.02 + wander, abs(across));
	edge = mix(edge, edge * (0.35 + 0.65 * gaps), aerated);
	float solid = mix(lip_opacity, 0.95, aerated * 0.8 + froth * 0.2);
	ALPHA = clamp(solid * torn * edge * body, 0.0, 1.0);

	// Aerated water is a bright, rough, diffuse thing; the smooth top is glassy.
	ROUGHNESS = mix(0.12, 0.85, aerated);
	SPECULAR = mix(0.65, 0.3, aerated);
	// A little light of its own where it's thickest with air, so the fall still
	// reads as white water in shadow under the cliff.
	EMISSION = white_water * froth * aerated * 0.12;
}
