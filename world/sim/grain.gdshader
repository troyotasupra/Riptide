shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// One grain of the simulation: a small flat-shaded box, coloured by what it is
// and how much life it has left. The colour comes in as per-instance custom
// data (rgb, alpha), so the whole sim draws in one go.

varying flat vec4 grain;

void vertex() {
	grain = INSTANCE_CUSTOM;
}

void fragment() {
	ALBEDO = grain.rgb;
	ALPHA = grain.a;
}
