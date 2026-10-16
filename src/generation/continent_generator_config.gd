class_name ContinentGeneratorConfig
extends Resource

## Configuration resource for procedural continent terrain generation.

@export_group("Continent Shape & Mask")
@export var coast_falloff_distance: float = 600.0 ## Distance from map border where land fades to ocean
@export var coast_warp_amplitude: float = 250.0  ## Noise displacement on continent coastline
@export var coast_warp_frequency: float = 0.002

@export_group("Elevation & Noise")
@export var base_elevation: float = 22.0
@export var base_noise_amplitude: float = 35.0
@export var base_noise_frequency: float = 0.004
@export var fractal_octaves: int = 4
@export var fractal_lacunarity: float = 2.0
@export var fractal_gain: float = 0.5

@export_group("Mountains")
@export var mountain_amplitude: float = 85.0
@export var mountain_frequency: float = 0.006
@export var mountain_threshold: float = 0.45

@export_group("Levels & Materials")
@export var sea_level: int = 24
@export var seabed_level: int = 6
@export var sand_height_offset: int = 2
@export var stone_height: int = 90
@export var snow_height: int = 125
