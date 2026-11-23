// Shared by distant_terrain.gdshader and wind_turbine.gdshader (D-133).
// The distant terrain and turbines are modelled at their real distances (up to
// 80 km), far beyond the camera's 4 km far plane. Each vertex is pulled toward
// the camera along its own line of sight to a distance under SQUEEZE_MAX: it
// lands on the same pixel, only its depth shrinks, and depth order is kept.
// Same formula and constants as HorizonMath.compressed_distance() in
// scripts/horizon_math.gd (test_horizon.gd checks they agree).
const float SQUEEZE_START = 2400.0;
const float SQUEEZE_RANGE = 1150.0;
const float SQUEEZE_SCALE = 25000.0;

float horizon_compressed_distance(float d) {
	if (d <= SQUEEZE_START) {
		return d;
	}
	return SQUEEZE_START + SQUEEZE_RANGE * (1.0 - exp(-(d - SQUEEZE_START) / SQUEEZE_SCALE));
}

// `world` squeezed toward `camera`.
vec3 horizon_squeeze(vec3 world, vec3 camera) {
	vec3 offset = world - camera;
	float d = length(offset);
	if (d < 1.0) {
		return world;
	}
	return camera + offset * (horizon_compressed_distance(d) / d);
}

// Aerial perspective: the shader's own distance haze, since the scene fog
// (tuned for the farm, a few hundred metres) would erase anything kilometres
// away. ALBEDO is dimmed and the haze colour added as emission, so at full
// haze the ground shows exactly the sky colour whatever the light.
uniform vec3 haze_color : source_color = vec3(0.55, 0.75, 0.95);
uniform float haze_per_metre = 1.6e-5;
