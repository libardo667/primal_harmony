## Player Controller — CharacterBody2D with tile-locked 4-directional movement.
##
## Movement is atomic: each step is a tween from one 16 px tile to the next.
## Collision is pre-checked with test_move() before committing a step, so the
## player can never slide through corners (noclip impossible).
##
## Handles WASD / Arrow input, walk/run speeds, AnimatedSprite2D animation,
## tile-step detection for world transitions, and wild-encounter-zone tracking.
##
## Owner: The Mechanic (Phase 5)
extends CharacterBody2D

# =========================================================================
#  Signals
# =========================================================================

## Emitted every time the player arrives at a new 16 px tile.
## tile_pos is in tile coordinates (global_position / 16, floored).
signal stepped_on_tile(tile_pos: Vector2i)

## Emitted when the player enters an EncounterZone Area2D.
signal entered_encounter_zone(zone_node: Area2D)

## Emitted when the player leaves an EncounterZone.
signal exited_encounter_zone(zone_node: Area2D)

## Emitted when the player presses the interact button.
## facing_tile is the tile directly in front of the player.
signal interact_pressed(facing_tile: Vector2i)

# =========================================================================
#  Constants
# =========================================================================

const BRENDAN_FRAMES := preload("res://assets/sprites/player/brendan/brendan_spriteframes.tres")
const MAY_FRAMES := preload("res://assets/sprites/player/may/may_spriteframes.tres")

## Seconds to tween one 16 px tile at walk speed (~5.3 tiles/s).
const WALK_STEP_DURATION: float = 0.19

## Seconds to tween one 16 px tile at run speed (~10 tiles/s).
const RUN_STEP_DURATION: float = 0.10

## Tile size in pixels.  Matches the rest of the project.
const TILE_SIZE: int = 16

# =========================================================================
#  Node References
# =========================================================================

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _shadow: Sprite2D = $Shadow
@onready var _encounter_detector: Area2D = $EncounterDetector
@onready var _collision_shape: CollisionShape2D = $CollisionShape2D

# =========================================================================
#  State
# =========================================================================

enum MoveState { IDLE, MOVING, JUMPING }

## Current movement state — only one step or jump can be in flight at a time.
var _state: MoveState = MoveState.IDLE

## The direction the player is currently facing.  Persists when idle.
var _facing: StringName = &"down"

## Discrete tile position — the tile the player currently occupies.
## Updated by set_tile() on spawn and at the end of every step.
var _current_tile: Vector2i = Vector2i.ZERO


## Currently overlapping encounter zone (or null).
var _current_encounter_zone: Area2D = null

## Zone ID extracted from the current encounter zone metadata.
var _current_zone_id: String = ""

## 0 = Brendan, 1 = May.  Toggled with F4.
var _character_idx: int = 0

## Direct reference to the center map's TileMapTerrain for behavior lookups.
## Set by MainGame after every map load / seamless focus shift.
## Using a direct reference avoids the find_child depth-first-order ambiguity
## that caused lookups to hit a neighbor's (offset) terrain and return 0.
var _active_terrain: TileMap = null

# Behavior constants (matching behavior_constants.json)
const MB_JUMP_EAST: int  = 56
const MB_JUMP_WEST: int  = 57
const MB_JUMP_NORTH: int = 58
const MB_JUMP_SOUTH: int = 59

# =========================================================================
#  Lifecycle
# =========================================================================

func _ready() -> void:
	# Connect EncounterDetector signals.
	_encounter_detector.area_entered.connect(_on_encounter_area_entered)
	_encounter_detector.area_exited.connect(_on_encounter_area_exited)

	# Start idle animation.
	_play_animation("idle")
	print("[Player] Ready.  Facing %s." % _facing)


func _physics_process(_delta: float) -> void:
	# Y-sort: offset 100 ensures z stays positive even when player is on a northern
	# neighbor map (negative global y). Terrain=0, characters=1–200, decoration=500.
	z_index = int(global_position.y / 16) + 100

	match _state:
		MoveState.JUMPING:
			# Jump is handled entirely by _jump_ledge() coroutine — nothing to do.
			return
		MoveState.MOVING:
			return  # step is in flight; _start_step() chains when it completes
		MoveState.IDLE:
			_try_start_step()


# =========================================================================
#  Tile-Based Movement
# =========================================================================

## Teleports the player to the centre of [tile] and resets tile tracking.
## Called by MainGame whenever a new map loads or a warp fires.
func set_tile(tile: Vector2i) -> void:
	_current_tile = tile
	global_position = Vector2(tile) * TILE_SIZE + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)


