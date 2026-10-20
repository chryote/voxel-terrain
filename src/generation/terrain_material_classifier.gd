class_name TerrainMaterialClassifier
extends RefCounted

## Pure component responsible for classifying terrain top and side materials
## based on elevation, local slope, water table, fluvial context, and climatic moisture.
##
## Decoupled from scene nodes and rendering servers for testability and performance.

var config: ContinentGeneratorConfig

func _init(p_config: ContinentGeneratorConfig) -> void:
	config = p_config

## Classifies surface and side materials returning a Dictionary {"top": id, "side": id}.
## Delegates directly to classify_v2i for single-source-of-truth maintainability.
func classify(h: int, slope: int, water_h: int, is_river: bool = false, is_lake: bool = false, moisture: float = 0.5) -> Dictionary:
	var mats = classify_v2i(h, slope, water_h, is_river, is_lake, moisture)
	return {
		"top": mats.x,
		"side": mats.y
	}

## Fast vectorized material classification returning Vector2i(top_mat_id, side_mat_id).
func classify_v2i(h: int, slope: int, water_h: int, is_river: bool = false, is_lake: bool = false, moisture: float = 0.5) -> Vector2i:
	# 1. Submerged below ocean sea level
	if h < config.sea_level:
		return Vector2i(MaterialDef.ID_SEABED, MaterialDef.ID_SEABED)

	# 2. Submerged riverbed or lakebed (elevated water)
	if h < water_h:
		var bed_mat = MaterialDef.ID_GRAVEL if (is_river or is_lake) else MaterialDef.ID_SAND
		return Vector2i(bed_mat, bed_mat)

	# 3. Beach & shoreline transition (decoupled from elevation via moisture)
	var is_coastal_edge = (h <= config.sea_level + config.sand_height_offset)
	var is_inland_water_edge = (water_h > config.sea_level and h <= water_h + 1 and (is_river or is_lake))

	if is_coastal_edge:
		# Ocean coastal beaches: sand by default unless exceptionally wet
		if moisture < 0.75:
			return Vector2i(MaterialDef.ID_SAND, MaterialDef.ID_SAND)
	elif is_inland_water_edge:
		# Decouple sand from elevation: inland lakes/rivers only spawn sand if moisture is low (arid).
		# High moisture (e.g. inland forest lake) spawns dirt or grass right up to the water's edge.
		if moisture < config.moisture_beach_threshold:
			var bank_mat = MaterialDef.ID_GRAVEL if is_river else MaterialDef.ID_SAND
			return Vector2i(bank_mat, bank_mat)

	# 4. Alpine snow peaks
	if h >= config.snow_height:
		return Vector2i(MaterialDef.ID_SNOW, MaterialDef.ID_STONE)

	# 5. High altitude bare rock
	if h >= config.stone_height:
		return Vector2i(MaterialDef.ID_STONE, MaterialDef.ID_STONE)

	# 6. Slope-based classification (escarpments, cliffs, hillsides, plains)
	if slope >= 3:
		return Vector2i(MaterialDef.ID_STONE, MaterialDef.ID_STONE)
	elif slope == 2:
		return Vector2i(MaterialDef.ID_DIRT, MaterialDef.ID_DIRT)
	else:
		return Vector2i(MaterialDef.ID_GRASS, MaterialDef.ID_DIRT)
