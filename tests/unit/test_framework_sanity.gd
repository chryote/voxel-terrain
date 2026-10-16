class_name TestFrameworkSanity
extends "res://tests/framework/test_case.gd"

func test_basic_assertions() -> void:
	assert_true(true, "true should be true")
	assert_false(false, "false should be false")
	assert_eq(2 + 2, 4, "math should work")
	assert_almost_eq(1.00001, 1.0, 0.001, "almost eq should work")
	assert_array_eq([1, 2, 3], [1, 2, 3], "arrays should match")
