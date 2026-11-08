class_name TestNativeExtension
extends "res://tests/framework/test_case.gd"

## Validates Phase 0 of the C++ GDExtension rollout:
## - ClassDB registration of GDExtension types
## - Native instantiation and method binding
## - Direct execution of vendored FastNoiseLite.h in C++

func test_native_extension_loaded() -> void:
	assert_true(ClassDB.class_exists("TerrainNativeCore"), "TerrainNativeCore should be registered in ClassDB")
	var native = ClassDB.instantiate("TerrainNativeCore")
	assert_not_null(native, "TerrainNativeCore should instantiate")
	assert_true(native.is_native_active(), "is_native_active() should return true")
	assert_true(native.get_version().contains("godot-cpp"), "Version string should reference godot-cpp")

func test_vendored_fast_noise_lite() -> void:
	var native = ClassDB.instantiate("TerrainNativeCore")
	assert_not_null(native, "TerrainNativeCore should instantiate")
	var sample_a = native.sample_test_noise(10.5, 20.25, 1337)
	var sample_b = native.sample_test_noise(10.5, 20.25, 1337)
	var sample_c = native.sample_test_noise(99.0, -42.0, 1337)

	assert_true(sample_a >= -1.0 and sample_a <= 1.0, "Noise sample A must be within [-1.0, 1.0]")
	assert_eq(sample_a, sample_b, "Noise sampling with same coordinates and seed must be deterministic")
	assert_true(sample_a != sample_c, "Noise sampling different coordinates should produce different values")

