class_name TestPollutionSmog
extends "res://tests/framework/test_case.gd"

## Unit tests validating low-overhead ground pollution smog, particle emission, and environmental fog.

const EmitterClass = preload("res://src/rendering/pollution_smog_emitter.gd")

func test_smog_emitter_creation_and_defaults() -> void:
	var emitter = EmitterClass.new()
	assert_not_null(emitter, "PollutionSmogEmitter should instantiate cleanly")
	emitter._ready()

	assert_true(emitter.amount <= 160, "Particle count must be economical (<= 160) for cheap performance")
	assert_almost_eq(emitter.lifetime, 6.0, 0.1, "Lifetime should be around 6.0 seconds")
	assert_false(emitter.local_coords, "local_coords should be false so smoke puffs drift across world space")
	assert_not_null(emitter.draw_pass_1, "Draw pass mesh should be assigned")
	assert_not_null(emitter.material_override, "Material override should be assigned")
	assert_not_null(emitter.process_material, "Process material should be assigned")

	emitter.free()

func test_smog_material_properties() -> void:
	var mat = EmitterClass.create_smog_material()
	assert_not_null(mat, "Material must be generated")
	assert_true(mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "Smog material should be unshaded for cheap rendering")
	assert_true(mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "Smog material should use alpha transparency")
	assert_true(mat.billboard_mode == BaseMaterial3D.BILLBOARD_PARTICLES, "Particles should billboard toward camera")
	assert_true(mat.proximity_fade_enabled, "Proximity fade must be enabled to softly blend against terrain voxels")
	assert_almost_eq(mat.proximity_fade_distance, 0.8, 0.05, "Proximity fade distance should be around 0.8m")
	assert_not_null(mat.albedo_texture, "Radial puff texture should be assigned")

func test_smog_puff_texture() -> void:
	var tex = EmitterClass.create_smoke_puff_texture()
	assert_not_null(tex, "Radial puff texture should generate")
	assert_eq(tex.width, 64, "Puff texture width should be 64")
	assert_eq(tex.height, 64, "Puff texture height should be 64")
	assert_eq(tex.fill, GradientTexture2D.FILL_RADIAL, "Texture fill must be radial")

func test_smog_process_material() -> void:
	var pmat = EmitterClass.create_process_material(Vector3(30, 4, 30), Vector3(1, 0, 0), 1.0)
	assert_not_null(pmat, "Process material must generate")
	assert_eq(pmat.emission_shape, ParticleProcessMaterial.EMISSION_SHAPE_BOX, "Emission shape should be box")
	assert_almost_eq(pmat.emission_box_extents.x, 30.0, 0.1, "Box extents X should match")
	assert_not_null(pmat.color_ramp, "Color ramp for alpha fade-in/fade-out must be bound")

func test_main_scene_environmental_fog() -> void:
	var main_packed = load("res://scenes/main.tscn") as PackedScene
	assert_not_null(main_packed, "Main scene must load")
	var main_node = main_packed.instantiate()
	assert_not_null(main_node, "Main scene must instantiate")

	var world_env = main_node.get_node_or_null("WorldEnvironment") as WorldEnvironment
	assert_not_null(world_env, "WorldEnvironment must exist in main scene")
	assert_not_null(world_env.environment, "Environment resource must exist")
	assert_true(world_env.environment.fog_enabled, "Ground fog must be enabled for surface smog")
	assert_almost_eq(world_env.environment.fog_height, 24.0, 0.1, "Ground fog height should be configured for low-lying terrain smog")

	main_node.free()

func test_player_scene_contains_smog_emitter() -> void:
	var player_packed = load("res://scenes/player.tscn") as PackedScene
	assert_not_null(player_packed, "Player scene must load")
	var player_node = player_packed.instantiate()
	assert_not_null(player_node, "Player scene must instantiate")

	var emitter = player_node.get_node_or_null("PollutionSmogEmitter")
	assert_not_null(emitter, "Player scene must contain PollutionSmogEmitter")
	assert_true(emitter is EmitterClass, "PollutionSmogEmitter must be an instance of PollutionSmogEmitter")

	player_node.free()

