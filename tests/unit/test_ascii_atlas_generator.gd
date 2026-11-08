class_name TestAsciiAtlasGenerator
extends "res://tests/framework/test_case.gd"

const ConfigClass = preload("res://src/rendering/ascii_atlas_config.gd")
const GeneratorClass = preload("res://src/rendering/ascii_atlas_generator.gd")
const RasterizerClass = preload("res://src/rendering/ascii_glyph_rasterizer.gd")

func test_config_defaults() -> void:
	var cfg = ConfigClass.create_default_config()
	assert_not_null(cfg, "Config should instantiate")
	assert_eq(cfg.grid_columns, 16, "Default grid_columns should be 16")
	assert_eq(cfg.grid_rows, 16, "Default grid_rows should be 16")
	assert_eq(cfg.cell_size_px, 16, "Default cell_size_px should be 16")
	assert_almost_eq(cfg.glyphs_per_voxel, 10.0, 0.01, "Default glyphs_per_voxel should be 10.0")
	assert_almost_eq(cfg.glyph_contrast, 0.30, 0.01, "Default glyph_contrast should be 0.30")
	assert_almost_eq(cfg.depth_relief_strength, 0.15, 0.01, "Default depth_relief_strength should be 0.15")
	assert_almost_eq(cfg.cavity_shadow_intensity, 0.25, 0.01, "Default cavity_shadow_intensity should be 0.25")
	assert_almost_eq(cfg.parallax_strength, 0.015, 0.001, "Default parallax_strength should be 0.015")
	assert_almost_eq(cfg.lit_threshold, 0.30, 0.01, "Default lit_threshold should be 0.30")

func test_rasterizer_space_is_empty() -> void:
	var space_mask = RasterizerClass.rasterize_glyph_8x8(32)
	assert_eq(space_mask.size(), 64, "Mask size must be 64 bytes")
	var stroke_count = 0
	for bit in space_mask:
		stroke_count += bit
	assert_eq(stroke_count, 0, "Space character must have 0 stroke pixels")

func test_rasterizer_hash_has_strokes() -> void:
	var hash_mask = RasterizerClass.rasterize_glyph_8x8(35) # '#'
	assert_eq(hash_mask.size(), 64, "Mask size must be 64 bytes")
	var stroke_count = 0
	for bit in hash_mask:
		stroke_count += bit
	assert_true(stroke_count >= 16, "Hash character must have at least 16 stroke pixels")

func test_rasterizer_solid_block_is_full() -> void:
	var solid_mask = RasterizerClass.rasterize_glyph_8x8(219) # '█'
	var stroke_count = 0
	for bit in solid_mask:
		stroke_count += bit
	assert_eq(stroke_count, 64, "Solid block 219 must have all 64 pixels filled")

func test_atlas_image_dimensions_and_format() -> void:
	var img = GeneratorClass.generate_atlas_image(16, 16, 16)
	assert_not_null(img, "Generated image should not be null")
	assert_eq(img.get_width(), 256, "Width must be 256 (16 cols * 16 px)")
	assert_eq(img.get_height(), 256, "Height must be 256 (16 rows * 16 px)")
	assert_eq(img.get_format(), Image.FORMAT_RGBA8, "Image format must be RGBA8")

func test_multi_channel_relief_encoding() -> void:
	var img = GeneratorClass.generate_atlas_image(16, 16, 16)
	# Examine solid block at index 219: gx = 219 % 16 = 11, gy = 219 / 16 = 13
	var solid_px = img.get_pixel(11 * 16 + 8, 13 * 16 + 8)
	assert_almost_eq(solid_px.r, 1.0, 0.01, "Solid stroke R must be 1.0")
	assert_almost_eq(solid_px.g, 1.0, 0.01, "Solid stroke G (bevel height) must be 1.0")
	assert_almost_eq(solid_px.b, 1.0, 0.01, "Solid stroke B (cavity) must be 1.0")
	assert_almost_eq(solid_px.a, 1.0, 0.01, "Alpha must be 1.0")

	# Examine space at index 32: gx = 32 % 16 = 0, gy = 32 / 16 = 2
	var space_px = img.get_pixel(0 * 16 + 8, 2 * 16 + 8)
	assert_almost_eq(space_px.r, 0.0, 0.01, "Empty space R must be 0.0")
	assert_almost_eq(space_px.g, 0.0, 0.01, "Empty space G (bevel) must be 0.0")
	assert_almost_eq(space_px.b, 0.35, 0.05, "Empty space B (cavity floor) must be ~0.35")

func test_save_and_load_atlas_file() -> void:
	var path = "res://assets/textures/ascii_atlas.png"
	var err = GeneratorClass.save_atlas_to_file(path, 16)
	assert_eq(err, OK, "save_atlas_to_file should return OK")
	assert_true(FileAccess.file_exists(path), "Atlas PNG file must exist on disk")

	var loaded = Image.load_from_file(path)
	assert_not_null(loaded, "Image should load back from file")
	assert_eq(loaded.get_width(), 256, "Loaded width must match")
	assert_eq(loaded.get_height(), 256, "Loaded height must match")
