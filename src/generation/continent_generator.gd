class_name ContinentGenerator
extends TerrainGenerator

## Procedural continent generator with mask falloff, fractal hills, and ridged mountains.

var config: ContinentGeneratorConfig
var mask: ContinentMask
var base_noise: FastNoiseLite
var mountain_noise: FastNoiseLite

# Material IDs
const MAT_AIR: int = 0
const MAT_GRASS: int = 1
const MAT_DIRT: int = 2
const MAT_STONE: int = 3
const MAT_SAND: int = 4
const MAT_SNOW: int = 5
const MAT_SEABED: int = 6

func _init(seed_val: int = 1337, p_config: ContinentGeneratorConfig = null) -> void:
	config = p_config if p_config != null else ContinentGeneratorConfig.new()
	mask = ContinentMask.new(seed_val, config)

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

func generate(coord: ChunkCoord, bounds: WorldBounds) -> SurfaceChunkData:
	var c_size = bounds.chunk_size
	var data = SurfaceChunkData.new(c_size)

	# Pass 1: compute heights across chunk and 1-column apron
	for lz in range(-1, c_size + 1):
		var gz = coord.z * c_size + lz
		for lx in range(-1, c_size + 1):
			var gx = coord.x * c_size + lx
			if not bounds.contains_column(gx, gz):
				data.set_height(lx, lz, config.seabed_level)
				data.set_top_material(lx, lz, MAT_SEABED)
				data.set_side_material(lx, lz, MAT_SEABED)
			else:
				var h = _calculate_height(gx, gz, bounds)
				data.set_height(lx, lz, h)

	# Pass 2: compute materials based on height and local slope
	for lz in range(-1, c_size + 1):
		for lx in range(-1, c_size + 1):
			var h = data.get_height(lx, lz)
			var slope = 0
			if lx > -1 and lx < c_size and lz > -1 and lz < c_size:
				var h_l = data.get_height(lx - 1, lz)
				var h_r = data.get_height(lx + 1, lz)
				var h_d = data.get_height(lx, lz - 1)
				var h_u = data.get_height(lx, lz + 1)
				slope = maxi(maxi(absi(h - h_l), absi(h - h_r)), maxi(absi(h - h_d), absi(h - h_u)))

			var mats = _determine_materials(h, slope)
			data.set_top_material(lx, lz, mats.top)
			data.set_side_material(lx, lz, mats.side)

	return data

func height_at(col: Vector2i, bounds: WorldBounds) -> int:
	if not bounds.contains_column(col.x, col.y):
		return config.seabed_level
	return _calculate_height(col.x, col.y, bounds)

func _calculate_height(gx: int, gz: int, bounds: WorldBounds) -> int:
	var wx = (float(gx) + 0.5) * bounds.voxel_size
	var wz = (float(gz) + 0.5) * bounds.voxel_size

	var land_factor = mask.get_factor_world(wx, wz, bounds)
	if land_factor <= 0.001:
		return config.seabed_level

	var b_noise = (base_noise.get_noise_2d(wx, wz) + 1.0) * 0.5 # 0..1
	var elevation = config.base_elevation + b_noise * config.base_noise_amplitude

	# Mountain ridge layer
	var m_sample = mountain_noise.get_noise_2d(wx, wz) # -1..1
	if m_sample > config.mountain_threshold:
		var m_factor = (m_sample - config.mountain_threshold) / (1.0 - config.mountain_threshold)
		elevation += m_factor * config.mountain_amplitude

	var final_h = float(config.seabed_level) + land_factor * (elevation - float(config.seabed_level))
	return clampi(int(round(final_h)), config.seabed_level, 255)

func _determine_materials(h: int, slope: int) -> Dictionary:
	if h < config.sea_level:
		return {"top": MAT_SEABED, "side": MAT_SEABED}
	elif h <= config.sea_level + config.sand_height_offset:
		return {"top": MAT_SAND, "side": MAT_SAND}
	elif h >= config.snow_height:
		return {"top": MAT_SNOW, "side": MAT_STONE}
	elif h >= config.stone_height:
		return {"top": MAT_STONE, "side": MAT_STONE}
	else:
		if slope >= 3:
			return {"top": MAT_STONE, "side": MAT_STONE}
		elif slope == 2:
			return {"top": MAT_DIRT, "side": MAT_DIRT}
		else:
			return {"top": MAT_GRASS, "side": MAT_DIRT}
