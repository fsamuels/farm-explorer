// The ground beyond the farm (D-146): real 3DEP relief draped with one NAIP
// aerial photo of the whole 11.2 km world square, with a little fine-scale
// noise on top so the 5.5 m pixels don't smear when you stand on them. The
// farm's own ground (terrain.gdshader) is sharper and draws over the middle.
shader_type spatial;
render_mode cull_back, specular_disabled;

uniform sampler2D naip : source_color, filter_linear_mipmap_anisotropic, repeat_disable;

varying vec3 world_pos;

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

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 color = texture(naip, UV).rgb;
	float detail = value_noise(world_pos.xz * 0.9) * 0.5 + value_noise(world_pos.xz * 3.1) * 0.3 + value_noise(world_pos.xz * 11.0) * 0.2;
	ALBEDO = color * (0.8 + 0.4 * detail);
	ROUGHNESS = 0.95;
}
