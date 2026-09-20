shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
// One flame particle: a tiny billboarded speck, hottest in the middle, added to
// whatever is behind it so a crowd of them builds into a body of fire.
// The colour and alpha come from the particle itself (COLOR), which the
// ParticleProcessMaterial's colour ramp sets over the particle's life.

// How hard the middle burns compared with the edge.
uniform float core_boost = 1.0;
// 0 a soft blob, 1 a hard-edged speck.
uniform float hardness = 0.35;

void vertex() {
	// Billboard, keeping the scale the particle system gave us.
	mat4 facing = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = facing * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	// A round speck: solid in the middle, falling away to nothing at the rim.
	float speck = 1.0 - smoothstep(mix(0.0, 0.85, hardness), 1.0, d);
	float core = pow(speck, 3.0);
	ALBEDO = COLOR.rgb * (1.0 + core * core_boost);
	ALPHA = COLOR.a * speck;
}
