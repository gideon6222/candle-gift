shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Molten wax lying FLAT in the track.
//
// Read off the reference at 1080p: a pool is an area of colour level with the
// road, with a slightly irregular edge - no side wall, no rim, no depth. What
// makes it read as liquid is entirely what happens ON it.
//
// THIS USED TO BE THIRTEEN OCTAVES OF VALUE NOISE plus a 3x3 cell neighbourhood
// of bubbles plus two more fbm evaluations for a fragment-computed normal, per
// fragment, over a surface that fills the lower third of the screen. Measured
// against a flat stand-in with vsync off at 1080x2340, it cost 0.26 ms of a
// 1.60 ms frame on a desktop GPU - and this game crashes on an Adreno.
//
// It is now a TEXTURE: an ambientCG marble swirl (CC0), scrolled at two speeds
// and two scales. Two samples and a handful of arithmetic replace about 250
// hash evaluations.
//
// AND IT IS THE COLOUR MAP, NOT THE NORMAL, which is a correction to the rule
// this project has used for every other import. "Take the normal, leave the
// colour" is right when the pattern is RELIEF. Polished marble's pattern is
// PIGMENT: its normal map is blank - every pixel measured at (0.502, 0.498,
// 1.0) - and using it produced a pool of one flat colour. The swirl only exists
// in the colour map, so that is what came across, converted to LUMINANCE at
// import so it carries the pattern and none of the hue. The wax's own colour
// does the rest.

uniform vec4 tint : source_color = vec4(1.0, 0.24, 0.57, 1.0);
uniform sampler2D swirl : source_color, filter_linear_mipmap, repeat_enable;

uniform float flow_speed = 0.09;
uniform float marble_scale = 0.55;   // cycles per metre; a swirl is ~1.5 m across
uniform float ripple_scale = 7.0;    // the fine layer, in centimetres
uniform float bubble_scale = 0.9;    // kept so `_dress_rig` needs no special case
uniform float gloss = 0.45;
uniform float relief = 1.15;

// Where the ladle's stream is landing, in object space, and when it last did.
uniform vec2 impact = vec2(0.0, 0.0);
uniform float impact_age = 99.0;

void fragment() {
	// Object space, so the pattern is anchored to the pool and does not swim
	// when the pool moves with the level.
	vec2 p = (UV - 0.5) * vec2(8.0, 22.0);
	float t = TIME;

	// TWO LAYERS AT DIFFERENT SPEEDS AND SCALES, which is what stops a scrolling
	// texture reading as a scrolling texture. One drifts down the track slowly;
	// the other is finer, faster and moving slightly across it, so the two never
	// line up and the surface never shows its period.
	vec2 uv_a = p * marble_scale * 0.5 + vec2(0.0, -t * flow_speed);
	vec2 uv_b = p * ripple_scale * 0.12 + vec2(t * flow_speed * 0.32, -t * flow_speed * 1.7);
	// Two scrolling samples of the swirl, differenced so the pattern moves
	// rather than simply sliding: where the fast layer is bright over a dark
	// slow layer, the wax reads as being stirred.
	float a = texture(swirl, uv_a).r;
	float b = texture(swirl, uv_b).r;
	float swirled = clamp(a * 0.66 + b * 0.34, 0.0, 1.0);

	// A ring spreading from where the stream lands, fading as it goes. This is
	// the one thing a texture cannot do, because it answers the game.
	float ring = 0.0;
	if (impact_age < 1.6) {
		float d = length(p - impact);
		float radius = impact_age * 2.4;
		ring = smoothstep(0.28, 0.0, abs(d - radius)) * (1.0 - impact_age / 1.6);
	}

	// Wax is SATURATED. Mixing too far toward white, and then reflecting a bright
	// sky on top of it, washes the whole pool out to a pale strip - the
	// reference's magenta is nearly full strength with the marbling only a shade
	// lighter than the body.
	vec3 base = tint.rgb;
	vec3 light = mix(base, vec3(1.0), 0.24);
	vec3 dark = base * 0.74;

	// The relief IS the shading: the normal's own slope picks out the swirl in a
	// lighter and a darker tint of the wax, which is what the noise was for.
	float slope = swirled;
	vec3 col = mix(dark, light, smoothstep(0.35, 0.72, slope));
	col = mix(col, vec3(1.0), ring * 0.55);

	ALBEDO = col;
	// NO DERIVED NORMAL. Taking `dFdx`/`dFdy` of the swirl to get a slope is two
	// instructions and looks like a free relief map; at a grazing angle it is a
	// speckle generator. Screen-space derivatives are the difference between
	// ADJACENT PIXELS, and on a surface this foreshortened adjacent pixels are
	// far apart in the texture - so the "slope" is sampling noise, and the pool
	// rendered as television static. Blurring the texture did not touch it,
	// which is what said the noise was not coming from the texture.
	//
	// The swirl is in the albedo, where the eye reads it perfectly well on a
	// flat surface, and the pool stays flat - which is what the reference's is.
	ROUGHNESS = clamp(1.0 - gloss, 0.04, 1.0);
	METALLIC = 0.0;
	SPECULAR = 0.32;
}
