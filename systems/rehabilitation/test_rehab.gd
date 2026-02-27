## Test harness for the RehabLog system.
## Attach to the root node of test_rehab.tscn. Run with F6.
## Note: Requires EHI and RehabLog autoloads registered by The Elder.
##
## Owner: The Mechanic
extends Node

var _tests_passed: int = 0
var _tests_failed: int = 0


func _ready() -> void:
	print("========================================")
	print("  RehabLog — Test Suite")
	print("========================================\n")

	_test_initial_state()
	_test_native_release()
	_test_ehi_boost_on_native_release()
	_test_quell_release()
	_test_quell_progress()
	_test_query_by_species()
	_test_query_by_zone()
	_test_milestone_signal()
	_test_summary()

	print("\n========================================")
	print("  Results:  %d passed  /  %d failed" % [_tests_passed, _tests_failed])
	print("========================================")


# ----- Test Cases -----

func _test_initial_state() -> void:
	_assert_eq(RehabLog.get_total_releases(), 0, "Total releases starts at 0")
	_assert_approx(RehabLog.get_quell_progress("ashen_glacier"), 0.0,
		"No quell progress for new zone")
	_assert_false(RehabLog.is_zone_quelled("ashen_glacier"), "Zone not quelled initially")


func _test_native_release() -> void:
	var species_data: Dictionary = {"is_native_hoenn": true, "native_zone": "ashen_glacier"}
	RehabLog.record_release("spinda", "ashen_glacier", species_data)
	_assert_eq(RehabLog.get_total_releases(), 1, "Total = 1 after release")


func _test_ehi_boost_on_native_release() -> void:
	# Check EHI got boosted in the zone.
	var ehi: float = EHI.get_zone_ehi("ashen_glacier")
	# Zone may not have been registered — default is 30.0, native boost adds 2.0.
	_assert_true(ehi >= RehabLog.NATIVE_RELEASE_EHI_BOOST,
		"EHI boosted after native release (ehi = %.1f)" % ehi)


func _test_quell_release() -> void:
	RehabLog.record_quell_release("swinub", "ashen_glacier")
	_assert_eq(RehabLog.get_total_releases(), 2, "Total = 2 after quell release")


func _test_quell_progress() -> void:
	var progress: float = RehabLog.get_quell_progress("ashen_glacier")
	_assert_approx(progress, RehabLog.QUELL_PROGRESS_PER_RELEASE,
		"Quell progress = %.2f" % RehabLog.QUELL_PROGRESS_PER_RELEASE)
	_assert_false(RehabLog.is_zone_quelled("ashen_glacier"), "Zone not yet quelled")


func _test_query_by_species() -> void:
	var spinda_releases: Array[Dictionary] = RehabLog.get_releases_by_species("spinda")
	_assert_eq(spinda_releases.size(), 1, "get_releases_by_species returns 1 for spinda")


func _test_query_by_zone() -> void:
	var zone_releases: Array[Dictionary] = RehabLog.get_releases_by_zone("ashen_glacier")
	_assert_eq(zone_releases.size(), 2, "get_releases_by_zone returns 2 for ashen_glacier")


func _test_milestone_signal() -> void:
	var result: Array = [false, 0] # [received, milestone]

	var callback := func(milestone: int, _total: int) -> void:
		result[0] = true
		result[1] = milestone

	RehabLog.milestone_reached.connect(callback)
	# We already have 2 releases. Need to push to 5 to hit the next milestone.
	for i: int in range(3):
		RehabLog.record_release("swablu", "ashen_glacier", {"is_native_hoenn": true})
	RehabLog.milestone_reached.disconnect(callback)

	_assert_true(result[0], "milestone_reached signal emitted")
	_assert_eq(result[1], 5, "Milestone 5 triggered")


func _test_summary() -> void:
	var summary: Dictionary = RehabLog.get_summary()
	_assert_true(summary.has("total"), "Summary has 'total'")
	_assert_true(summary.has("native_releases"), "Summary has 'native_releases'")
	_assert_true(summary.has("milestones_hit"), "Summary has 'milestones_hit'")


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
		print("  ✗  %s  (expected ~%.3f, got %.3f)" % [label, expected, actual])


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
