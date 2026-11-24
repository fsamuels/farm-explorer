shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// Flames, smoke, embers and the torch's jet (D-156): one billboard shader with
// a mode. INSTANCE_CUSTOM.y is the particle's age as a fraction of its life.
// 0 flame, 1 smoke, 2 ember, 3 torch jet.

uniform int mode = 0;
uniform float strength = 1.0;

varying float life;
varying float seed;

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
	life = INSTANCE_CUSTOM.y;
	seed = hash(MODEL_MATRIX[3].xz + INSTANCE_CUSTOM.x);
	vec2 scale = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
	float a = INSTANCE_CUSTOM.x;
	if (mode == 0 || mode == 3) {
		a = 0.0; // flames stand upright on screen
	}
	mat4 world = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	world = world * mat4(vec4(cos(a), -sin(a), 0.0, 0.0), vec4(sin(a), cos(a), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * world;
	VERTEX.xy *= scale;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	if (mode == 0 || mode == 3) {
		// A flickering tongue: wide at the foot, pointed at the tip.
		float y = 1.0 - UV.y;
		float sway = (noise(vec2(y * 3.0 + seed * 9.0, TIME * 3.0 + seed * 20.0)) - 0.5) * 0.9 * y;
		float width = pow(max(1.0 - y, 0.0), 0.75) * 0.85;
		float d = abs(p.x - sway);
		float shape = smoothstep(width, width * 0.15, d) * smoothstep(0.0, 0.1, y);
		float heat = clamp(1.0 - y * 0.9 - life * 0.8, 0.0, 1.0);
		vec3 cool = vec3(1.0, 0.28, 0.04);
		vec3 warm = vec3(1.0, 0.72, 0.18);
		vec3 hot = mode == 3 ? vec3(0.75, 0.88, 1.0) : vec3(1.0, 0.95, 0.7);
		vec3 col = mix(cool, warm, smoothstep(0.1, 0.6, heat));
		col = mix(col, hot, smoothstep(0.65, 1.0, heat));
		ALBEDO = col * strength;
		ALPHA = shape * pow(max(1.0 - life, 0.0), 1.1) * (mode == 3 ? 0.9 : 0.75);
	} else if (mode == 1) {
		float r = length(p);
		float puff = noise(p * 2.2 + seed * 31.0) * 0.5 + noise(p * 5.0 + seed * 17.0) * 0.5;
		float shape = smoothstep(1.0, 0.25, r + (puff - 0.5) * 0.7);
		float fade = smoothstep(0.0, 0.12, life) * pow(max(1.0 - life, 0.0), 1.4);
		ALBEDO = mix(vec3(0.1, 0.095, 0.09), vec3(0.34, 0.33, 0.32), life);
		ALPHA = shape * fade * 0.32 * strength;
	} else {
		float r = length(p);
		float dot_shape = smoothstep(1.0, 0.0, r);
		ALBEDO = mix(vec3(1.0, 0.8, 0.35), vec3(1.0, 0.25, 0.04), life) * 2.0;
		ALPHA = dot_shape * (1.0 - life * life);
	}
}
