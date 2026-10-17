class_name LayeredTerrainGenerator
extends TerrainGenerator

## Two-phase procedural terrain generator physically separating 2D surface topography
## generation from 3D subterranean cave carving for demand-driven lazy streaming.
## Enables instantaneous ~22 ms surface streaming while deferring heavy 3D voxel carving
## until subterranean traversal or cave mouth proximity.

var config: ContinentGeneratorConfig
var cave_config: CaveGeneratorConfig

var continent_gen: ContinentGenerator
var cave_carver: CaveCarver
var _mouths_initialized: bool = false

func _init(seed_val: int = 1337, p_config: ContinentGeneratorConfig = null, p_cave_config: CaveGeneratorConfig = null) -> void:
	config = p_config if p_config != null else ContinentGeneratorConfig.new()
	cave_config = p_cave_config if p_cave_config != null else CaveGeneratorConfig.new()

	continent_gen = ContinentGenerator.new(seed_val, config)
	cave_carver = CaveCarver.new(seed_val, cave_config)

const CaveMouthDetectorClass = preload("res://src/map/cave_mouth_detector.gd")
const ChasmChunkDataClass = preload("res://src/core/chasm_chunk_data.gd")

func init_cave_mouths(bounds: WorldBounds) -> Array:
	## Discovers and initializes continent-wide allowed cave mouths respecting configured limits.
	if bounds != null:
		cave_carver.set_continent_mask(continent_gen.mask, bounds)
	if not cave_config.enabled or not cave_config.limit_cave_mouths or bounds == null:
		_mouths_initialized = true
		return []
	var detector = CaveMouthDetectorClass.new()
	var mouths = detector.detect_cave_mouths(self, bounds)
	cave_carver.set_allowed_mouths(mouths)
	_mouths_initialized = true
	return mouths

## Phase A: High-speed surface-only generation (~14 ms)
func generate_surface(coord: ChunkCoord, bounds: WorldBounds) -> SurfaceChunkData:
	if bounds != null:
		cave_carver.set_continent_mask(continent_gen.mask, bounds)
	if not _mouths_initialized and cave_config.enabled and cave_config.limit_cave_mouths and bounds != null:
		init_cave_mouths(bounds)
	var surface_data: SurfaceChunkData = continent_gen.generate(coord, bounds)
	surface_data.has_cave_mouth = check_has_cave_mouth(surface_data, coord, bounds)
	return surface_data

## Evaluates whether any column in the chunk contains a cave mouth candidate
func check_has_cave_mouth(surface_data: SurfaceChunkData, coord: ChunkCoord, bounds: WorldBounds) -> bool:
	if not cave_config.enabled:
		return false
	if not _mouths_initialized and cave_config.limit_cave_mouths and bounds != null:
		init_cave_mouths(bounds)

	var c_size = bounds.chunk_size
	# Fast-path: if allowed mouths are active, check if chunk AABB intersects any allowed mouth
	if cave_carver.mouth_sampler.use_allowed_mouths:
		var chunk_origin = bounds.chunk_origin(coord)
		var c_span = float(c_size) * bounds.voxel_size
		if not cave_carver.mouth_sampler.limiter.can_box_intersect_mouths(
			chunk_origin.x, chunk_origin.z,
			chunk_origin.x + c_span, chunk_origin.z + c_span,
			cave_carver.mouth_sampler.allowed_mouths,
			cave_carver.config.mouth_radius
		):
			return false

	var sea_level = config.sea_level
	for lz in range(c_size):
		for lx in range(c_size):
			var gx = coord.x * c_size + lx
			var gz = coord.z * c_size + lz
			var wx = (float(gx) + 0.5) * bounds.voxel_size
			var wz = (float(gz) + 0.5) * bounds.voxel_size
			var col_h = float(surface_data.get_height(lx, lz))
			if cave_carver.mouth_sampler.is_mouth_candidate(wx, wz, col_h, sea_level):
				return true
	return false

