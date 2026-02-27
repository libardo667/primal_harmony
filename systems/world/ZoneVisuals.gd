## ZoneVisuals — TOZ Visual State Manager
##
## Autoload that applies zone-type TileMap shaders and keeps their EHI uniforms
## in sync with the EHI autoload.
##
## Called by MainGame._load_map() with the loaded map node and its zone_id.
## Automatically disconnects from the previous map's TileMaps on the next call.
##
## Shader parameters per zone type are defined in ZONE_SHADER_PARAMS below.
## New TOZ zones: add an entry to ZONE_SHADER_PARAMS with their type signature.
extends Node

# =========================================================================
#  Shader & Zone Config
# =========================================================================

const TOZ_SHADER := preload("res://shaders/toz_tilemap.gdshader")
const FOG_SHADER := preload("res://shaders/fog_overlay.gdshader")

## Per-zone shader parameter overrides.
## Keys match zone_id strings from data/zones/*.json.
## Any omitted parameter falls back to the shader's built-in default.
const ZONE_SHADER_PARAMS: Dictionary = {
	"ashen_glacier": {
		# Ice — pale blue-white, slow crystalline shimmer
		"zone_tint": Vector3(0.55, 0.85, 1.0),
		"tint_strength": 0.50,
		"infested_saturation": 0.7, # Desaturated — ice washes out colour
		"shimmer_amplitude": 0.002,
		"shimmer_speed": 0.3,
		"shimmer_frequency": 3.0,
		"shadow_strength": 0.10,
		"flash_strength": 0.15, # whiteout pulse
	},
	"static_sprawl": {
		# Electric — acid yellow, fast crackling shimmer
		"zone_tint": Vector3(0.9, 0.95, 0.1),
		"tint_strength": 0.50,
		"infested_saturation": 1.6, # High saturation for electrical energy
		"shimmer_amplitude": 0.006,
		"shimmer_speed": 2.5,
		"shimmer_frequency": 10.0,
		"shadow_strength": 0.05,
		"flash_strength": 0.25, # static discharge spark
	},
	"emberscar": {
		# Fire — scorched orange-red, heat shimmer
		"zone_tint": Vector3(1.0, 0.35, 0.05),
		"tint_strength": 0.60,
		"infested_saturation": 1.2,
		"shimmer_amplitude": 0.005,
		"shimmer_speed": 1.2,
		"shimmer_frequency": 6.0,
		"shadow_strength": 0.20,
	},
	"the_veil": {
		# Psychic — deep purple-black, slow undulating distortion
		"zone_tint": Vector3(0.45, 0.2, 0.6),
		"tint_strength": 0.65,
		"infested_saturation": 0.8,
		"shimmer_amplitude": 0.007,
		"shimmer_speed": 0.4,
		"shimmer_frequency": 2.5,
		"shadow_strength": 0.30,
	},
	"dread_shore": {
		# Dark — murky brackish teal
		"zone_tint": Vector3(0.1, 0.5, 0.45),
		"tint_strength": 0.55,
		"infested_saturation": 1.1,
		"shimmer_amplitude": 0.005,
		"shimmer_speed": 0.6,
		"shimmer_frequency": 4.5,
		"shadow_strength": 0.25,
	},
	"the_murk": {
		# Poison — deep purple miasma haze, slow bioluminescent shimmer + poison flash
		"zone_tint": Vector3(0.52, 0.18, 0.78),
		"tint_strength": 0.55,
		"infested_saturation": 1.4,
		"shimmer_amplitude": 0.004,
		"shimmer_speed": 0.7,
		"shimmer_frequency": 4.0,
		"shadow_strength": 0.20,
		"flash_strength": 0.22,
	},
	"the_crucible": {
		# Ground — dusty red-brown
		"zone_tint": Vector3(0.75, 0.35, 0.15),
		"tint_strength": 0.50,
		"infested_saturation": 1.1,
		"shimmer_amplitude": 0.004,
		"shimmer_speed": 0.9,
		"shimmer_frequency": 5.0,
		"shadow_strength": 0.18,
	},
	"the_overgrowth": {
		# Grass — hyper-saturated green, pulsing overgrowth
		"zone_tint": Vector3(0.1, 0.9, 0.15),
		"tint_strength": 0.50,
		"infested_saturation": 1.8,
		"shimmer_amplitude": 0.003,
		"shimmer_speed": 0.5,
		"shimmer_frequency": 3.5,
		"shadow_strength": 0.12,
	},
	"abyss_bloom": {
		# Water/Psychic — deep indigo with bioluminescent bloom
		"zone_tint": Vector3(0.2, 0.1, 0.8),
		"tint_strength": 0.60,
		"infested_saturation": 1.3,
		"shimmer_amplitude": 0.005,
		"shimmer_speed": 0.5,
		"shimmer_frequency": 3.0,
		"shadow_strength": 0.28,
	},
	"static_sky": {
		# Dragon — bleached white with aurora crackle
		"zone_tint": Vector3(0.95, 0.98, 1.0),
		"tint_strength": 0.45,
		"infested_saturation": 0.6,
		"shimmer_amplitude": 0.005,
		"shimmer_speed": 3.0,
		"shimmer_frequency": 8.0,
		"shadow_strength": 0.05,
		"flash_strength": 0.20, # dragon energy discharge
	},
}

