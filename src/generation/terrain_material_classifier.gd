class_name TerrainMaterialClassifier
extends RefCounted

## Pure component responsible for classifying terrain top and side materials
## based on elevation, local slope, water table, and fluvial context.

var config: ContinentGeneratorConfig

func _init(p_config: ContinentGeneratorConfig) -> void:
	config = p_config

func classify(h: int, slope: int, water_h: int, is_river: bool = false, is_lake: bool = false) -> Dictionary:
	# 1. Submerged below ocean sea level
	if h < config.sea_level:
		return {
			"top": MaterialDef.ID_SEABED,
			"side": MaterialDef.ID_SEABED
		}

	# 2. Submerged riverbed or lakebed (elevated water)
	if h < water_h:
		var bed_mat = MaterialDef.ID_GRAVEL if (is_river or is_lake) else MaterialDef.ID_SAND
		return {
			"top": bed_mat,
			"side": bed_mat
		}

	# 3. Beach & shoreline transition
	if h <= config.sea_level + config.sand_height_offset or (water_h > config.sea_level and h <= water_h + 1 and (is_river or is_lake)):
		return {
			"top": MaterialDef.ID_SAND,
			"side": MaterialDef.ID_SAND
		}

	# 4. Alpine snow peaks
	if h >= config.snow_height:
		return {
			"top": MaterialDef.ID_SNOW,
			"side": MaterialDef.ID_STONE
		}

	# 5. High altitude bare rock
	if h >= config.stone_height:
		return {
			"top": MaterialDef.ID_STONE,
			"side": MaterialDef.ID_STONE
		}

	# 6. Slope-based classification (escarpments, cliffs, hillsides, plains)
	if slope >= 3:
		# Vertical cliff or plateau escarpment
		return {
			"top": MaterialDef.ID_STONE,
			"side": MaterialDef.ID_STONE
		}
	elif slope == 2:
		# Steep hillside
		return {
			"top": MaterialDef.ID_DIRT,
			"side": MaterialDef.ID_DIRT
		}
	else:
		# Flat to gentle rolling terrain
		return {
			"top": MaterialDef.ID_GRASS,
			"side": MaterialDef.ID_DIRT
		}

func classify_v2i(h: int, slope: int, water_h: int, is_river: bool = false, is_lake: bool = false) -> Vector2i:
	if h < config.sea_level:
		return Vector2i(MaterialDef.ID_SEABED, MaterialDef.ID_SEABED)

	if h < water_h:
		var bed_mat = MaterialDef.ID_GRAVEL if (is_river or is_lake) else MaterialDef.ID_SAND
		return Vector2i(bed_mat, bed_mat)

	if h <= config.sea_level + config.sand_height_offset or (water_h > config.sea_level and h <= water_h + 1 and (is_river or is_lake)):
		return Vector2i(MaterialDef.ID_SAND, MaterialDef.ID_SAND)

	if h >= config.snow_height:
		return Vector2i(MaterialDef.ID_SNOW, MaterialDef.ID_STONE)

	if h >= config.stone_height:
		return Vector2i(MaterialDef.ID_STONE, MaterialDef.ID_STONE)

	if slope >= 3:
		return Vector2i(MaterialDef.ID_STONE, MaterialDef.ID_STONE)
	elif slope == 2:
		return Vector2i(MaterialDef.ID_DIRT, MaterialDef.ID_DIRT)
	else:
		return Vector2i(MaterialDef.ID_GRASS, MaterialDef.ID_DIRT)
