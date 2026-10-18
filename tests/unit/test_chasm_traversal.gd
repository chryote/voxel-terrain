class_name TestChasmTraversal
extends "res://tests/framework/test_case.gd"

## Unit test suite for Phase 4: In-Game Traversal Validation.
## Verifies player character clearance (1.8m capsule), step transitions,
## overlook vistas, abyssal lake foundations, and collision shape generation.

func test_player_capsule_vertical_clearance() -> void:
	## Validates that every walkable column in active chasm caverns
	## provides at least 5.0m vertical clearance, preventing player capsule
	## (radius=0.4m, height=1.8m) from ever colliding with ceiling geometry.
	var config = CaveGeneratorConfig.new()
	var sampler = UndergroundChasmSampler.new(1337, config)
	var col = ChasmColumnResult.new()

	var player_height = 1.8
	var tested_positions = 0

	for ix in range(-40, 40):
		for iz in range(-40, 40):
			var wx = float(ix) * 4.0
			var wz = float(iz) * 4.0
			sampler.sample_column(wx, wz, col)

			if col.is_chasm and not col.is_pillar:
				tested_positions += 1
				var vertical_clearance = float(col.ceil_y - col.floor_y)
				assert_true(
					vertical_clearance >= config.min_chasm_height,
					"Clearance (%f) must be >= min_chasm_height (%f) at (%f, %f)" % [vertical_clearance, config.min_chasm_height, wx, wz]
				)
				assert_true(
					vertical_clearance >= player_height + 2.0,
					"Clearance (%f) must provide ample headroom for 1.8m player capsule at (%f, %f)" % [vertical_clearance, wx, wz]
				)

	assert_true(tested_positions > 50, "Must test at least 50 chasm floor positions (tested %d)" % tested_positions)

func test_floor_stair_gradient_and_steppability() -> void:
	## Validates that adjacent floor columns have gentle elevation deltas
	## (smooth undulating floor noise), preventing impassable vertical step blocks
	## along player walking trajectories.
	var config = CaveGeneratorConfig.new()
	var sampler = UndergroundChasmSampler.new(1337, config)
	var col1 = ChasmColumnResult.new()
	var col2 = ChasmColumnResult.new()

	var transitions_checked = 0
	var max_step_delta = 0

	for ix in range(-30, 30):
		for iz in range(-30, 30):
			var wx = float(ix) * 3.0
			var wz = float(iz) * 3.0

			sampler.sample_column(wx, wz, col1)
			sampler.sample_column(wx + 1.0, wz, col2)

			if col1.is_chasm and col2.is_chasm and not col1.is_pillar and not col2.is_pillar:
				transitions_checked += 1
				var step_delta = absi(col1.floor_y - col2.floor_y)
				max_step_delta = maxi(max_step_delta, step_delta)
				assert_true(
					step_delta <= 2,
					"Horizontal 1m step delta (%d) must be walkable without cliff wall blocks" % step_delta
				)

	assert_true(transitions_checked > 30, "Must test adjacent walking steps (tested %d)" % transitions_checked)
	assert_true(max_step_delta <= 2, "Maximum single-meter step delta must be <= 2 meters")

func test_high_balcony_overlook_and_line_of_sight() -> void:
	## Validates that high subterranean worm tunnels intersecting chasm rifts
	## have open line-of-sight peering downward into the abyssal basin floor.
	var bounds = WorldBounds.new(Vector2i(32, 32), 16, 1.0)
	var gen = LayeredTerrainGenerator.new(1337)
	var config = gen.cave_config

	# Locate a chunk containing both high tunnel/balcony and deep chasm void
	var target_coord: ChunkCoord = null
	var col = ChasmColumnResult.new()

	for cz in range(0, 12):
		for cx in range(0, 12):
			var wx = (float(cx * 16 + 8) + 0.5) * bounds.voxel_size
			var wz = (float(cz * 16 + 8) + 0.5) * bounds.voxel_size
			gen.cave_carver.sample_chasm_column(wx, wz, col)
			if col.is_chasm and not col.is_pillar and col.ceil_y >= 22:
				target_coord = ChunkCoord.new(cx, cz)
				break
		if target_coord != null:
			break

	assert_not_null(target_coord, "Must locate chunk with high vaulted chasm ceiling")
	if target_coord == null:
		return

	var s_data = gen.generate_surface(target_coord, bounds)
	var v_data = gen.generate_subterranean(s_data, target_coord, bounds)

	# In this chunk, verify that high balcony voxels (Y=20..22) peering down
	# to water basin (Y=10) pass through hollow air voxels
	var line_of_sight_verified = false
	for lz in range(4, 12):
		for lx in range(4, 12):
			var wx = (float(target_coord.x * 16 + lx) + 0.5) * bounds.voxel_size
			var wz = (float(target_coord.z * 16 + lz) + 0.5) * bounds.voxel_size
			gen.cave_carver.sample_chasm_column(wx, wz, col)

			if col.is_chasm and not col.is_pillar and col.ceil_y >= 22:
				# Check vertical line-of-sight raycast from upper overlook to basin
				var ray_blocked = false
				for ly in range(config.chasm_water_level + 1, col.ceil_y):
					if v_data.get_voxel(lx, ly, lz) != 0:
						ray_blocked = true
						break
				if not ray_blocked:
					line_of_sight_verified = true
					break
		if line_of_sight_verified:
			break

	assert_true(line_of_sight_verified, "High overlook balcony must have clear vertical line of sight into chasm abyss")

