class_name TestBushFoliage
extends "res://tests/framework/test_case.gd"

## Unit tests validating procedural bush scattering, LOD transitions, MultiMesh pooling, and material caching.

const FoliageChunkDataClass = preload("res://src/core/foliage_chunk_data.gd")
const FoliageConfigClass = preload("res://src/generation/foliage_generator_config.gd")
const FoliageGeneratorClass = preload("res://src/generation/foliage_generator.gd")
const ChunkNodeClass = preload("res://src/world/chunk_node.gd")
const FoliageProviderClass = preload("res://src/rendering/foliage_material_provider.gd")
const TerrainMaterialProviderClass = preload("res://src/rendering/terrain_material_provider.gd")

func before_each() -> void:
	FoliageProviderClass.reset()
	TerrainMaterialProviderClass.reset()

func after_each() -> void:
	FoliageProviderClass.reset()
	TerrainMaterialProviderClass.reset()

func test_bush_models_and_textures_exist() -> void:
	assert_true(ResourceLoader.exists("res://assets/textures/bush.png"), "bush.png texture must exist")
	assert_true(ResourceLoader.exists("res://assets/models/bush.tres"), "bush.tres mesh must exist")
	assert_true(ResourceLoader.exists("res://assets/models/bush_lod.tres"), "bush_lod.tres mesh must exist")

	var high_mesh = load("res://assets/models/bush.tres") as Mesh
	assert_not_null(high_mesh, "High detail bush mesh must load")
	assert_true(high_mesh.get_surface_count() > 0, "High detail bush mesh must have surfaces")

	var lod_mesh = load("res://assets/models/bush_lod.tres") as Mesh
	assert_not_null(lod_mesh, "LOD bush mesh must load")
	assert_true(lod_mesh.get_surface_count() > 0, "LOD bush mesh must have surfaces")

func test_bush_scatter_generation_and_toggling() -> void:
	var gen = FoliageGeneratorClass.new()
	var coord = ChunkCoord.new(2, 3)
	var s_data = SurfaceChunkData.new(16, 2)
	s_data.fill(20, MaterialDef.ID_GRASS, MaterialDef.ID_DIRT)

	var cfg = FoliageConfigClass.new()
	cfg.bushes_enabled = true
	cfg.bush_density_probability = 0.5 # High probability for testing
	cfg.world_seed = 424242

	var res = gen.generate(coord, s_data, cfg)
	assert_true(res.bush_instance_count > 0, "Should generate bush instances when bushes_enabled is true")
	assert_eq(res.bush_transform_buffer.size(), res.bush_instance_count * 12, "Bush buffer size must match bush_count * 12 floats")

	# Disable bushes
	cfg.bushes_enabled = false
	var res_no_bushes = gen.generate(coord, s_data, cfg)
	assert_eq(res_no_bushes.bush_instance_count, 0, "Should generate 0 bushes when bushes_enabled is false")
	assert_eq(res_no_bushes.bush_transform_buffer.size(), 0, "Bush buffer must be empty when bushes are disabled")
	assert_true(res_no_bushes.instance_count > 0, "Grass instances should still generate when only bushes are disabled")

func test_bush_determinism() -> void:
	var gen = FoliageGeneratorClass.new()
	var coord = ChunkCoord.new(-4, 7)
	var s_data = SurfaceChunkData.new(16, 2)
	s_data.fill(25, MaterialDef.ID_GRASS, MaterialDef.ID_DIRT)

	var cfg = FoliageConfigClass.new()
	cfg.bushes_enabled = true
	cfg.bush_density_probability = 0.4
	cfg.world_seed = 88123

	var run1 = gen.generate(coord, s_data, cfg)
	var run2 = gen.generate(coord, s_data, cfg)

	assert_eq(run1.bush_instance_count, run2.bush_instance_count, "Bush instance count must be deterministic")
	assert_eq(run1.bush_transform_buffer.size(), run2.bush_transform_buffer.size(), "Bush buffer length must be identical")

	var identical: bool = true
	for i in range(run1.bush_transform_buffer.size()):
		if not is_equal_approx(run1.bush_transform_buffer[i], run2.bush_transform_buffer[i]):
			identical = false
			break
	assert_true(identical, "Bush transform buffer contents must be identical across deterministic runs")

func test_bush_transform_bounds_and_height() -> void:
	var gen = FoliageGeneratorClass.new()
	var coord = ChunkCoord.new(0, 0)
	var s_data = SurfaceChunkData.new(8, 2)
	for lz in range(8):
		for lx in range(8):
			s_data.set_height(lx, lz, 15 + lz)
			s_data.set_top_material(lx, lz, MaterialDef.ID_GRASS)

	var cfg = FoliageConfigClass.new()
	cfg.bushes_enabled = true
	cfg.bush_density_probability = 1.0 # Guarantee spawn on every column

	var res = gen.generate(coord, s_data, cfg)
	assert_true(res.bush_instance_count > 0, "Must generate bush instances")

	for i in range(res.bush_instance_count):
		var t = res.get_bush_instance_transform(i)
		assert_true(t.origin.x >= 0.0, "Bush origin X must be >= 0")
		assert_true(t.origin.x <= 8.0, "Bush origin X must be <= chunk_size")
		assert_true(t.origin.z >= 0.0, "Bush origin Z must be >= 0")
		assert_true(t.origin.z <= 8.0, "Bush origin Z must be <= chunk_size")

		var col_x = clampi(int(floor(t.origin.x)), 0, 7)
		var col_z = clampi(int(floor(t.origin.z)), 0, 7)
		var expected_h = float(s_data.get_height(col_x, col_z))
		assert_eq(t.origin.y, expected_h, "Bush origin Y must match column height")

