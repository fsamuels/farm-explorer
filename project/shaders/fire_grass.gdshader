shader_type spatial;
render_mode cull_disabled;
// Tall dry bunch grass along the ditch (D-156). The fire's state texture has
// one texel per cell: R is how far the cell has burned (0 untouched .. 1 burnt
// out), G is the strength of its flames. A clump reads the texel it stands on:
// it blackens and shrinks to stubble as the cell burns, and glows while alight.

uniform sampler2D state_tex : filter_linear, repeat_disable;
uniform vec2 grid_origin;
uniform vec2 grid_extent;
uniform vec2 wind = vec2(3.0, -3.0);

varying vec2 burn;
varying float tip;
varying float shade;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec2 uv = (origin.xz - grid_origin) / grid_extent;
	vec4 s = textureLod(state_tex, uv, 0.0);
	burn = vec2(s.r, s.g);
	tip = UV.y;
	shade = hash(origin.xz);
	// Burnt grass is a short black stub.
	float h = 1.0 - 0.88 * smoothstep(0.08, 0.7, s.r);
	VERTEX.y *= h;
	// Sway with the wind: the tips lean downwind and flutter.
	float flutter = 0.55 + 0.45 * sin(TIME * 1.7 + origin.x * 0.61 + origin.z * 0.43);
	vec2 lean = wind * (0.018 + 0.012 * flutter) * tip * tip * h;
	VERTEX.x += lean.x;
	VERTEX.z += lean.y;
}

void fragment() {
	vec3 low = vec3(0.45, 0.36, 0.2);
	vec3 high = vec3(0.86, 0.74, 0.46);
	vec3 col = mix(low, high, smoothstep(0.0, 0.9, tip));
	col *= 0.85 + 0.3 * shade;
	vec3 char_col = vec3(0.035, 0.03, 0.028);
	col = mix(col, char_col, smoothstep(0.02, 0.45, burn.x));
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.05;
	BACKLIGHT = vec3(0.3, 0.24, 0.12) * (1.0 - burn.x);
	EMISSION = vec3(1.3, 0.42, 0.06) * burn.y * (0.25 + 0.75 * tip) * 1.6;
}
