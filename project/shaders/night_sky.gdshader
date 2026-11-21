// Night sky (D-104): the flat sky colour with, as it gets dark, the stars, a
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
// Northern lights (D-105): 0 = none .. 1 = strong. They hang in the northern
// sky (-z in the world), not on the turning star map, so they use the world
// view direction. `aurora_time` is advanced by time_of_day.gd.
uniform float aurora_strength = 0.0;
uniform float aurora_time = 0.0;
// The sun by day and the moon by night (D-120): one disc where the scene's
// light comes from. `body_glow` is the halo size (big in smoke, near the
// horizon) and `body_moon` 0..1 turns it into a pale, mottled moon.
uniform vec3 body_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 body_color = vec3(1.0, 0.95, 0.85);
uniform float body_strength = 0.0;
uniform float body_glow = 0.25;
uniform float body_moon = 0.0;
// Planets: unit vectors in the same celestial frame as the stars, colour in
// rgb and brightness in alpha.
uniform vec3 planet_dir[4];
uniform vec4 planet_col[4];
// Shooting stars (world directions), one every few seconds on a dark clear
// sky. `meteor_time` is advanced by time_of_day.gd.
uniform float meteor_strength = 0.0;
uniform float meteor_time = 0.0;
// Seconds between possible shooting stars (11 normally, 2.5 in a shower).
uniform float meteor_period = 11.0;
// A Starlink train (D-123): seconds since it came up in the west-north-west,
// or -1 when there is none. It only shows on a dark sky.
uniform float train_time = -1.0;

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
	if (abs(b) > 0.7) {
		return vec3(0.0);  // the band is ~e^-12 here: skip the noise
	}
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

// Curtains of light over the northern horizon: a sharp, bright green lower
// edge fading up into pink, broken into vertical rays that drift and sway.
vec3 aurora(vec3 d, float t) {
	float az = atan(d.x, -d.z);                       // 0 = due north, + = east
	float alt = asin(clamp(d.y, -1.0, 1.0));
	if (alt < 0.0 || abs(az) > 1.6) {
		return vec3(0.0);
	}
	// The curtain's lower edge ripples along the horizon.
	float wave = 0.10 * sin(az * 3.0 + t * 0.15) + 0.05 * sin(az * 7.0 - t * 0.22) + 0.03 * sin(az * 13.0 + t * 0.4);
	float h = (alt - 0.14 - wave) / 0.6;              // 0 at the lower edge, 1 at the top
	float rays = smoothstep(0.25, 0.85, fbm(vec3(az * 20.0, alt * 1.5, t * 0.1)));
	float body = smoothstep(0.0, 0.07, h) * (1.0 - smoothstep(0.55, 1.2, h));
	float drift = 0.55 + 0.45 * sin(az * 2.3 + t * 0.3);
	float ends = 1.0 - smoothstep(0.8, 1.6, abs(az));
	float low = smoothstep(0.0, 0.08, alt);
	float a = body * (0.3 + 0.7 * rays) * drift * ends * low;
	// Green below, pink above; slow patches of pink reach lower down.
	float pink_patch = fbm(vec3(az * 2.5, 3.0, t * 0.05));
	float pink = smoothstep(0.2, 0.75, h + (pink_patch - 0.5) * 0.9);
	vec3 col = mix(vec3(0.12, 1.0, 0.42), vec3(1.0, 0.3, 0.7), pink);
	// Pink glows a little brighter than the green it sits above.
	return col * a * mix(0.5, 0.85, pink);
}

// The sun or moon: a disc with a soft halo. The moon is a little smaller and
// mottled with dark patches.
vec3 sky_body(vec3 d) {
	float c = dot(d, body_dir);
	if (c < 0.9) {
		return vec3(0.0);
	}
	float ang = acos(clamp(c, -1.0, 1.0));
	float r = mix(0.034, 0.028, body_moon);
	float disc = 1.0 - smoothstep(r * 0.9, r, ang);
	float h = 0.10 + 0.25 * body_glow;
	float halo = exp(-(ang * ang) / (h * h)) * (0.25 + 0.5 * body_glow) * (1.0 - 0.9 * body_moon) * smoothstep(0.9, 0.97, c);
	vec3 t1 = normalize(cross(body_dir, abs(body_dir.y) > 0.95 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0)));
	vec3 t2 = cross(body_dir, t1);
	vec2 uv = vec2(dot(d, t1), dot(d, t2)) / r;
	float mottle = 0.7 + 0.5 * fbm(vec3(uv * 2.5, 1.7));
	vec3 sun_disc = body_color * 1.6;
	vec3 moon_disc = body_color * mottle * 0.85;
	vec3 disc_col = mix(sun_disc, moon_disc, body_moon);
	return (disc_col * disc + body_color * halo) * body_strength;
}

