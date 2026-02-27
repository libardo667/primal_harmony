// fog_overlay.gdshader
//
// Full-screen scrolling fog overlay for Type Overload Zones.
// Applied to a ColorRect inside a CanvasLayer (layer 10) by ZoneVisuals.gd.
//
// The fog texture is a greyscale tileable pattern where bright pixels = dense fog
// and dark pixels = clear.  Luminance is used as alpha; the colour comes entirely
// from fog_tint so the same grey asset can be recoloured per zone.
//
// The Murk: toxic sickly green  scroll=(0.012, 0.003)  opacity~0.38 infested
// Other zones: add entries to ZoneVisuals.ZONE_FOG_PARAMS

shader_type canvas_item;
render_mode blend_mix;

// ── Fog texture ───────────────────────────────────────────────────────────────

// Greyscale tileable fog/cloud PNG.  repeat_enable lets UVs wrap seamlessly.
uniform sampler2D fog_texture : repeat_enable, filter_linear;

// ── Scroll ────────────────────────────────────────────────────────────────────

// World-space scroll in UV-units-per-second.  Negative x = left drift.
uniform vec2 scroll_speed = vec2(0.012, 0.003);

// How many times the 128 px tile repeats across the screen width.
// Higher = smaller, denser fog pattern; lower = big rolling clouds.
uniform float tile_scale : hint_range(1.0, 16.0) = 5.0;

// ── Colour & Opacity ──────────────────────────────────────────────────────────

// Zone type tint — replaces the grey with whatever colour the zone needs.
uniform vec4 fog_tint : source_color = vec4(0.28, 0.75, 0.10, 1.0);

// Overall opacity of the fog layer (0 = invisible, 1 = fully opaque).
// Tweened by ZoneVisuals based on EHI state.
uniform float opacity : hint_range(0.0, 1.0) = 0.35;


// ── Fragment ──────────────────────────────────────────────────────────────────

void fragment() {
	// Tile and scroll the fog pattern continuously.
	vec2 uv = UV * tile_scale + scroll_speed * TIME;
	float fog_density = texture(fog_texture, uv).r;

	// Luminance drives alpha; tint drives colour.
	COLOR = vec4(fog_tint.rgb, fog_density * opacity * fog_tint.a);
}
