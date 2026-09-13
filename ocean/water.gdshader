shader_type spatial;
// Low-poly Gerstner ocean. The wave math here MUST match ocean/waves.gd
// exactly, or boats will float on water that isn't where you see it.

render_mode cull_disabled, specular_schlick_ggx;

uniform float wave_time = 0.0;
// 0 flattens the surface; used by the coarse far-sea mesh out to the horizon.
uniform float wave_scale = 1.0;
uniform vec4 deep_color : source_color = vec4(0.04, 0.26, 0.40, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.16, 0.58, 0.64, 1.0);
uniform vec4 foam_color : source_color = vec4(0.88, 0.95, 0.97, 1.0);

const float GRAVITY = 9.8;
const float CALM_ROUGHNESS = 0.35;
const float MAX_ROUGHNESS = 1.6;
const float ROUGH_DISTANCE = 1500.0;
const vec4 WAVES[4] = vec4[4](
	vec4(1.0, 0.0, 0.18, 38.0),
	vec4(0.7, 0.7, 0.14, 22.0),
	vec4(-0.3, 0.95, 0.10, 13.0),
	vec4(0.9, -0.4, 0.06, 7.0)
);

// Hull interiors (e.g. the sailboat cabin) the sea must not draw inside.
const int MAX_HULLS = 4;
uniform int hull_count = 0;
uniform mat4 hull_world_to_local[4];
uniform vec3 hull_min[4];
uniform vec3 hull_max[4];

varying float v_height;
varying float v_amplitude;

float roughness(vec2 xz) {
	return clamp(CALM_ROUGHNESS + length(xz) / ROUGH_DISTANCE, CALM_ROUGHNESS, MAX_ROUGHNESS);
}

vec3 displacement(vec2 xz, float t) {
	float r = roughness(xz);
	vec3 o = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		vec4 w = WAVES[i];
		vec2 d = normalize(w.xy);
		float k = TAU / w.w;
		float c = sqrt(GRAVITY / k);
		float a = w.z * r / k;
		float f = k * (dot(d, xz) - c * t);
		o.x += d.x * a * cos(f);
		o.y += a * sin(f);
		o.z += d.y * a * cos(f);
	}
	return o;
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 disp = displacement(world.xz, wave_time) * wave_scale;
	VERTEX += disp;
	v_height = disp.y;
	float amplitude = 0.0;
	for (int i = 0; i < 4; i++) {
		amplitude += WAVES[i].z * WAVES[i].w / TAU;
	}
	v_amplitude = amplitude * roughness(world.xz);
}

void fragment() {
	vec3 world_position = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	for (int i = 0; i < hull_count && i < MAX_HULLS; i++) {
		vec3 local = (hull_world_to_local[i] * vec4(world_position, 1.0)).xyz;
		if (all(greaterThan(local, hull_min[i])) && all(lessThan(local, hull_max[i]))) {
			discard;
		}
	}
	// Flat shading: one normal per triangle for the low-poly look.
	NORMAL = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	float h = clamp(v_height / v_amplitude * 0.5 + 0.5, 0.0, 1.0);
	float crest = smoothstep(0.72, 0.95, h);
	vec3 color = mix(deep_color.rgb, shallow_color.rgb, h);
	ALBEDO = mix(color, foam_color.rgb, crest * 0.75);
	ROUGHNESS = 0.18;
	SPECULAR = 0.45;
}
