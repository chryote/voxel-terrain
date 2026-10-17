class_name TestDualMeshPipeline
extends "res://tests/framework/test_case.gd"

## Unit test suite validating Phase 1: Dual-Mesh Pipeline & Shadow Map Fix.
## Verifies that surface and subterranean cave geometry are physically decoupled,
## cave shadow casting is disabled, and layer visibility gating operates correctly.

func test_dual_mesh_bundle_properties() -> void:
	var bundle = DualMeshBundle.new()
	assert_true(bundle.is_empty(), "Fresh bundle should be empty")
	assert_false(bundle.has_cave_geometry(), "Fresh bundle should not have cave geometry")
	assert_eq(bundle.get_total_triangle_count(), 0)

	# Populate dummy surface vertices
	bundle.vertices.append(Vector3(0, 0, 0))
	bundle.vertices.append(Vector3(1, 0, 0))
	bundle.vertices.append(Vector3(0, 0, 1))
	bundle.indices.append(0)
	bundle.indices.append(1)
	bundle.indices.append(2)

	assert_false(bundle.is_empty(), "Bundle with surface vertices should not be empty")
	assert_eq(bundle.get_surface_triangle_count(), 1)
	assert_eq(bundle.get_cave_triangle_count(), 0)
	assert_eq(bundle.get_total_triangle_count(), 1)

	# Populate dummy cave vertices
	bundle.cave_mesh_data.vertices.append(Vector3(0, -10, 0))
	bundle.cave_mesh_data.vertices.append(Vector3(1, -10, 0))
	bundle.cave_mesh_data.vertices.append(Vector3(0, -10, 1))
	bundle.cave_mesh_data.indices.append(0)
	bundle.cave_mesh_data.indices.append(1)
	bundle.cave_mesh_data.indices.append(2)

	assert_true(bundle.has_cave_geometry(), "Bundle with cave vertices must report has_cave_geometry")
	assert_eq(bundle.get_cave_triangle_count(), 1)
	assert_eq(bundle.get_total_triangle_count(), 2)
	assert_eq(bundle.get_total_vertex_count(), 6)

func test_voxel_mesher_decouples_surface_and_caves() -> void:
	var bounds = WorldBounds.new(Vector2i(64, 64), 32, 1.0)
	var reg = MaterialRegistry.create_default_registry()
	var vol_gen = VolumetricTerrainGenerator.new(1337)
	var mesher = VoxelMesher.new()

	var data = vol_gen.generate(ChunkCoord.new(0, 0), bounds)
	var result = mesher.build_mesh(data, reg)

	assert_true(result is DualMeshBundle, "VoxelMesher must return a DualMeshBundle")
	var bundle: DualMeshBundle = result as DualMeshBundle

	assert_true(bundle.has_cave_geometry(), "Volumetric chunk with caves must contain cave geometry in bundle")
	var s_tris = bundle.get_surface_triangle_count()
	var c_tris = bundle.get_cave_triangle_count()

	assert_true(s_tris > 0, "Surface mesh must have triangles (found: %d)" % s_tris)
	assert_true(c_tris > 0, "Cave mesh must have triangles (found: %d)" % c_tris)

	# Major optimization verification: cave triangles should constitute > 50% of the chunk
	assert_true(c_tris > s_tris, "Subterranean cave triangles (%d) should outnumber surface triangles (%d)" % [c_tris, s_tris])

