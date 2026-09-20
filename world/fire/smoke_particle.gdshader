shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, shadows_disabled, diffuse_lambert;
// One puff of smoke: a soft billboarded disc, lit so it darkens on the side away
// from the sun instead of being a flat grey blob. Colour and alpha come from the
// particle (COLOR), set over its life by the process material's ramp.

uniform float softness = 0.75;

void vertex() {
	mat4 facing = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = facing * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float puff = 1.0 - smoothstep(1.0 - softness, 1.0, d);
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * puff * puff;
	ROUGHNESS = 1.0;
}