# =========================================================================
#  Internal State
# =========================================================================

## The current zone_id being displayed (empty for bleed-only maps).
var _current_zone_id: String = ""

## Zone_id of the adjacent TOZ this map is bleeding from (empty if none).
## Bleed mats use the adjacent zone's palette but at reduced strength and no flash.
var _bleed_zone_id: String = ""

## ShaderMaterial instances currently applied to TileMaps and sprites.
var _active_materials: Array[ShaderMaterial] = []

## CanvasItem nodes with active materials — tracked so they can be cleared on zone restore.
var _active_canvas_items: Array[CanvasItem] = []

## Whether EHI signal is currently connected.
var _ehi_connected: bool = false

## Camera2D to shake when a step-based flash fires.  Set by MainGame after each player spawn.
var _shake_camera: Camera2D = null

## Steps since last poison flash; resets at FLASH_STEP_INTERVAL.
var _step_counter: int = 0

## EHI thresholds — must match EncounterManager.EHI_INFESTED_MAX / EHI_PARTIAL_MAX.
const EHI_INFESTED_MAX: float = 35.0
const EHI_RESTORED_MIN: float = 67.0

## Steps between poison flashes, matching pokeemerald's overworld poison timing.
const FLASH_STEP_INTERVAL: int = 4

## Per-zone fog overlay config.  Zones without an entry get no fog.
## opacity_infested / opacity_partial drive the fog density per EHI band.
const ZONE_FOG_PARAMS: Dictionary = {
	"ashen_glacier": {
		"texture": "res://assets/fog/clouds.png",
		"scroll_speed": Vector2(0.005, 0.002),
		"fog_tint": Vector3(0.9, 0.95, 1.0), # frozen ash white
		"tile_scale": 2.0,
		"opacity_infested": 0.40,
		"opacity_partial": 0.20,
	},
	"emberscar": {
		"texture": "res://assets/fog/fog_horizontal.png",
		"scroll_speed": Vector2(0.02, 0.005),
		"fog_tint": Vector3(0.4, 0.3, 0.2), # grey ash fall
		"tile_scale": 4.0,
		"opacity_infested": 0.30,
		"opacity_partial": 0.15,
	},
	"the_veil": {
		"texture": "res://assets/fog/fog_diagonal.png",
		"scroll_speed": Vector2(0.01, 0.01),
		"fog_tint": Vector3(0.5, 0.2, 0.7), # psychic purple haze
		"tile_scale": 3.0,
		"opacity_infested": 0.25,
		"opacity_partial": 0.12,
	},
	"dread_shore": {
		"texture": "res://assets/fog/fog_diagonal.png",
		"scroll_speed": Vector2(-0.02, 0.01), # disorienting left-drift
		"fog_tint": Vector3(0.05, 0.1, 0.15), # deep murky black-teal
		"tile_scale": 6.0,
		"opacity_infested": 0.60,
		"opacity_partial": 0.30,
	},
	"the_murk": {
		"texture": "res://assets/fog/fog_horizontal.png",
		"scroll_speed": Vector2(0.012, 0.003),
		"fog_tint": Vector3(0.28, 0.75, 0.10), # toxic sickly green
		"tile_scale": 5.0,
		"opacity_infested": 0.38,
		"opacity_partial": 0.18,
	},
	"the_crucible": {
		"texture": "res://assets/fog/fog_horizontal.png",
		"scroll_speed": Vector2(0.08, 0.01), # fast sandstorm
		"fog_tint": Vector3(0.6, 0.45, 0.3), # dusty sand brown
		"tile_scale": 4.0,
		"opacity_infested": 0.50,
		"opacity_partial": 0.25,
	},
	"the_overgrowth": {
		"texture": "res://assets/fog/clouds.png",
		"scroll_speed": Vector2(0.01, 0.004),
		"fog_tint": Vector3(0.2, 0.6, 0.15), # primordial green mist
		"tile_scale": 3.0,
		"opacity_infested": 0.20,
		"opacity_partial": 0.10,
	},
	"abyss_bloom": {
		"texture": "res://assets/fog/fog_diagonal.png",
		"scroll_speed": Vector2(0.005, 0.015),
		"fog_tint": Vector3(0.1, 0.2, 0.8), # deep underwater blue
		"tile_scale": 5.0,
		"opacity_infested": 0.40,
		"opacity_partial": 0.20,
	},
	"static_sky": {
		"texture": "res://assets/fog/clouds.png",
		"scroll_speed": Vector2(0.03, 0.01),
		"fog_tint": Vector3(0.8, 0.4, 0.9), # aurora pink-purple
		"tile_scale": 2.5,
		"opacity_infested": 0.35,
		"opacity_partial": 0.15,
	},
}

