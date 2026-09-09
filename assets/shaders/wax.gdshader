shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Molten wax lying FLAT in the track.
//
// Read off the reference at 1080p: a pool is an area of colour level with the
// road, with a slightly irregular edge - no side wall, no rim, no depth. What
// makes it read as liquid is entirely what happens ON it:
//
//   - soft swirled marbling in a lighter tint, flowing slowly down the track
//   - six to eight dark dimples, like craters, scattered over the surface
//   - a ring spreading from wherever the ladle's stream lands
//
// So this is a shader rather than a mesh and rather than a photograph. Two
// reasons. The wax COLOUR is game state - which pool you drove through is what
// the candle is worth - so a baked texture would need one per wax. And a
// photoreal liquid normal map would drop a photograph into a flat-shaded
// low-poly world, which is the join that shows in the first frame.

uniform vec4 tint : source_color = vec4(1.0, 0.24, 0.57, 1.0);
uniform float flow_speed = 0.09;
uniform float marble_scale = 0.55;   // cycles per metre; a swirl is ~1.5 m across
uniform float ripple_scale = 7.0;    // ripples are CENTIMETRES, not metres
uniform float bubble_scale = 0.9;    // one candidate dimple per ~1.1 m cell
uniform float gloss = 0.42;

// Where the ladle's stream is landing, in object space, and when it last did.
uniform vec2 impact = vec2(0.0, 0.0);
uniform float impact_age = 99.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
	return vec2(hash21(p), hash21(p + 17.13));
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Each octave is rotated by an irrational-ish angle.
//
// Value noise sits on an axis-aligned integer lattice, and octaves that share
// that lattice leave the grid visible as rectangular plates at a grazing view -
// which is exactly the angle this surface is always seen from.
const mat2 ROT = mat2(vec2(0.8038, 0.5949), vec2(-0.5949, 0.8038));

float fbm(vec2 p, int octaves) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < octaves; i++) {
		v += amp * value_noise(p);
		p = ROT * p * 2.03;
		amp *= 0.5;
	}
	return v;
}

// Discrete dimples on a jittered grid, so they read as separate craters rather
// than as another layer of noise.
float bubbles(vec2 p, float t) {
	float acc = 0.0;
	vec2 cell = floor(p);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = cell + vec2(float(x), float(y));
			vec2 seed = hash22(c);
			// only some cells carry one at all
			if (seed.x > 0.55) { continue; }
			vec2 centre = c + 0.2 + 0.6 * hash22(c + 3.1);
			// a slow bob, so the surface is never completely still
			centre.y += sin(t * 0.6 + seed.y * 6.28) * 0.05;
			float r = 0.10 + seed.y * 0.13;
			float d = length(p - centre);
			acc += smoothstep(r, r * 0.35, d);
		}
	}
	return clamp(acc, 0.0, 1.0);
}

void fragment() {
	// Object space, so the pattern is anchored to the pool and does not swim
	// when the pool moves with the level.
	vec2 p = (UV - 0.5) * vec2(8.0, 22.0);
	float t = TIME;

	// The flow: the whole field drifts slowly down the track.
	vec2 flow = vec2(0.0, -t * flow_speed);

	float marble = fbm(p * marble_scale + flow, 4);
	// Push it toward streaks rather than blobs: a second sample warped by the
	// first is what makes stirred paint rather than clouds.
	marble = fbm(p * marble_scale + vec2(marble * 1.6, marble * 0.7) + flow, 3);

	float fine = fbm(p * ripple_scale + flow * 3.0, 2);

	float dim = bubbles(p * bubble_scale + flow * 0.4, t);

	// A ring spreading from where the stream lands, fading as it goes.
	float ring = 0.0;
	if (impact_age < 1.6) {
		float d = length(p - impact);
		float radius = impact_age * 2.4;
		ring = smoothstep(0.28, 0.0, abs(d - radius)) * (1.0 - impact_age / 1.6);
	}

	vec3 base = tint.rgb;
	// Wax is SATURATED. Mixing too far toward white, and then reflecting a
	// bright sky on top of it, washed the whole pool out to a pale strip - the
	// reference's magenta is nearly full-strength with the marbling only a
	// shade lighter than the body.
	vec3 light = mix(base, vec3(1.0), 0.26);
	vec3 dark = base * 0.72;

	vec3 col = mix(base, light, smoothstep(0.42, 0.72, marble));
	col = mix(col, dark, dim * 0.55);
	col = mix(col, vec3(1.0), ring * 0.55);
	col = mix(col, light, fine * 0.05);

	ALBEDO = col;
	// Wax is glossy but not a mirror, and it is slightly rougher where a dimple
	// breaks the surface.
	ROUGHNESS = clamp(1.0 - gloss + dim * 0.25 + fine * 0.08, 0.04, 1.0);
	METALLIC = 0.0;
	SPECULAR = 0.32;

	// The fine octave is the NORMAL, not the geometry. The surface is flat, and
	// the eye reads a normal far more readily than it reads displacement - which
	// is just as well, because a quad this size could not represent a
	// centimetre-scale wave at any sane vertex count.
	float e = 0.035;
	float nx = fbm((p + vec2(e, 0.0)) * ripple_scale + flow * 3.0, 2) - fine;
	float ny = fbm((p + vec2(0.0, e)) * ripple_scale + flow * 3.0, 2) - fine;
	NORMAL_MAP = normalize(vec3(-nx * 6.0, -ny * 6.0, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.8 + ring * 2.0;
}
