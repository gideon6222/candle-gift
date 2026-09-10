shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_burley, specular_schlick_ggx;

// A stand-in for wax.gdshader with the same uniforms and none of the noise.
// Used by scripts/gpucost.gd to measure what the procedural surface costs, and
// as the LOW-DETAIL fallback: same colour, same place, no fbm.

uniform vec4 tint : source_color = vec4(1.0, 0.24, 0.57, 1.0);
uniform float flow_speed = 0.0;
uniform float marble_scale = 0.0;
uniform float ripple_scale = 0.0;
uniform float bubble_scale = 0.0;
uniform float gloss = 0.45;
uniform vec2 impact = vec2(0.0);
uniform float impact_age = 99.0;

void fragment() {
	ALBEDO = tint.rgb;
	ROUGHNESS = clamp(1.0 - gloss, 0.04, 1.0);
	METALLIC = 0.0;
	SPECULAR = 0.32;
}
