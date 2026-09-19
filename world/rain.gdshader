shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_opaque;
// Rain streaks. Drops that fall inside a roofed room are thrown away, so from
// indoors you see the rain through the doorway and the windows while none of it
// comes through the roof. `room_*` is the one room you can be inside (the
// fishing shack); it is off when room_on is 0.

uniform vec4 streak_color : source_color = vec4(0.78, 0.82, 0.9, 0.35);
uniform int room_on = 0;
uniform mat4 room_world_to_local;
uniform vec3 room_min;
uniform vec3 room_max;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (room_on == 1) {
		vec3 local = (room_world_to_local * vec4(v_world, 1.0)).xyz;
		if (all(greaterThan(local, room_min)) && all(lessThan(local, room_max))) {
			discard;
		}
	}
	ALBEDO = streak_color.rgb;
	ALPHA = streak_color.a;
}
