class_name VoxelMaterialClassifier
extends RefCounted

## Pure utility for classifying materials in a 3D volumetric chunk column.
## Identifies surface exposure, sunlight, underground depth, and biome thresholds.

const MAT_AIR: int = 0
const MAT_GRASS: int = 1
const MAT_DIRT: int = 2
const MAT_STONE: int = 3
const MAT_SAND: int = 4
const MAT_SNOW: int = 5
const MAT_SEABED: int = 6

func classify_column(data: VoxelChunkData, lx: int, lz: int, config: ContinentGeneratorConfig) -> void:
	var h = data.height
	var dirt_layers_remaining: int = 0

	for ly in range(h - 1, -1, -1):
		var val = data.get_voxel(lx, ly, lz)
		if val == MAT_AIR:
			dirt_layers_remaining = 0
			continue

		# Check if the voxel above is air (exposed top surface)
		var is_top_exposed = (ly == h - 1) or (data.get_voxel(lx, ly + 1, lz) == MAT_AIR)

		if is_top_exposed:
			var mat = _determine_surface_material(ly, config)
			data.set_voxel(lx, ly, lz, mat)
			if mat == MAT_GRASS:
				dirt_layers_remaining = 2
			else:
				dirt_layers_remaining = 0
		else:
			if dirt_layers_remaining > 0:
				data.set_voxel(lx, ly, lz, MAT_DIRT)
				dirt_layers_remaining -= 1
			else:
				# Deep rock, cave walls, or overhang underbelly
				if ly < config.sea_level and val == MAT_SEABED:
					data.set_voxel(lx, ly, lz, MAT_SEABED)
				else:
					data.set_voxel(lx, ly, lz, MAT_STONE)

func _determine_surface_material(y: int, config: ContinentGeneratorConfig) -> int:
	if y < config.sea_level:
		return MAT_SEABED
	elif y <= config.sea_level + config.sand_height_offset:
		return MAT_SAND
	elif y >= config.snow_height:
		return MAT_SNOW
	elif y >= config.stone_height:
		return MAT_STONE
	else:
		return MAT_GRASS
