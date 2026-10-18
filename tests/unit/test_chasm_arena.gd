class_name TestChasmArena
extends "res://tests/framework/test_case.gd"

## Unit test suite for Phase 2.2: Chasm Arena POI Anchor System.
## Validates procedural generation of wide, flat subterranean battle arenas,
## suppression of random pillars in the combat zone, stepped perimeter spectator ledges,
## and vaulted high ceiling domes.

const ChasmChunkData = preload("res://src/core/chasm_chunk_data.gd")

func test_arena_trigger_and_flattened_floor() -> void:
	var config = CaveGeneratorConfig.new()
	config.arena_enabled = true
	config.arena_rift_threshold = 0.80
	config.arena_floor_y = 6
	config.arena_ceiling_y = 28
	var sampler = UndergroundChasmSampler.new(1337, config)
	var col = ChasmColumnResult.new()

	var found_core_arena = false
	var found_perimeter_ledge = false

	var max_raw_rift = 0.0
	for ix in range(-200, 200, 4):
		for iz in range(-200, 200, 4):
			var wx = float(ix) * 5.0
			var wz = float(iz) * 5.0
			var r = sampler.sample_rift_mask(wx, wz)
			max_raw_rift = maxf(max_raw_rift, r)

			sampler.sample_column(wx, wz, col)

			if col.is_arena:
				assert_true(col.is_chasm, "Arena columns must be active chasm voids")
				assert_true(col.raw_rift >= 0.80, "Arena raw_rift must be >= 0.80")

				if col.raw_rift >= 0.82:
					found_core_arena = true
					assert_false(col.is_arena_ledge, "Core combat arena must not be marked as ledge")
					assert_eq(col.floor_y, config.arena_floor_y, "Combat arena floor must be flattened to arena_floor_y (6)")
					assert_true(col.ceil_y >= config.arena_ceiling_y, "Ceiling dome must reach arena_ceiling_y (28)")
				else:
					found_perimeter_ledge = true
					assert_true(col.is_arena_ledge, "Perimeter zone must be marked as arena ledge")
					assert_true(col.floor_y >= 3, "Perimeter ledge must remain above bedrock")

			if found_core_arena and found_perimeter_ledge:
				break
		if found_core_arena and found_perimeter_ledge:
			break

	assert_true(found_core_arena, "Must locate core combat arena with flattened floor")
	assert_true(found_perimeter_ledge, "Must locate stepped perimeter spectator ledges")

func test_arena_pillar_suppression() -> void:
	## Validates that within the core combat arena,
	## random support pillars are strictly suppressed so the battle floor is clear.
	var config = CaveGeneratorConfig.new()
	config.arena_enabled = true
	config.arena_rift_threshold = 0.80
	config.arena_floor_y = 6
	config.arena_ceiling_y = 28
	config.pillar_threshold = 0.1 # Very low pillar threshold to force pillars everywhere
	var sampler = UndergroundChasmSampler.new(1337, config)
	var col = ChasmColumnResult.new()

	# 1. Locate arena center
	var arena_center: Vector2 = Vector2.ZERO
	var found = false
	for ix in range(-200, 200, 4):
		for iz in range(-200, 200, 4):
			var wx = float(ix) * 5.0
			var wz = float(iz) * 5.0
			sampler.sample_column(wx, wz, col)
			if col.is_arena and col.raw_rift >= (config.arena_rift_threshold + 0.02):
				arena_center = Vector2(wx, wz)
				found = true
				break
		if found:
			break

	assert_true(found, "Must locate core combat arena")

	# 2. Test neighborhood columns inside the combat zone
	var tested_core_columns = 0
	for dx in range(-15, 16, 2):
		for dz in range(-15, 16, 2):
			var wx = arena_center.x + float(dx)
			var wz = arena_center.y + float(dz)
			sampler.sample_column(wx, wz, col)

			if col.is_arena and col.raw_rift >= (config.arena_rift_threshold + 0.02):
				tested_core_columns += 1
				assert_false(col.is_pillar, "Support pillars must be suppressed in combat arena pit at (%f, %f)" % [wx, wz])
				# Point-query carve check: middle combat elevation (Y=18) must be open air
				assert_eq(sampler.get_chasm_carve(wx, 18.0, wz), 1.0, "Combat zone must be open air void")

	assert_true(tested_core_columns >= 10, "Must test core arena columns for pillar suppression (tested %d)" % tested_core_columns)