## Active fog CanvasLayer (layer=10, above world, below UI at 100).
var _fog_layer: CanvasLayer = null
var _fog_material: ShaderMaterial = null


# =========================================================================
#  Lifecycle
# =========================================================================

func _ready() -> void:
	print("[ZoneVisuals] System online.")


# =========================================================================
#  Public API
# =========================================================================

## Called by MainGame after a map is loaded.
## Clears previous shader state, detects if the map is in a TOZ, and applies
## the appropriate shader to TileMapTerrain and TileMapDecoration.
## [param map_node] The freshly instantiated map Node2D.
## [param zone_id] The TOZ zone_id, or "" if this map is not in a TOZ.
func setup_for_map(map_node: Node2D, zone_id: String) -> void:
	_clear_materials()
	_current_zone_id = zone_id
	_step_counter = 0

	if zone_id.is_empty() or not ZONE_SHADER_PARAMS.has(zone_id):
		# Not a TOZ — no shader needed.
		_disconnect_ehi()
		return

	# Zone already restored — show normal tileset, no shader.
	var initial_ehi: float = EHI.get_zone_ehi(zone_id)
	if initial_ehi > EHI_RESTORED_MIN:
		_disconnect_ehi()
		return

	# Find TileMap nodes in the map.
	var tilemaps: Array[Node] = []
	for child_name: String in ["TileMapTerrain", "TileMapDecoration"]:
		var tm: Node = map_node.find_child(child_name, true, false)
		if tm != null:
			tilemaps.append(tm)

	if tilemaps.is_empty():
		push_warning("[ZoneVisuals] No TileMap nodes found in map for zone '%s'." % zone_id)
		return

	# Build and apply shader material to each TileMap.
	var params: Dictionary = ZONE_SHADER_PARAMS[zone_id]
	var ehi_normalized: float = initial_ehi / EHI.EHI_MAX

	for tm: Node in tilemaps:
		var mat := ShaderMaterial.new()
		mat.shader = TOZ_SHADER
		_apply_params(mat, params)
		mat.set_shader_parameter("ehi_normalized", ehi_normalized)
		var ci := tm as CanvasItem
		ci.material = mat
		_active_materials.append(mat)
		_active_canvas_items.append(ci)

	print("[ZoneVisuals] Applied TOZ shader to %d TileMap(s) for zone '%s' (EHI=%.1f)." % [
		tilemaps.size(), zone_id, initial_ehi
	])

	# Connect EHI signal so visuals update in real-time.
	_connect_ehi()

	# Fog overlay (independent of tilemaps — uses a dedicated CanvasLayer).
	_setup_fog(zone_id, initial_ehi)


