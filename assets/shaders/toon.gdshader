shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_disabled;

// Flat toon shading with an INKED SILHOUETTE, for everything drawn as a
// MultiMesh: the batch, the pickups, the obstacles, the props.
//
// The line is a fresnel term, not an inverted hull.
//
// The hull is the usual way to do this and it does not work on a MultiMesh in
// Godot 4.7. Measured rather than assumed: as a `next_pass`, as a second
// MultiMeshInstance3D sharing the buffer, with `CULL_FRONT`, with the hull
// SHRUNK six centimetres inside the object, with depth writing off, and in both
// draw orders - in every one of those the hull covered the object instead of
// sitting behind it. It works on a plain MeshInstance3D, which is what makes it
// look like it should work here.
//
// A fresnel rim is not the same thing: it cannot make a line of even width, and
// it darkens a flat face seen edge-on. What it does do is put a dark edge
// around every silhouette, which is the job - a cream candle on a white runway
// had no edge at all and read as a smudge - and it costs one dot product.

uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 ink : source_color = vec3(0.114, 0.106, 0.208);
uniform float ink_width = 0.42;   // how far in from the silhouette the line reaches
uniform float ink_power = 5.0;    // higher is a tighter, harder line
uniform float steps = 3.0;        // shading bands; the toon part
uniform bool use_instance_color = true;

varying vec4 vcol;

void vertex() {
	vcol = COLOR;
}

void fragment() {
	vec3 base = tint.rgb;
	if (use_instance_color) {
		base *= vcol.rgb;
	}

	// Facing ratio: 1 head-on, 0 at the silhouette. The line is where the
	// surface has turned far enough away to be near the edge.
	//
	// `ink_width` is that threshold, so 0 means NO LINE. Written the other way
	// round - as a smoothstep whose edges meet at zero width - it inked every
	// surface completely, and the road stripes, which are the one thing asking
	// for no line at all, turned solid black.
	float e = 0.0;
	if (ink_width > 0.0) {
		float face = abs(dot(normalize(NORMAL), normalize(VIEW)));
		e = smoothstep(ink_width, ink_width * 0.35, face);
	}

	ALBEDO = mix(base, ink, e);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}

void light() {
	// Quantised diffuse: the flat bands that make a toy read as a toy. A smooth
	// ramp on these pastels goes muddy through the mid tones.
	//
	// Kept deliberately dim. The sky HDRI is already supplying a strong ambient
	// and the sun is at 1.0, so a full-strength diffuse term on top of both
	// blew every pale surface out to pure white - which is the same failure as
	// having no line: a cream candle with no shading and no edge.
	float d = clamp(dot(normalize(NORMAL), normalize(LIGHT)), 0.0, 1.0);
	d = floor(d * steps + 0.5) / steps;
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * (0.10 + 0.42 * d);
}
