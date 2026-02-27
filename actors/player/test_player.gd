## Test harness for the Player scene.
## Attach to the root node of test_player.tscn.  Run with F6.
## Verifies: node structure, SpriteFrames loading, signal wiring,
## and prints live movement / warp / encounter events to the console.
##
## Owner: The Mechanic (Phase 5)
extends Node2D

var _tests_passed: int = 0
var _tests_failed: int = 0


func _ready() -> void:
	print("========================================")
	print("  Player — Test Suite")
	print("========================================\n")

	var player: CharacterBody2D = $Player
	_test_node_structure(player)
	_test_spriteframes(player)
	_test_signals(player)

	print("\n========================================")
	print("  Results:  %d passed  /  %d failed" % [_tests_passed, _tests_failed])
	print("========================================")
	print("\n  ▶  Use WASD / Arrows to move.  Hold Shift to run.")
	print("  ▶  Walk into the green zone (encounter) or red zone (warp).")


# ----- Tests -----

func _test_node_structure(player: CharacterBody2D) -> void:
	_assert_true(player != null, "Player node exists")
	_assert_true(player.has_node("AnimatedSprite2D"), "Has AnimatedSprite2D")
	_assert_true(player.has_node("CollisionShape2D"), "Has CollisionShape2D")
	_assert_true(player.has_node("Camera2D"), "Has Camera2D")
	_assert_true(player.has_node("WarpDetector"), "Has WarpDetector")
	_assert_true(player.has_node("EncounterDetector"), "Has EncounterDetector")


func _test_spriteframes(player: CharacterBody2D) -> void:
	var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
	_assert_true(sprite.sprite_frames != null, "SpriteFrames resource loaded")
	if sprite.sprite_frames:
		var has_idle: bool = sprite.sprite_frames.has_animation("idle_down")
		_assert_true(has_idle, "SpriteFrames contains 'idle_down' animation")


func _test_signals(player: CharacterBody2D) -> void:
	_assert_true(player.has_signal("entered_warp"), "Player has 'entered_warp' signal")
	_assert_true(player.has_signal("entered_encounter_zone"), "Player has 'entered_encounter_zone' signal")
	_assert_true(player.has_signal("exited_encounter_zone"), "Player has 'exited_encounter_zone' signal")

	# Connect for live feedback during manual testing.
	player.entered_warp.connect(_on_warp)
	player.entered_encounter_zone.connect(_on_encounter_enter)
	player.exited_encounter_zone.connect(_on_encounter_exit)


# ----- Live Event Handlers -----

func _on_warp(dest_scene: String, dest_warp_id: String) -> void:
	print("  ⚡ WARP → scene=%s  warp_id=%s" % [dest_scene, dest_warp_id])


func _on_encounter_enter(zone: Area2D) -> void:
	print("  🌿 ENCOUNTER ZONE ENTERED → %s" % zone.get_meta("zone_id", "unknown"))


func _on_encounter_exit(zone: Area2D) -> void:
	print("  🌿 ENCOUNTER ZONE EXITED → %s" % zone.get_meta("zone_id", "unknown"))


# ----- Assertion Helpers -----

func _assert_true(condition: bool, label: String) -> void:
	if condition:
		_tests_passed += 1
		print("  ✓  %s" % label)
	else:
		_tests_failed += 1
		print("  ✗  %s  (expected true)" % label)
