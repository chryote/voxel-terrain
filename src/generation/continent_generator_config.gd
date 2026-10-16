class_name ContinentGeneratorConfig
extends Resource

## Configuration resource for procedural continent terrain generation with realistic topography.

@export_group("Continent Shape & Mask")
@export var coast_falloff_distance: float = 600.0 ## Distance from map border where land fades to ocean
@export var coast_warp_amplitude: float = 250.0  ## Noise displacement on continent coastline
@export var coast_warp_frequency: float = 0.0018
@export var continent_noise_frequency: float = 0.00065 ## Macro continentalness noise frequency
@export var inland_elevation_bias: float = 8.0 ## Flat elevation lift added to continental landmass to prevent noise dips from dropping below sea level

@export_group("Erosion & Lowlands")
@export var erosion_frequency: float = 0.0012
@export var lowland_base_elevation: float = 25.0
@export var lowland_amplitude: float = 8.0
@export var lowland_frequency: float = 0.003

@export_group("Rolling Hills")
@export var rolling_hills_amplitude: float = 24.0
@export var rolling_hills_frequency: float = 0.0035

@export_group("Highlands & Plateaus")
@export var highland_threshold: float = 0.55
@export var highland_boost: float = 60.0
@export var highland_frequency: float = 0.0012

@export_group("Mountains")
@export var mountain_amplitude: float = 85.0
@export var mountain_frequency: float = 0.004
@export var mountain_threshold: float = 0.45
@export var mountain_power: float = 1.6 ## Power curve exponent to widen mountain base and round peaks
@export var mountain_octaves: int = 4
@export var mountain_fractal_gain: float = 0.32 ## Reduced persistence to smooth out secondary noisy spikes and boulders into natural rolling ridges
@export var mountain_lacunarity: float = 2.0

@export_group("Climate & Moisture")
@export var moisture_frequency: float = 0.0008 ## Low frequency for macro moisture map
@export var moisture_octaves: int = 3
@export var moisture_fractal_gain: float = 0.4
@export var moisture_beach_threshold: float = 0.40 ## Moisture threshold below which water edges spawn sand, and above which water edges spawn lush grass/dirt

@export_group("Wide Rivers")
@export var wide_river_frequency: float = 0.00075
@export var wide_river_warp_amplitude: float = 120.0
@export var wide_river_width_threshold: float = 0.020 ## Controls river channel half-width (~20-30m)
@export var wide_river_depth: float = 12.0

@export_group("Small Winding Rivers")
@export var small_river_frequency: float = 0.0028
@export var small_river_warp_amplitude: float = 40.0
@export var small_river_width_threshold: float = 0.024 ## Controls stream channel half-width (~4-6m)
@export var small_river_depth: float = 4.0

@export_group("Lakes")
@export var lake_frequency: float = 0.00075
@export var lake_threshold: float = 0.68
@export var lake_depth: float = 7.0

@export_group("Levels & Materials")
@export var sea_level: int = 24
@export var seabed_level: int = 6
@export var sand_height_offset: int = 2
@export var stone_height: int = 90
@export var snow_height: int = 125

@export_group("Legacy / Base Fallback")
@export var base_elevation: float = 22.0
@export var base_noise_amplitude: float = 35.0
@export var base_noise_frequency: float = 0.004
@export var fractal_octaves: int = 4
@export var fractal_lacunarity: float = 2.0
@export var fractal_gain: float = 0.5
