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
		"queasy_amplitude": 0.0,
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
		"queasy_amplitude": 0.1,
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
		"queasy_amplitude": 0.0,
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
		"queasy_amplitude": 0.4, # Psychic undulation
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
		"queasy_amplitude": 0.0,
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
		"queasy_amplitude": 1.0, # The Murk is the most nauseating
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
		"queasy_amplitude": 0.0,
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
		"queasy_amplitude": 0.0,
	},
	"abyss_bloom": {
		# Water/Psychic — deep indigo with bioluminescent bloom.
		# zone_tint kept mid-bright so dark stone/dive pixels don't collapse to black.
		# shadow_strength kept low for the same reason — dark textures already read dark.
		"zone_tint": Vector3(0.35, 0.25, 0.90),
		"tint_strength": 0.50,
		"infested_saturation": 1.3,
		"shimmer_amplitude": 0.005,
		"shimmer_speed": 0.5,
		"shimmer_frequency": 3.0,
		"shadow_strength": 0.12,
		"queasy_amplitude": 0.1,
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
		"queasy_amplitude": 0.0,
	},
}

# =========================================================================
#  Internal State
# =========================================================================

## The current primary zone_id (the one the player is on).
## Drives global effects like Flash and Shake intensities.
var _primary_zone_id: String = ""

## Per-map visual data: Node2D -> { "materials": [], "fog": Node, "particles": [] }
var _map_visuals: Dictionary = {}

## CanvasItem nodes with active materials (like player sprite) — tracked globally
## so they can be cleared on zone restore.
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

## Weather types matching nostalgic GBA effects.
enum WeatherType {NONE, RAIN, SNOW, SANDSTORM, SUNSHINE}

## Per-zone weather config.
const ZONE_WEATHER_PARAMS: Dictionary = {
	"abyss_bloom": WeatherType.RAIN,
	"ashen_glacier": WeatherType.SNOW,
	"the_crucible": WeatherType.SANDSTORM,
	"emberscar": WeatherType.SUNSHINE,
	"static_sprawl": WeatherType.RAIN, # Thunderstorm feel
	"the_murk": WeatherType.NONE, # Fog is enough for poison
}

# ── Particles ──────────────────────────────────────────────────────────────────

const ZONE_PARTICLE_PARAMS := {
	"the_murk": {
		"color": Color(0.28, 0.75, 0.10, 0.6), # Toxic Green
		"size": 2.0,
		"speed": Vector2(10, 20),
		"amount": 20,
		"gravity": Vector2(0, 5)
	},
	"emberscar": {
		"color": Color(1.0, 0.4, 0.1, 0.8), # Ember Orange
		"size": 1.5,
		"speed": Vector2(5, 30),
		"amount": 25,
		"gravity": Vector2(0, -10) # Rising embers
	}
}

## Active fog CanvasLayer (layer=10).
var _fog_layer: CanvasLayer = null
var _fog_material: ShaderMaterial = null

## Active weather CanvasLayer (layer=11, above fog).
var _weather_layer: CanvasLayer = null
var _weather_particles: GPUParticles2D = null
var _current_weather: WeatherType = WeatherType.NONE


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
	_clear_map_visuals(map_node)
	
	if zone_id.is_empty() or not ZONE_SHADER_PARAMS.has(zone_id):
		return

	# Zone already restored — show normal tileset, no shader.
	var initial_ehi: float = EHI.get_zone_ehi(zone_id)
	if initial_ehi > EHI_RESTORED_MIN:
		return

	# Prepare map visual storage
	_map_visuals[map_node] = {
		"materials": [],
		"fog": null,
		"particles": [],
		"zone_id": zone_id
	}

	# Find TileMap nodes in the map.
	var tilemaps: Array[Node] = []
	for child_name: String in ["TileMapTerrain", "TileMapDecoration"]:
		var tm: Node = map_node.find_child(child_name, true, false)
		if tm != null:
			tilemaps.append(tm)

	if tilemaps.is_empty():
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
		_map_visuals[map_node]["materials"].append(mat)
		_active_canvas_items.append(ci)

	# Connect EHI signal if not already
	_connect_ehi()

	# Fog (Attached to map node for world-space transition)
	_setup_fog(map_node, zone_id, initial_ehi)
	
	print("[ZoneVisuals] Applied TOZ shader to map '%s' (zone=%s, ehi=%.1f)." % [
		map_node.name, zone_id, initial_ehi
	])