## Phase B: Subterranean voxel column population and 3D cave carving
func generate_subterranean(surface_data: SurfaceChunkData, coord: ChunkCoord, bounds: WorldBounds) -> RefCounted:
	if bounds != null:
		cave_carver.set_continent_mask(continent_gen.mask, bounds)
	if not _mouths_initialized and cave_config.enabled and cave_config.limit_cave_mouths and bounds != null:
		init_cave_mouths(bounds)
	if surface_data == null:
		surface_data = generate_surface(coord, bounds)

	var max_h = 160

	# 2.1 Bypass 3D Voxelization Pattern for pure chasm / non-tunnel chunks
	if cave_config.bypass_chasm_voxelization and not surface_data.has_cave_mouth:
		var c_size = bounds.chunk_size
		var min_wx = float(coord.x * c_size) * bounds.voxel_size
		var min_wz = float(coord.z * c_size) * bounds.voxel_size
		var max_wx = float((coord.x + 1) * c_size) * bounds.voxel_size
		var max_wz = float((coord.z + 1) * c_size) * bounds.voxel_size
		var cell_min_p = Vector3(min_wx, 0.0, min_wz)
		var cell_max_p = Vector3(max_wx, float(max_h) * bounds.voxel_size, max_wz)

		var can_tunnel = cave_config.enabled and cave_carver.tunnel_sampler.can_tunnel_intersect_cell(cell_min_p, cell_max_p)
		var can_mouth = cave_config.enabled and cave_carver.mouth_sampler.can_mouth_intersect_cell(cell_min_p, cell_max_p, 255.0, config.sea_level)

		if not can_tunnel and not can_mouth:
			return generate_chasm_data(surface_data, coord, bounds, max_h)

	var v_data = _populate_voxel_columns(surface_data, bounds, max_h)
	_carve_subterranean_caves(v_data, surface_data, coord, bounds, max_h)
	return v_data

func generate_chasm_data(
	surface_data: SurfaceChunkData,
	coord: ChunkCoord,
	bounds: WorldBounds,
	max_h: int = 160
) -> RefCounted:
	## High-speed 2.5D chasm generation bypassing 3D voxel arrays (185k voxels).
	## Evaluates floor, ceiling, and wall boundary flags column-by-column in O(N^2) time.
	var c_size = bounds.chunk_size
	var chasm_data = ChasmChunkDataClass.new(c_size, max_h, surface_data)
	chasm_data.chasm_water_level = cave_config.chasm_water_level
	chasm_data.cave_water_enabled = cave_config.cave_water_enabled

	if not cave_config.enabled:
		return chasm_data

	var min_wx = float(coord.x * c_size) * bounds.voxel_size
	var min_wz = float(coord.z * c_size) * bounds.voxel_size
	var max_wx = float((coord.x + 1) * c_size) * bounds.voxel_size
	var max_wz = float((coord.z + 1) * c_size) * bounds.voxel_size
	var cell_min_p = Vector3(min_wx, 0.0, min_wz)
	var cell_max_p = Vector3(max_wx, float(max_h) * bounds.voxel_size, max_wz)

	if not cave_carver.chasm_sampler.can_chasm_intersect_cell(cell_min_p, cell_max_p):
		return chasm_data

	var chasm_col = ChasmColumnResult.new()
	var apron_w = chasm_data.apron_size

	for lz in range(-1, c_size + 1):
		var gz = coord.z * c_size + lz
		var wz = (float(gz) + 0.5) * bounds.voxel_size
		var row_start = (lz + 1) * apron_w

		for lx in range(-1, c_size + 1):
			var gx = coord.x * c_size + lx
			var wx = (float(gx) + 0.5) * bounds.voxel_size
			var col_idx = (lx + 1) + row_start
			var col_h = float(surface_data.get_height(lx, lz))
			cave_carver.sample_chasm_column(wx, wz, chasm_col, col_h)

			chasm_data.floor_heights[col_idx] = chasm_col.floor_y
			chasm_data.ceil_heights[col_idx] = chasm_col.ceil_y

			var flag = 0
			if chasm_col.is_chasm:
				flag |= ChasmChunkDataClass.FLAG_CHASM
				chasm_data.has_chasm = true
			if chasm_col.is_pillar:
				flag |= ChasmChunkDataClass.FLAG_PILLAR
			if chasm_col.is_wall:
				flag |= ChasmChunkDataClass.FLAG_WALL
			if chasm_col.is_arena:
				flag |= ChasmChunkDataClass.FLAG_ARENA
			if chasm_col.is_arena_ledge:
				flag |= ChasmChunkDataClass.FLAG_ARENA_LEDGE
			if chasm_col.is_basalt_column:
				flag |= ChasmChunkDataClass.FLAG_BASALT_COLUMN

			chasm_data.chasm_flags[col_idx] = flag

			var mat = cave_carver.classify_subterranean_voxel(wx, float(chasm_col.floor_y), wz)
			chasm_data.materials[col_idx] = mat

	return chasm_data

