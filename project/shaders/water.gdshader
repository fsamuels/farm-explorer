// Water for the pond and the irrigation ditch (D-141).
//
// The pond is one flat sheet at the pond's current level, laid under the whole
// basin: the carved terrain hides it wherever the ground is higher, so the
// shoreline moves by itself as the level rises and falls.
//
// The ditch is a ribbon along the channel (`ribbon` on). Each vertex carries its
// distance along the route in UV.x; the vertex stage looks up how full the
// channel is there in `flow_tex` (a row of stations that water_system.gd slides
// downstream) and lifts the surface to that depth, so a surge shows as a
// travelling front. Where there is no water the ribbon is discarded.
//
// Both are see-through, tinting from clear shallows to murky deep water by how
// much water the view ray crosses (read from the depth texture), with a foam
// edge where it meets the bank and slow ripples that bend the reflection.
shader_type spatial;
render_mode blend_mix, cull_disabled, specular_schlick_ggx;

uniform bool ribbon = false;
uniform sampler2D flow_tex : filter_linear, repeat_disable;
uniform float stations = 256.0;
uniform float ditch_depth_max = 0.65;
uniform float bed_y = -0.76;
// Standing rain water (0..1 of a full ditch), a floor under the flowing water.
uniform float rain_pool : hint_range(0.0, 1.0) = 0.0;

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 shallow_color : source_color = vec3(0.17, 0.26, 0.17);
uniform vec3 deep_color : source_color = vec3(0.03, 0.09, 0.10);
uniform float murk = 0.9;
uniform float foam_width = 0.16;
uniform float ripple = 1.0;

varying vec3 world_pos;
varying float water_depth;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Slope of the ripple height field at p, by finite differences.
vec2 ripple_slope(vec2 p) {
	float e = 0.08;
	float c = value_noise(p);
	return vec2(value_noise(p + vec2(e, 0.0)) - c, value_noise(p + vec2(0.0, e)) - c) / e;
}

void vertex() {
	water_depth = 1.0;
	if (ribbon) {
		float u = (UV.x * (stations - 1.0) + 0.5) / stations;
		float fill = max(textureLod(flow_tex, vec2(u, 0.5), 0.0).r, rain_pool);
		water_depth = fill * ditch_depth_max;
		VERTEX.y = bed_y + water_depth;
	}
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (ribbon && water_depth < 0.03) {
		discard;
	}
	// How much water the view ray crosses: scene depth behind the surface minus the surface's own.
	float scene_depth = texture(depth_tex, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_depth, 1.0);
	behind.xyz /= behind.w;
	float thick = max(0.0, -behind.z + VERTEX.z);

	// Ripples: two scrolling layers, stronger across open water than in the narrow ditch.
	vec2 p = world_pos.xz;
	vec2 slope = ripple_slope(p * 0.8 + vec2(TIME * 0.05, TIME * 0.03)) + 0.5 * ripple_slope(p * 2.3 - vec2(TIME * 0.04, -TIME * 0.07));
	vec3 world_normal = normalize(vec3(-slope.x * 0.05 * ripple, 1.0, -slope.y * 0.05 * ripple));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);

	float k = 1.0 - exp(-thick * murk);
	vec3 col = mix(shallow_color, deep_color, k);
	float foam = (1.0 - smoothstep(0.0, foam_width, thick)) * (0.55 + 0.45 * value_noise(p * 3.0 + TIME * 0.1));
	col = mix(col, vec3(0.8, 0.84, 0.8), foam * 0.55);

	ALBEDO = col;
	ALPHA = clamp((0.34 + 0.6 * k) * smoothstep(0.0, 0.06, thick) + foam * 0.5, 0.0, 0.96);
	ROUGHNESS = mix(0.06, 0.35, foam);
	SPECULAR = 0.65;
	METALLIC = 0.0;
}
