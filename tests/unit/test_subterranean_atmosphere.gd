class_name TestSubterraneanAtmosphere
extends "res://tests/framework/test_case.gd"

## Unit test suite validating:
## 1. Exclusive underground Crimson Rot / Creature Stomach / Lake of Rot atmosphere.
## 2. Dynamic transition of WorldEnvironment, DirectionalLight3D, GraphicNovelPostProcess.
## 3. Disabling ember particles (AshFallEmitter) underground and re-enabling on surface.
## 4. Lake of Rot subterranean toon water configuration.
## 5. Crimson Rot strata palette horizons and cave material bindings.
## 6. End-to-end integration with MainScene.

const SubterraneanAtmosphereControllerClass = preload("res://src/rendering/subterranean_atmosphere_controller.gd")
const AshFallEmitterClass = preload("res://src/rendering/ash_fall_emitter.gd")
const TerrainMaterialProviderClass = preload("res://src/rendering/terrain_material_provider.gd")
const ToonWaterConfigClass = preload("res://src/rendering/toon_water_config.gd")
const StrataPaletteRegistryClass = preload("res://src/rendering/strata_palette_registry.gd")
const ContinentMapColorPaletteClass = preload("res://src/map/continent_map_color_palette.gd")

func test_strata_palette_registry_crimson_rot() -> void:
	var presets = StrataPaletteRegistryClass.get_presets(StrataPaletteRegistryClass.GROUP_ALIEN)
	assert_true(presets.has("crimson_rot"), "GROUP_ALIEN must contain 'crimson_rot' preset")

	var pal = StrataPaletteRegistryClass.get_palette(StrataPaletteRegistryClass.GROUP_ALIEN, "crimson_rot")
	assert_eq(pal.size(), 4, "Crimson rot palette must contain 4 horizon colors")
	for i in range(4):
		assert_true(pal[i].a >= 0.99, "Horizon color %d must be fully opaque" % i)
		assert_true(pal[i].r > pal[i].g and pal[i].r > pal[i].b, "Horizon color %d must be predominantly red" % i)

func test_cave_material_crimson_rot_theme() -> void:
	TerrainMaterialProviderClass.reset()
	var surf_mat = TerrainMaterialProviderClass.get_ascii_surface_material()
	var cave_mat = TerrainMaterialProviderClass.get_ascii_cave_material()

	assert_not_null(surf_mat, "Surface material must exist")
	assert_not_null(cave_mat, "Cave material must exist")

	# Cave material must have crimson rot strata colors assigned
	var s0 = cave_mat.get_shader_parameter("strata_color_0") as Color
	var s1 = cave_mat.get_shader_parameter("strata_color_1") as Color
	var s2 = cave_mat.get_shader_parameter("strata_color_2") as Color
	assert_true(s1.r > s1.g and s1.r > s1.b, "Cave strata_color_1 must be predominantly crimson red")
	assert_true(s2.r > s2.g and s2.r > s2.b, "Cave strata_color_2 must be predominantly scarlet red")

	# Cave material stains must be crimson rot themed
	var dark_stain = cave_mat.get_shader_parameter("stain_color_dark") as Color
	var rot_stain = cave_mat.get_shader_parameter("stain_color_green") as Color
	assert_true(rot_stain.r > rot_stain.g and rot_stain.r > rot_stain.b, "Cave rot stain must be scarlet red")
	assert_true(dark_stain.r > dark_stain.g and dark_stain.r > dark_stain.b, "Cave dark stain must be crimson tinted")

	# Cave mist color must be dark crimson rot
	var cave_mist = cave_mat.get_shader_parameter("mist_color") as Color
	assert_not_null(cave_mist, "Cave mist_color must be set")
	assert_true(cave_mist.r > cave_mist.g and cave_mist.r > cave_mist.b, "Cave mist must be crimson red")

	# Cave shadow tint must be crimson rot ambient red
	var surf_tint = surf_mat.get_shader_parameter("shadow_tint") as Color
	var cave_tint = cave_mat.get_shader_parameter("shadow_tint") as Color
	assert_true(cave_tint.r > 0.60 and cave_tint.g < 0.20, "Cave shadow tint must be crimson rot red")

	# Cave ink scratches enabled and valley mist disabled exclusively for cave
	assert_true(bool(cave_mat.get_shader_parameter("scratches_enabled")), "Cave scratches must be enabled")
	assert_true(float(cave_mat.get_shader_parameter("scratch_intensity")) >= 0.8, "Cave scratch intensity must be >= 0.8")
	var scratch_col = cave_mat.get_shader_parameter("scratch_color") as Color
	assert_not_null(scratch_col, "Cave scratch_color must be set")
	assert_true(scratch_col.r > scratch_col.g and scratch_col.r > scratch_col.b, "Cave scratch_color must be predominantly red")
	assert_true(scratch_col.r >= 0.45 and scratch_col.r <= 0.65, "Cave scratch_color must be milder crimson red (0.45 <= r <= 0.65)")
	assert_almost_eq(float(cave_mat.get_shader_parameter("valley_mist_strength")), 0.0, 0.01, "Cave valley mist must be disabled (0.0)")

	assert_false(bool(surf_mat.get_shader_parameter("scratches_enabled")), "Surface scratches must be disabled")
	assert_almost_eq(float(surf_mat.get_shader_parameter("valley_mist_strength")), 0.75, 0.01, "Surface valley mist must be 0.75")

	# Floor and ceiling rock ink streaks and stains suppressed (norm.y > 0.4 || norm.y < -0.4) and crimson red styling with sparse ASCII highlight
	assert_true(cave_mat.shader.code.contains("norm.y > 0.4"), "Cave shader must suppress ink scratches on upward floor faces (norm.y > 0.4)")
	assert_true(cave_mat.shader.code.contains("norm.y < -0.4"), "Cave shader must suppress ink scratches and streaks on bottom-facing ceiling (norm.y < -0.4)")
	assert_true(cave_mat.shader.code.contains("scratches_enabled && (norm.y > 0.4 || norm.y < -0.4)"), "Cave shader must suppress stains on horizontal faces")
	assert_true(cave_mat.shader.code.contains("mix(strata_color_1.rgb, strata_color_2.rgb, 0.45)"), "Cave shader must compute crimson red for top-facing floor rock")
	assert_true(cave_mat.shader.code.contains("ground_col * (1.0 + eff_contrast * 0.75)"), "Cave shader must apply ASCII texture highlight to floor rock")
	assert_true(cave_mat.shader.code.contains("jitter < 0.75"), "Cave shader must sparsely distribute floor ASCII characters")
	assert_true(cave_mat.shader.code.contains("glyphs_per_voxel * 0.5"), "Cave shader must widen floor ASCII cell spacing for sparse readability")
	assert_true(cave_mat.shader.code.contains("mix(strata_color_0.rgb, strata_color_1.rgb, 0.55)"), "Cave shader must compute subterranean strata mix")

