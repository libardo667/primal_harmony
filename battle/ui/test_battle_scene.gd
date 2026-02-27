## Test harness for BattleScene UI.
## Attach to root of test_battle_scene.tscn and run with F6.
## Owner: The Mechanic
extends Node

@onready var battle_scene: CanvasLayer = $BattleScene

func _ready() -> void:
	print("========================================")
	print("  BattleScene UI — Test Engine")
	print("========================================\n")
	
	# Delay start slightly to let autoloads settle
	await get_tree().create_timer(0.5).timeout
	
	print("[test_battle_scene] Spawning mocked Pokemon data...")
	var player_p: Dictionary = BattleManager.build_pokemon_state("treecko", 15)
	var wild_p: Dictionary = BattleManager.build_pokemon_state("scleecko", 14)
	
	# Give the player some moves
	player_p["learnset"] = [
		{"move_id": "pound"},
		{"move_id": "leer"},
		{"move_id": "absorb"},
		{"move_id": "quick_attack"}
	]
	
	print("[test_battle_scene] Initiating wild battle...")
	BattleManager.start_wild_battle(player_p, wild_p, "the_murk")
	
	print("[test_battle_scene] Battle started. UI should display 'the_murk' background and show turn menu.")