func test_abyssal_lake_basin_and_bedrock_foundation() -> void:
	## Validates that flooded cavern basins (Y <= chasm_water_level)
	## have solid basalt floors and intact bedrock underneath, so players
	## swimming or diving never fall out of the world bounds.
	var bounds = WorldBounds.new(Vector2i(32, 32), 16, 1.0)
	var gen = LayeredTerrainGenerator.new(1337)
	var config = gen.cave_config

	var target_coord: ChunkCoord = null
	var col = ChasmColumnResult.new()

	for cz in range(0, 10):
		for cx in range(0, 10):
			var wx = (float(cx * 16 + 8) + 0.5) * bounds.voxel_size
			var wz = (float(cz * 16 + 8) + 0.5) * bounds.voxel_size
			gen.cave_carver.sample_chasm_column(wx, wz, col)
			if col.is_chasm and not col.is_pillar and col.floor_y < config.chasm_water_level:
				target_coord = ChunkCoord.new(cx, cz)
				break
		if target_coord != null:
			break

	assert_not_null(target_coord, "Must locate flooded chasm basin chunk")
	if target_coord == null:
		return

	var s_data = gen.generate_surface(target_coord, bounds)
	var v_data = gen.generate_subterranean(s_data, target_coord, bounds)

	var flooded_columns_checked = 0
	for lz in range(16):
		for lx in range(16):
			var wx = (float(target_coord.x * 16 + lx) + 0.5) * bounds.voxel_size
			var wz = (float(target_coord.z * 16 + lz) + 0.5) * bounds.voxel_size
			gen.cave_carver.sample_chasm_column(wx, wz, col)

			if col.is_chasm and not col.is_pillar and col.floor_y < config.chasm_water_level:
				flooded_columns_checked += 1
				# 1. Floor voxel must be solid basalt
				var floor_mat = v_data.get_voxel(lx, col.floor_y, lz)
				assert_eq(floor_mat, MaterialDef.ID_CHASM_BASALT, "Basin floor must be basalt")

				# 2. Bedrock underneath must be solid stone
				for by in range(0, 3):
					assert_eq(v_data.get_voxel(lx, by, lz), MaterialDef.ID_STONE, "Bedrock under basin must be solid stone")

				# 3. Water voxels between floor_y+1 and water_level
				for wy in range(col.floor_y + 1, config.chasm_water_level + 1):
					assert_true(v_data.has_water(lx, wy, lz), "Voxel Y=%d must contain subterranean water" % wy)

	assert_true(flooded_columns_checked > 0, "Must check flooded columns in basin")

func test_cavern_collision_mesh_presence() -> void:
	## Validates that chunks with subterranean caves generate valid
	## concave polygon collision shapes ready for Godot's physics engine.
	var bounds = WorldBounds.new(Vector2i(32, 32), 16, 1.0)
	var gen = LayeredTerrainGenerator.new(1337)
	var mesher = VoxelMesher.new()
	var reg = MaterialRegistry.create_default_registry()
	var baker = OffThreadCollisionBaker.new()

	var coord = ChunkCoord.new(2, 2)
	var s_data = gen.generate_surface(coord, bounds)
	var v_data = gen.generate_subterranean(s_data, coord, bounds)

	var mesh_data = mesher.build_mesh(v_data, reg)
	var bundle = mesh_data as DualMeshBundle
	assert_not_null(bundle, "Mesher must return DualMeshBundle")

	var shapes = baker.bake_shapes_for_bundle(bundle)
	assert_not_null(shapes.surface_shape, "Surface shape must exist")
	if bundle.has_cave_geometry():
		assert_not_null(shapes.cave_shape, "Cave collision shape must be generated for subterranean geometry")
		assert_true(shapes.cave_shape.get_faces().size() > 0, "Cave collision shape must contain triangular faces")

func test_subterranean_chunk_boundary_seam_integrity() -> void:
	## Validates that adjacent subterranean chunks with 3D tunnels and chasms
	## have 100% consistent boundary aprons with zero air-vs-solid seam mismatches,
	## preventing X-ray rendering glitches and traversable out-of-bounds gaps.
	var world_config = WorldConfig.new()
	var gen_config = ContinentGeneratorConfig.new()
	var cave_config = CaveGeneratorConfig.new()
	cave_config.use_directed_worm_corridors = false
	var bounds = world_config.create_world_bounds()
	var generator = VolumetricTerrainGenerator.new(world_config.world_seed, gen_config, cave_config)
	if "cave_carver" in generator and generator.cave_carver != null:
		generator.cave_carver.set_continent_mask(generator.continent_gen.mask, bounds)
	generator.init_cave_mouths(bounds)

	var cA = ChunkCoord.new(-16, -8)
	var cB = ChunkCoord.new(-16, -7)

	var sA = generator.generate_surface(cA, bounds)
	var subA = generator.generate_subterranean(sA, cA, bounds) as VoxelChunkData

	var sB = generator.generate_surface(cB, bounds)
	var subB = generator.generate_subterranean(sB, cB, bounds) as VoxelChunkData

	assert_not_null(subA, "Chunk A subterranean data must exist")
	assert_not_null(subB, "Chunk B subterranean data must exist")

	var air_mismatches = 0
	for lx in range(bounds.chunk_size):
		for y in range(bounds.chunk_size):
			var vA_inside = subA.get_voxel(lx, y, 31)
			var vB_apron  = subB.get_voxel(lx, y, -1)
			if vA_inside != vB_apron and (vA_inside == 0 or vB_apron == 0):
				air_mismatches += 1

			var vA_apron  = subA.get_voxel(lx, y, 32)
			var vB_inside = subB.get_voxel(lx, y, 0)
			if vA_apron != vB_inside and (vA_apron == 0 or vB_inside == 0):
				air_mismatches += 1

	assert_eq(air_mismatches, 0, "Must have 0 air-vs-solid seam mismatches across chunk boundary (found %d)" % air_mismatches)

