class_name TestStrataPaletteRegistry
extends "res://tests/framework/test_case.gd"

const StrataRegistryClass = preload("res://src/rendering/strata_palette_registry.gd")

func test_groups_exist_and_match_categories() -> void:
	var groups = StrataRegistryClass.get_groups()
	assert_true(groups.has(StrataRegistryClass.GROUP_SOIL), "Must contain soil group")
	assert_true(groups.has(StrataRegistryClass.GROUP_BADLANDS), "Must contain badlands group")
	assert_true(groups.has(StrataRegistryClass.GROUP_MINERAL), "Must contain mineral group")
	assert_true(groups.has(StrataRegistryClass.GROUP_VOLCANIC), "Must contain volcanic group")

func test_all_presets_have_four_valid_colors() -> void:
	var groups = StrataRegistryClass.get_groups()
	for grp in groups:
		var presets = StrataRegistryClass.get_presets(grp)
		assert_true(presets.size() >= 2, "Group %s must have at least 2 presets" % grp)
		for p in presets:
			var pal = StrataRegistryClass.get_palette(grp, p)
			assert_eq(pal.size(), 4, "Palette for %s/%s must have exactly 4 horizons" % [grp, p])
			for i in range(4):
				assert_true(pal[i].a > 0.9, "Color %d in %s/%s must be fully opaque" % [i, grp, p])

func test_invalid_group_or_preset_fallback() -> void:
	var def_pal = StrataRegistryClass.get_default_palette()
	var fallback_pal1 = StrataRegistryClass.get_palette("non_existent_group", "foo")
	var fallback_pal2 = StrataRegistryClass.get_palette(StrataRegistryClass.GROUP_SOIL, "non_existent_preset")
	assert_eq(fallback_pal1, def_pal, "Invalid group must fallback to default palette")
	assert_eq(fallback_pal2, def_pal, "Invalid preset must fallback to default palette")

func test_apply_to_material_parameters() -> void:
	var mat = ShaderMaterial.new()
	var cfg = RefCounted.new()
	cfg.set_meta("strata_enabled", true)
	cfg.set_meta("strata_group", StrataRegistryClass.GROUP_BADLANDS)
	cfg.set_meta("strata_preset", "canyon_terracotta")
	cfg.set_meta("strata_frequency", 0.42)
	cfg.set_meta("strata_warp_strength", 0.65)

	# Mock duck-typed resource
	var ConfigClass = preload("res://src/rendering/ascii_atlas_config.gd")
	var real_cfg = ConfigClass.create_default_config()
	if real_cfg.get("strata_group") != null:
		real_cfg.set("strata_group", StrataRegistryClass.GROUP_BADLANDS)
		real_cfg.set("strata_preset", "canyon_terracotta")

	StrataRegistryClass.apply_to_material(mat, real_cfg)
	assert_true(bool(mat.get_shader_parameter("strata_enabled")), "strata_enabled must be applied")
	assert_not_null(mat.get_shader_parameter("strata_color_0"), "strata_color_0 must be set")
	assert_not_null(mat.get_shader_parameter("strata_color_1"), "strata_color_1 must be set")
	assert_not_null(mat.get_shader_parameter("strata_color_2"), "strata_color_2 must be set")
	assert_not_null(mat.get_shader_parameter("strata_color_3"), "strata_color_3 must be set")