func set_primary_zone(zone_id: String) -> void:
	_primary_zone_id = zone_id
	_step_counter = 0
	var ehi: float = EHI.get_zone_ehi(zone_id) if not zone_id.is_empty() else 100.0
	_setup_weather(zone_id, ehi)


func _clear_map_visuals(map_node: Node2D) -> void:
	if not _map_visuals.has(map_node):
		return
	
	var data = _map_visuals[map_node]
	for mat in data["materials"]:
		# Find the canvas item using this material and clear it
		for ci in _active_canvas_items:
			if is_instance_valid(ci) and ci.material == mat:
				ci.material = null
				break
	
	if is_instance_valid(data["fog"]):
		data["fog"].queue_free()
	
	for p in data["particles"]:
		if is_instance_valid(p):
			p.queue_free()
			
	_map_visuals.erase(map_node)


## Called by MainGame when the current map is adjacent to (but not inside) a TOZ.
## Applies the adjacent zone's palette at one EHI stage lower with reduced intensity.
## - Adjacent zone infested  → show partial-level shader
## - Adjacent zone partial   → show near-restored shader (very subtle)
## - Adjacent zone restored  → no effect
## No EHI signal is connected — bleed state is static for the duration of the visit.
func setup_for_map_bleed(map_node: Node2D, source_zone_id: String) -> void:
	_clear_map_visuals(map_node)
	
	if not ZONE_SHADER_PARAMS.has(source_zone_id):
		return

	var actual_ehi: float = EHI.get_zone_ehi(source_zone_id)
	if actual_ehi > EHI_RESTORED_MIN:
		return

	var ehi_normalized: float = _bleed_ehi_normalized(source_zone_id)
	var params: Dictionary = ZONE_SHADER_PARAMS[source_zone_id].duplicate()
	params["tint_strength"] = params.get("tint_strength", 0.5) * 0.4
	params["flash_strength"] = 0.0

	_map_visuals[map_node] = {
		"materials": [],
		"fog": null,
		"particles": [],
		"zone_id": source_zone_id
	}

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
		_map_visuals[map_node]["materials"].append(mat)
		_active_canvas_items.append(ci)

	_setup_fog_bleed(map_node, source_zone_id)
	_setup_bleed_particles(map_node, source_zone_id)


## Called by MainGame before queue_freeing a map to clean up tracking data.
## Prevents _map_visuals from accumulating stale entries for freed nodes.
func clear_map(map_node: Node2D) -> void:
	_clear_map_visuals(map_node)
	# Also prune any dead canvas items from the global list.
	var pruned: Array[CanvasItem] = []
	for ci in _active_canvas_items:
		if is_instance_valid(ci):
			pruned.append(ci)
	_active_canvas_items = pruned


func _setup_bleed_particles(map_node: Node2D, zone_id: String) -> void:
	if not ZONE_PARTICLE_PARAMS.has(zone_id):
		return
	
	var params = ZONE_PARTICLE_PARAMS[zone_id]
	var map_id = WorldConnections.get_map_id_for_scene(map_node.scene_file_path)
	var size = WorldConnections.get_map_size(map_id)
	
	# Create a simple CPUParticles2D for the "bleeding" effect
	# In a real implementation, we'd place these at specific boundaries,
	# but for now we'll spread them across the map area to simulate the "mist".
	var p := CPUParticles2D.new()
	p.name = "BleedParticles"
	p.amount = params["amount"]
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(size) * 8.0 # half size * 16
	p.position = Vector2(size) * 8.0 # center
	p.gravity = params["gravity"]
	p.direction = Vector2(1, 1)
	p.spread = 180.0
	p.initial_velocity_min = params["speed"].x
	p.initial_velocity_max = params["speed"].y
	p.scale_amount_min = params["size"] * 0.5
	p.scale_amount_max = params["size"]
	p.color = params["color"]
	p.z_index = 610 # Above fog (600) and decoration (500)
	
	map_node.add_child(p)
	if _map_visuals.has(map_node):
		_map_visuals[map_node]["particles"].append(p)

	print("[ZoneVisuals] Bleed shader from '%s'." % [zone_id])


