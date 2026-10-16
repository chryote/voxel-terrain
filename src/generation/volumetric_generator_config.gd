class_name VolumetricGeneratorConfig
extends ContinentGeneratorConfig

## Configuration resource for 3D volumetric continent generation (overhangs & caves).

@export_group("3D Overhangs")
@export var overhang_amplitude: float = 16.0    ## Maximum vertical/horizontal bulge of overhangs
@export var overhang_frequency: float = 0.015    ## Frequency of 3D overhang shape noise
@export var overhang_threshold: float = 0.15    ## Threshold above which 3D noise expands solid rock

@export_group("3D Caves")
@export var cave_cheese_threshold: float = 0.52 ## Threshold for spacious caverns (lower = larger caves)
@export var cave_cheese_frequency: float = 0.016
@export var cave_worm_threshold: float = 0.035  ## Threshold for twisting tunnels (higher = wider tunnels)
@export var cave_worm_frequency: float = 0.020
@export var cave_min_depth: int = 4             ## Minimum blocks below surface before caves can carve
@export var cave_seabed_buffer: int = 4         ## Blocks above seabed where caves are suppressed

@export_group("Vertical Limits")
@export var chunk_height: int = 128             ## Maximum vertical voxel height per chunk
@export var bedrock_level: int = 2              ## Bottom-most unbreakable rock floor