## Attempts to start a step based on current or queued input.
## Called every physics frame while IDLE, and once more when a step completes
## (so continuous movement chains without a 1-frame gap).
func _try_start_step() -> void:
	if _state != MoveState.IDLE:
		return

	var dir := _get_input_direction()
	if dir == Vector2.ZERO:
		_play_animation("idle")
		return

	# Update facing immediately — even if the step is blocked the character
	# should turn to face the pressed direction (standard Pokemon behaviour).
	_facing = _direction_to_name(dir)
	_play_animation("idle")

	# ── 1. Ledge jump — fires when the player IS ON the ledge tile ──────────
	var cur_behavior := _get_behavior_at_tile(_current_tile)
	if _can_jump_ledge(cur_behavior, dir):
		_state = MoveState.JUMPING
		_jump_ledge(dir)
		return

	# ── 2. Compute target tile (dominant axis — diagonals not allowed) ───────
	var step: Vector2i
	if abs(dir.x) >= abs(dir.y):
		step = Vector2i(1 if dir.x > 0.0 else -1, 0)
	else:
		step = Vector2i(0, 1 if dir.y > 0.0 else -1)
	var target_tile := _current_tile + step

	# ── 3. Block wrong-way ledge entry ───────────────────────────────────────
	if _blocks_movement_into(_get_behavior_at_tile(target_tile), dir):
		return  # idle animation + facing already set above

	# ── 4. Physics collision check (terrain tiles + NPCs) ───────────────────
	var target_pos := Vector2(target_tile) * TILE_SIZE + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)
	if test_move(global_transform, target_pos - global_position):
		return  # blocked — stay idle

	# ── 5. All clear — commit to the step ────────────────────────────────────
	_state = MoveState.MOVING
	_start_step(target_tile)


## Tweens the player from their current position to [target_tile].
## Fires stepped_on_tile on arrival, then tries to chain the next step.
func _start_step(target_tile: Vector2i) -> void:
	var is_running := Input.is_action_pressed("run")
	var duration := RUN_STEP_DURATION if is_running else WALK_STEP_DURATION
	_play_animation("run" if is_running else "walk")

	var target_pos := Vector2(target_tile) * TILE_SIZE + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)
	var tween := create_tween()
	tween.tween_property(self, "global_position", target_pos, duration)
	await tween.finished

	# Snap to exact grid centre to prevent floating-point drift.
	_current_tile = target_tile
	global_position = target_pos

	# stepped_on_tile may trigger a warp which queue_frees this node.
	stepped_on_tile.emit(_current_tile)
	if not is_inside_tree():
		return

	_try_encounter_step()
	_state = MoveState.IDLE

	# Chain immediately — avoids the 1-frame idle gap between continuous steps.
	_try_start_step()


# =========================================================================
#  Input / Interaction
# =========================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F4:
			_character_idx = 1 - _character_idx
			var new_frames: SpriteFrames = BRENDAN_FRAMES if _character_idx == 0 else MAY_FRAMES
			var cur_anim: StringName = _sprite.animation
			_sprite.sprite_frames = new_frames
			_sprite.play(cur_anim)
			print("[Player] Character switched to %s." % ("Brendan" if _character_idx == 0 else "May"))
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("interact") and not DialogueManager._is_active:
		interact_pressed.emit(_current_tile + _facing_offset())
		get_viewport().set_input_as_handled()


func _get_input_direction() -> Vector2:
	# Use Godot's built-in get_vector to handle normalised diagonal movement
	# and analogue stick deadzones correctly.
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

# =========================================================================
#  Animation
# =========================================================================

## Plays the correct directional animation (e.g. "walk_down", "idle_left").
func _play_animation(action: String) -> void:
	var facing_anim = _facing
	if _facing == &"right":
		_sprite.flip_h = true
		facing_anim = &"left"
	else:
		_sprite.flip_h = false

	var anim_name: String = "%s_%s" % [action, facing_anim]
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(anim_name):
		if _sprite.animation != anim_name:
			_sprite.play(anim_name)
	else:
		# Fallback: try plain action name.
		if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(action):
			if _sprite.animation != action:
				_sprite.play(action)


## Returns the tile-offset one step in the player's current facing direction.
func _facing_offset() -> Vector2i:
	match _facing:
		&"up":    return Vector2i(0, -1)
		&"down":  return Vector2i(0, 1)
		&"left":  return Vector2i(-1, 0)
		&"right": return Vector2i(1, 0)
	return Vector2i(0, 1)


## Converts an input vector into a facing name string.
func _direction_to_name(dir: Vector2) -> StringName:
	if abs(dir.x) >= abs(dir.y):
		return &"right" if dir.x > 0.0 else &"left"
	else:
		return &"down" if dir.y > 0.0 else &"up"

# =========================================================================
#  Encounter Detection
# =========================================================================

func _on_encounter_area_entered(area: Area2D) -> void:
	_current_encounter_zone = area
	_current_zone_id = area.get_meta("zone_id", "")
	print("[Player] Entered encounter zone: %s" % _current_zone_id)
	entered_encounter_zone.emit(area)


func _on_encounter_area_exited(area: Area2D) -> void:
	if _current_encounter_zone == area:
		print("[Player] Exited encounter zone: %s" % _current_zone_id)
		exited_encounter_zone.emit(area)
		_current_encounter_zone = null
		_current_zone_id = ""