## Applies the current zone's TOZ shader to any additional CanvasItem.
## Call this after setup_for_map() for nodes not part of the map tree —
## typically the player's AnimatedSprite2D.
## The material is tracked in _active_materials so EHI updates reach it.
## Clears the material if no TOZ is currently active.
func apply_to_canvas_item(item: CanvasItem) -> void:
	var zone = _primary_zone_id
	if zone.is_empty() or not ZONE_SHADER_PARAMS.has(zone):
		item.material = null
		return
	
	var ehi: float = EHI.get_zone_ehi(zone)
	if ehi > EHI_RESTORED_MIN:
		item.material = null
		return
		
	var params: Dictionary = ZONE_SHADER_PARAMS[zone].duplicate()
	var ehi_normalized = ehi / EHI.EHI_MAX
	
	var mat := ShaderMaterial.new()
	mat.shader = TOZ_SHADER
	_apply_params(mat, params)
	mat.set_shader_parameter("ehi_normalized", ehi_normalized)
	item.material = mat
	
	# Track for global EHI updates
	_active_canvas_items.append(item)


## Manually updates the EHI uniform on all active materials.
## Called by MainGame if EHI changes outside of normal signal flow.
func refresh_ehi() -> void:
	var snapshot := EHI.get_all_zone_data()
	for zone_id: String in snapshot:
		_on_ehi_changed(zone_id, snapshot[zone_id])


## Called by MainGame._on_stepped_on_tile() on every player tile step.
## Counts steps and triggers the poison flash + camera shake every FLASH_STEP_INTERVAL
## steps while the zone is infested — matching pokeemerald's overworld poison timing.
func notify_zone_step() -> void:
	if _primary_zone_id.is_empty():
		return
	# Flash only in infested state.
	if EHI.get_zone_ehi(_primary_zone_id) > EHI_INFESTED_MAX:
		return
	var params: Dictionary = ZONE_SHADER_PARAMS.get(_primary_zone_id, {})
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
	
	# Clear all map-specific visuals
	var keys = _map_visuals.keys()
	for node in keys:
		_clear_map_visuals(node)
	
	_clear_fog()
	_clear_weather()


func _connect_ehi() -> void:
	if not _ehi_connected:
		EHI.ehi_changed.connect(_on_ehi_changed)
		_ehi_connected = true


func _disconnect_ehi() -> void:
	if _ehi_connected:
		EHI.ehi_changed.disconnect(_on_ehi_changed)
		_ehi_connected = false


func _on_ehi_changed(zone_id: String, value: float) -> void:
	var ehi_normalized: float = value / EHI.EHI_MAX
	
	# Update all map nodes assigned to this zone
	for map_node in _map_visuals:
		if not is_instance_valid(map_node):
			continue
		var data = _map_visuals[map_node]
		if data["zone_id"] == zone_id:
			for mat in data["materials"]:
				mat.set_shader_parameter("ehi_normalized", ehi_normalized)
			_update_map_fog_opacity(map_node, value)
			# TODO: update particles

	# Update global canvas items (player, etc.) if we are in the primary zone
	if zone_id == _primary_zone_id:
		for ci in _active_canvas_items:
			if is_instance_valid(ci) and ci.material:
				ci.material.set_shader_parameter("ehi_normalized", ehi_normalized)
		
		# Weather follows primary zone
		_update_weather_intensity(value)

	# Zone fully restored — cleanup will happen on next map transition or here?
	# Better to let MainGame/Transition clear it, but we can strip current mats
	if value > EHI_RESTORED_MIN:
		# Search and clear only this zone's mats
		var to_clear = []
		for map_node in _map_visuals:
			if _map_visuals[map_node]["zone_id"] == zone_id:
				to_clear.append(map_node)
		for node in to_clear:
			_clear_map_visuals(node)