func test_lake_of_rot_subterranean_water() -> void:
	var cfg = ToonWaterConfigClass.create_subterranean_config()
	assert_not_null(cfg, "Subterranean water config must exist")

	# Must be rich red/scarlet rot fluid
	assert_true(cfg.shallow_color.r > cfg.shallow_color.g and cfg.shallow_color.r > cfg.shallow_color.b,
		"Lake of Rot shallow water must be red")
	assert_true(cfg.mid_color.r > cfg.mid_color.g and cfg.mid_color.r > cfg.mid_color.b,
		"Lake of Rot mid water must be crimson red")
	assert_true(cfg.deep_color.r >= cfg.deep_color.g and cfg.deep_color.r >= cfg.deep_color.b,
		"Lake of Rot deep water must be clotted rot red")
	assert_true(cfg.deep_color.v < 0.15, "Deep subterranean color must be dark ink (v < 0.15)")

	# Foam and ripples must reflect rot
	assert_true(cfg.foam_color.r > cfg.foam_color.g, "Foam color must have pinkish rot tint")
	assert_true(cfg.ripple_color.r > cfg.ripple_color.g, "Ripple color must be scarlet")

func test_continent_map_underground_rot_palette() -> void:
	var pal = ContinentMapColorPaletteClass.new()
	assert_true(pal.color_arena_floor.r > pal.color_arena_floor.g, "Arena floor must be red crimson rot")
	assert_true(pal.color_subterranean_water.r > pal.color_subterranean_water.g, "Subterranean water must be crimson rot")
	assert_true(pal.color_chasm_floor.r > pal.color_chasm_floor.g, "Chasm floor must have rot tint")

