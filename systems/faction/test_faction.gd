## Test harness for the FactionManager system.
## Attach to the root node of test_faction.tscn. Run with F6.
##
## Owner: The Mechanic
extends Node

var _tests_passed: int = 0
var _tests_failed: int = 0


func _ready() -> void:
	print("========================================")
	print("  FactionManager — Test Suite")
	print("========================================\n")

	_test_initial_state()
	_test_modify_rep()
	_test_tension_mechanic()
	_test_clamp_upper()
	_test_clamp_lower()
	_test_rep_tiers()
	_test_alliance_threshold()
	_test_signal_emission()
	_test_no_tension()
	_test_get_all_rep_data()

	print("\n========================================")
	print("  Results:  %d passed  /  %d failed" % [_tests_passed, _tests_failed])
	print("========================================")


# ----- Test Cases -----

func _test_initial_state() -> void:
	_assert_approx(FactionManager.get_rep("aqua"), FactionManager.DEFAULT_REP,
		"Aqua rep starts at DEFAULT_REP")
	_assert_approx(FactionManager.get_rep("magma"), FactionManager.DEFAULT_REP,
		"Magma rep starts at DEFAULT_REP")
	_assert_false(FactionManager.get_alliance_ready(),
		"Alliance not ready at default rep")


func _test_modify_rep() -> void:
	FactionManager.modify_rep("aqua", 10.0, 0.0) # no tension for isolated test
	_assert_approx(FactionManager.get_rep("aqua"), 35.0, "Aqua +10 = 35")


func _test_tension_mechanic() -> void:
	# Reset to known state
	FactionManager._aqua_rep = 50.0
	FactionManager._magma_rep = 50.0
	# Default tension = 0.25 → +20 aqua should cost -5 magma
	FactionManager.modify_rep("aqua", 20.0)
	_assert_approx(FactionManager.get_rep("aqua"), 70.0, "Aqua +20 = 70")
	_assert_approx(FactionManager.get_rep("magma"), 45.0,
		"Magma penalised by tension (50 - 20*0.25 = 45)")


func _test_clamp_upper() -> void:
	FactionManager._aqua_rep = 95.0
	FactionManager.modify_rep("aqua", 999.0, 0.0)
	_assert_approx(FactionManager.get_rep("aqua"), 100.0, "Aqua clamped to 100")


func _test_clamp_lower() -> void:
	FactionManager._magma_rep = 5.0
	FactionManager.modify_rep("magma", -999.0, 0.0)
	_assert_approx(FactionManager.get_rep("magma"), 0.0, "Magma clamped to 0")


func _test_rep_tiers() -> void:
	FactionManager._aqua_rep = 0.0
	_assert_eq(FactionManager.get_rep_tier("aqua"), "distrust", "0 = distrust")
	FactionManager._aqua_rep = 25.0
	_assert_eq(FactionManager.get_rep_tier("aqua"), "neutral", "25 = neutral")
	FactionManager._aqua_rep = 50.0
	_assert_eq(FactionManager.get_rep_tier("aqua"), "friendly", "50 = friendly")
	FactionManager._aqua_rep = 75.0
	_assert_eq(FactionManager.get_rep_tier("aqua"), "trusted", "75 = trusted")
	FactionManager._aqua_rep = 100.0
	_assert_eq(FactionManager.get_rep_tier("aqua"), "bonded", "100 = bonded")


func _test_alliance_threshold() -> void:
	FactionManager._aqua_rep = 75.0
	FactionManager._magma_rep = 75.0
	FactionManager._alliance_unlocked = false
	_assert_true(FactionManager.get_alliance_ready(), "Alliance ready at 75/75")
	FactionManager._magma_rep = 74.0
	_assert_false(FactionManager.get_alliance_ready(), "Alliance not ready at 75/74")


func _test_signal_emission() -> void:
	# Use an Array container — lambdas capture the reference, not the value.
	var result: Array = [false, "", 0.0] # [received, faction, value]

	var callback := func(faction: String, value: float) -> void:
		result[0] = true
		result[1] = faction
		result[2] = value

	FactionManager._magma_rep = 50.0
	FactionManager.faction_rep_changed.connect(callback)
	FactionManager.modify_rep("magma", 10.0, 0.0)
	FactionManager.faction_rep_changed.disconnect(callback)

	_assert_true(result[0], "faction_rep_changed signal was emitted")
	_assert_eq(result[1], "magma", "Signal carried correct faction")
	_assert_approx(result[2], 60.0, "Signal carried correct value")


func _test_no_tension() -> void:
	FactionManager._aqua_rep = 50.0
	FactionManager._magma_rep = 50.0
	FactionManager.modify_rep("aqua", 10.0, 0.0)
	_assert_approx(FactionManager.get_rep("magma"), 50.0,
		"Magma unchanged when tension_factor = 0")


func _test_get_all_rep_data() -> void:
	var data: Dictionary = FactionManager.get_all_rep_data()
	_assert_true(data.has("aqua"), "get_all_rep_data has 'aqua' key")
	_assert_true(data.has("magma"), "get_all_rep_data has 'magma' key")
	_assert_true(data.has("alliance_ready"), "get_all_rep_data has 'alliance_ready' key")


# ----- Assertion Helpers -----

func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		_tests_passed += 1
		print("  ✓  %s" % label)
	else:
		_tests_failed += 1
		print("  ✗  %s  (expected %s, got %s)" % [label, str(expected), str(actual)])


func _assert_approx(actual: float, expected: float, label: String) -> void:
	if is_equal_approx(actual, expected):
		_tests_passed += 1
		print("  ✓  %s" % label)
	else:
		_tests_failed += 1
		print("  ✗  %s  (expected ~%.2f, got %.2f)" % [label, expected, actual])


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		_tests_passed += 1
		print("  ✓  %s" % label)
	else:
		_tests_failed += 1
		print("  ✗  %s  (expected true)" % label)


func _assert_false(condition: bool, label: String) -> void:
	if not condition:
		_tests_passed += 1
		print("  ✓  %s" % label)
	else:
		_tests_failed += 1
		print("  ✗  %s  (expected false)" % label)
