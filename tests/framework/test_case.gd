class_name TestCase
extends RefCounted

## Base class for unit tests in the custom test framework.

var _failures: Array[String] = []
var _assertions_count: int = 0

func before_each() -> void:
	pass

func after_each() -> void:
	pass

func get_failures() -> Array[String]:
	return _failures

func get_assertions_count() -> int:
	return _assertions_count

func has_failed() -> bool:
	return _failures.size() > 0

func reset_test_state() -> void:
	_failures.clear()
	_assertions_count = 0

func fail(message: String = "Test failed explicitly") -> void:
	_assertions_count += 1
	_failures.append(message)

func assert_true(condition: bool, message: String = "") -> void:
	_assertions_count += 1
	if not condition:
		var msg = message if message != "" else "Expected true, got false"
		_failures.append(msg)

func assert_false(condition: bool, message: String = "") -> void:
	_assertions_count += 1
	if condition:
		var msg = message if message != "" else "Expected false, got true"
		_failures.append(msg)

func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	_assertions_count += 1
	if actual != expected:
		var msg = message if message != "" else "Expected '%s', got '%s'" % [str(expected), str(actual)]
		_failures.append(msg)

func assert_ne(actual: Variant, expected: Variant, message: String = "") -> void:
	_assertions_count += 1
	if actual == expected:
		var msg = message if message != "" else "Expected value not equal to '%s'" % [str(expected)]
		_failures.append(msg)

func assert_null(value: Variant, message: String = "") -> void:
	_assertions_count += 1
	if value != null:
		var msg = message if message != "" else "Expected null, got '%s'" % [str(value)]
		_failures.append(msg)

func assert_not_null(value: Variant, message: String = "") -> void:
	_assertions_count += 1
	if value == null:
		var msg = message if message != "" else "Expected non-null value, got null"
		_failures.append(msg)

func assert_almost_eq(actual: float, expected: float, tolerance: float = 0.0001, message: String = "") -> void:
	_assertions_count += 1
	if absf(actual - expected) > tolerance:
		var msg = message if message != "" else "Expected '%f' within %f of '%f'" % [actual, tolerance, expected]
		_failures.append(msg)

func assert_vec_almost_eq(actual: Vector3, expected: Vector3, tolerance: float = 0.0001, message: String = "") -> void:
	_assertions_count += 1
	if (actual - expected).length() > tolerance:
		var msg = message if message != "" else "Expected Vector3 %s within %f of %s (diff: %f)" % [str(actual), tolerance, str(expected), (actual - expected).length()]
		_failures.append(msg)

func assert_array_eq(actual: Array, expected: Array, message: String = "") -> void:
	_assertions_count += 1
	if actual.size() != expected.size():
		var msg = message if message != "" else "Array size mismatch: actual %d, expected %d" % [actual.size(), expected.size()]
		_failures.append(msg)
		return
	for i in range(actual.size()):
		if actual[i] != expected[i]:
			var msg = message if message != "" else "Array mismatch at index %d: actual '%s', expected '%s'" % [i, str(actual[i]), str(expected[i])]
			_failures.append(msg)
			return
