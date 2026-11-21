// Night sky (D-103): the flat sky colour with, as it gets dark, the stars, a
// procedural Milky Way and (optionally) constellation lines on top. Stars and
// lines come from equirectangular maps baked by scripts/star_map.gd in
// celestial (right ascension / declination) coordinates; `sky_to_celestial`
// turns a view direction in the world into that frame and is turned by
// time_of_day.gd as the clock runs.
shader_type sky;

uniform vec3 sky_color : source_color = vec3(0.55, 0.75, 0.95);
uniform sampler2D star_map : filter_linear, repeat_enable;
uniform sampler2D line_map : filter_linear, repeat_enable;
uniform mat3 sky_to_celestial = mat3(1.0);
// 0 = no stars (daylight, cloud, fog) .. 1 = full dark.
uniform float star_strength = 0.0;
uniform float line_strength = 0.0;
uniform float milky_way_strength = 1.0;

// J2000 equatorial unit vectors of the north galactic pole and the galactic
// centre (Sagittarius). The third axis completes the galactic frame.
const vec3 GAL_POLE = vec3(-0.86757, -0.19835, 0.45598);
const vec3 GAL_CENTRE = vec3(-0.05487, -0.87344, -0.48384);

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float value_noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * value_noise(p);
		p = p * 2.03 + vec3(7.1, 3.7, 1.3);
		a *= 0.5;
	}
	return v;
}

// A band of light along the galactic equator, brightest toward the galactic
// centre, broken up by cloud-like noise and split by a dark dust lane.
vec3 milky_way(vec3 d) {
	vec3 gy = cross(GAL_POLE, GAL_CENTRE);
	float b = asin(clamp(dot(d, GAL_POLE), -1.0, 1.0));   // galactic latitude
	float l = atan(dot(d, gy), dot(d, GAL_CENTRE));        // galactic longitude
	float band = exp(-pow(b / 0.2, 2.0));
	float core = exp(-pow(b / 0.07, 2.0));
	float toward_centre = 0.45 + 0.55 * exp(-pow(l / 1.1, 2.0));
	float clouds = fbm(d * 5.0);
	float fine = fbm(d * 22.0);
	float lane = smoothstep(0.3, 0.8, fbm(d * 6.0 + 11.0)) * core;
	float v = band * toward_centre * (0.25 + 1.1 * clouds) * (0.7 + 0.6 * fine);
	v = max(v * (1.0 - 0.45 * lane), 0.0);
	vec3 tint = mix(vec3(0.62, 0.7, 1.0), vec3(1.0, 0.88, 0.7), core * toward_centre);
	return tint * v * 0.22;
}

void sky() {
	vec3 col = sky_color;
	if (star_strength > 0.001) {
		vec3 c = normalize(sky_to_celestial * EYEDIR);
		vec2 uv = vec2(atan(c.y, c.x) / TAU + 0.5, 0.5 - asin(clamp(c.z, -1.0, 1.0)) / PI);
		// Dimmer near the horizon, where the long path through air dims stars.
		float horizon = smoothstep(-0.05, 0.25, EYEDIR.y);
		vec3 stars = texture(star_map, uv).rgb;
		// The Milky Way is faint: it only shows once the sky is properly dark.
		vec3 add = stars + milky_way(c) * milky_way_strength * star_strength;
		add += vec3(0.4, 0.55, 0.9) * texture(line_map, uv).r * line_strength;
		col += add * star_strength * horizon;
	}
	COLOR = col;
}
