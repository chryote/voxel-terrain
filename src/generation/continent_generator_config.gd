class_name ContinentGeneratorConfig
extends Resource

## Configuration resource for procedural continent terrain generation with realistic topography.

@export_group("Continent Shape & Mask")
@export_range(0.5, 0.95) var continent_radius: float = 0.83 ## Target continent radius as fraction of map extent [0.5..0.95]
@export var coast_falloff_distance: float = 600.0 ## Distance from map border where land fades to ocean
@export var coast_warp_amplitude: float = 250.0  ## Noise displacement on continent coastline
@export var coast_warp_frequency: float = 0.0018
@export var continent_noise_frequency: float = 0.00065 ## Macro continentalness noise frequency
@export var inland_elevation_bias: float = 8.0 ## Flat elevation lift added to continental landmass to prevent noise dips from dropping below sea level

@export_group("Offshore Islands")
@export var islands_enabled: bool = true ## Generates offshore cliff islands with stepped stone stair terraces in coastal ocean waters
@export var island_frequency: float = 0.0012 ## Island noise frequency
@export var island_threshold: float = 0.68 ## Higher values yield fewer, more isolated offshore islands
@export var island_boost: float = 0.25 ## Land raw boost for offshore islands
@export var island_cliff_height: float = 16.0 ## Flat vertical elevation raise (in meters above sea level) for offshore cliff islands
@export var island_terrace_step_height: int = 1 ## Vertical height (in blocks) of each regular stone stair terrace step on the ocean entry ramp
@export var island_terrace_span: float = 0.55 ## Fraction of island radius spanned by the ocean entry stair-terrace ramp

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
@export var wide_river_water_recede: float = 3.0 ## Meters below uncarved bank top where wide river water surface sits (higher = water recedes deeper into carved channel)

@export_group("Small Winding Rivers")
@export var small_river_frequency: float = 0.0028
@export var small_river_warp_amplitude: float = 40.0
@export var small_river_width_threshold: float = 0.022 ## Controls stream channel half-width (~4-7m)
@export var small_river_depth: float = 5.5
@export var small_river_water_recede: float = 2.0 ## Meters below uncarved bank top where stream water surface sits (higher = narrower wet stream recessed inside banks)

@export_group("Lakes")
@export var lake_frequency: float = 0.00075
@export var lake_threshold: float = 0.68 ## Higher values [0.65..0.78] make lakes rarer and more contained
@export var lake_depth: float = 10.0
@export var lake_water_recede: float = 2.5 ## Meters below outer basin rim where lake water surface sits

@export_group("Ponds")
@export var pond_frequency: float = 0.0024
@export var pond_threshold: float = 0.72 ## Higher values [0.70..0.82] make ponds smaller and more isolated
@export var pond_depth: float = 6.0
@export var pond_water_recede: float = 2.0 ## Meters below surrounding bank where pond water surface sits

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
