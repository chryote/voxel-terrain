class_name VolumetricTerrainGenerator
extends TerrainGenerator

## 3D Volumetric Terrain Generator executing procedural macro topography,
## fluvial carving, and 3D subterranean cave carving (caves, dead ends, chasms, and water pools).
## Produces VoxelChunkData for 3D greedy meshing and physics.

var config: ContinentGeneratorConfig
var cave_config: CaveGeneratorConfig

var continent_gen: ContinentGenerator
var cave_carver: CaveCarver

func _init(seed_val: int = 1337, p_config: ContinentGeneratorConfig = null, p_cave_config: CaveGeneratorConfig = null) -> void:
	config = p_config if p_config != null else ContinentGeneratorConfig.new()
	cave_config = p_cave_config if p_cave_config != null else CaveGeneratorConfig.new()

	continent_gen = ContinentGenerator.new(seed_val, config)
	cave_carver = CaveCarver.new(seed_val, cave_config)

func generate(coord: ChunkCoord, bounds: WorldBounds) -> RefCounted:
	var c_size = bounds.chunk_size
	var max_h = 160
	var v_data = VoxelChunkData.new(c_size, max_h)

	# 1. Generate surface topography and column data
	var surface_data: SurfaceChunkData = continent_gen.generate(coord, bounds)
	var sea_level = config.sea_level

	# 2. Populate solid columns and surface water from surface data
	for lz in range(-1, c_size + 1):
		for lx in range(-1, c_size + 1):
			var h = surface_data.get_height(lx, lz)
			v_data.set_surface_height(lx, lz, h)
			var water_h = surface_data.get_water_height(lx, lz)
			var top_mat = surface_data.get_top_material(lx, lz)
			var side_mat = surface_data.get_side_material(lx, lz)

			var clamped_h = mini(h, max_h - 1)
			var clamped_w = mini(water_h, max_h - 1)

			# Bedrock and deep stone
			for ly in range(0, mini(3, clamped_h + 1)):
				v_data.set_voxel(lx, ly, lz, MaterialDef.ID_STONE)

			# Mid rock
			var rock_top = max(3, clamped_h - 3)
			for ly in range(3, rock_top):
				v_data.set_voxel(lx, ly, lz, MaterialDef.ID_STONE)

			# Sub-surface soil/side material
			for ly in range(rock_top, clamped_h):
				v_data.set_voxel(lx, ly, lz, side_mat)

			# Surface top material
			if clamped_h >= 0:
				v_data.set_voxel(lx, clamped_h, lz, top_mat)

			# Surface ocean / river / lake water
			if clamped_w > clamped_h:
				for ly in range(clamped_h + 1, clamped_w + 1):
					v_data.set_water(lx, ly, lz, true)

	# 3. 3D Cave Carving Pass with coarse hierarchical culling
	var block_size = 4
	for bz in range(-1, c_size + 1, block_size):
		for bx in range(-1, c_size + 1, block_size):
			# Compute block bounds
			var min_gx = coord.x * c_size + bx
			var min_gz = coord.z * c_size + bz
			var max_gx = coord.x * c_size + mini(bx + block_size - 1, c_size)
			var max_gz = coord.z * c_size + mini(bz + block_size - 1, c_size)

			var min_wx = float(min_gx) * bounds.voxel_size
			var min_wz = float(min_gz) * bounds.voxel_size
			var max_wx = float(max_gx + 1) * bounds.voxel_size
			var max_wz = float(max_gz + 1) * bounds.voxel_size

			# Local surface height range for this coarse cell
			var cell_min_h = 255.0
			var cell_max_h = 0.0
			for cz in range(bz, mini(bz + block_size, c_size + 1)):
				for cx in range(bx, mini(bx + block_size, c_size + 1)):
					var col_h = float(surface_data.get_height(cx, cz))
					cell_min_h = minf(cell_min_h, col_h)
					cell_max_h = maxf(cell_max_h, col_h)

			for by in range(3, max_h - 1, block_size):
				var min_wy = float(by) * bounds.voxel_size
				var max_wy = float(mini(by + block_size, max_h)) * bounds.voxel_size

				var status = cave_carver.sample_coarse_cell_status(
					Vector3(min_wx, min_wy, min_wz),
					Vector3(max_wx, max_wy, max_wz),
					cell_min_h, cell_max_h, sea_level
				)

				# Skip evaluating pure air or pure solid blocks entirely
				if status == CaveCarver.STATUS_AIR or status == CaveCarver.STATUS_SOLID:
					continue

				# Fine per-voxel evaluation for mixed boundary blocks
				for lz in range(bz, mini(bz + block_size, c_size + 1)):
					var gz = coord.z * c_size + lz
					var wz = (float(gz) + 0.5) * bounds.voxel_size

					for lx in range(bx, mini(bx + block_size, c_size + 1)):
						var gx = coord.x * c_size + lx
						var wx = (float(gx) + 0.5) * bounds.voxel_size
						var col_h = float(surface_data.get_height(lx, lz))

						for ly in range(by, mini(by + block_size, max_h)):
							# Bedrock at Y <= 2 is indestructible solid stone
							if ly <= 2:
								continue

							var wy = float(ly) * bounds.voxel_size

							# Skip voxels already in the sky above surface (unless inside entrance funnel)
							if wy > col_h + 1.0 and ly > col_h:
								continue

							if cave_carver.is_carved(wx, wy, wz, col_h, sea_level):
								if not v_data.has_cave_mouth and wy >= (col_h - cave_config.crust_depth) and cave_carver.mouth_sampler.is_mouth_candidate(wx, wz, col_h, sea_level):
									v_data.has_cave_mouth = true
								if cave_carver.is_subterranean_water(wx, wy, wz, col_h, sea_level):
									v_data.set_voxel(lx, ly, lz, 0)
									v_data.set_water(lx, ly, lz, true)
								else:
									v_data.set_voxel(lx, ly, lz, 0)
									v_data.set_water(lx, ly, lz, false)
							else:
								# If solid subterranean rock is within deep chasm strata, classify as basalt/crystal
								var current_mat = v_data.get_voxel(lx, ly, lz)
								if current_mat == MaterialDef.ID_STONE and ly > 2 and ly <= cave_config.chasm_max_y:
									var sub_mat = cave_carver.classify_subterranean_voxel(wx, wy, wz)
									v_data.set_voxel(lx, ly, lz, sub_mat)

	return v_data

func height_at(col: Vector2i, bounds: WorldBounds) -> int:
	return continent_gen.height_at(col, bounds)

func water_height_at(col: Vector2i, bounds: WorldBounds) -> int:
	return continent_gen.water_height_at(col, bounds)

func is_water_at(col: Vector2i, bounds: WorldBounds) -> bool:
	return continent_gen.is_water_at(col, bounds)