func _try_encounter_step() -> void:
	if _current_zone_id.is_empty():
		return
	# Delegate to EncounterManager — fires once per tile, matching GBA step count.
	EncounterManager.try_encounter(_current_zone_id)


# =========================================================================
#  Ledge Jumping
# =========================================================================

func _get_behavior_at_tile(tile_pos: Vector2i) -> int:
	if not _active_terrain:
		return 0
	# Convert global tile coordinates to local coordinates within this TileMap.
	# Neighbor maps are positioned at non-zero global_position, so this offset matters
	# whenever the center has shifted from the original (0,0) spawn position.
	var terrain_origin := Vector2i(_active_terrain.global_position / 16.0)
	var local_pos := tile_pos - terrain_origin
	for layer in _active_terrain.get_layers_count():
		var source_id := _active_terrain.get_cell_source_id(layer, local_pos)
		if source_id == -1: continue
		var atlas_coords := _active_terrain.get_cell_atlas_coords(layer, local_pos)
		var source := _active_terrain.tile_set.get_source(source_id) as TileSetAtlasSource
		if source:
			var tile_data := source.get_tile_data(atlas_coords, 0)
			if tile_data:
				var b = tile_data.get_custom_data("behavior")
				if b != 0: return b
	return 0


func _can_jump_ledge(behavior: int, input_dir: Vector2) -> bool:
	if behavior == MB_JUMP_SOUTH and input_dir.y > 0.5: return true
	if behavior == MB_JUMP_NORTH and input_dir.y < -0.5: return true
	if behavior == MB_JUMP_EAST  and input_dir.x > 0.5:  return true
	if behavior == MB_JUMP_WEST  and input_dir.x < -0.5: return true
	return false


## Returns true if moving in [input_dir] into a tile with [behavior] is wrong-way.
## Ledge tiles have no collision tile, so this replaces the wall that would normally
## stop the player from traversing the ledge from the non-jumping side.
func _blocks_movement_into(behavior: int, input_dir: Vector2) -> bool:
	if behavior == MB_JUMP_SOUTH and input_dir.y < -0.5: return true  # north into south-jump
	if behavior == MB_JUMP_NORTH and input_dir.y > 0.5:  return true  # south into north-jump
	if behavior == MB_JUMP_EAST  and input_dir.x < -0.5: return true  # west  into east-jump
	if behavior == MB_JUMP_WEST  and input_dir.x > 0.5:  return true  # east  into west-jump
	return false


## Called by MainGame after every map load or seamless focus shift.
## Stores a direct reference to the center map's TileMapTerrain so that
## _get_behavior_at_tile cannot accidentally pick up a neighbor's offset terrain.
func set_active_terrain(terrain: TileMap) -> void:
	_active_terrain = terrain


func _jump_ledge(direction: Vector2) -> void:
	# _state is already MoveState.JUMPING when this is called.
	_facing = _direction_to_name(direction)

	# Freeze on the idle pose — no walking-in-midair.
	_play_animation("idle")
	_sprite.stop()

	_collision_shape.set_deferred("disabled", true)

	_shadow.visible = true
	_shadow.scale = Vector2(1.0, 1.0)

	var target_pos := global_position + direction.normalized() * TILE_SIZE * 2.0

	const JUMP_DURATION := 0.38

	# Three independent sequential tweens — avoids the parallel-tween bug where
	# two tweens targeting the same property fight each other simultaneously.

	# 1. Body: smooth 2-tile slide across the ledge.
	var body_tween := create_tween()
	body_tween.tween_property(self, "global_position", target_pos, JUMP_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 2. Sprite: arch up relative to root then return to normal offset.
	var sprite_tween := create_tween()
	sprite_tween.tween_property(_sprite, "position:y", -20.0, JUMP_DURATION * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	sprite_tween.tween_property(_sprite, "position:y", -8.0, JUMP_DURATION * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 3. Shadow: expand at apex, contract on landing.
	var shadow_tween := create_tween()
	shadow_tween.tween_property(_shadow, "scale", Vector2(1.3, 1.3), JUMP_DURATION * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	shadow_tween.tween_property(_shadow, "scale", Vector2(0.7, 0.7), JUMP_DURATION * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	await body_tween.finished

	# Snap to tile centre, restore sprite offset and shadow state.
	global_position = Vector2(Vector2i(target_pos / float(TILE_SIZE))) * TILE_SIZE + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)
	_current_tile = Vector2i(global_position / float(TILE_SIZE))
	_sprite.position.y = -8.0
	_shadow.visible = false
	_shadow.scale = Vector2(1.0, 1.0)

	_collision_shape.set_deferred("disabled", false)
	_state = MoveState.IDLE

	_play_animation("idle")

	stepped_on_tile.emit(_current_tile)
	if not is_inside_tree():
		return
	_try_encounter_step()

	# Chain input — allows pressing a direction mid-jump for immediate next step.
	_try_start_step()
