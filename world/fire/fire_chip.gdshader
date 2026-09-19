shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// One fire chip. Up close it is its true size (about half an inch); farther
// away it grows, so a swarm of them still reads as flame at a distance rather
// than dissolving into sub-pixel glitter.

uniform vec3 boost = vec3(2.4, 1.9, 1.5);
uniform float true_size_within = 4.0;

void vertex() {
	vec3 center = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float d = distance(center, CAMERA_POSITION_WORLD);
	VERTEX *= max(1.0, d / true_size_within);
}

void fragment() {
	ALBEDO = COLOR.rgb * boost;
}
