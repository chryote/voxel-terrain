class_name FoliageGeneratorConfig
extends Resource

## Configuration resource for procedural grass scatter and instanced foliage distribution.
## Pure data resource with zero scene tree or Node dependencies.

@export var enabled: bool = true
@export var world_seed: int = 1337

@export_group("Density & Placement")
@export_range(0.0, 1.0, 0.05) var density_probability: float = 0.55 ## Probability of placing foliage tufts on a candidate voxel
@export_range(1, 4, 1) var max_tufts_per_voxel: int = 2 ## Maximum tuft instances scattered on a single voxel
@export_range(0.05, 0.45, 0.05) var jitter_spread: float = 0.35 ## Horizontal jitter offset from voxel center (+/- meters)
@export var target_material_id: int = 1 ## Default: MaterialDef.ID_GRASS

@export_group("Transform Variation")
@export_range(0.3, 1.5, 0.05) var min_scale: float = 0.75 ## Minimum uniform scale multiplier
@export_range(0.5, 2.5, 0.05) var max_scale: float = 1.25 ## Maximum uniform scale multiplier
@export var random_y_rotation: bool = true ## Random yaw rotation [0..2*PI]