// Each planet is a small bright point with a faint halo, brightest for Venus.
vec3 planets(vec3 c) {
	vec3 sum = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		float a = length(c - planet_dir[i]);   // ~ the angle, in radians
		float core = exp(-pow(a / 0.0022, 2.0));
		float halo = exp(-pow(a / 0.008, 2.0)) * 0.3;
		sum += planet_col[i].rgb * (core + halo) * planet_col[i].a;
	}
	return sum;
}

// One shooting star at a time: every PERIOD seconds a hashed slot may fire a
// short bright streak along a great circle from a random high spot.
vec3 meteor(vec3 d, float t) {
	float PERIOD = meteor_period;
	const float DURATION = 0.9;
	float id = floor(t / PERIOD);
	float local = t - id * PERIOD;
	if (local > DURATION || hash(vec3(id, 1.7, 3.1)) < 0.3) {
		return vec3(0.0);
	}
	float prog = local / DURATION;
	float az = hash(vec3(id, 7.3, 0.5)) * TAU;
	float alt = 0.6 + 0.7 * hash(vec3(id, 2.2, 9.1));
	vec3 p = vec3(sin(az) * cos(alt), sin(alt), -cos(az) * cos(alt));
	vec3 e1 = normalize(cross(p, abs(p.y) > 0.95 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0)));
	vec3 e2 = cross(p, e1);
	float th = hash(vec3(id, 5.5, 4.4)) * TAU;
	vec3 u = e1 * cos(th) + e2 * sin(th);
	float along_angle = atan(dot(d, u), dot(d, p));
	float side = dot(d, cross(p, u));
	float head = prog * 0.5;
	float tail = 0.2;
	float along = (along_angle - (head - tail)) / tail;   // 0 at the tail tip .. 1 at the head
	float inside = step(0.0, along) * (1.0 - step(1.0, along));
	float line = exp(-pow(side / 0.0022, 2.0));
	return vec3(0.85, 0.92, 1.0) * inside * along * along * line * sin(prog * PI) * 2.2;
}

// A Starlink train: a string of evenly spaced, steady points a few degrees
// apart, one behind the other, crossing the sky from the west-north-west to the
// south-east on a great circle. Each point fades in and out near the horizons
// (as the satellites enter and leave the Earth's shadow), and unlike a shooting
// star the train takes about a minute and does not flash.
vec3 starlink_train(vec3 d, float t) {
	const float SECONDS = 70.0;
	const int BEADS = 24;
	const float SPACING = 0.012;   // radians between satellites
	vec3 a = normalize(vec3(-0.85, 0.30, -0.45));
	vec3 b = normalize(vec3(0.80, 0.22, 0.55));
	float arc = acos(dot(a, b));
	vec3 e2 = normalize(b - a * dot(a, b));
	vec3 n = cross(a, e2);
	float side = dot(d, n);
	if (abs(side) > 0.01 || d.y < 0.0) {
		return vec3(0.0);
	}
	float ang = atan(dot(d, e2), dot(d, a));
	float lead = t / SECONDS * (arc + float(BEADS) * SPACING);
	float sum = 0.0;
	for (int k = 0; k < BEADS; k++) {
		float at = lead - float(k) * SPACING;
		float inside = smoothstep(0.0, 0.15, at / arc) * (1.0 - smoothstep(0.85, 1.0, at / arc));
		float dist = length(vec2(ang - at, side));
		sum += exp(-pow(dist / 0.0016, 2.0)) * inside * (1.0 - 0.012 * float(k));
	}
	return vec3(0.95, 0.96, 1.0) * sum * 1.4;
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
		vec3 add = stars + milky_way(c) * milky_way_strength * star_strength + planets(c);
		add += vec3(0.4, 0.55, 0.9) * texture(line_map, uv).r * line_strength;
		col += add * star_strength * horizon;
	}
	col += aurora(EYEDIR, aurora_time) * aurora_strength;
	if (meteor_strength > 0.001) {
		col += meteor(EYEDIR, meteor_time) * meteor_strength * smoothstep(0.0, 0.2, EYEDIR.y);
	}
	if (train_time >= 0.0) {
		col += starlink_train(EYEDIR, train_time) * smoothstep(0.2, 0.6, star_strength);
	}
	col += sky_body(EYEDIR);
	COLOR = col;
}