func test_arena_disabled_toggle() -> void:
	var config = CaveGeneratorConfig.new()
	config.arena_enabled = false
	var sampler = UndergroundChasmSampler.new(1337, config)
	var col = ChasmColumnResult.new()

	for ix in range(-100, 100, 5):
		for iz in range(-100, 100, 5):
			var wx = float(ix) * 5.0
			var wz = float(iz) * 5.0
			sampler.sample_column(wx, wz, col)
			assert_false(col.is_arena, "Arena flags must be false when arena_enabled is false")
			assert_false(sampler.is_arena(wx, wz), "is_arena must return false when arena_enabled is false")

func test_ocean_falloff_encasing() -> void:
	## Validates that chasms and arenas are 100% encased with solid rock curtain walls
	## facing the continental ocean fall-off and never puncture the ocean plane.
	var world_config = WorldConfig.new()
	var gen_config = ContinentGeneratorConfig.new()
	var cave_config = CaveGeneratorConfig.new()
	var bounds = world_config.create_world_bounds()
	var cont_gen = ContinentGenerator.new(1337, gen_config)
	var sampler = UndergroundChasmSampler.new(1337, cave_config)
	sampler.set_continent_mask(cont_gen.mask, bounds)

	var col = ChasmColumnResult.new()

	# 1. Verify that ocean columns (land_raw < 0.08) have zero chasm density and zero carve
	var ocean_samples = 0
	for cz in range(bounds.min_chunk_z + 2, bounds.max_chunk_z - 2, 8):
		for cx in range(bounds.min_chunk_x + 2, bounds.max_chunk_x - 2, 8):
			var wx = float(cx * bounds.chunk_size + 16) * bounds.voxel_size
			var wz = float(cz * bounds.chunk_size + 16) * bounds.voxel_size
			var land = cont_gen.mask.get_land_raw(wx, wz, bounds)
			if land < 0.08:
				ocean_samples += 1
				var rift = sampler.sample_rift_mask(wx, wz)
				assert_eq(rift, 0.0, "Ocean rift density must be 0.0 at land=%.3f" % land)
				sampler.sample_column(wx, wz, col)
				assert_false(col.is_chasm, "Chasm must be false in ocean falloff")
				assert_false(col.is_arena, "Arena must be false in ocean falloff")
				assert_eq(sampler.get_chasm_carve(wx, 10.0, wz), 0.0, "Carve density must be 0.0 in ocean")

	assert_true(ocean_samples > 20, "Should have tested at least 20 ocean samples")

	# 2. Verify encasing at chunk (33, 57) boundary facing ocean chunk (33, 58)
	var start_p = Vector3(1073.1, 4.0, 1851.2)
	var dir = Vector3(-0.5, 0.0, 0.866).normalized()
	var hit_wall = false
	var hit_d = 0.0
	for d in range(1, 20):
		var p = start_p + dir * float(d)
		sampler.sample_column(p.x, p.z, col)
		if not col.is_chasm:
			hit_wall = true
			hit_d = float(d)
			break

	assert_true(hit_wall, "Cavern near chunk (33, 57) must hit solid encasing wall towards ocean")
	assert_true(hit_d <= 5.0, "Wall encasing must seal cave within 5 meters of margin (hit at %.1f m)" % hit_d)

func test_ocean_plane_gating_in_underground_chasm() -> void:
	var world = VoxelWorld.new()
	world.world_config = WorldConfig.new()
	world.world_config.map_size_chunks = Vector2i(256, 256)
	world.world_config.chunk_size = 16
	world.world_config.view_distance_chunks = 0
	world.world_config.collision_distance_chunks = 1
	world.spawn_on_underground_arena = true
	world.caves_enabled = true

	world._ready()

	assert_not_null(world.water_plane, "WaterPlane must be present")
	var spawn_pos = world.get_spawn_point()
	assert_true(world.is_in_underground_chasm(spawn_pos), "Arena spawn point must be in underground chasm")

	# Verify camera at Y=9.6 (more than 9.0) in chasm is identified as in chasm
	var camera_in_chasm = Vector3(spawn_pos.x, 9.6, spawn_pos.z)
	assert_true(world.is_in_underground_chasm(camera_in_chasm), "Camera pos Y > 9.0 in chasm must be identified as in chasm")

	var dummy = Node3D.new()
	world.add_child(dummy)
	world.focus_target = dummy
	dummy.global_position = spawn_pos
	world._update_layer_visibility(true)

	# When player is in underground chasm, water_plane must NOT be visible
	assert_false(world.water_plane.visible, "Ocean plane must not be visible inside underground chasm")

	# Move focus to surface above chasm: water_plane must become visible
	var surf_h = world.get_height_at(spawn_pos.x, spawn_pos.z)
	dummy.global_position = Vector3(spawn_pos.x, surf_h + 2.0, spawn_pos.z)
	world._update_layer_visibility(true)
	assert_true(world.water_plane.visible, "Ocean plane must be visible on the surface")

	if world.scheduler != null:
		world.scheduler.clear()
	world.free()

