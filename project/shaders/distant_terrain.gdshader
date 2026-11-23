// Distant terrain around the farm (D-133): real USGS elevations, stretched in
// height with distance, drawn as flat-shaded low-poly facets. Colour comes
// from height, slope, which way a facet faces and a per-facet random value
// (COLOR.r = real elevation / 2500 m, COLOR.g = random), and `snow` blends the
// summer look (gold and green fields, tan grass slopes, dark forest on the
// high, north-facing Blue Mountains) into the winter one (snow-covered open
// slopes above ~600 m with the forest standing out dark).
shader_type spatial;
render_mode skip_vertex_transform, fog_disabled, cull_back, diffuse_lambert, specular_disabled;

#include "res://shaders/horizon.gdshaderinc"

// 0 = summer .. 1 = winter.
uniform float snow : hint_range(0.0, 1.0) = 1.0;

varying float v_dist;
varying float v_elev;
varying float v_rand;
varying vec3 v_world_normal;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 camera = INV_VIEW_MATRIX[3].xyz;
	v_dist = length(world - camera);
	v_elev = COLOR.r * 2500.0;
	v_rand = COLOR.g;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	VERTEX = (VIEW_MATRIX * vec4(horizon_squeeze(world, camera), 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(v_world_normal, 0.0)).xyz);
}

void fragment() {
	vec3 n = v_world_normal;
	float steep = 1.0 - clamp(n.y, 0.0, 1.0);
	// North is -z: a facet tilted that way gets less sun, keeps forest and snow.
	float north = clamp(-n.z / max(length(n.xz), 1e-4), -1.0, 1.0) * smoothstep(0.02, 0.15, steep);
	float r = v_rand;

	// Valley farmland: a patchwork of irrigated green and dry gold (summer),
	// winter wheat and brown stubble (winter). Albedos are kept near the aerial
	// photo ground's so the land beyond the fence doesn't glow, by day or night.
	float field = smoothstep(0.5, 0.56, r);
	vec3 summer_low = mix(vec3(0.58, 0.49, 0.31), vec3(0.27, 0.36, 0.18), field);
	vec3 winter_low = mix(vec3(0.36, 0.31, 0.24), vec3(0.30, 0.38, 0.23), field);
	// Open grass slopes: pale tan with a pink cast, as in the summer photo.
	vec3 summer_grass = mix(vec3(0.62, 0.53, 0.43), vec3(0.54, 0.46, 0.37), r);
	vec3 forest = mix(vec3(0.13, 0.18, 0.14), vec3(0.09, 0.13, 0.11), r);
	vec3 snow_col = mix(vec3(0.9, 0.92, 0.97), vec3(0.8, 0.84, 0.92), r * 0.6);

	float upland = smoothstep(260.0, 420.0, v_elev + r * 60.0);
	float forested = smoothstep(1080.0, 1260.0, v_elev + north * 260.0 + r * 160.0);
	// Winter snow line, lower on north faces, ragged facet to facet.
	float snowy = smoothstep(560.0, 760.0, v_elev + north * 120.0 + (r - 0.5) * 180.0);

	vec3 summer = mix(mix(summer_low, summer_grass, upland), forest, forested);
	vec3 winter_open = mix(winter_low, snow_col, snowy);
	vec3 winter = mix(winter_open, mix(forest, snow_col, 0.22), forested);
	vec3 col = mix(summer, winter, snow);

	float h = 1.0 - exp(-v_dist * haze_per_metre);
	ALBEDO = col * (1.0 - h);
	EMISSION = haze_color * h;
	ROUGHNESS = 1.0;
}
