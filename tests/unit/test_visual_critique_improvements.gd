class_name TestVisualCritiqueImprovements
extends "res://tests/framework/test_case.gd"

## Unit test suite validating fixes for visual critiques:
## 1. Capsule contact ambient occlusion, SSAO, and contact shadow projector.
## 2. Atmospheric depth, aerial perspective, and valley height fog.
## 3. Directional/rim highlights on upward-facing edges and silhouette separation.
## 4. Camera-space vignetting, color grading, and ash/ember environmental particles.

const ContactShadowProjectorClass = preload("res://src/player/contact_shadow_projector.gd")
const AshFallEmitterClass = preload("res://src/rendering/ash_fall_emitter.gd")
const GraphicNovelConfigClass = preload("res://src/rendering/graphic_novel_config.gd")
const GraphicNovelPostProcessClass = preload("res://src/rendering/graphic_novel_post_process.gd")

func test_capsule_contact_ambient_occlusion_and_ssao() -> void:
	# 1. Main WorldEnvironment SSAO enabled
	var main_packed = load("res://scenes/main.tscn") as PackedScene
	assert_not_null(main_packed, "Main scene must load")
	var main_node = main_packed.instantiate()
	assert_not_null(main_node, "Main scene must instantiate")

	var world_env = main_node.get_node_or_null("WorldEnvironment") as WorldEnvironment
	assert_not_null(world_env, "WorldEnvironment must exist")
	assert_not_null(world_env.environment, "Environment must exist")
	assert_true(world_env.environment.ssao_enabled, "Screen Space Ambient Occlusion (SSAO) must be enabled")
	assert_true(world_env.environment.ssao_intensity >= 2.0, "SSAO intensity should provide rich contact crevices (>= 2.0)")

	main_node.free()

	# 2. Weathered capsule shader uniforms and crevice AO
	var capsule_shader = load("res://shaders/character/weathered_capsule.gdshader") as Shader
	assert_not_null(capsule_shader, "Capsule shader must load")
	var code = capsule_shader.code
	assert_true(code.contains("contact_ao_intensity"), "Capsule shader must declare contact_ao_intensity")
	assert_true(code.contains("contact_ao_height"), "Capsule shader must declare contact_ao_height")
	assert_true(code.contains("contact_crevice"), "Capsule shader must calculate contact_crevice AO")
	assert_true(code.contains("AO ="), "Capsule shader must write to spatial AO channel")

func test_player_contact_shadow_projector() -> void:
	var projector = ContactShadowProjectorClass.new()
	assert_not_null(projector, "ContactShadowProjector should instantiate cleanly")
	projector._ready()

	assert_true(projector.size.x > 0.5, "Projector width should cover capsule footprint")
	assert_true(projector.cull_mask & 1 != 0, "Projector must mask terrain layer 1")
	assert_not_null(projector.texture_albedo, "Projector must have radial shadow texture generated")
	projector.free()

	# Check player scene contains the projector
	var player_packed = load("res://scenes/player.tscn") as PackedScene
	assert_not_null(player_packed, "Player scene must load")
	var player_node = player_packed.instantiate()
	assert_not_null(player_node, "Player scene must instantiate")

	var found_projector = player_node.get_node_or_null("ContactShadowProjector")
	assert_not_null(found_projector, "Player scene must contain ContactShadowProjector node")
	assert_true(found_projector is ContactShadowProjectorClass, "Must be an instance of ContactShadowProjector")

	player_node.free()

func test_atmospheric_depth_and_height_fog() -> void:
	# 1. WorldEnvironment fog settings
	var main_packed = load("res://scenes/main.tscn") as PackedScene
	var main_node = main_packed.instantiate()
	var env = (main_node.get_node_or_null("WorldEnvironment") as WorldEnvironment).environment

	assert_true(env.fog_enabled, "Fog must be enabled")
	assert_almost_eq(env.fog_height, 24.0, 0.1, "Fog height must align with low valley / water level at 24.0")
	assert_true(env.fog_height_density >= 0.08, "Fog height density must be configured for dense valley pooling")
	assert_true(env.fog_aerial_perspective >= 0.60, "Aerial perspective should be pronounced (>= 0.60)")

	main_node.free()

	# 2. Terrain shaders distance aerial perspective and valley height mist
	var ascii_shader = load("res://shaders/terrain/ascii_terrain.gdshader") as Shader
	assert_not_null(ascii_shader, "Ascii terrain shader must load")
	var ascii_code = ascii_shader.code
	assert_true(ascii_code.contains("dist_fade"), "Ascii terrain shader must compute camera distance fade")
	assert_true(ascii_code.contains("valley_mist"), "Ascii terrain shader must compute deep valley height mist")

	var halftone_shader = load("res://shaders/terrain/halftone_terrain.gdshader") as Shader
	assert_not_null(halftone_shader, "Halftone terrain shader must load")
	var halftone_code = halftone_shader.code
	assert_true(halftone_code.contains("dist_fade"), "Halftone terrain shader must compute distance fade")
	assert_true(halftone_code.contains("valley_mist"), "Halftone terrain shader must compute valley mist")