func _trigger_flash_and_shake() -> void:
	_set_flash_impulse(1.0)
	var tween := create_tween()
	tween.tween_method(_set_flash_impulse, 1.0, 0.0, 0.45)
	if _shake_camera != null:
		var flash_strength: float = ZONE_SHADER_PARAMS.get(_primary_zone_id, {}).get("flash_strength", 0.22)
		_do_camera_shake(flash_strength)


func _set_flash_impulse(value: float) -> void:
	for map_node in _map_visuals:
		for mat in _map_visuals[map_node]["materials"]:
			mat.set_shader_parameter("flash_impulse", value)
	
	for ci in _active_canvas_items:
		if is_instance_valid(ci) and ci.material:
			ci.material.set_shader_parameter("flash_impulse", value)


func _do_camera_shake(intensity: float) -> void:
	# Brief three-phase offset tween: right → left → centre.
	# Magnitude scales with flash intensity but stays in a narrow GBA-feel range.
	var mag: float = clamp(intensity * 28.0, 3.0, 8.0)
	var tween := create_tween()
	tween.tween_property(_shake_camera, "offset", Vector2(mag, -2.0), 0.05)
	tween.tween_property(_shake_camera, "offset", Vector2(-mag, 2.0), 0.05)
	tween.tween_property(_shake_camera, "offset", Vector2.ZERO, 0.04)


# ── Fog overlay ───────────────────────────────────────────────────────────────

func _setup_fog(map_node: Node2D, zone_id: String, ehi: float) -> void:
	if not ZONE_FOG_PARAMS.has(zone_id) or ehi > EHI_RESTORED_MIN:
		return

	var fp: Dictionary = ZONE_FOG_PARAMS[zone_id]
	var tex: Texture2D = load(fp.get("texture", "")) as Texture2D
	if tex == null:
		return

	# Attachment for world-space transition
	var rect := ColorRect.new()
	rect.name = "FogOverlay"
	# Detect map size for rect bounds
	var map_id = WorldConnections.get_map_id_for_scene(map_node.scene_file_path)
	var size = WorldConnections.get_map_size(map_id)
	rect.size = Vector2(size) * 16.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.z_index = 600 # Above decoration (500) and characters (100–200)
	map_node.add_child(rect)

	var mat := ShaderMaterial.new()
	mat.shader = FOG_SHADER
	mat.set_shader_parameter("fog_texture", tex)
	mat.set_shader_parameter("scroll_speed", fp.get("scroll_speed", Vector2(0.01, 0.0)))
	var tint_v: Vector3 = fp.get("fog_tint", Vector3(0.3, 0.8, 0.1))
	mat.set_shader_parameter("fog_tint", Color(tint_v.x, tint_v.y, tint_v.z, 1.0))
	mat.set_shader_parameter("tile_scale", fp.get("tile_scale", 5.0))
	rect.material = mat

	if _map_visuals.has(map_node):
		_map_visuals[map_node]["fog"] = rect

	_update_map_fog_opacity(map_node, ehi)


func _update_map_fog_opacity(map_node: Node2D, ehi: float) -> void:
	if not _map_visuals.has(map_node): return
	var rect = _map_visuals[map_node]["fog"]
	if not is_instance_valid(rect): return
	
	var zone_id = _map_visuals[map_node]["zone_id"]
	var fp: Dictionary = ZONE_FOG_PARAMS.get(zone_id, {})
	if fp.is_empty(): return
	
	var target: float
	if ehi <= EHI_INFESTED_MAX:
		target = fp.get("opacity_infested", 0.38)
	elif ehi <= EHI_RESTORED_MIN:
		target = fp.get("opacity_partial", 0.18)
	else:
		target = 0.0
	rect.material.set_shader_parameter("opacity", target)


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
func _setup_fog_bleed(map_node: Node2D, source_zone_id: String) -> void:
	if not ZONE_FOG_PARAMS.has(source_zone_id):
		return
	var fp: Dictionary = ZONE_FOG_PARAMS[source_zone_id]
	var tex: Texture2D = load(fp.get("texture", "")) as Texture2D
	if tex == null:
		return

	var rect := ColorRect.new()
	rect.name = "FogBleed"
	var map_id = WorldConnections.get_map_id_for_scene(map_node.scene_file_path)
	var size = WorldConnections.get_map_size(map_id)
	rect.size = Vector2(size) * 16.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.z_index = 600 # Above decoration (500), matching primary fog z_index
	map_node.add_child(rect)

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
	
	if _map_visuals.has(map_node):
		_map_visuals[map_node]["fog"] = rect