func test_chunk_node_dual_instances_and_shadow_isolation() -> void:
	var chunk_node = ChunkNode.new()
	var bundle = DualMeshBundle.new()

	# 1 surface triangle
	bundle.vertices.append(Vector3(0, 0, 0))
	bundle.vertices.append(Vector3(1, 0, 0))
	bundle.vertices.append(Vector3(0, 0, 1))
	bundle.indices.append(0)
	bundle.indices.append(1)
	bundle.indices.append(2)

	# 1 cave triangle
	bundle.cave_mesh_data.vertices.append(Vector3(0, -10, 0))
	bundle.cave_mesh_data.vertices.append(Vector3(1, -10, 0))
	bundle.cave_mesh_data.vertices.append(Vector3(0, -10, 1))
	bundle.cave_mesh_data.indices.append(0)
	bundle.cave_mesh_data.indices.append(1)
	bundle.cave_mesh_data.indices.append(2)

	# 1 cave water triangle
	bundle.cave_mesh_data.water_mesh_data = MeshData.new()
	bundle.cave_mesh_data.water_mesh_data.vertices.append(Vector3(0, -12, 0))
	bundle.cave_mesh_data.water_mesh_data.vertices.append(Vector3(1, -12, 0))
	bundle.cave_mesh_data.water_mesh_data.vertices.append(Vector3(0, -12, 1))
	bundle.cave_mesh_data.water_mesh_data.indices.append(0)
	bundle.cave_mesh_data.water_mesh_data.indices.append(1)
	bundle.cave_mesh_data.water_mesh_data.indices.append(2)

	chunk_node.setup(ChunkCoord.new(0, 0), Vector3.ZERO, bundle, true)

	assert_not_null(chunk_node.mesh_instance.mesh, "Surface mesh must be assigned")
	assert_not_null(chunk_node.cave_mesh_instance.mesh, "Cave mesh must be assigned")
	assert_not_null(chunk_node.cave_water_instance, "Cave water instance must be created")
	var c_water_mat: StandardMaterial3D = chunk_node.cave_water_instance.material_override as StandardMaterial3D
	assert_not_null(c_water_mat, "Cave water material must be assigned")
	assert_eq(c_water_mat.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, "Subterranean water must use alpha scissor to prevent deep depth-sorting stalls")
	assert_eq(c_water_mat.depth_draw_mode, BaseMaterial3D.DEPTH_DRAW_ALWAYS, "Subterranean water must write to depth buffer to prevent overdraw behind rock")

	# Shadow isolation check: surface must cast shadows, cave must NOT cast shadows
	assert_eq(chunk_node.mesh_instance.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "Surface mesh must cast shadows")
	assert_eq(chunk_node.cave_mesh_instance.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Cave mesh MUST NOT cast directional shadows")

	# Default subterranean visibility
	assert_false(chunk_node.is_subterranean_visible(), "Subterranean mesh must be hidden by default on surface")

	chunk_node.set_subterranean_visible(true)
	assert_true(chunk_node.is_subterranean_visible(), "set_subterranean_visible(true) must toggle visibility")

	chunk_node.set_subterranean_visible(false)
	assert_false(chunk_node.is_subterranean_visible(), "set_subterranean_visible(false) must hide cave mesh")

	chunk_node.free()

func test_layer_visibility_coordinator_transitions() -> void:
	var coordinator = LayerVisibilityCoordinator.new()
	var node_surf = ChunkNode.new()
	var node_mouth = ChunkNode.new()

	var bundle_surf = DualMeshBundle.new()
	bundle_surf.has_cave_mouth = false
	bundle_surf.cave_mesh_data.vertices.append(Vector3(0, 0, 0))
	bundle_surf.cave_mesh_data.indices.append(0)
	node_surf.setup(ChunkCoord.new(0, 0), Vector3.ZERO, bundle_surf, false)

	var bundle_mouth = DualMeshBundle.new()
	bundle_mouth.has_cave_mouth = true
	bundle_mouth.cave_mesh_data.vertices.append(Vector3(0, 0, 0))
	bundle_mouth.cave_mesh_data.indices.append(0)
	node_mouth.setup(ChunkCoord.new(5, 5), Vector3(160, 0, 160), bundle_mouth, false)

	var loaded = {
		node_surf.coord.to_key(): node_surf,
		node_mouth.coord.to_key(): node_mouth
	}
	var mouth_cache = {
		node_surf.coord.to_key(): false,
		node_mouth.coord.to_key(): true
	}

	# 1. Player is on surface at (0, 40, 0), surface height is 40.0
	var state = coordinator.update_chunk_visibility(
		Vector3(0, 40, 0),
		node_surf.coord,
		40.0,
		loaded,
		mouth_cache,
		true
	)
	assert_eq(state, LayerVisibilityCoordinator.PlayerLayerState.SURFACE)
	assert_false(node_surf.is_subterranean_visible(), "Surface chunk without mouth must have subterranean mesh hidden")
	assert_true(node_mouth.is_subterranean_visible(), "Chunk with cave mouth must have subterranean mesh visible")

	# 2. Player descends underground at (0, 15, 0), surface height is 40.0
	state = coordinator.update_chunk_visibility(
		Vector3(0, 15, 0),
		node_surf.coord,
		40.0,
		loaded,
		mouth_cache,
		true
	)
	assert_eq(state, LayerVisibilityCoordinator.PlayerLayerState.SUBTERRANEAN)
	assert_true(node_surf.is_subterranean_visible(), "When subterranean, all loaded cave meshes must be visible")
	assert_true(node_mouth.is_subterranean_visible())

	node_surf.free()
	node_mouth.free()