## Combined full generation (implements TerrainGenerator polymorphism)
func generate(coord: ChunkCoord, bounds: WorldBounds) -> RefCounted:
	var surface_data = generate_surface(coord, bounds)
	return generate_subterranean(surface_data, coord, bounds)

func _populate_voxel_columns(surface_data: SurfaceChunkData, bounds: WorldBounds, max_h: int) -> VoxelChunkData:
	var c_size = bounds.chunk_size
	var v_data = VoxelChunkData.new(c_size, max_h)

	for lz in range(-1, c_size + 1):
		for lx in range(-1, c_size + 1):
			var h = surface_data.get_height(lx, lz)
			v_data.set_surface_height(lx, lz, h)
			var water_h = surface_data.get_water_height(lx, lz)
			var top_mat = surface_data.get_top_material(lx, lz)
			var side_mat = surface_data.get_side_material(lx, lz)

			var clamped_h = mini(h, max_h)
			var clamped_w = mini(water_h, max_h)

			# Bedrock (Y=0..2)
			for ly in range(0, mini(3, clamped_h)):
				v_data.set_voxel(lx, ly, lz, MaterialDef.ID_STONE)

			# Mid stone
			var rock_top = max(3, clamped_h - 4)
			for ly in range(3, rock_top):
				v_data.set_voxel(lx, ly, lz, MaterialDef.ID_STONE)

			# Sub-surface soil/side material
			for ly in range(rock_top, clamped_h - 1):
				v_data.set_voxel(lx, ly, lz, side_mat)

			# Surface top material (sits at ly = clamped_h - 1, top face at Y = clamped_h.0)
			if clamped_h > 0:
				v_data.set_voxel(lx, clamped_h - 1, lz, top_mat)

			# Surface water (sits directly on terrain at clamped_h up to clamped_w - 1, top face at clamped_w.0)
			if clamped_w > clamped_h:
				for ly in range(clamped_h, clamped_w):
					v_data.set_water(lx, ly, lz, true)

	return v_data

