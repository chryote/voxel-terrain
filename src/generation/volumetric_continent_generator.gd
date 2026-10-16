class_name VolumetricContinentGenerator
extends TerrainGenerator

## 3D procedural continent generator capable of producing overhangs and caves.
## Uses pure RefCounted data structures and is thread-safe for background workers.

var config: VolumetricGeneratorConfig
var mask: ContinentMask
var base_noise: FastNoiseLite
var mountain_noise: FastNoiseLite
var sampler: DensitySampler3D
var classifier: VoxelMaterialClassifier

func _init(seed_val: int = 1337, p_config: VolumetricGeneratorConfig = null) -> void:
	config = p_config if p_config != null else VolumetricGeneratorConfig.new()
	mask = ContinentMask.new(seed_val, config)
	sampler = DensitySampler3D.new(seed_val, config)
	classifier = VoxelMaterialClassifier.new()

	base_noise = FastNoiseLite.new()
	base_noise.seed = seed_val
	base_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	base_noise.frequency = config.base_noise_frequency
	base_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	base_noise.fractal_octaves = config.fractal_octaves
	base_noise.fractal_lacunarity = config.fractal_lacunarity
	base_noise.fractal_gain = config.fractal_gain

	mountain_noise = FastNoiseLite.new()
	mountain_noise.seed = seed_val + 777
	mountain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	mountain_noise.frequency = config.mountain_frequency
	mountain_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	mountain_noise.fractal_octaves = 3

func generate(coord: ChunkCoord, bounds: WorldBounds) -> RefCounted:
	var c_size = bounds.chunk_size
	var data = VoxelChunkData.new(c_size, config.chunk_height)
	var apron_dim = c_size + 2
	var base_heights = PackedInt32Array()
	base_heights.resize(apron_dim * apron_dim)

	_compute_base_heights(coord, bounds, c_size, base_heights)
	_generate_density_field(coord, bounds, c_size, base_heights, data)
	_apply_materials(c_size, data)

	return data

func height_at(col: Vector2i, bounds: WorldBounds) -> int:
	if not bounds.contains_column(col.x, col.y):
		return config.seabed_level
	var h_base = _calculate_base_elevation(col.x, col.y, bounds)
	if h_base <= config.sea_level:
		return h_base
	var wx = (float(col.x) + 0.5) * bounds.voxel_size
	var wz = (float(col.y) + 0.5) * bounds.voxel_size
	var y_max = mini(h_base + int(config.overhang_amplitude) + 2, config.chunk_height - 1)

	for ly in range(y_max, config.bedrock_level, -1):
		var wy = float(ly) * bounds.voxel_size
		var density = float(h_base - ly)
		var n_over = sampler.sample_overhang(wx, wy, wz)
		if n_over > config.overhang_threshold:
			var factor = (n_over - config.overhang_threshold) / (1.0 - config.overhang_threshold)
			density += factor * config.overhang_amplitude

		if density >= 0.0:
			var depth = float(h_base - ly)
			if not sampler.is_cave(wx, wy, wz, depth, ly):
				return ly

	return h_base

func _compute_base_heights(
	coord: ChunkCoord,
	bounds: WorldBounds,
	c_size: int,
	out_heights: PackedInt32Array
) -> void:
	var apron_dim = c_size + 2
	for lz in range(-1, c_size + 1):
		var gz = coord.z * c_size + lz
		for lx in range(-1, c_size + 1):
			var gx = coord.x * c_size + lx
			var idx = (lx + 1) + (lz + 1) * apron_dim
			if not bounds.contains_column(gx, gz):
				out_heights[idx] = config.seabed_level
			else:
				out_heights[idx] = _calculate_base_elevation(gx, gz, bounds)

func _generate_density_field(
	coord: ChunkCoord,
	bounds: WorldBounds,
	c_size: int,
	base_heights: PackedInt32Array,
	data: VoxelChunkData
) -> void:
	var apron_dim = c_size + 2

	for lz in range(-1, c_size + 1):
		var gz = coord.z * c_size + lz
		var wz = (float(gz) + 0.5) * bounds.voxel_size

		for lx in range(-1, c_size + 1):
			var gx = coord.x * c_size + lx
			var wx = (float(gx) + 0.5) * bounds.voxel_size
			var col_idx = (lx + 1) + (lz + 1) * apron_dim
			var h_base = base_heights[col_idx]

			# Seabed outside bounds
			if not bounds.contains_column(gx, gz):
				for y in range(0, config.seabed_level + 1):
					data.set_voxel(lx, y, lz, VoxelMaterialClassifier.MAT_SEABED)
				continue

			# Bedrock floor
			for y in range(0, config.bedrock_level + 1):
				data.set_voxel(lx, y, lz, VoxelMaterialClassifier.MAT_STONE)

			# Vertical band culling: only evaluate 3D noise within active range
			var y_max = mini(h_base + int(config.overhang_amplitude) + 2, config.chunk_height - 1)
			var y_min = config.bedrock_level + 1

			for ly in range(y_min, y_max + 1):
				var wy = float(ly) * bounds.voxel_size
				var density = float(h_base - ly)

				# Overhang expansion
				var n_over = sampler.sample_overhang(wx, wy, wz)
				if n_over > config.overhang_threshold:
					var factor = (n_over - config.overhang_threshold) / (1.0 - config.overhang_threshold)
					density += factor * config.overhang_amplitude

				# Solid check
				if density >= 0.0:
					var depth = float(h_base - ly)
					if not sampler.is_cave(wx, wy, wz, depth, ly):
						# Temporary solid flag; material classified in subsequent pass
						data.set_voxel(lx, ly, lz, VoxelMaterialClassifier.MAT_STONE)

func _apply_materials(c_size: int, data: VoxelChunkData) -> void:
	for lz in range(-1, c_size + 1):
		for lx in range(-1, c_size + 1):
			classifier.classify_column(data, lx, lz, config)

func _calculate_base_elevation(gx: int, gz: int, bounds: WorldBounds) -> int:
	var wx = (float(gx) + 0.5) * bounds.voxel_size
	var wz = (float(gz) + 0.5) * bounds.voxel_size

	var land_factor = mask.get_factor_world(wx, wz, bounds)
	if land_factor <= 0.001:
		return config.seabed_level

	var b_noise = (base_noise.get_noise_2d(wx, wz) + 1.0) * 0.5
	var elevation = config.base_elevation + b_noise * config.base_noise_amplitude

	var m_sample = mountain_noise.get_noise_2d(wx, wz)
	if m_sample > config.mountain_threshold:
		var m_factor = (m_sample - config.mountain_threshold) / (1.0 - config.mountain_threshold)
		elevation += m_factor * config.mountain_amplitude

	var final_h = float(config.seabed_level) + land_factor * (elevation - float(config.seabed_level))
	return clampi(int(round(final_h)), config.seabed_level, config.chunk_height - 5)