## Called by MainGame when the current map is adjacent to (but not inside) a TOZ.
## Applies the adjacent zone's palette at one EHI stage lower with reduced intensity.
## - Adjacent zone infested  → show partial-level shader
## - Adjacent zone partial   → show near-restored shader (very subtle)
## - Adjacent zone restored  → no effect
## No EHI signal is connected — bleed state is static for the duration of the visit.
func setup_for_map_bleed(map_node: Node2D, source_zone_id: String) -> void:
	_clear_materials()
	_bleed_zone_id = source_zone_id
	_step_counter = 0

	if not ZONE_SHADER_PARAMS.has(source_zone_id):
		return

	var actual_ehi: float = EHI.get_zone_ehi(source_zone_id)
	# Restored zone → no bleed effect visible.
	if actual_ehi > EHI_RESTORED_MIN:
		return

	var ehi_normalized: float = _bleed_ehi_normalized(source_zone_id)

	# Reduced-strength copy of the source zone's shader params; no flash.
	var params: Dictionary = ZONE_SHADER_PARAMS[source_zone_id].duplicate()
	params["tint_strength"] = params.get("tint_strength", 0.5) * 0.4
	params["flash_strength"] = 0.0

	var tilemaps: Array[Node] = []
	for child_name: String in ["TileMapTerrain", "TileMapDecoration"]:
		var tm: Node = map_node.find_child(child_name, true, false)
		if tm != null:
			tilemaps.append(tm)

	for tm: Node in tilemaps:
		var mat := ShaderMaterial.new()
		mat.shader = TOZ_SHADER
		_apply_params(mat, params)
		mat.set_shader_parameter("ehi_normalized", ehi_normalized)
		var ci := tm as CanvasItem
		ci.material = mat
		_active_materials.append(mat)
		_active_canvas_items.append(ci)

	# Fog at half the partial opacity — present but dim.
	_setup_fog_bleed(source_zone_id)

	print("[ZoneVisuals] Bleed shader from '%s' (ehi_norm=%.2f)." \
		% [source_zone_id, ehi_normalized])


## Applies the current zone's TOZ shader to any additional CanvasItem.
## Call this after setup_for_map() for nodes not part of the map tree —
## typically the player's AnimatedSprite2D.
## The material is tracked in _active_materials so EHI updates reach it.
## Clears the material if no TOZ is currently active.
func apply_to_canvas_item(item: CanvasItem) -> void:
	# Use primary zone if available; fall back to bleed zone.
	var zone: String = _current_zone_id if not _current_zone_id.is_empty() else _bleed_zone_id
	if zone.is_empty() or not ZONE_SHADER_PARAMS.has(zone):
		item.material = null
		return
	var ehi: float = EHI.get_zone_ehi(zone)
	if ehi > EHI_RESTORED_MIN and _current_zone_id == zone:
		# Only skip for primary zones — bleed always renders below restored threshold.
		item.material = null
		return
	var params: Dictionary = ZONE_SHADER_PARAMS[zone].duplicate()
	var ehi_normalized: float
	if _current_zone_id.is_empty():
		# Bleed mode: reduced tint, fixed partial-range EHI, no flash.
		params["tint_strength"] = params.get("tint_strength", 0.5) * 0.4
		params["flash_strength"] = 0.0
		ehi_normalized = _bleed_ehi_normalized(zone)
	else:
		ehi_normalized = ehi / EHI.EHI_MAX
	var mat := ShaderMaterial.new()
	mat.shader = TOZ_SHADER
	_apply_params(mat, params)
	mat.set_shader_parameter("ehi_normalized", ehi_normalized)
	item.material = mat
	_active_materials.append(mat)
	_active_canvas_items.append(item)


## Manually updates the EHI uniform on all active materials.
## Called by MainGame if EHI changes outside of normal signal flow.
func refresh_ehi() -> void:
	if _current_zone_id.is_empty():
		return
	_on_ehi_changed(_current_zone_id, EHI.get_zone_ehi(_current_zone_id))


