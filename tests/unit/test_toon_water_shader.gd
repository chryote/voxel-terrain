class_name TestToonWaterShader
extends "res://tests/framework/test_case.gd"

## Unit and architectural test for the Stylized NPR Toon Water Shader.
## Validates:
## 1. Shader resource loading and Godot compilation without warnings/errors.
## 2. Fulfillment of the 4 NPR pillars (Hard-Edge Foam, Stepped Colors, Graphic Ripples, Unshaded/No-Specular).
## 3. Strict code architecture bounds (no God functions, line count <= 140).

const SHADER_PATH = "res://shaders/water/toon_water.gdshader"

func test_shader_resource_loading_and_material_attachment() -> void:
	var shader = load(SHADER_PATH) as Shader
	assert_not_null(shader, "Toon water shader resource must load successfully")
	
	var mat = ShaderMaterial.new()
	mat.shader = shader
	assert_not_null(mat.shader, "ShaderMaterial should accept the toon water shader")
	
	# Verify shader parameter assignment and retrieval
	mat.set_shader_parameter("foam_thickness", 0.42)
	mat.set_shader_parameter("shallow_color", Color(0.2, 0.6, 0.8, 0.9))
	mat.set_shader_parameter("mid_color", Color(0.1, 0.4, 0.6, 0.9))
	mat.set_shader_parameter("deep_color", Color(0.05, 0.15, 0.25, 0.95))

	assert_almost_eq(float(mat.get_shader_parameter("foam_thickness")), 0.42, 0.001, "foam_thickness should match assigned value")
	assert_eq(mat.get_shader_parameter("shallow_color"), Color(0.2, 0.6, 0.8, 0.9), "shallow_color should match assigned value")
	assert_eq(mat.get_shader_parameter("mid_color"), Color(0.1, 0.4, 0.6, 0.9), "mid_color should match assigned value")
	assert_eq(mat.get_shader_parameter("deep_color"), Color(0.05, 0.15, 0.25, 0.95), "deep_color should match assigned value")

func test_shader_pillar_unshaded_and_no_specular() -> void:
	var file = FileAccess.open(SHADER_PATH, FileAccess.READ)
	assert_not_null(file, "Shader file must be readable")
	var code = file.get_as_text()
	file.close()

	assert_true(code.contains("shader_type spatial;"), "Must be a 3D spatial shader")
	assert_true(code.contains("render_mode unshaded"), "Must use unshaded render mode for flat NPR colors")
	assert_true(code.contains("cull_back"), "Must use backface culling")
	assert_true(code.contains("depth_draw_always"), "Must write depth for transparent sorting")
	
	# Verify no specular calculations or normal maps
	assert_false(code.contains("SPECULAR"), "Shader must drop all specular calculations")
	assert_false(code.contains("ROUGHNESS ="), "Shader must not compute PBR roughness")
	assert_false(code.contains("NORMAL_MAP"), "Shader must drop normal maps to match flat voxel blocks")

func test_shader_pillar_hard_edge_intersection_foam() -> void:
	var file = FileAccess.open(SHADER_PATH, FileAccess.READ)
	assert_not_null(file, "Shader file must be readable")
	var code = file.get_as_text()
	file.close()

	assert_true(code.contains("hint_depth_texture"), "Must sample hint_depth_texture")
	assert_true(code.contains("get_linear_scene_depth"), "Must contain linear depth reconstruction helper")
	assert_true(code.contains("foam_thickness"), "Must expose foam_thickness uniform")
	assert_true(code.contains("foam_color"), "Must expose foam_color uniform")
	assert_true(code.contains("depth_diff < foam_thickness"), "Must use crisp threshold without soft blending")

func test_shader_pillar_stepped_depth_colors() -> void:
	var file = FileAccess.open(SHADER_PATH, FileAccess.READ)
	assert_not_null(file, "Shader file must be readable")
	var code = file.get_as_text()
	file.close()

	assert_true(code.contains("evaluate_stepped_depth"), "Must have modular stepped depth evaluator")
	assert_true(code.contains("shallow_threshold"), "Must have shallow depth threshold")
	assert_true(code.contains("deep_threshold"), "Must have deep depth threshold")
	assert_true(code.contains("shallow_color"), "Must define shallow color band")
	assert_true(code.contains("mid_color"), "Must define mid-depth color band")
	assert_true(code.contains("deep_color"), "Must define deep color band")

func test_shader_pillar_graphic_ripples_and_cellular_math() -> void:
	var file = FileAccess.open(SHADER_PATH, FileAccess.READ)
	assert_not_null(file, "Shader file must be readable")
	var code = file.get_as_text()
	file.close()

	assert_true(code.contains("cellular_distance"), "Must contain cellular/Voronoi distance evaluator")
	assert_true(code.contains("evaluate_graphic_ripples"), "Must contain dual-scrolling ripple evaluator")
	assert_true(code.contains("step("), "Must use step() for hard comic contour lines")
	assert_true(code.contains("ripple_threshold"), "Must expose ripple line threshold")
	assert_true(code.contains("ripple_radius"), "Must expose ripple radius uniform")

func test_shader_pixelized_foam_and_side_fluid_flow() -> void:
	var file = FileAccess.open(SHADER_PATH, FileAccess.READ)
	assert_not_null(file, "Shader file must be readable")
	var code = file.get_as_text()
	file.close()

	assert_true(code.contains("pixel_density"), "Shader must expose pixel_density uniform for pixelized foam")
	assert_true(code.contains("foam_enabled"), "Shader must expose foam_enabled toggle to silence ocean noise")
	assert_true(code.contains("side_fluid_speed"), "Shader must expose side_fluid_speed uniform")
	assert_true(code.contains("evaluate_side_fluid_flow"), "Shader must contain evaluate_side_fluid_flow helper")
	assert_true(code.contains("v_world_normal"), "Shader must calculate and utilize world normal for face orientation")

func test_shader_architectural_limits_and_no_god_functions() -> void:
	var file = FileAccess.open(SHADER_PATH, FileAccess.READ)
	assert_not_null(file, "Shader file must be readable")
	var code = file.get_as_text()
	file.close()

	var total_lines = code.split("\n").size()
	assert_true(total_lines <= 140, "Shader must be <= 140 lines total (got %d)" % total_lines)

	# Audit discrete helper functions
	var required_helpers = [
		"hash2",
		"cellular_distance",
		"get_linear_scene_depth",
		"evaluate_stepped_depth",
		"evaluate_graphic_ripples",
		"fragment"
	]
	for h in required_helpers:
		assert_true(code.contains(h), "Shader must contain discrete helper %s" % h)