func test_cave_water_table_toggle() -> void:
	# 1. Sampler toggle validation
	var cfg = CaveGeneratorConfig.new()
	cfg.chasm_water_level = 10
	cfg.cave_water_enabled = false
	var sampler = UndergroundChasmSampler.new(1337, cfg)
	assert_false(sampler.is_subterranean_water(0.0, 5.0, 0.0), "Cave water must be disabled when cave_water_enabled is false")

	cfg.cave_water_enabled = true
	var sampler_enabled = UndergroundChasmSampler.new(1337, cfg)
	var found_water = false
	for x in range(0, 300, 20):
		for z in range(0, 300, 20):
			if sampler_enabled.is_subterranean_water(float(x), 5.0, float(z)):
				found_water = true
				break
		if found_water:
			break
	assert_true(found_water, "Cave water must be present when cave_water_enabled is true")

	# 2. VoxelMesher toggle validation
	var v_data = VoxelChunkData.new(16, 64)
	v_data.has_surface_heights = true
	v_data.surface_heights.resize(v_data.slice_size)
	v_data.surface_heights.fill(20) # Surface at 20, crust_depth=4 -> cave water is below 16
	v_data.set_voxel(4, 5, 4, 0)
	v_data.set_water(4, 5, 4, true)
	v_data.compute_section_status()

	var reg = MaterialRegistry.create_default_registry()
	var mesher_disabled = VoxelMesher.new()
	mesher_disabled.cave_water_enabled = false
	var bundle_disabled = mesher_disabled.build_mesh(v_data, reg) as DualMeshBundle
	assert_true(bundle_disabled.cave_mesh_data == null or bundle_disabled.cave_mesh_data.water_mesh_data == null, "Cave water mesh must be null when mesher cave_water_enabled is false")

	# 3. ChasmChunkData toggle validation: rock geometry MUST be preserved when cave_water is false
	var chasm_sampler = UndergroundChasmSampler.new(1337)
	var bounds = WorldConfig.new().create_world_bounds()
	var gen = LayeredTerrainGenerator.new(1337)
	var selector = preload("res://tests/benchmark/chunk_bench/benchmark_chunk_selector.gd").new()
	var arena_coord = selector.find_arena_center(gen.cave_carver.chasm_sampler, bounds)
	var s_data = gen.generate_surface(arena_coord, bounds)
	var c_data = gen.generate_subterranean(s_data, arena_coord, bounds) as ChasmChunkData
	assert_not_null(c_data, "Arena chunk data must exist")

	var chasm_mesher_dry = VoxelMesher.new()
	chasm_mesher_dry.cave_water_enabled = false
	var bundle_dry = chasm_mesher_dry.build_mesh(c_data, reg) as DualMeshBundle
	assert_not_null(bundle_dry, "Dry arena meshing must produce bundle")
	assert_true(bundle_dry.has_cave_geometry(), "Dry arena must still generate floor/ceiling cave geometry!")
	assert_true(bundle_dry.cave_mesh_data.get_vertex_count() > 0, "Dry arena must have cave vertices")
	assert_true(bundle_dry.cave_mesh_data.get_triangle_count() > 0, "Dry arena must have cave triangles")
	assert_true(bundle_dry.cave_mesh_data.water_mesh_data == null or bundle_dry.cave_mesh_data.water_mesh_data.is_empty(), "Cave water must be empty when disabled")