## Called by MainGame._on_stepped_on_tile() on every player tile step.
## Counts steps and triggers the poison flash + camera shake every FLASH_STEP_INTERVAL
## steps while the zone is infested — matching pokeemerald's overworld poison timing.
func notify_zone_step() -> void:
	if _current_zone_id.is_empty() or _active_materials.is_empty():
		return
	# Flash only in infested state.
	if EHI.get_zone_ehi(_current_zone_id) > EHI_INFESTED_MAX:
		return
	var params: Dictionary = ZONE_SHADER_PARAMS.get(_current_zone_id, {})
	if params.get("flash_strength", 0.0) < 0.01:
		return
	_step_counter += 1
	if _step_counter < FLASH_STEP_INTERVAL:
		return
	_step_counter = 0
	_trigger_flash_and_shake()


## Registers the Camera2D to shake when a step-based flash fires.
## Call this each time the player is spawned (MainGame._load_map).
func set_shake_camera(cam: Camera2D) -> void:
	_shake_camera = cam
	_step_counter = 0


# =========================================================================
#  Internal
# =========================================================================

func _apply_params(mat: ShaderMaterial, params: Dictionary) -> void:
	for key: String in params:
		var value: Variant = params[key]
		# Vector3 → Color conversion for source_color uniforms.
		if value is Vector3:
			var v := value as Vector3
			mat.set_shader_parameter(key, Color(v.x, v.y, v.z, 1.0))
		else:
			mat.set_shader_parameter(key, value)


func _clear_materials() -> void:
	for item: CanvasItem in _active_canvas_items:
		if is_instance_valid(item):
			item.material = null
	_active_canvas_items.clear()
	_active_materials.clear()
	_bleed_zone_id = ""
	_clear_fog()


func _connect_ehi() -> void:
	if not _ehi_connected:
		EHI.ehi_changed.connect(_on_ehi_changed)
		_ehi_connected = true


func _disconnect_ehi() -> void:
	if _ehi_connected:
		EHI.ehi_changed.disconnect(_on_ehi_changed)
		_ehi_connected = false


func _on_ehi_changed(zone_id: String, value: float) -> void:
	if zone_id != _current_zone_id:
		return
	var ehi_normalized: float = value / EHI.EHI_MAX
	for mat: ShaderMaterial in _active_materials:
		mat.set_shader_parameter("ehi_normalized", ehi_normalized)
	# Keep fog opacity in sync with EHI state.
	_update_fog_opacity(value)
	# Zone fully restored — strip the shader so the normal tileset shows through.
	if value > EHI_RESTORED_MIN:
		_clear_materials() # also calls _clear_fog()
		_disconnect_ehi()


func _trigger_flash_and_shake() -> void:
	_set_flash_impulse(1.0)
	var tween := create_tween()
	tween.tween_method(_set_flash_impulse, 1.0, 0.0, 0.45)
	if _shake_camera != null:
		var flash_strength: float = ZONE_SHADER_PARAMS.get(_current_zone_id, {}).get("flash_strength", 0.22)
		_do_camera_shake(flash_strength)


func _set_flash_impulse(value: float) -> void:
	for mat: ShaderMaterial in _active_materials:
		mat.set_shader_parameter("flash_impulse", value)


func _do_camera_shake(intensity: float) -> void:
	# Brief three-phase offset tween: right → left → centre.
	# Magnitude scales with flash intensity but stays in a narrow GBA-feel range.
	var mag: float = clamp(intensity * 28.0, 3.0, 8.0)
	var tween := create_tween()
	tween.tween_property(_shake_camera, "offset", Vector2(mag, -2.0), 0.05)
	tween.tween_property(_shake_camera, "offset", Vector2(-mag, 2.0), 0.05)
	tween.tween_property(_shake_camera, "offset", Vector2.ZERO, 0.04)


# ── Fog overlay ───────────────────────────────────────────────────────────────

