class_name TestAsciiTerrainShader
extends "res://tests/framework/test_case.gd"

const SHADER_PATH = "res://shaders/terrain/ascii_terrain.gdshader"

func test_shader_compilation_and_code() -> void:
	var shader = load(SHADER_PATH) as Shader
	assert_not_null(shader, "Ascii terrain shader resource should load")
	var code = shader.code
	assert_true(code.contains("shader_type spatial;"), "Shader type must be spatial")
	assert_true(code.contains("render_mode diffuse_toon"), "Shader must use diffuse_toon render mode")
	assert_true(code.contains("void light()"), "Shader must override light() entrypoint")
	assert_true(code.contains("void fragment()"), "Shader must override fragment() entrypoint")

func test_shader_decomposed_helper_functions() -> void:
	var shader = load(SHADER_PATH) as Shader
	assert_not_null(shader, "Shader resource should load")
	var code = shader.code
	assert_true(code.contains("calculate_voxel_face_uv"), "Must contain calculate_voxel_face_uv helper")
	assert_true(code.contains("get_atlas_tile_uv"), "Must contain get_atlas_tile_uv helper")
	assert_true(code.contains("evaluate_parallax"), "Must contain evaluate_parallax helper")
	assert_true(code.contains("decode_material_id"), "Must contain decode_material_id helper")
	assert_true(code.contains("sample_glyph_data"), "Must contain sample_glyph_data helper")
	assert_true(code.contains("perturb_normal_micro_relief"), "Must contain perturb_normal_micro_relief helper")

func test_shader_uniforms_declared() -> void:
	var shader = load(SHADER_PATH) as Shader
	assert_not_null(shader, "Shader resource should load")
	var code = shader.code
	assert_true(code.contains("ascii_atlas"), "Must declare ascii_atlas uniform")
	assert_true(code.contains("material_lut"), "Must declare material_lut uniform")
	assert_true(code.contains("atlas_grid"), "Must declare atlas_grid uniform")
	assert_true(code.contains("glyphs_per_voxel"), "Must declare glyphs_per_voxel uniform")
	assert_true(code.contains("depth_relief_strength"), "Must declare depth_relief_strength uniform")
	assert_true(code.contains("cavity_shadow_intensity"), "Must declare cavity_shadow_intensity uniform")
	assert_true(code.contains("parallax_strength"), "Must declare parallax_strength uniform")
	assert_true(code.contains("lit_threshold"), "Must declare lit_threshold uniform")
	assert_true(code.contains("shadow_tint"), "Must declare shadow_tint uniform")

func test_shader_material_parameter_assignment() -> void:
	var shader = load(SHADER_PATH) as Shader
	assert_not_null(shader, "Shader resource should load")
	var mat = ShaderMaterial.new()
	mat.shader = shader

	mat.set_shader_parameter("glyphs_per_voxel", 3.5)
	mat.set_shader_parameter("depth_relief_strength", 0.72)
	mat.set_shader_parameter("cavity_shadow_intensity", 0.81)

	assert_almost_eq(float(mat.get_shader_parameter("glyphs_per_voxel")), 3.5, 0.01, "glyphs_per_voxel should match")
	assert_almost_eq(float(mat.get_shader_parameter("depth_relief_strength")), 0.72, 0.01, "depth_relief_strength should match")
	assert_almost_eq(float(mat.get_shader_parameter("cavity_shadow_intensity")), 0.81, 0.01, "cavity_shadow_intensity should match")