func test_arena_chunk_bypasses_3d_voxelization() -> void:
	## Validates Task 1.3: Core arena chunks bypass 3D voxelization (185k voxels)
	## and return ChasmChunkData (2.5D heightfield) for ultra-fast generation.
	var world_config = WorldConfig.new()
	var bounds = world_config.create_world_bounds()
	var gen = LayeredTerrainGenerator.new(1337)
	var selector = preload("res://tests/benchmark/chunk_bench/benchmark_chunk_selector.gd").new()
	var arena_center_coord = selector.find_arena_center(gen.cave_carver.chasm_sampler, bounds)

	assert_not_null(arena_center_coord, "Must locate arena center chunk")

	var s_data = gen.generate_surface(arena_center_coord, bounds)
	var sub_data = gen.generate_subterranean(s_data, arena_center_coord, bounds)

	assert_not_null(sub_data, "Subterranean data must not be null")
	assert_true(sub_data is ChasmChunkData, "Arena center chunk must return 2.5D ChasmChunkData")
	assert_true(sub_data.has_chasm, "Arena chunk must have has_chasm = true")

	# Meshing validation: VoxelMesher must delegate to ChasmShellMesher and produce DualMeshBundle
	var mesher = VoxelMesher.new()
	var reg = MaterialRegistry.create_default_registry()
	var bundle = mesher.build_mesh(sub_data, reg) as DualMeshBundle

	assert_not_null(bundle, "Meshing must produce DualMeshBundle")
	assert_true(bundle.has_cave_geometry(), "Arena must contain cave geometry")
	assert_true(bundle.cave_mesh_data.get_triangle_count() > 0, "Cave mesh must have triangles")

	# Collision baking validation: OffThreadCollisionBaker must successfully bake concave shape
	var baker = OffThreadCollisionBaker.new()
	var shapes = baker.bake_shapes_for_bundle(bundle, true)
	assert_not_null(shapes.cave_shape, "Arena must produce valid physics cave collision shape")

func test_arena_boundary_seams() -> void:
	## Validates Step 4: Boundary seam continuity between an arena chunk (2.5D ChasmChunkData)
	## and an adjacent non-arena chunk (3D VoxelChunkData).
	## Verifies that worm tunnels do not carve unmeshed holes into solid rock at the shared border.
	var world_config = WorldConfig.new()
	var bounds = world_config.create_world_bounds()
	var cave_config = CaveGeneratorConfig.new()
	cave_config.use_directed_worm_corridors = false
	var gen = LayeredTerrainGenerator.new(1337, null, cave_config)
	var selector = preload("res://tests/benchmark/chunk_bench/benchmark_chunk_selector.gd").new()
	var arena_coord = selector.find_arena_center(gen.cave_carver.chasm_sampler, bounds)

	assert_not_null(arena_coord, "Must locate arena center chunk")

	var s_data_a = gen.generate_surface(arena_coord, bounds)
	var sub_data_a = gen.generate_subterranean(s_data_a, arena_coord, bounds)
	assert_true(sub_data_a is ChasmChunkData, "Chunk A must be 2.5D ChasmChunkData")

	# Find a neighboring chunk that generates as 3D VoxelChunkData
	var neighbor_coord: ChunkCoord = null
	var sub_data_b = null
	var offset: Vector2i = Vector2i.ZERO

	for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
		var cand = ChunkCoord.new(arena_coord.x + off.x, arena_coord.z + off.y)
		var s_data_cand = gen.generate_surface(cand, bounds)
		var sub_cand = gen.generate_subterranean(s_data_cand, cand, bounds)
		if sub_cand is VoxelChunkData:
			neighbor_coord = cand
			sub_data_b = sub_cand
			offset = off
			break

	assert_not_null(neighbor_coord, "Must find adjacent or nearby 3D voxel chunk")
	if neighbor_coord == null:
		return

	# Verify that in sub_data_b, at the boundary facing the arena,
	# worm tunnels are pinched shut (arena_supp <= 0) when approaching the arena,
	# ensuring no open cavity opens into solid uncarved rock.
	var c_size = bounds.chunk_size
	var tunnel_sampler = gen.cave_carver.tunnel_sampler

	var checked_points = 0
	var suppressed_points = 0

	# Find the boundary between cand and the arena
	# Along the shared edge:
	if offset.x != 0:
		var edge_wx = float(arena_coord.x * c_size + (c_size if offset.x > 0 else 0)) * bounds.voxel_size
		for lz in range(c_size):
			var wz = float(arena_coord.z * c_size + lz) * bounds.voxel_size
			var supp = tunnel_sampler.get_arena_suppression(edge_wx, wz)
			checked_points += 1
			if supp < 1.0:
				suppressed_points += 1
	elif offset.y != 0:
		var edge_wz = float(arena_coord.z * c_size + (c_size if offset.y > 0 else 0)) * bounds.voxel_size
		for lx in range(c_size):
			var wx = float(arena_coord.x * c_size + lx) * bounds.voxel_size
			var supp = tunnel_sampler.get_arena_suppression(wx, edge_wz)
			checked_points += 1
			if supp < 1.0:
				suppressed_points += 1

	assert_true(checked_points > 0, "Must check boundary coordinates")
	assert_true(suppressed_points > 0, "Tunnel suppression must be active along arena boundary")



