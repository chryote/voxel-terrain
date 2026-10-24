class_name TestAsciiMaterialMapper
extends "res://tests/framework/test_case.gd"

const MapperClass = preload("res://src/rendering/ascii_material_mapper.gd")
const MaterialDefClass = preload("res://src/core/material_def.gd")

func test_air_material_maps_to_space() -> void:
	var glyph = MapperClass.get_glyph_for_material(MaterialDefClass.ID_AIR, MapperClass.BAND_MIDTONE)
	assert_eq(glyph, 32, "Air must map to character code 32 (space)")

func test_all_terrain_materials_have_valid_glyphs() -> void:
	var material_ids = [
		MaterialDefClass.ID_GRASS,
		MaterialDefClass.ID_DIRT,
		MaterialDefClass.ID_STONE,
		MaterialDefClass.ID_SAND,
		MaterialDefClass.ID_SNOW,
		MaterialDefClass.ID_SEABED,
		MaterialDefClass.ID_GRAVEL,
		MaterialDefClass.ID_CAVE_WALL,
		MaterialDefClass.ID_CHASM_BASALT,
		MaterialDefClass.ID_CAVE_CRYSTAL
	]

	for mat_id in material_ids:
		var ramp = MapperClass.get_density_ramp(mat_id)
		assert_eq(ramp.size(), 4, "Material %d must have 4 lighting bands in its ramp" % mat_id)
		for band in range(4):
			var code = ramp[band]
			assert_true(code > 0, "Material %d band %d must have valid non-zero glyph code" % [mat_id, band])
			assert_true(code <= 255, "Material %d band %d glyph code must fit in byte range [0, 255]" % [mat_id, band])

func test_bake_lut_image_dimensions_and_format() -> void:
	var img = MapperClass.bake_material_lut_image()
	assert_not_null(img, "Baked LUT image should not be null")
	assert_eq(img.get_width(), 16, "LUT image width must be 16 (for 16 material slots)")
	assert_eq(img.get_height(), 4, "LUT image height must be 4 (for 4 lighting/slope bands)")
	assert_eq(img.get_format(), Image.FORMAT_RGBA8, "Format should be RGBA8")

func test_lut_pixel_values_match_ramps() -> void:
	var img = MapperClass.bake_material_lut_image()
	for mat_id in range(16):
		var ramp = MapperClass.get_density_ramp(mat_id)
		for band in range(4):
			var expected_code = ramp[band]
			var px = img.get_pixel(mat_id, band)
			var decoded_code = int(round(px.r * 255.0))
			assert_eq(decoded_code, expected_code, "Decoded LUT pixel at (%d, %d) must match ramp glyph code" % [mat_id, band])

func test_lut_texture_creation() -> void:
	var tex = MapperClass.create_lut_texture()
	assert_not_null(tex, "Created LUT texture should not be null")
	assert_eq(tex.get_width(), 16, "Texture width must be 16")
	assert_eq(tex.get_height(), 4, "Texture height must be 4")

func test_save_lut_to_file() -> void:
	var path = "res://assets/textures/ascii_material_lut.png"
	var err = MapperClass.save_lut_to_file(path)
	assert_eq(err, OK, "save_lut_to_file should succeed with OK")
	assert_true(FileAccess.file_exists(path), "LUT PNG file must exist on disk")

	var loaded = Image.load_from_file(path)
	assert_not_null(loaded, "LUT file should load back into Image")
	assert_eq(loaded.get_width(), 16, "Loaded width must be 16")
	assert_eq(loaded.get_height(), 4, "Loaded height must be 4")
