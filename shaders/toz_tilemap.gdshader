// toz_tilemap.gdshader
//
// Applied to TileMapTerrain and TileMapDecoration nodes when the player is in a
// Type Overload Zone. Transforms the tile palette to reflect the zone's ecological
// state — from fully infested (ehi=0) through partial to fully restored (ehi=100).
//
// Design principles:
//   - At ehi_normalized = 0.0 (infested):  maximum type-tint + shimmer + saturation shift
//   - At ehi_normalized = 1.0 (restored):  no effect — normal GBA palette
//   - Smooth lerp between states; no hard cuts
//
// Each TOZ type has a characteristic visual signature set via shader uniforms.
// The Murk (Poison): sickly green-purple, bioluminescent shimmer, increased saturation

shader_type canvas_item;

// ── EHI State ─────────────────────────────────────────────────────────────────

// 0.0 = fully infested, 1.0 = fully restored
// Set by ZoneVisuals.gd via ShaderMaterial.set_shader_parameter()
uniform float ehi_normalized : hint_range(0.0, 1.0) = 0.0;

// ── Zone Type Colour ──────────────────────────────────────────────────────────

// Dominant type hue tint applied at full infestation.
// Poison (The Murk):        vec3(0.52, 0.18, 0.78)  — deep purple miasma
// Fire   (Emberscar):       vec3(1.0,  0.35, 0.05)
// Ice    (Ashen Glacier):   vec3(0.55, 0.85, 1.0)
// Electric (Static Sprawl): vec3(0.9,  0.95, 0.1)
// Ghost  (The Veil):        vec3(0.45, 0.2,  0.6)
// etc.
uniform vec3 zone_tint : source_color = vec3(0.35, 0.85, 0.30);

// How strongly the tint is applied at full infestation (0=none, 1=full replacement)
uniform float tint_strength : hint_range(0.0, 1.0) = 0.55;

// ── Saturation Shift ──────────────────────────────────────────────────────────

// At infestation: > 1.0 = more saturated (sickly vivid), < 1.0 = desaturated (washed)
// Poison zones feel wrong because they're TOO vivid and bright in wrong hues.
uniform float infested_saturation : hint_range(0.0, 3.0) = 1.4;

// ── Shimmer / Distortion ──────────────────────────────────────────────────────

// UV distortion amplitude for the bioluminescent miasma shimmer.
// 0 = no shimmer, 0.005 = subtle, 0.02 = dramatic
uniform float shimmer_amplitude : hint_range(0.0, 0.03) = 0.004;

// Speed of the shimmer wave in time units
uniform float shimmer_speed : hint_range(0.0, 5.0) = 0.7;

// Frequency of the shimmer wave (higher = more ripples across the screen)
uniform float shimmer_frequency : hint_range(0.5, 20.0) = 4.0;

// ── Darkness Tinting ──────────────────────────────────────────────────────────

// At full infestation, slightly darken non-tinted areas to make the glowing
// parts feel like they're poking through a dim canopy.
uniform float shadow_strength : hint_range(0.0, 0.5) = 0.15;

// ── Poison Overworld Flash ─────────────────────────────────────────────────────

// Driven by ZoneVisuals.gd — set to 1.0 when a step-based flash triggers (every
// FLASH_STEP_INTERVAL steps while infested), then tweened back to 0.0 over ~0.45 s.
// Replaces the old time-based sin() approach for step-accurate GBA-style timing.
uniform float flash_impulse  : hint_range(0.0, 1.0) = 0.0;

// Peak brightness added at the top of each flash (0 = off, 0.25 = strong).
uniform float flash_strength : hint_range(0.0, 0.5) = 0.0;


// ── Colour Helpers ────────────────────────────────────────────────────────────

vec3 rgb_to_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}


// ── Fragment ──────────────────────────────────────────────────────────────────

void fragment() {
	// Effect strength: 0 at restored, 1 at infested.
	float effect = 1.0 - ehi_normalized;

	// ── UV shimmer (miasma / queasy displacement) ──────────────────────────────
	// Continuous screen-space wave pattern that creates a "queasy" or "distorted" feel.
	// We use two waves at different frequencies and speeds for organic complexity.
	vec2 uv = UV;
	vec2 world_coord = FRAGCOORD.xy / 16.0;
	if (effect > 0.01) {
		// Large, slow "queasy" screen wave
		float queasy = sin(world_coord.y * 0.5 + TIME * 0.5) * 0.002 * effect;
		// Faster shimmer/jitter (type-specific)
		float shimmer_x = sin(world_coord.y * shimmer_frequency + TIME * shimmer_speed) * shimmer_amplitude * effect;
		float shimmer_y = cos(world_coord.x * shimmer_frequency * 0.8 + TIME * shimmer_speed * 1.1) * shimmer_amplitude * 0.5 * effect;
		
		uv += vec2(shimmer_x + queasy, shimmer_y + queasy);
	}

	// ── Sample tile texture at (potentially displaced) UV ─────────────────────
	vec4 tex = texture(TEXTURE, uv);

	// Pass-through: fully transparent pixels or no infestation effect.
	if (tex.a < 0.01 || effect < 0.01) {
		COLOR = tex;
	} else {
		vec3 col = tex.rgb;

		// ── Saturation adjustment ─────────────────────────────────────────────
		vec3 hsv = rgb_to_hsv(col);
		// Lerp saturation toward infested_saturation (clamped to avoid artefacts)
		float sat_target = mix(1.0, infested_saturation, effect);
		hsv.y = clamp(hsv.y * sat_target, 0.0, 1.0);
		col = hsv_to_rgb(hsv);

		// ── Zone tint (hue shift toward type colour) ──────────────────────────
		// Lerp between the tile's current colour and the zone type tint.
		// Preserving luminance keeps the texture detail visible.
		float effective_tint = tint_strength * effect;
		vec3 tinted = mix(col, zone_tint * hsv.z, effective_tint);
		// Increase contrast at full infestation for a more intense look.
		tinted = mix(tinted, tinted * tinted * (3.0 - 2.0 * tinted), effect * 0.2);
		tinted = clamp(tinted, 0.0, 1.0);

		// ── Bioluminescence pulse ─────────────────────────────────────────────
		// Pixels that align with the zone_tint get a "glow" that pulses.
		// Use a broader similarity check for "yummy" glow coverage.
		float tint_similarity = 1.0 - clamp(length(col - zone_tint) * 1.5, 0.0, 1.0);
		float bio_pulse = tint_similarity * effect * 0.25
			* (0.6 + 0.4 * sin(TIME * shimmer_speed * 1.5 + world_coord.x * 2.0 + world_coord.y * 1.5));
		
		// Add the pulse back as an additive glow in the tint color.
		tinted = clamp(tinted + bio_pulse * zone_tint, 0.0, 1.0);

		// ── Shadow — non-tinted areas darken slightly ─────────────────────────
		// Creates depth where the "un-infested" native colors are struggling.
		float shadow = (1.0 - tint_similarity) * shadow_strength * effect;
		tinted = clamp(tinted - shadow, 0.0, 1.0);

		// ── Poison overworld flash ─────────────────────────────────────────────
		// flash_impulse peaks at 1.0 on a step and tweens down.
		if (flash_impulse > 0.001 && flash_strength > 0.001) {
			float flash = flash_impulse * flash_strength * effect;
			// A sharp additive white/tint blend for that classic GBA poison flash.
			tinted = clamp(tinted + flash * mix(vec3(1.0), zone_tint, 0.3), 0.0, 1.0);
		}

		COLOR = vec4(tinted, tex.a);
	}
}
