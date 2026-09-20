shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// One grain of the simulation: a small solid block. Grains are opaque — fire
// made of pixels is hard-edged, not a glow — so a dying grain shrinks away
// instead of fading, and the blocks sort against each other properly.
// Its colour arrives as per-instance custom data.

varying flat vec3 grain;

void vertex() {
	grain = INSTANCE_CUSTOM.rgb;
}

void fragment() {
	ALBEDO = grain;
}
