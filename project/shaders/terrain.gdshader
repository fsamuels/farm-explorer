// The farm's ground (D-140): the NAIP base image with the two drone orthomosaic
// patches blended over it, all projected straight down from world position onto
// the carved terrain mesh. Replaces the three flat imagery planes, which would
// have floated over the ditch and pond; they stay in the scene, hidden, because
// the map reads their textures and placement.
shader_type spatial;
render_mode cull_back;

uniform sampler2D base_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform mat4 base_inv;
uniform vec2 base_size = vec2(520.0, 520.0);

uniform sampler2D front_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform mat4 front_inv;
uniform vec2 front_size = vec2(1.0, 1.0);

uniform sampler2D middle_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform mat4 middle_inv;
uniform vec2 middle_size = vec2(1.0, 1.0);

// 0 hides a patch (set when its texture is missing).
uniform float front_on = 0.0;
uniform float middle_on = 0.0;

varying vec3 world_pos;

// Image coordinates of this fragment on a plane placed by `inv` (the inverse of
// the plane node's transform) with the given size, the way PlaneMesh maps UVs.
vec2 plane_uv(vec3 at, mat4 inv, vec2 size) {
	vec3 local = (inv * vec4(at, 1.0)).xyz;
	return local.xz / size + 0.5;
}

// Patch colour and coverage; zero outside the image so nothing smears.
vec4 patch(sampler2D tex, vec3 at, mat4 inv, vec2 size, float on) {
	vec2 uv = plane_uv(at, inv, size);
	vec2 inside = step(vec2(0.0), uv) * step(uv, vec2(1.0));
	vec4 c = texture(tex, uv);
	return vec4(c.rgb, c.a * inside.x * inside.y * on);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 color = texture(base_tex, plane_uv(world_pos, base_inv, base_size)).rgb;
	vec4 front = patch(front_tex, world_pos, front_inv, front_size, front_on);
	color = mix(color, front.rgb, front.a);
	vec4 middle = patch(middle_tex, world_pos, middle_inv, middle_size, middle_on);
	color = mix(color, middle.rgb, middle.a);
	ALBEDO = color;
	ROUGHNESS = 0.9;
}
