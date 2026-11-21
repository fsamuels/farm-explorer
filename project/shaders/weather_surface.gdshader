// Wet and snowy surfaces (D-105): an overlay laid over the ground and roofs by
// weather.gd. `wet` (0..1) darkens and glosses everything and, as it rises,
// opens puddles on flat ground; `snow` (0..1) covers upward-facing surfaces in
// patchy white that fills in as it grows, so roofs and ground whiten while
// walls stay clear.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;

uniform float wet : hint_range(0.0, 1.0) = 0.0;
uniform float snow : hint_range(0.0, 1.0) = 0.0;
uniform vec3 snow_color : source_color = vec3(0.92, 0.95, 1.0);

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * value_noise(p);
		p = p * 2.07 + vec2(5.2, 1.3);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 n = normalize(world_normal);
	float up = n.y;
	vec2 p = world_pos.xz;

	// Snow: settles on surfaces that face up, in patches that merge as it deepens.
	// The noise is skipped while a term can't show: uniform branches, so cheap.
	float snow_a = 0.0;
	if (snow > 0.003) {
		float facing = smoothstep(0.35, 0.8, up);
		float patch_noise = fbm(p * 0.45) * 0.75 + value_noise(p * 3.0) * 0.25;
		float cover = snow * 1.16 - 0.04;
		snow_a = smoothstep(patch_noise - 0.08, patch_noise + 0.08, cover) * smoothstep(0.0, 0.04, snow) * facing;
	}

	// Wet: a general darkening, plus puddles in the low spots of flat ground.
	float flat_ground = smoothstep(0.92, 0.99, up);
	float puddle = 0.0;
	if (wet > 0.35) {
		float low_spots = fbm(p * 0.13 + 7.0);
		puddle = (1.0 - smoothstep(wet * 0.34 - 0.06, wet * 0.34 + 0.02, low_spots)) * flat_ground * smoothstep(0.35, 0.8, wet);
	}
	float damp_a = wet * 0.32;
	float wet_a = mix(damp_a, 0.8, puddle) * (1.0 - snow_a);

	float a = snow_a + wet_a;
	if (a < 0.003) {
		discard;
	}
	vec3 wet_color = mix(vec3(0.0), vec3(0.04, 0.06, 0.09), puddle);
	ALBEDO = (snow_color * snow_a + wet_color * wet_a) / a;
	ROUGHNESS = (0.9 * snow_a + mix(0.18, 0.02, puddle) * wet_a) / a;
	SPECULAR = (0.3 * snow_a + mix(0.7, 1.0, puddle) * wet_a) / a;
	ALPHA = min(a, 1.0);
}