func _carve_subterranean_caves(
	v_data: VoxelChunkData,
	surface_data: SurfaceChunkData,
	coord: ChunkCoord,
	bounds: WorldBounds,
	max_h: int
) -> void:
	if not cave_config.enabled:
		return

	var c_size = bounds.chunk_size
	var sea_level = config.sea_level
	var block_size = 4

	# Find highest surface elevation in chunk to clamp vertical carving ceiling
	var max_chunk_h = 0
	for lz in range(c_size):
		for lx in range(c_size):
			max_chunk_h = maxi(max_chunk_h, surface_data.get_height(lx, lz))
	var carve_ceiling = mini(max_h, max_chunk_h + 2)

	# Reusable column result allocated once per chunk generation (thread-safe local variable)
	var chasm_col = ChasmColumnResult.new()

	for bz in range(-1, c_size + 1, block_size):
		for bx in range(-1, c_size + 1, block_size):
			var min_gx = coord.x * c_size + bx
			var min_gz = coord.z * c_size + bz
			var max_gx = min_gx + block_size - 1
			var max_gz = min_gz + block_size - 1

			var min_wx = float(min_gx) * bounds.voxel_size
			var min_wz = float(min_gz) * bounds.voxel_size
			var max_wx = float(max_gx + 1) * bounds.voxel_size
			var max_wz = float(max_gz + 1) * bounds.voxel_size

			# Local surface elevation envelope for coarse cell
			var cell_min_h = 255.0
			var cell_max_h = 0.0
			for cz in range(bz, mini(bz + block_size, c_size + 1)):
				for cx in range(bx, mini(bx + block_size, c_size + 1)):
					var col_h = float(surface_data.get_height(cx, cz))
					cell_min_h = minf(cell_min_h, col_h)
					cell_max_h = maxf(cell_max_h, col_h)

			for by in range(3, carve_ceiling, block_size):
				var min_wy = float(by) * bounds.voxel_size
				var max_wy = float(mini(by + block_size, carve_ceiling)) * bounds.voxel_size

				var cell_min_p = Vector3(min_wx, min_wy, min_wz)
				var cell_max_p = Vector3(max_wx, max_wy, max_wz)

				var status = cave_carver.sample_coarse_cell_status(
					cell_min_p, cell_max_p,
					cell_min_h, cell_max_h, sea_level
				)

				if status == CaveCarver.STATUS_AIR or status == CaveCarver.STATUS_SOLID:
					continue

				# Check whether deep chasm voids or tunnels/mouths can intersect this active cell
				var cell_can_chasm = cave_carver.chasm_sampler.can_chasm_intersect_cell(cell_min_p, cell_max_p)
				var cell_can_tunnel = cave_carver.tunnel_sampler.can_tunnel_intersect_cell(cell_min_p, cell_max_p)
				var cell_can_mouth = cave_carver.mouth_sampler.can_mouth_intersect_cell(cell_min_p, cell_max_p, cell_max_h, sea_level)
				var cell_can_tunnel_or_mouth = cell_can_tunnel or cell_can_mouth

				# Item 3.3: Trilinear density interpolation for 3D worm tunnels
				var use_trilinear = cave_config.use_trilinear_tunnel_grid and cell_can_tunnel
				var tunnel_corners: PackedFloat32Array
				var has_tunnel_density = false
				if use_trilinear:
					tunnel_corners = cave_carver.tunnel_sampler.sample_trilinear_cell_corners(cell_min_p, cell_max_p)
					var max_c = maxf(
						maxf(maxf(tunnel_corners[0], tunnel_corners[1]), maxf(tunnel_corners[2], tunnel_corners[3])),
						maxf(maxf(tunnel_corners[4], tunnel_corners[5]), maxf(tunnel_corners[6], tunnel_corners[7]))
					)
					if max_c > 0.0:
						has_tunnel_density = true
					else:
						var mid_c = cave_carver.tunnel_sampler.get_tunnel_carve((cell_min_p.x + cell_max_p.x) * 0.5, (cell_min_p.y + cell_max_p.y) * 0.5, (cell_min_p.z + cell_max_p.z) * 0.5)
						has_tunnel_density = (mid_c > 0.0)

				# Fine per-voxel evaluation within active boundary block
				for lz in range(bz, mini(bz + block_size, c_size + 1)):
					var gz = coord.z * c_size + lz
					var wz = (float(gz) + 0.5) * bounds.voxel_size

					for lx in range(bx, mini(bx + block_size, c_size + 1)):
						var gx = coord.x * c_size + lx
						var wx = (float(gx) + 0.5) * bounds.voxel_size
						var col_h = float(surface_data.get_height(lx, lz))

						# 2D Chasm column sampled ONCE outside the inner Y loop
						if cell_can_chasm:
							cave_carver.sample_chasm_column(wx, wz, chasm_col, col_h)
						else:
							chasm_col.reset()

						for ly in range(by, mini(by + block_size, carve_ceiling)):
							if ly <= 2:
								continue

							var wy = float(ly) * bounds.voxel_size
							if wy > col_h + 1.0 and ly > col_h:
								continue

							var is_void = false
							var is_water = false

							# 1. Fast O(1) span check for 2D chasm void
							if cave_carver.is_chasm_void(wy, chasm_col, col_h):
								is_void = true
								is_water = cave_config.cave_water_enabled and (wy <= float(cave_config.chasm_water_level)) and not chasm_col.is_arena
							elif cell_can_tunnel_or_mouth:
								# 2. Check 3D worm tunnels and cave mouth funnels
								var tunnel_or_mouth = 0.0
								if cell_can_mouth and wy <= (col_h + 1.0):
									tunnel_or_mouth = cave_carver.get_mouth_descent_carve(wx, wy, wz, col_h, sea_level, chasm_col)
								if tunnel_or_mouth <= 0.05 and cell_can_tunnel:
									if use_trilinear:
										if has_tunnel_density:
											var u = clampf((wx - cell_min_p.x) / (cell_max_p.x - cell_min_p.x), 0.0, 1.0)
											var v = clampf((wy - cell_min_p.y) / (cell_max_p.y - cell_min_p.y), 0.0, 1.0)
											var w = clampf((wz - cell_min_p.z) / (cell_max_p.z - cell_min_p.z), 0.0, 1.0)
											tunnel_or_mouth = cave_carver.tunnel_sampler.evaluate_trilinear(tunnel_corners, u, v, w)
									else:
										tunnel_or_mouth = cave_carver.tunnel_sampler.get_tunnel_carve(wx, wy, wz)

								if tunnel_or_mouth > 0.05 and not cave_carver.mouth_sampler.is_crust_sealed(wx, wy, wz, col_h, sea_level):
									is_void = true
									if not v_data.has_cave_mouth and wy >= (col_h - cave_config.crust_depth) and cave_carver.mouth_sampler.is_mouth_candidate(wx, wz, col_h, sea_level):
										v_data.has_cave_mouth = true

							if is_void:
								v_data.set_voxel(lx, ly, lz, 0)
								v_data.set_water(lx, ly, lz, is_water)
							elif chasm_col.is_chasm:
								if ly == chasm_col.floor_y:
									var sub_mat = cave_carver.classify_subterranean_voxel(wx, wy, wz)
									v_data.set_voxel(lx, ly, lz, sub_mat)
								elif ly == chasm_col.ceil_y + 1 and ly < carve_ceiling:
									var sub_mat = cave_carver.classify_subterranean_voxel(wx, wy, wz)
									v_data.set_voxel(lx, ly, lz, sub_mat)
							elif chasm_col.is_pillar or chasm_col.is_wall:
								if ly >= chasm_col.floor_y and ly <= chasm_col.ceil_y + 1 and ly < carve_ceiling:
									var sub_mat = cave_carver.classify_subterranean_voxel(wx, wy, wz)
									v_data.set_voxel(lx, ly, lz, sub_mat)




func height_at(col: Vector2i, bounds: WorldBounds) -> int:
	return continent_gen.height_at(col, bounds)

func water_height_at(col: Vector2i, bounds: WorldBounds) -> int:
	return continent_gen.water_height_at(col, bounds)

func is_water_at(col: Vector2i, bounds: WorldBounds) -> bool:
	return continent_gen.is_water_at(col, bounds)

func sample_world(wx: float, wz: float, bounds: WorldBounds) -> Dictionary:
	return continent_gen.sample_world(wx, wz, bounds)
