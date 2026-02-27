extends SceneTree

func _init() -> void:
	print("========================================")
	print("Starting DataManager Test")
	print("========================================")
	
	# Instance DataManager
	var data_manager: Node = load("res://systems/DataManager.gd").new()
	data_manager._ready() # Force load
	
	print("\n--- Verifying Counts ---")
	print("Pokemon loaded: %d" % data_manager.get_all_pokemon_ids().size())
	print("Moves loaded: %d" % data_manager.get_all_move_ids().size())
	print("Items loaded: %d" % data_manager.get_all_item_ids().size())
	print("Abilities loaded: %d" % data_manager.get_all_ability_ids().size())
	print("Zones loaded: %d" % data_manager.get_all_zone_ids().size())
	
	print("\n--- Verifying Wrapper Types ---")
	var success := true
	
	# Test PokemonData
	var treecko = data_manager.get_pokemon("treecko")
	if treecko == null:
		print("FAIL: get_pokemon returned null")
		success = false
	elif not treecko is PokemonData:
		print("FAIL: get_pokemon did not return PokemonData. Type: %s" % typeof(treecko))
		success = false
	else:
		print("PASS: PokemonData - Name: %s, Types: %s" % [treecko.name, treecko.types])
		if treecko.base_stats.is_empty():
			print("FAIL: PokemonData base_stats is empty")
			success = false
			
	# Test ZoneData
	var ashen_glacier = data_manager.get_zone("ashen_glacier")
	if ashen_glacier == null:
		print("FAIL: get_zone returned null")
		success = false
	elif not ashen_glacier is ZoneData:
		print("FAIL: get_zone did not return ZoneData")
		success = false
	else:
		print("PASS: ZoneData - Name: %s, Dominant Type: %s" % [ashen_glacier.zone_name, ashen_glacier.dominant_type])
		
	# Test MoveData
	var pound = data_manager.get_move("pound")
	if pound != null and not pound is MoveData:
		print("FAIL: get_move did not return MoveData")
		success = false
	elif pound != null:
		print("PASS: MoveData - Name: %s, Power: %s" % [pound.name, pound.power])
		
	# Test ItemData
	var potion = data_manager.get_item("potion")
	if potion != null and not potion is ItemData:
		print("FAIL: get_item did not return ItemData")
		success = false
	elif potion != null:
		print("PASS: ItemData - Name: %s, Category: %s" % [potion.name, potion.category])
		
	# Test AbilityData
	var overgrow = data_manager.get_ability("overgrow")
	if overgrow != null and not overgrow is AbilityData:
		print("FAIL: get_ability did not return AbilityData")
		success = false
	elif overgrow != null:
		print("PASS: AbilityData - Name: %s, Description: %s" % [overgrow.name, overgrow.description])
		
	print("\n========================================")
	if success:
		print("ALL TESTS PASSED")
	else:
		print("SOME TESTS FAILED")
	print("========================================")
	
	quit()
