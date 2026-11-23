// Wind turbines on the distant ridges (D-133), drawn from two MultiMeshes: the
// towers (with a nacelle and a red warning light on top) and the rotors, which
// spin about their local z axis at each turbine's own speed. INSTANCE_CUSTOM
// holds (spin phase, spin speed in rad/s, 1 if this turbine carries a warning
// light, rotor blade width / blade length). Shares the distance squeezing and
// haze of the terrain.
shader_type spatial;
render_mode skip_vertex_transform, fog_disabled, cull_disabled, diffuse_lambert, specular_disabled;

#include "res://shaders/horizon.gdshaderinc"

uniform bool spin = false;
// 0 by day .. 1 at night: the warning lights only show in the dark.
uniform float darkness : hint_range(0.0, 1.0) = 0.0;

varying float v_dist;
varying float v_beacon;

void vertex() {
	vec3 v = VERTEX;
	vec3 nrm = NORMAL;
	if (spin) {
		// Rotor vertices carry blade coordinates, not positions: UV.y runs 0..1
		// from hub to tip, UV.x across the blade (-0.5..0.5) and UV2.x picks the
		// blade (0, 1/3, 2/3 of a turn). The instance is scaled to the blade
		// length, and INSTANCE_CUSTOM.w is the blade's width relative to it, so
		// distant rotors can be drawn wider than real without fattening the tips.
		float a = INSTANCE_CUSTOM.x + INSTANCE_CUSTOM.y * TIME + UV2.x * TAU;
		vec2 along = vec2(-sin(a), cos(a));
		vec2 across = vec2(cos(a), sin(a));
		float taper = 1.0 - 0.6 * UV.y;
		v = vec3(along * UV.y + across * UV.x * INSTANCE_CUSTOM.w * taper, 0.0);
		nrm = vec3(0.0, 0.0, 1.0);
	}
	// UV.x = 1 marks the warning light on the nacelle (the rotor's UV is blade
	// coordinates, so it never counts); only some turbines carry one.
	v_beacon = spin ? 0.0 : step(0.75, UV.x) * INSTANCE_CUSTOM.z;
	vec3 world = (MODEL_MATRIX * vec4(v, 1.0)).xyz;
	vec3 camera = INV_VIEW_MATRIX[3].xyz;
	v_dist = length(world - camera);
	VERTEX = (VIEW_MATRIX * vec4(horizon_squeeze(world, camera), 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(nrm, 0.0)).xyz);
}

void fragment() {
	float h = 1.0 - exp(-v_dist * haze_per_metre);
	vec3 body = vec3(0.9, 0.91, 0.92);
	ALBEDO = mix(body, vec3(0.5, 0.1, 0.1), v_beacon) * (1.0 - h);
	EMISSION = haze_color * h;
	// FAA-style synchronised red flash: on for half a second every two.
	float flash = step(fract(TIME * 0.5), 0.25);
	EMISSION += vec3(6.0, 0.25, 0.15) * v_beacon * darkness * flash * (1.0 - 0.7 * h);
	ROUGHNESS = 0.7;
}