func _setup_fog(zone_id: String, ehi: float) -> void:
	_clear_fog()
	if not ZONE_FOG_PARAMS.has(zone_id) or ehi > EHI_RESTORED_MIN:
		return

	var fp: Dictionary = ZONE_FOG_PARAMS[zone_id]
	var tex: Texture2D = load(fp.get("texture", "")) as Texture2D
	if tex == null:
		push_warning("[ZoneVisuals] Fog texture not found: %s" % fp.get("texture", ""))
		return

	# CanvasLayer sits above the world (z=10) but below UI (z=100).
	_fog_layer = CanvasLayer.new()
	_fog_layer.layer = 10
	add_child(_fog_layer)

	# Full-screen ColorRect driven by the fog shader.
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog_layer.add_child(rect)

	var mat := ShaderMaterial.new()
	mat.shader = FOG_SHADER
	mat.set_shader_parameter("fog_texture", tex)
	mat.set_shader_parameter("scroll_speed", fp.get("scroll_speed", Vector2(0.01, 0.0)))
	var tint_v: Vector3 = fp.get("fog_tint", Vector3(0.3, 0.8, 0.1))
	mat.set_shader_parameter("fog_tint", Color(tint_v.x, tint_v.y, tint_v.z, 1.0))
	mat.set_shader_parameter("tile_scale", fp.get("tile_scale", 5.0))
	rect.material = mat
	_fog_material = mat

	_update_fog_opacity(ehi)
	print("[ZoneVisuals] Fog overlay active for zone '%s'." % zone_id)


func _update_fog_opacity(ehi: float) -> void:
	if _fog_material == null or not ZONE_FOG_PARAMS.has(_current_zone_id):
		return
	var fp: Dictionary = ZONE_FOG_PARAMS[_current_zone_id]
	var target: float
	if ehi <= EHI_INFESTED_MAX:
		target = fp.get("opacity_infested", 0.38)
	elif ehi <= EHI_RESTORED_MIN:
		target = fp.get("opacity_partial", 0.18)
	else:
		target = 0.0
	_fog_material.set_shader_parameter("opacity", target)


func _clear_fog() -> void:
	if _fog_layer != null:
		_fog_layer.queue_free()
		_fog_layer = null
		_fog_material = null


## Returns the ehi_normalized value to use for bleed rendering.
## Maps the adjacent zone's actual EHI state one stage lower:
##   infested (≤35)  → 0.50 (mid partial)
##   partial  (≤67)  → 0.70 (near restored, barely visible)
func _bleed_ehi_normalized(source_zone_id: String) -> float:
	var actual_ehi: float = EHI.get_zone_ehi(source_zone_id)
	if actual_ehi <= EHI_INFESTED_MAX:
		return 50.0 / EHI.EHI_MAX # render as partial
	return 70.0 / EHI.EHI_MAX # render as near-restored


## Sets up a dim fog overlay for bleed maps (half of partial opacity, no EHI tracking).
func _setup_fog_bleed(source_zone_id: String) -> void:
	_clear_fog()
	if not ZONE_FOG_PARAMS.has(source_zone_id):
		return
	var fp: Dictionary = ZONE_FOG_PARAMS[source_zone_id]
	var tex: Texture2D = load(fp.get("texture", "")) as Texture2D
	if tex == null:
		return

	_fog_layer = CanvasLayer.new()
	_fog_layer.layer = 10
	add_child(_fog_layer)

	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog_layer.add_child(rect)

	var mat := ShaderMaterial.new()
	mat.shader = FOG_SHADER
	mat.set_shader_parameter("fog_texture", tex)
	mat.set_shader_parameter("scroll_speed", fp.get("scroll_speed", Vector2(0.01, 0.0)))
	var tint_v: Vector3 = fp.get("fog_tint", Vector3(0.3, 0.8, 0.1))
	mat.set_shader_parameter("fog_tint", Color(tint_v.x, tint_v.y, tint_v.z, 1.0))
	mat.set_shader_parameter("tile_scale", fp.get("tile_scale", 5.0))
	# Bleed fog: half of the partial opacity.
	mat.set_shader_parameter("opacity", fp.get("opacity_partial", 0.18) * 0.5)
	rect.material = mat
	_fog_material = mat