func test_rim_lighting_and_silhouette_highlights() -> void:
	# 1. Ascii terrain shader: clean solid shadows, white pattern effect eliminated
	var ascii_shader = load("res://shaders/terrain/ascii_terrain.gdshader") as Shader
	var ascii_code = ascii_shader.code
	assert_false(ascii_code.contains("is_sky_rim"), "White pattern effect / is_sky_rim must be removed from terrain shadow")

	# 2. Weathered capsule shader rim highlights
	var capsule_shader = load("res://shaders/character/weathered_capsule.gdshader") as Shader
	var capsule_code = capsule_shader.code
	assert_true(capsule_code.contains("void light()"), "Capsule shader must override light() entrypoint")
	assert_true(capsule_code.contains("rim_highlight_enabled"), "Capsule shader must expose rim_highlight_enabled")
	assert_true(capsule_code.contains("is_rim"), "Capsule shader must compute rim highlights")
	assert_false(capsule_code.contains("is_sky_rim"), "Capsule shader must not produce white shadow pattern")

	# 3. Halftone terrain shader
	var halftone_shader = load("res://shaders/terrain/halftone_terrain.gdshader") as Shader
	var halftone_code = halftone_shader.code
	assert_false(halftone_code.contains("is_sky_rim"), "Halftone shader must not inject white pattern into shadows")

	# 4. Extreme distance LOD terrain shader: clean cel lighting, no dither artifacts on mountain slopes
	var macro_shader = load("res://shaders/terrain/distant_macro_terrain.gdshader") as Shader
	assert_not_null(macro_shader, "Distant macro terrain shader must load")
	var macro_code = macro_shader.code
	assert_false(macro_code.contains("is_lit = (clamp"), "Extreme LOD shader must not use dither penumbra in is_lit")
	assert_false(macro_code.contains("is_rim = (rim > (0.6 + dither"), "Extreme LOD shader must not use dither in is_rim")

func test_camera_space_vignetting_and_color_grading() -> void:
	# 1. Post-process shader vignetting
	var outline_shader = load("res://shaders/postprocess/outline_postprocess.gdshader") as Shader
	assert_not_null(outline_shader, "Outline postprocess shader must load")
	var code = outline_shader.code
	assert_true(code.contains("vignette_enabled"), "Shader must declare vignette_enabled")
	assert_true(code.contains("vignette_intensity"), "Shader must declare vignette_intensity")
	assert_true(code.contains("calculate_vignette"), "Shader must contain calculate_vignette helper")

	# 2. Graphic novel config & theme
	var cfg = GraphicNovelConfigClass.create_default_config()
	assert_true(cfg.get("vignette_enabled"), "Default config must enable vignette")
	assert_true(float(cfg.get("vignette_intensity")) > 0.0, "Default config must have positive vignette intensity")

	var theme = load("res://config/graphic_novel_theme.tres") as Resource
	assert_not_null(theme, "graphic_novel_theme.tres must load")
	assert_true(bool(theme.get("vignette_enabled")), "Theme must enable vignette")

	# 3. Controller applies vignette uniforms
	var controller = GraphicNovelPostProcessClass.new()
	controller.config = cfg
	controller._ready()
	assert_not_null(controller.post_material, "Post material must exist")
	assert_true(controller.post_material.get_shader_parameter("vignette_enabled"), "Post material must receive vignette_enabled uniform")
	controller.mesh_instance.free()
	controller.free()

	# 4. Main Environment color adjustments
	var main_packed = load("res://scenes/main.tscn") as PackedScene
	var main_node = main_packed.instantiate()
	var env = (main_node.get_node_or_null("WorldEnvironment") as WorldEnvironment).environment
	assert_true(env.adjustment_enabled, "Color adjustments must be enabled for desolate mood")
	assert_true(env.adjustment_contrast > 1.0, "Contrast should be enhanced (> 1.0)")
	assert_true(env.adjustment_saturation < 1.0, "Saturation should be reduced (< 1.0) for desolate aesthetic")
	main_node.free()

func test_ash_fall_particle_system() -> void:
	var emitter = AshFallEmitterClass.new()
	assert_not_null(emitter, "AshFallEmitter should instantiate cleanly")
	emitter._ready()

	assert_true(emitter.amount <= 160, "Ash particle count must be economical (<= 160)")
	assert_almost_eq(emitter.lifetime, 4.5, 0.2, "Lifetime should be around 4.5 seconds")
	assert_false(emitter.local_coords, "local_coords should be false so ash drifts in world space")
	assert_not_null(emitter.material_override, "Material override must be assigned")
	assert_not_null(emitter.process_material, "Process material must be assigned")
	assert_true(emitter.ember_color.r <= 0.05 and emitter.ember_color.g <= 0.05 and emitter.ember_color.b <= 0.05, "Ember color must be black")
	emitter.free()

	# Check player scene contains AshFallEmitter
	var player_packed = load("res://scenes/player.tscn") as PackedScene
	var player_node = player_packed.instantiate()
	var found_emitter = player_node.get_node_or_null("AshFallEmitter")
	assert_not_null(found_emitter, "Player scene must contain AshFallEmitter node")
	assert_true(found_emitter is AshFallEmitterClass, "Must be an instance of AshFallEmitter")
	player_node.free()
