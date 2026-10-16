class_name ContinentGenerator
extends TerrainGenerator

## Procedural continent generator with realistic multi-noise topography:
## Coasts, Lowlands, Rolling Hills, Highlands, Mountains, Wide Rivers,
## Small Winding Rivers, and Lakes.
##
## Built with decoupled components:
## - ContinentMask (boundary falloff)
## - MacroTopography (macro continentalness, erosion, relief, plateaus, mountains)
## - FluvialCarver (wide rivers, small winding streams, lake basins)
## - TerrainMaterialClassifier (slope, altitude, and water table classification)

const MacroTopography = preload("res://src/generation/macro_topography.gd")
const FluvialCarver = preload("res://src/generation/fluvial_carver.gd")
const TerrainMaterialClassifier = preload("res://src/generation/terrain_material_classifier.gd")

var config: ContinentGeneratorConfig
var mask: ContinentMask
var macro: MacroTopography
var fluvial: FluvialCarver
var classifier: TerrainMaterialClassifier

# Strongly-typed material IDs mapped from MaterialDef
const MAT_AIR: int = MaterialDef.ID_AIR
const MAT_GRASS: int = MaterialDef.ID_GRASS
const MAT_DIRT: int = MaterialDef.ID_DIRT
const MAT_STONE: int = MaterialDef.ID_STONE
const MAT_SAND: int = MaterialDef.ID_SAND
const MAT_SNOW: int = MaterialDef.ID_SNOW
const MAT_SEABED: int = MaterialDef.ID_SEABED
const MAT_GRAVEL: int = MaterialDef.ID_GRAVEL

func _init(seed_val: int = 1337, p_config: ContinentGeneratorConfig = null) -> void:
	config = p_config if p_config != null else ContinentGeneratorConfig.new()
	mask = ContinentMask.new(seed_val, config)
	macro = MacroTopography.new(seed_val, config, mask)
	fluvial = FluvialCarver.new(seed_val, config)
	classifier = TerrainMaterialClassifier.new(config)

func generate(coord: ChunkCoord, bounds: WorldBounds) -> SurfaceChunkData:
	var c_size = bounds.chunk_size
	var data = SurfaceChunkData.new(c_size)
	var apron_w = c_size + 2
	var total_columns = apron_w * apron_w

	# Fluvial flags: bit 0 = is_river, bit 1 = is_lake
	var fluvial_flags = PackedByteArray()
	fluvial_flags.resize(total_columns)
	fluvial_flags.fill(0)

	# -------------------------------------------------------------------------
	# Pass 1: Calculate raw elevation, water table, and fluvial channels
	# -------------------------------------------------------------------------
	for lz in range(-1, c_size + 1):
		var gz = coord.z * c_size + lz
		for lx in range(-1, c_size + 1):
			var gx = coord.x * c_size + lx
			var col_idx = (lx + 1) + (lz + 1) * apron_w

			if not bounds.contains_column(gx, gz):
				data.set_height(lx, lz, config.seabed_level)
				data.set_water_height(lx, lz, config.sea_level)
				data.set_top_material(lx, lz, MAT_SEABED)
				data.set_side_material(lx, lz, MAT_SEABED)
			else:
				var wx = (float(gx) + 0.5) * bounds.voxel_size
				var wz = (float(gz) + 0.5) * bounds.voxel_size

				var m_v2 = macro.sample_macro_v2(wx, wz, bounds)
				var f_v3 = fluvial.sample_fluvial_v3(wx, wz, m_v2.x, m_v2.y)

				var final_h = clampi(int(round(m_v2.x - f_v3.x)), config.seabed_level, 255)
				data.set_height(lx, lz, final_h)
				data.set_water_height(lx, lz, int(f_v3.y))
				fluvial_flags[col_idx] = int(f_v3.z)

	# -------------------------------------------------------------------------
	# Pass 2: Calculate local 4-directional slope and classify materials
	# -------------------------------------------------------------------------
	for lz in range(-1, c_size + 1):
		for lx in range(-1, c_size + 1):
			var col_idx = (lx + 1) + (lz + 1) * apron_w
			var h = data.get_height(lx, lz)
			var water_h = data.get_water_height(lx, lz)
			var flags = fluvial_flags[col_idx]
			var is_river = (flags & 1) != 0
			var is_lake = (flags & 2) != 0

			var slope = 0
			if lx > -1 and lx < c_size and lz > -1 and lz < c_size:
				var h_l = data.get_height(lx - 1, lz)
				var h_r = data.get_height(lx + 1, lz)
				var h_d = data.get_height(lx, lz - 1)
				var h_u = data.get_height(lx, lz + 1)
				slope = maxi(maxi(absi(h - h_l), absi(h - h_r)), maxi(absi(h - h_d), absi(h - h_u)))

			var mats_v2i = classifier.classify_v2i(h, slope, water_h, is_river, is_lake)
			data.set_top_material(lx, lz, mats_v2i.x)
			data.set_side_material(lx, lz, mats_v2i.y)

	return data

func height_at(col: Vector2i, bounds: WorldBounds) -> int:
	if not bounds.contains_column(col.x, col.y):
		return config.seabed_level

	var wx = (float(col.x) + 0.5) * bounds.voxel_size
	var wz = (float(col.y) + 0.5) * bounds.voxel_size

	var m_v2 = macro.sample_macro_v2(wx, wz, bounds)
	var f_v3 = fluvial.sample_fluvial_v3(wx, wz, m_v2.x, m_v2.y)

	return clampi(int(round(m_v2.x - f_v3.x)), config.seabed_level, 255)

func water_height_at(col: Vector2i, bounds: WorldBounds) -> int:
	if not bounds.contains_column(col.x, col.y):
		return config.sea_level

	var wx = (float(col.x) + 0.5) * bounds.voxel_size
	var wz = (float(col.y) + 0.5) * bounds.voxel_size

	var m_v2 = macro.sample_macro_v2(wx, wz, bounds)
	var f_v3 = fluvial.sample_fluvial_v3(wx, wz, m_v2.x, m_v2.y)

	return int(round(f_v3.y))

func is_water_at(col: Vector2i, bounds: WorldBounds) -> bool:
	if not bounds.contains_column(col.x, col.y):
		return true

	var wx = (float(col.x) + 0.5) * bounds.voxel_size
	var wz = (float(col.y) + 0.5) * bounds.voxel_size

	var m_v2 = macro.sample_macro_v2(wx, wz, bounds)
	var f_v3 = fluvial.sample_fluvial_v3(wx, wz, m_v2.x, m_v2.y)

	var h = m_v2.x - f_v3.x
	return h < f_v3.y

func sample_world(wx: float, wz: float, bounds: WorldBounds) -> Dictionary:
	var m_data = macro.sample_macro(wx, wz, bounds)
	var f_data = fluvial.sample_fluvial(wx, wz, m_data.elevation, m_data.continentalness)
	var final_h = clampi(int(round(m_data.elevation - f_data.carve_depth)), config.seabed_level, 255)

	return {
		"height": final_h,
		"water_height": f_data.water_elevation,
		"carve_depth": f_data.carve_depth,
		"continentalness": m_data.continentalness,
		"erosion": m_data.erosion,
		"is_highland": m_data.is_highland,
		"is_mountain": m_data.is_mountain,
		"is_river": f_data.is_river,
		"is_lake": f_data.is_lake,
		"is_water": f_data.is_water
	}
