class_name CaveGeneratorConfig
extends Resource

## Configuration resource for procedural cave and chasm generation.
## Controls 2D cave mouth detection, 3D worm tunnels, dead ends,
## massive deep chasms, and subterranean water tables.

@export_group("General")
@export var enabled: bool = true ## Global switch enabling or disabling subterranean cave systems and cave mouths

@export_group("2D Cave Mouth & Portals")
@export_range(0.0001, 0.01) var mouth_frequency: float = 0.0012 ## Spatial frequency of cave mouth placement
@export_range(0.5, 0.99) var mouth_threshold: float = 0.76 ## Peak noise threshold required to trigger a cave mouth
@export_range(2.0, 20.0) var mouth_radius: float = 7.0 ## Radius in meters of the surface entrance opening
@export_range(0.0, 10.0) var water_safety_margin: float = 3.0 ## Minimum meters above sea level required for dry-land cave mouths
@export_range(15.0, 60.0) var funnel_descent_angle_deg: float = 35.0 ## Downward slope angle of entrance tunnel connecting surface to caves
@export_range(1.0, 10.0) var crust_depth: float = 3.0 ## Thickness of solid surface crust protected from accidental subterranean punctures
@export_range(5.0, 30.0) var max_entrance_depth: float = 14.0 ## Maximum depth of the entrance descent funnel

@export_group("3D Worm Tunnels & Navigation")
@export_range(0.005, 0.05) var tunnel_frequency: float = 0.016 ## Spatial frequency of 3D worm tunnels
@export_range(1.5, 10.0) var tunnel_radius_base: float = 3.8 ## Base radius of traversable corridors (calibrated for player movement)
@export_range(0.0, 3.0) var tunnel_radius_variation: float = 0.8 ## High-frequency perturbation on tunnel walls
@export_range(0.5, 2.0) var tunnel_vertical_squish: float = 1.15 ## Vertical squish factor (>1 compresses vertically for flatter floors)
@export_range(1.5, 4.0) var min_clearance: float = 2.2 ## Guaranteed minimum vertical clearance for player movement

@export_group("Continuity & Dead Ends")
@export_range(0.001, 0.03) var continuity_frequency: float = 0.006 ## Frequency of modulation noise controlling tunnel continuity
@export_range(-0.5, 0.5) var dead_end_threshold: float = -0.08 ## Threshold below which corridors taper and pinch to a solid dead end
@export_range(1.0, 8.0) var pinch_rate: float = 4.0 ## Sharpness of tunnel termination at dead ends

@export_group("Deep Chasms & Abyssal Caverns")
@export_range(0.001, 0.01) var chasm_frequency: float = 0.0035 ## Low-frequency 3D FBM noise for massive cavern voids
@export_range(0.1, 0.9) var chasm_threshold: float = 0.42 ## Density threshold for hollowing out cavern chambers
@export var chasm_min_y: int = 4 ## Bedrock floor boundary
@export var chasm_max_y: int = 22 ## Vaulted ceiling boundary
@export var chasm_water_level: int = 10 ## Elevation below which carved voids are flooded with subterranean water
@export_range(0.001, 0.02) var pillar_frequency: float = 0.008 ## Frequency of vertical natural support columns
@export_range(0.1, 0.9) var pillar_threshold: float = 0.58 ## Density threshold above which solid rock pillars remain
