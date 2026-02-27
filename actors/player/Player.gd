## Player Controller — CharacterBody2D with grid-aware 4-directional movement.
##
## Handles WASD / Arrow input, walk/run speeds, AnimatedSprite2D animation,
## tile-step detection for world transitions, and wild-encounter-zone tracking.
##
## Owner: The Mechanic (Phase 5)
extends CharacterBody2D

# =========================================================================
#  Signals
# =========================================================================

## Emitted every time the player crosses a 16 px tile boundary.
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
const MAY_FRAMES     := preload("res://assets/sprites/player/may/may_spriteframes.tres")

## Walk speed in pixels per second (roughly 5 tiles/s at 16 px/tile).
const WALK_SPEED: float = 80.0

## Run speed in pixels per second.
const RUN_SPEED: float = 140.0

## Step distance in pixels. Every time the player moves this far,
## a tile-step signal is emitted and an encounter roll is attempted.
const STEP_SIZE: float = 16.0

# =========================================================================
#  Node References
# =========================================================================

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _encounter_detector: Area2D = $EncounterDetector

# =========================================================================
#  State
# =========================================================================

## The direction the player is currently facing.  Persists when idle.
var _facing: StringName = &"down"

## Is the player currently moving?
var _moving: bool = false

## Distance walked since last tile-step check.
var _step_accumulator: float = 0.0

## Currently overlapping encounter zone (or null).
var _current_encounter_zone: Area2D = null

## Zone ID extracted from the current encounter zone metadata.
var _current_zone_id: String = ""

## 0 = Brendan, 1 = May.  Toggled with F4.
var _character_idx: int = 0

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


func _physics_process(delta: float) -> void:
	# Y-sort: tile row + 1 keeps player above terrain (z=0), below decoration (z=100).
	z_index = int(global_position.y / 16) + 1

	var input_dir: Vector2 = _get_input_direction()
	var is_running: bool = Input.is_action_pressed("run")

	if input_dir != Vector2.ZERO:
		_moving = true
		_facing = _direction_to_name(input_dir)

		var speed: float = RUN_SPEED if is_running else WALK_SPEED
		velocity = input_dir * speed
		_play_animation("run" if is_running else "walk")

		# Tile-step tracking: emit stepped_on_tile every 16 px and roll encounters.
		_step_accumulator += speed * delta
		if _step_accumulator >= STEP_SIZE:
			_step_accumulator -= STEP_SIZE
			var tile_pos := Vector2i(
				int(global_position.x / STEP_SIZE),
				int(global_position.y / STEP_SIZE)
			)
			stepped_on_tile.emit(tile_pos)
			_try_encounter_step()
	else:
		_moving = false
		velocity = Vector2.ZERO
		_play_animation("idle")
		_step_accumulator = 0.0

	move_and_slide()


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
		var tile := Vector2i(
			int(global_position.x / STEP_SIZE),
			int(global_position.y / STEP_SIZE)
		)
		interact_pressed.emit(tile + _facing_offset())
		get_viewport().set_input_as_handled()

# =========================================================================
#  Input Helpers
# =========================================================================

func _get_input_direction() -> Vector2:
	# Use Godot's built-in get_vector to handle normalized diagonal movement
	# and analog stick deadzones correctly.
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
		&"up":    return Vector2i( 0, -1)
		&"down":  return Vector2i( 0,  1)
		&"left":  return Vector2i(-1,  0)
		&"right": return Vector2i( 1,  0)
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
	_step_accumulator = 0.0
	print("[Player] Entered encounter zone: %s" % _current_zone_id)
	entered_encounter_zone.emit(area)


func _on_encounter_area_exited(area: Area2D) -> void:
	if _current_encounter_zone == area:
		print("[Player] Exited encounter zone: %s" % _current_zone_id)
		exited_encounter_zone.emit(area)
		_current_encounter_zone = null
		_current_zone_id = ""
		_step_accumulator = 0.0


func _try_encounter_step() -> void:
	if _current_zone_id.is_empty():
		return
	# Delegate to EncounterManager with default step rate.
	EncounterManager.try_encounter(_current_zone_id)
