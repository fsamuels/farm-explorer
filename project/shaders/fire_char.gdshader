shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;
// The scorched ground under the burn (D-156): a skin over the terrain that
// darkens where the fire has been. It reads the same state texture as the
// grass (R burnt, G flame) and roughs up the edge with noise so the burn line
// is ragged, not a grid. Hot cells glow a little as they burn.

uniform sampler2D state_tex : filter_linear, repeat_disable;
uniform vec2 grid_origin;
uniform vec2 grid_extent;

varying vec3 world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = (world.xz - grid_origin) / grid_extent;
	vec4 s = texture(state_tex, uv);
	float n = noise(world.xz * 2.3) * 0.6 + noise(world.xz * 7.0) * 0.4;
	float burnt = smoothstep(0.22, 0.5, s.r + (n - 0.5) * 0.55);
	float ash = smoothstep(0.75, 1.0, s.r) * noise(world.xz * 4.1 + 9.0);
	vec3 col = mix(vec3(0.025, 0.022, 0.02), vec3(0.2, 0.19, 0.18), ash * 0.6);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	ALPHA = burnt * 0.94;
	EMISSION = vec3(1.0, 0.35, 0.06) * s.g * 0.7 * smoothstep(0.1, 0.5, s.r);
}
