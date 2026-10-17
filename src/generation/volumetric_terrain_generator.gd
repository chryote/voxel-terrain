class_name VolumetricTerrainGenerator
extends LayeredTerrainGenerator

## 3D Volumetric Terrain Generator executing procedural macro topography,
## fluvial carving, and 3D subterranean cave carving (caves, dead ends, chasms, and water pools).
## Produces VoxelChunkData for 3D greedy meshing and physics.
##
## Inherits from LayeredTerrainGenerator to support both seamless monolithic generation
## and demand-driven two-phase surface-first lazy streaming.

func _init(seed_val: int = 1337, p_config: ContinentGeneratorConfig = null, p_cave_config: CaveGeneratorConfig = null) -> void:
	super(seed_val, p_config, p_cave_config)
