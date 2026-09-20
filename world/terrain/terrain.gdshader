shader_type spatial;
// Island ground: five photo layers blended by per-vertex weights (UV, UV2),
// rock forced onto steep slopes and mapped triplanar so cliffs don't smear,
// each layer sampled at two scales and mixed by a large noise so the repeat
// doesn't show, then tinted by the vertex colour (0.5 = the photo as is).
// Burnt ground (the fire) darkens to ash through burn_mask.

uniform sampler2D sand_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D jungle_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D jungle_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wet_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wet_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D macro : filter_linear, repeat_enable;
uniform sampler2D burn_mask : filter_linear, repeat_disable;
uniform vec4 burn_rect = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec4 scales_a = vec4(3.0, 2.5, 3.5, 5.0);
uniform float scale_wet = 3.0;

// How the ground breaks into separate grains close to the eye: how far the
// grain shows, and how big a grain is on each layer (metres).
uniform float grain_fade_start = 1.5;
uniform float grain_fade_end = 16.0;
uniform vec4 grain_size = vec4(0.013, 0.018, 0.022, 0.016);
uniform float grain_size_wet = 0.013;
uniform float grain_strength = 0.55;

varying vec3 world_pos;
varying vec3 world_normal;
varying vec4 weights;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	weights = vec4(UV, UV2);
	// Planar ground mapping runs u along +X and v along +Z.
	TANGENT = normalize(vec3(1.0, 0.0, 0.0) - NORMAL * NORMAL.x);
	BINORMAL = normalize(cross(TANGENT, NORMAL));
}

float grain_hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

// Loose grains: every speck its own brightness, at three sizes so the ground
// reads as sand rather than a noisy photograph.
float grains(vec2 xz, float size) {
	float g = grain_hash(floor(xz / size));
	g = mix(g, grain_hash(floor(xz / (size * 2.3) + 17.0)), 0.45);
	g = mix(g, grain_hash(floor(xz / (size * 5.1) + 41.0)), 0.25);
	return g;
}


// One layer on flat ground: two scales, blended by the macro noise.
vec4 planar(sampler2D tex, vec2 xz, float metres, float blend) {
	vec4 near = texture(tex, xz / metres);
	vec4 far = texture(tex, xz / (metres * 3.7) + vec2(0.37, 0.71));
	return mix(near, far, blend * 0.55);
}