func test_subterranean_atmosphere_controller_transitions() -> void:
	var main_packed = load("res://scenes/main.tscn") as PackedScene
	assert_not_null(main_packed, "Main scene must load")
	var main_node = main_packed.instantiate()
	assert_not_null(main_node, "Main scene must instantiate")

	var world_env = main_node.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var light = main_node.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	var post = main_node.get_node_or_null("GraphicNovelPostProcess") as GraphicNovelPostProcess
	var controller = main_node.get_node_or_null("SubterraneanAtmosphereController")
	var player_node = main_node.get_node_or_null("Player")
	var emitter = player_node.get_node_or_null("AshFallEmitter")
	var rot_fog = player_node.get_node_or_null("RotFogVolume") as FogVolume

	assert_not_null(controller, "SubterraneanAtmosphereController must exist in main scene")
	assert_not_null(emitter, "AshFallEmitter must exist on player")
	assert_not_null(rot_fog, "RotFogVolume must exist on player")

	controller._capture_surface_baseline()
	controller.ash_emitter = emitter
	controller.rot_fog_volume = rot_fog

	# 1. Switch to UNDERGROUND mode
	controller.set_underground_mode(true, true)
	assert_true(controller.is_underground, "Controller must be in underground mode")
	assert_almost_eq(controller.transition_progress, 1.0, 0.01, "Progress must be 1.0")

	# WorldEnvironment in underground rot mode:
	var env = world_env.environment
	assert_true(env.ambient_light_color.r > 0.40 and env.ambient_light_color.g < 0.15,
		"Underground ambient light must be crimson rot")
	assert_true(env.fog_light_color.r > env.fog_light_color.g,
		"Underground fog light must be crimson red")
	assert_true(env.volumetric_fog_albedo.r > 0.55 and env.volumetric_fog_albedo.g < 0.20,
		"Underground volumetric fog albedo must be scarlet rot")
	assert_true(env.volumetric_fog_emission.r > env.volumetric_fog_emission.g,
		"Underground volumetric fog emission must have organic rot glow")
	assert_almost_eq(env.fog_height_density, 0.0, 0.001,
		"Underground height fog density must be 0.0 to prevent obscuring cavern surfaces")
	assert_true(env.fog_depth_begin >= 30.0,
		"Underground fog depth begin must be >= 30.0m to keep local cavern clear")
	# Option A: Global volumetric fog density underground is 0.0 so distant structures are clear
	assert_almost_eq(env.volumetric_fog_density, 0.0, 0.001,
		"Underground global volumetric fog density must be 0.0 so distant cavern structures remain clear")

	# Option A: Local RotFogVolume attached to player exclusively active underground
	assert_true(rot_fog.visible, "RotFogVolume must be visible underground")
	assert_eq(rot_fog.shape, RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID, "RotFogVolume shape must be Ellipsoid")
	var fm = rot_fog.material as FogMaterial
	assert_not_null(fm, "RotFogVolume must use FogMaterial")
	assert_true(fm.density >= 0.15, "RotFogVolume density must be rich local crimson mist (>= 0.15)")
	assert_true(fm.albedo.r > fm.albedo.g and fm.albedo.r > fm.albedo.b, "RotFogVolume albedo must be crimson red")
	assert_true(fm.emission.r > fm.emission.g, "RotFogVolume emission must have crimson organic glow")
	assert_almost_eq(fm.edge_fade, 0.40, 0.05, "RotFogVolume edge_fade must be soft feathering (~0.40)")

	# Sky in underground mode:
	var sm = env.sky.sky_material as ShaderMaterial
	var sky_mid = sm.get_shader_parameter("sky_mid_color") as Color
	assert_true(sky_mid.r > sky_mid.g and sky_mid.r > sky_mid.b, "Underground sky mid must be crimson")
	assert_false(bool(sm.get_shader_parameter("sun_enabled")), "Sun must be disabled in underground void")

	# Directional light in underground mode:
	assert_true(light.light_color.r > light.light_color.g and light.light_color.r > light.light_color.b,
		"Directional light must be crimson tinted underground")

	# Post-process vignette and neon geometry outline in underground mode:
	var pm = post.post_material
	var vig_col = pm.get_shader_parameter("vignette_color") as Color
	assert_true(vig_col.r > vig_col.g and vig_col.r > 0.20, "Vignette must be deep crimson rot")
	var ug_outline = pm.get_shader_parameter("outline_color") as Color
	assert_true(ug_outline.r > 0.8 and ug_outline.g < 0.2, "Underground outline must keep vivid neon red highlight")

	# AshFallEmitter ember particles: MUST BE DISABLED underground
	assert_false(emitter.emitting, "Ember particles must NOT be emitting underground")
	assert_false(emitter.visible, "Ash fall emitter must NOT be visible underground")

	# 2. Switch back to SURFACE mode
	controller.set_underground_mode(false, true)
	assert_false(controller.is_underground, "Controller must be in surface mode")
	assert_almost_eq(controller.transition_progress, 0.0, 0.01, "Progress must be 0.0")

	var surf_outline = pm.get_shader_parameter("outline_color") as Color
	assert_true(surf_outline.r < 0.2, "Surface outline must revert to dark comic ink")

	# Ambient light must return to surface green-grey
	assert_true(env.ambient_light_color.g >= env.ambient_light_color.r,
		"Surface ambient light must return to original green-grey desolate tone")
	assert_almost_eq(env.fog_height_density, 0.15, 0.01,
		"Surface fog height density must be restored")
	assert_almost_eq(env.fog_depth_begin, 10.0, 0.01,
		"Surface fog depth begin must be restored")
	assert_true(bool(sm.get_shader_parameter("sun_enabled")), "Sun must be re-enabled on surface")

	# AshFallEmitter ember particles: MUST BE RE-ENABLED on surface
	assert_true(emitter.emitting, "Ember particles must be re-enabled on surface")
	assert_true(emitter.visible, "Ash fall emitter must be visible on surface")

	# RotFogVolume local fog: MUST BE INACTIVE on surface
	assert_false(rot_fog.visible, "RotFogVolume must NOT be visible on surface")
	assert_almost_eq(fm.density, 0.0, 0.001, "RotFogVolume density must be 0.0 on surface")
	assert_almost_eq(env.volumetric_fog_density, controller._surface_vol_fog_density, 0.005,
		"Surface global volumetric fog must be restored")

	main_node.free()