# =========================================================================
#  Weather System (Nostalgic GBA Focus)
# =========================================================================

func _setup_weather(zone_id: String, ehi: float) -> void:
	_clear_weather()
	if not ZONE_WEATHER_PARAMS.has(zone_id):
		return
	
	var type: WeatherType = ZONE_WEATHER_PARAMS[zone_id]
	if type == WeatherType.NONE:
		return
	
	_current_weather = type
	_weather_layer = CanvasLayer.new()
	_weather_layer.layer = 11 # Above fog
	add_child(_weather_layer)
	
	_weather_particles = GPUParticles2D.new()
	_weather_particles.name = "WeatherParticles"
	_weather_particles.amount = 400
	_weather_particles.preprocess = 5.0 # Pre-fill the screen
	_weather_layer.add_child(_weather_particles)
	
	var process_mat := ParticleProcessMaterial.new()
	_weather_particles.process_material = process_mat
	
	# Common settings
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_mat.emission_box_extents = Vector3(500, 300, 1) # Cover the screen area
	_weather_particles.position = Vector2(240, 160) # GBA resolution center roughly
	
	match type:
		WeatherType.RAIN:
			process_mat.direction = Vector3(-1, 2, 0)
			process_mat.spread = 2.0
			process_mat.initial_velocity_min = 400.0
			process_mat.initial_velocity_max = 500.0
			process_mat.color = Color(0.6, 0.7, 1.0, 0.4)
			_weather_particles.amount = 200
		
		WeatherType.SNOW:
			process_mat.direction = Vector3(0.1, 1, 0)
			process_mat.spread = 20.0
			process_mat.initial_velocity_min = 30.0
			process_mat.initial_velocity_max = 60.0
			process_mat.color = Color(1.0, 1.0, 1.0, 0.7)
			process_mat.scale_min = 2.0
			process_mat.scale_max = 3.0
			
		WeatherType.SANDSTORM:
			process_mat.direction = Vector3(-1, 0.05, 0)
			process_mat.spread = 1.0
			process_mat.initial_velocity_min = 600.0
			process_mat.initial_velocity_max = 900.0
			process_mat.color = Color(0.7, 0.6, 0.4, 0.3)
			_weather_particles.amount = 500

		WeatherType.SUNSHINE:
			# Sunshine: rising warm light motes drifting upward.
			process_mat.direction = Vector3(0, -1, 0)
			process_mat.spread = 30.0
			process_mat.initial_velocity_min = 15.0
			process_mat.initial_velocity_max = 35.0
			process_mat.color = Color(1.0, 0.95, 0.6, 0.25)
			process_mat.scale_min = 1.5
			process_mat.scale_max = 3.0
			_weather_particles.amount = 60

	_update_weather_intensity(ehi)


func _update_weather_intensity(ehi: float) -> void:
	if _weather_particles == null:
		return
	
	var intensity: float = 0.0
	if ehi <= EHI_INFESTED_MAX:
		intensity = 1.0
	elif ehi <= EHI_RESTORED_MIN:
		intensity = 0.4
	
	if intensity <= 0.01:
		_weather_particles.emitting = false
	else:
		_weather_particles.emitting = true
		_weather_particles.speed_scale = intensity
		_weather_particles.modulate.a = intensity


func _clear_weather() -> void:
	if _weather_layer != null:
		_weather_layer.queue_free()
		_weather_layer = null
		_weather_particles = null
		_current_weather = WeatherType.NONE
