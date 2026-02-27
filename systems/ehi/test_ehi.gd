## Test harness for the EHI system.
## Attach to the root node of test_ehi.tscn. Run with F6.
##
## Owner: The Mechanic
extends Node

var _tests_passed: int = 0
var _tests_failed: int = 0


func _ready() -> void:
	print("========================================")
	print("  EHI System — Test Suite")
	print("========================================\n")

	_test_initial_state()
	_test_register_zone()
	_test_modify_zone()
	_test_clamp_upper()
	_test_clamp_lower()
	_test_global_recalculation()
	_test_signal_emission()
	_test_set_zone_ehi()
	_test_get_all_zone_ids()

	print("\n========================================")
	print("  Results:  %d passed  /  %d failed" % [_tests_passed, _tests_failed])
	print("========================================")


# ----- Test Cases -----

func _test_initial_state() -> void:
	_assert_eq(EHI.get_global_ehi(), 0.0, "Global EHI starts at 0 (no zones)")
	_assert_eq(EHI.get_zone_count(), 0, "No zones registered initially")
	_assert_eq(EHI.get_zone_ehi("nonexistent"), EHI.DEFAULT_ZONE_EHI,
		"Unknown zone returns DEFAULT_ZONE_EHI")


func _test_register_zone() -> void:
	EHI.register_zone("route_113", 40.0)
	_assert_eq(EHI.get_zone_ehi("route_113"), 40.0, "Registered zone has correct EHI")
	_assert_eq(EHI.get_zone_count(), 1, "Zone count is 1 after first registration")
	# Duplicate registration should be a no-op
	EHI.register_zone("route_113", 99.0)
	_assert_eq(EHI.get_zone_ehi("route_113"), 40.0, "Duplicate register is a no-op")


func _test_modify_zone() -> void:
	EHI.modify_zone_ehi("route_113", 10.0)
	_assert_eq(EHI.get_zone_ehi("route_113"), 50.0, "Modify +10 works")
	EHI.modify_zone_ehi("route_113", -5.0)
	_assert_eq(EHI.get_zone_ehi("route_113"), 45.0, "Modify -5 works")


func _test_clamp_upper() -> void:
	EHI.modify_zone_ehi("route_113", 999.0)
	_assert_eq(EHI.get_zone_ehi("route_113"), 100.0, "Upper clamp to 100")


func _test_clamp_lower() -> void:
	EHI.set_zone_ehi("route_113", 5.0)
	EHI.modify_zone_ehi("route_113", -999.0)
	_assert_eq(EHI.get_zone_ehi("route_113"), 0.0, "Lower clamp to 0")


func _test_global_recalculation() -> void:
	EHI.set_zone_ehi("route_113", 60.0)
	EHI.register_zone("rustboro", 40.0)
	# Global should be mean of 60 and 40 = 50
	_assert_approx(EHI.get_global_ehi(), 50.0, "Global EHI = mean of zones (50)")


func _test_signal_emission() -> void:
	# Use an Array container — lambdas capture the reference, not the value.
	var result: Array = [false, "", 0.0] # [received, zone_id, value]

	var callback := func(zone_id: String, value: float) -> void:
		result[0] = true
		result[1] = zone_id
		result[2] = value

	EHI.ehi_changed.connect(callback)
	EHI.modify_zone_ehi("rustboro", 5.0)
	EHI.ehi_changed.disconnect(callback)

	_assert_true(result[0], "ehi_changed signal was emitted")
	_assert_eq(result[1], "rustboro", "Signal carried correct zone_id")
	_assert_approx(result[2], 45.0, "Signal carried correct value")


func _test_set_zone_ehi() -> void:
	EHI.set_zone_ehi("rustboro", 80.0)
	_assert_eq(EHI.get_zone_ehi("rustboro"), 80.0, "set_zone_ehi sets absolute value")


func _test_get_all_zone_ids() -> void:
	var ids: Array[String] = EHI.get_all_zone_ids()
	_assert_true(ids.has("route_113"), "All zone IDs includes route_113")
	_assert_true(ids.has("rustboro"), "All zone IDs includes rustboro")


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
