## NPC.gd — Generic overworld NPC (CharacterBody2D).
##
## Spawned at runtime by NPCSpawner from data/npc_placements.json.
## Supports idle/wander/look_around movement and a simple multi-line
## dialogue triggered by the player pressing "interact" on an adjacent tile.
extends CharacterBody2D

# ── Exported properties (set by NPCSpawner at spawn time) ─────────────────────

## Unique identifier for this NPC (matches the "id" key in npc_placements.json).
var npc_id:      String = ""
## Which direction the NPC faces when idle.
var facing:      String = "down"
## Movement pattern: "static" | "look_around" | "wander"
var movement:    String = "static"
## Wander radius in tiles (only used when movement == "wander").
var range_x:     int    = 0
var range_y:     int    = 0
## Name shown in the dialogue box speaker slot.  Empty = no speaker label.
var speaker_name: String = ""
## Lines of dialogue shown in order.  Supports BBCode (RichTextLabel).
var dialogue: Array = []

# ── Node references ────────────────────────────────────────────────────────────

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

# ── Internal state ─────────────────────────────────────────────────────────────

const WALK_SPEED: float = 45.0   # px/s — slightly slower than the player
const STEP: float       = 16.0   # tile size in pixels

## Pixel position at the time of spawn; wander stays within range of this.
var _origin: Vector2      = Vector2.ZERO
## Pixel position the NPC is walking toward (wander mode).
var _target: Vector2      = Vector2.ZERO
var _moving: bool         = false
var _wander_timer: float  = 0.0
## Randomised so NPCs don't all move simultaneously.
var _wander_interval: float = 0.0

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	_origin         = global_position
	_target         = global_position
	_wander_interval = 2.5 + randf() * 3.0
	collision_layer  = 1
	collision_mask   = 0      # NPCs don't initiate collisions, they just block
	_play("idle")

# ── Public API ─────────────────────────────────────────────────────────────────

## Load and apply a SpriteFrames resource from a res:// path.
func set_sprite_frames(path: String) -> void:
	if path.is_empty():
		return
	var frames: SpriteFrames = load(path)
	if frames:
		_sprite.sprite_frames = frames
		_play("idle")

## Called by NPCSpawner when the player interacts with this NPC.
func speak() -> void:
	if dialogue.is_empty():
		return
	# Face the player (rotate toward them roughly).
	# For now just face the player's most recent approach direction.
	# A proper "face player" needs the player position; handled in NPCSpawner.
	DialogueManager.play_dialogue(dialogue, speaker_name)

## Called by NPCSpawner to face this NPC toward a world position (e.g. player).
func face_toward(world_pos: Vector2) -> void:
	var diff := world_pos - global_position
	if abs(diff.x) >= abs(diff.y):
		facing = "right" if diff.x > 0 else "left"
	else:
		facing = "down" if diff.y > 0 else "up"
	_play("idle")

# ── Movement ───────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	# Y-sort: tile row + 1 keeps NPC above terrain (z=0), below decoration (z=100).
	z_index = int(global_position.y / 16) + 1

	match movement:
		"wander":      _do_wander(delta)
		"look_around": _do_look_around(delta)
		_:             pass   # "static" — no physics needed


func _do_look_around(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = _wander_interval
		var dirs := ["down", "up", "left", "right"]
		facing = dirs[randi() % dirs.size()]
		_play("idle")


func _do_wander(delta: float) -> void:
	if _moving:
		var diff := _target - global_position
		if diff.length() <= 1.5:
			global_position = _target
			_moving = false
			_play("idle")
		else:
			velocity = diff.normalized() * WALK_SPEED
			move_and_slide()
	else:
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			_wander_timer = _wander_interval
			_pick_wander_target()


func _pick_wander_target() -> void:
	# 30 % chance to stay in place — makes movement feel organic, not robotic.
	if randf() < 0.3:
		return
	var rx: int = range_x if range_x > 0 else 0
	var ry: int = range_y if range_y > 0 else 0
	var dx: int = randi_range(-rx, rx)
	var dy: int = randi_range(-ry, ry)
	var candidate := _origin + Vector2(dx, dy) * STEP
	if candidate != global_position:
		_target = candidate
		_moving = true
		facing  = _dir_name(_target - global_position)
		_play("walk")

# ── Animation helpers ──────────────────────────────────────────────────────────

func _play(action: String) -> void:
	if not _sprite.sprite_frames:
		return
	var flip := (facing == "right")
	_sprite.flip_h = flip
	var dir  := "left" if flip else facing
	var anim := "%s_%s" % [action, dir]
	if _sprite.sprite_frames.has_animation(anim):
		if _sprite.animation != anim:
			_sprite.play(anim)
	elif action == "walk" and _sprite.sprite_frames.has_animation("idle_%s" % dir):
		# Fallback: no walk animation, keep idle playing.
		pass
	elif _sprite.sprite_frames.has_animation("idle_down"):
		if _sprite.animation != "idle_down":
			_sprite.play("idle_down")


func _dir_name(v: Vector2) -> String:
	if abs(v.x) >= abs(v.y):
		return "right" if v.x > 0 else "left"
	return "down" if v.y > 0 else "up"
