// Asphalt for the named roads (D-148). The ribbon's UV.x runs 0..1 across it
// (verge to verge) and UV.y is metres along the road; COLOR is
// (kind / 2, half-width / 10, verge / 10), kind 0-1 being highways and 2 a
// local road. Highways get a double yellow centre line, local roads a dashed
// one, and all get white edge lines and a gravel verge.
shader_type spatial;
render_mode cull_back, specular_disabled;

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
	float kind = COLOR.r * 2.0;
	float half_w = COLOR.g * 10.0;
	float verge = COLOR.b * 10.0;
	float across = (UV.x - 0.5) * 2.0 * (half_w + verge);
	float off = abs(across);
	float grain = value_noise(world_pos.xz * 4.0) * 0.6 + value_noise(world_pos.xz * 17.0) * 0.4;

	vec3 asphalt = vec3(0.105, 0.108, 0.115) * (0.8 + 0.5 * grain);
	vec3 gravel = vec3(0.42, 0.37, 0.30) * (0.75 + 0.5 * grain);
	vec3 color = mix(asphalt, gravel, smoothstep(half_w - 0.1, half_w + 0.1, off));

	// White edge lines.
	float edge = step(half_w - 0.42, off) * step(off, half_w - 0.30);
	color = mix(color, vec3(0.75), edge * 0.9);
	// Centre line: double yellow on highways, dashed yellow on local roads.
	float double_line = step(0.06, off) * step(off, 0.16);
	float dash = step(off, 0.08) * step(fract(UV.y / 9.0), 0.4);
	float centre = kind < 1.5 ? double_line : dash;
	color = mix(color, vec3(0.78, 0.6, 0.1), centre * 0.9);

	ALBEDO = color;
	ROUGHNESS = mix(0.85, 0.95, smoothstep(half_w - 0.1, half_w + 0.1, off));
}