func test_bush_chunk_node_pooling_and_distance_gating() -> void:
	var node = ChunkNodeClass.new()
	node._ensure_nodes_exist()

	assert_not_null(node.bush_instance, "ChunkNode must possess bush_instance MultiMeshInstance3D")
	assert_not_null(node.bush_instance.multimesh, "bush_instance must have MultiMesh allocated")
	assert_eq(node.bush_instance.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Bush shadows must be disabled")
	assert_false(node.bush_instance.visible, "Bush instance should start hidden")

	# Setup with sample foliage data containing bushes
	var gen = FoliageGeneratorClass.new()
	var coord = ChunkCoord.new(0, 0)
	var s_data = SurfaceChunkData.new(8, 2)
	s_data.fill(20, MaterialDef.ID_GRASS, MaterialDef.ID_DIRT)

	var cfg = FoliageConfigClass.new()
	cfg.bushes_enabled = true
	cfg.bush_density_probability = 1.0

	var m_data = MeshData.new()
	m_data.vertices = PackedVector3Array([Vector3(0, 20, 0), Vector3(1, 20, 0), Vector3(0, 20, 1)])
	m_data.indices = PackedInt32Array([0, 1, 2])
	m_data.foliage_data = gen.generate(coord, s_data, cfg)

	node.setup(coord, Vector3.ZERO, m_data, true, null, null, true, false)
	assert_true(node.bush_instance.visible, "Bush MultiMeshInstance3D must be visible when foliage enabled")
	assert_true(node.bush_instance.multimesh.instance_count > 0, "Bush multimesh instance count must match bush data")

	# Distance gate off
	node.set_foliage_enabled(false)
	assert_false(node.bush_instance.visible, "Bush instance must be hidden when distance gated off")

	# Distance gate on
	node.set_foliage_enabled(true)
	assert_true(node.bush_instance.visible, "Bush instance must be visible when gated back on")

	# Pool reset
	node.prepare_for_pool()
	assert_false(node.bush_instance.visible, "Bush instance must be hidden in pool")
	assert_eq(node.bush_instance.multimesh.instance_count, 0, "Bush instance count must be 0 in pool")

	node.free()

func test_bush_lod_detail_transition() -> void:
	var node = ChunkNodeClass.new()
	var gen = FoliageGeneratorClass.new()
	var coord = ChunkCoord.new(0, 0)
	var s_data = SurfaceChunkData.new(8, 2)
	s_data.fill(20, MaterialDef.ID_GRASS, MaterialDef.ID_DIRT)

	var cfg = FoliageConfigClass.new()
	cfg.bushes_enabled = true
	cfg.bush_density_probability = 1.0

	var m_data = MeshData.new()
	m_data.vertices = PackedVector3Array([Vector3(0, 20, 0), Vector3(1, 20, 0), Vector3(0, 20, 1)])
	m_data.indices = PackedInt32Array([0, 1, 2])
	m_data.foliage_data = gen.generate(coord, s_data, cfg)
	var total_bushes = m_data.foliage_data.bush_instance_count

	# Near / High detail
	node.setup(coord, Vector3.ZERO, m_data, true, null, null, true, false)
	assert_eq(node.bush_instance.multimesh.mesh, ChunkNodeClass.get_shared_bush_mesh(), "Must use high-detail bush mesh")
	assert_eq(node.bush_instance.multimesh.visible_instance_count, -1, "High detail must draw all bushes")

	# Far / Low detail LOD
	node.set_foliage_enabled(true, true)
	assert_eq(node.bush_instance.multimesh.mesh, ChunkNodeClass.get_shared_bush_mesh_lod(), "Must switch to LOD bush mesh")
	var expected_lod_count = maxi(1, int(float(total_bushes) * ChunkNodeClass.get_shared_lod_density()))
	assert_eq(node.bush_instance.multimesh.visible_instance_count, expected_lod_count, "LOD tier must subsample bush count")

	node.free()

func test_bush_material_provider_and_delegation() -> void:
	var mat1 = FoliageProviderClass.get_bush_material()
	assert_not_null(mat1, "FoliageProvider must return bush material")
	assert_true(mat1 is ShaderMaterial, "Bush material must be ShaderMaterial")

	var mat2 = FoliageProviderClass.get_bush_material()
	assert_eq(mat1, mat2, "Provider must return cached bush material on repeated calls")

	var del_mat = TerrainMaterialProviderClass.get_bush_material()
	assert_not_null(del_mat, "TerrainMaterialProvider must delegate get_bush_material")
	assert_eq(mat1, del_mat, "Delegated material must match FoliageProvider instance")

	FoliageProviderClass.reset()
	var mat3 = FoliageProviderClass.get_bush_material()
	assert_ne(mat1, mat3, "Provider reset must create a fresh bush material instance")