void fragment() {
	vec2 xz = world_pos.xz;
	float variation = texture(macro, xz / 90.0).r;
	float blend = smoothstep(0.3, 0.7, variation);

	float steep = smoothstep(0.80, 0.62, world_normal.y);
	vec4 w = clamp(weights, 0.0, 1.0);
	float wet = max(0.0, 1.0 - (w.x + w.y + w.z + w.w));
	w.w = max(w.w, steep);
	w.xyz *= 1.0 - steep;
	wet *= 1.0 - steep;

	vec4 sand = planar(sand_albedo, xz, scales_a.x, blend);
	vec4 grass = planar(grass_albedo, xz, scales_a.y, blend);
	vec4 jungle = planar(jungle_albedo, xz, scales_a.z, blend);
	vec4 wet_sand = planar(wet_albedo, xz, scale_wet, blend);
	// Rock: triplanar, so cliff faces carry the photo instead of stretching it.
	vec3 tri = pow(abs(world_normal), vec3(4.0));
	tri /= (tri.x + tri.y + tri.z);
	float rs = scales_a.w;
	vec4 rock = texture(rock_albedo, world_pos.zy / rs) * tri.x
		+ texture(rock_albedo, world_pos.xz / rs) * tri.y
		+ texture(rock_albedo, world_pos.xy / rs) * tri.z;

	// Sharpen the blends by each photo's brightness, so grass gives way to sand
	// in clumps rather than a smooth fade.
	vec4 lum = vec4(dot(sand.rgb, vec3(0.33)), dot(grass.rgb, vec3(0.33)), dot(jungle.rgb, vec3(0.33)), dot(rock.rgb, vec3(0.33)));
	float lum_wet = dot(wet_sand.rgb, vec3(0.33));
	vec4 hw = w * (0.6 + lum);
	float hwet = wet * (0.6 + lum_wet);
	float top = max(max(max(hw.x, hw.y), max(hw.z, hw.w)), hwet) - 0.18;
	hw = max(hw - top, vec4(0.0));
	hwet = max(hwet - top, 0.0);
	float total = hw.x + hw.y + hw.z + hw.w + hwet + 1e-4;
	hw /= total;
	hwet /= total;

	vec3 albedo = sand.rgb * hw.x + grass.rgb * hw.y + jungle.rgb * hw.z + rock.rgb * hw.w + wet_sand.rgb * hwet;
	albedo *= clamp(COLOR.rgb * 2.0, vec3(0.0), vec3(2.0));
	albedo *= mix(0.86, 1.1, variation);

	vec3 n_sand = texture(sand_normal, xz / scales_a.x).rgb;
	vec3 n_grass = texture(grass_normal, xz / scales_a.y).rgb;
	vec3 n_jungle = texture(jungle_normal, xz / scales_a.z).rgb;
	vec3 n_rock = texture(rock_normal, world_pos.zy / rs).rgb * tri.x + texture(rock_normal, xz / rs).rgb * tri.y + texture(rock_normal, world_pos.xy / rs).rgb * tri.z;
	vec3 n_wet = texture(wet_normal, xz / scale_wet).rgb;
	NORMAL_MAP = n_sand * hw.x + n_grass * hw.y + n_jungle * hw.z + n_rock * hw.w + n_wet * hwet;
	NORMAL_MAP_DEPTH = 1.0;

	ROUGHNESS = 0.95 * hw.x + 0.95 * hw.y + 0.9 * hw.z + 0.85 * hw.w + 0.5 * hwet;
	SPECULAR = 0.4;

	if (burn_rect.z > 0.0) {
		vec2 at = (xz - burn_rect.xy) / burn_rect.zw;
		if (at.x > 0.0 && at.y > 0.0 && at.x < 1.0 && at.y < 1.0) {
			float burnt = texture(burn_mask, at).r;
			albedo = mix(albedo, vec3(0.045, 0.04, 0.035) + albedo * 0.08, burnt * 0.92);
			ROUGHNESS = mix(ROUGHNESS, 1.0, burnt);
		}
	}
	// --- the ground as loose grains, close to ---------------------------------
	// Every surface is made of specks: fine pale sand, coarser soil, grit on the
	// rock. It fades out with distance so it never turns into noise far away.
	float near = 1.0 - smoothstep(grain_fade_start, grain_fade_end, length(VERTEX));
	if (near > 0.002) {
		float size = grain_size.x * hw.x + grain_size.y * hw.y + grain_size.z * hw.z
			+ grain_size.w * hw.w + grain_size_wet * hwet;
		size = max(size, 0.002);
		// Up close the photo is magnified into visible blocks, so it gives way to
		// its own average colour and the grains carry the detail instead.
		vec3 flat_colour = textureLod(sand_albedo, xz / scales_a.x, 7.0).rgb * hw.x
			+ textureLod(grass_albedo, xz / scales_a.y, 7.0).rgb * hw.y
			+ textureLod(jungle_albedo, xz / scales_a.z, 7.0).rgb * hw.z
			+ textureLod(rock_albedo, xz / rs, 7.0).rgb * hw.w
			+ textureLod(wet_albedo, xz / scale_wet, 7.0).rgb * hwet;
		flat_colour *= clamp(COLOR.rgb * 2.0, vec3(0.0), vec3(2.0)) * mix(0.86, 1.1, variation);
		albedo = mix(albedo, flat_colour, near * 0.85);
		float g = grains(xz, size);
		// Grains differ in brightness, but only a little: sand is pale all over,
		// and a heavy spread reads as grit thrown over the ground.
		float depth = grain_strength * near;
		albedo *= 1.0 + (g - 0.45) * 0.5 * depth;
		// A few catch the sun the way quartz does, on dry sand most of all.
		float sparkle = pow(g, 30.0) * (hw.x + hwet * 0.6) * near;
		albedo += vec3(0.95, 0.92, 0.84) * sparkle * 0.55;
		// And they sit at their own angles, so the surface isn't glass-smooth.
		vec2 tilt = vec2(grains(xz + vec2(size, 0.0), size) - g, grains(xz + vec2(0.0, size), size) - g);
		NORMAL_MAP = clamp(NORMAL_MAP + vec3(tilt * depth * 0.16, 0.0), vec3(0.0), vec3(1.0));
		ROUGHNESS = clamp(ROUGHNESS + (g - 0.5) * 0.12 * near, 0.25, 1.0);
	}
	ALBEDO = albedo;
}
