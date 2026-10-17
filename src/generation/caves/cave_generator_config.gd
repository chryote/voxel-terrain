class_name CaveGeneratorConfig
extends Resource

## Configuration resource for procedural cave and chasm generation.
## Controls 2D cave mouth detection, 3D worm tunnels, dead ends,
## massive deep chasms, and subterranean water tables.

@export_group("General")
@export var enabled: bool = true ## Global switch enabling or disabling subterranean cave systems and cave mouths

@export_group("2D Cave Mouth & Portals")
@export_range(0.0001, 0.01) var mouth_frequency: float = 0.0012 ## Spatial frequency of cave mouth placement
@export_range(0.2, 0.9) var mouth_threshold: float = 0.50 ## Peak noise threshold required to trigger a cave mouth
@export_range(2.0, 20.0) var mouth_radius: float = 7.0 ## Radius in meters of the surface entrance opening
@export_range(0.0, 10.0) var water_safety_margin: float = 3.0 ## Minimum meters above sea level required for dry-land cave mouths
@export_range(15.0, 60.0) var funnel_descent_angle_deg: float = 35.0 ## Downward slope angle of entrance tunnel connecting surface to caves
@export_range(1.0, 10.0) var crust_depth: float = 3.0 ## Thickness of solid surface crust protected from accidental subterranean punctures
@export_range(5.0, 30.0) var max_entrance_depth: float = 14.0 ## Maximum depth of the entrance descent funnel

@export_group("Cave Mouth Generation Limits")
@export var limit_cave_mouths: bool = true ## Master switch to limit cave mouth generation across continent
@export var max_chasm_mouths: int = 1 ## Maximum allowed cave mouths leading to underground chasms
@export var max_tunnel_mouths: int = 2 ## Maximum allowed cave mouths leading to interconnected 3D tunnels
@export var max_dead_end_mouths: int = 3 ## Maximum allowed shallow dead-end cave mouths

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

@export_group("Deep Chasms & Abyssal Caverns (Dual 2D Heightfield)")
@export_range(0.001, 0.01) var chasm_rift_frequency: float = 0.003 ## 2D noise frequency for rift corridors
@export_range(0.1, 0.9) var chasm_rift_threshold: float = 0.45 ## Width/density threshold for rift void
@export_range(0.005, 0.05) var chasm_wall_warp_frequency: float = 0.015 ## Frequency of rock wall perturbation
@export_range(1.0, 10.0) var chasm_wall_warp_amplitude: float = 4.0 ## Distance in meters vertical walls wander
@export var chasm_min_y: int = 4 ## Base bedrock elevation
@export var chasm_max_y: int = 24 ## Base vaulted ceiling elevation
@export_range(1.0, 6.0) var chasm_floor_variation: float = 3.0 ## Amplitude of floor height undulations
@export_range(1.0, 6.0) var chasm_ceil_variation: float = 4.0 ## Amplitude of ceiling height undulations
@export_range(3.0, 10.0) var min_chasm_height: float = 5.0 ## Guaranteed clearance between floor and ceiling
@export var chasm_water_level: int = 10 ## Elevation below which cavern voids pool water
@export_range(0.001, 0.02) var pillar_frequency: float = 0.008 ## Frequency of stone support pillars
@export_group("Chasm Battle Arenas & POIs")
@export var arena_enabled: bool = true ## Enable procedural subterranean battle arenas
@export_range(0.70, 0.95) var arena_rift_threshold: float = 0.85 ## Rift corridor density threshold to anchor arenas
@export var arena_floor_y: int = 12 ## Flattened arena combat elevation (elevated above water level)
@export var arena_ceiling_y: int = 28 ## Vaulted ceiling dome elevation in battle arenas
@export var arena_ledge_step_height: int = 2 ## Height delta for stepped spectator ledges along perimeter
@export var bypass_chasm_voxelization: bool = true ## Bypass 3D voxel allocation for pure chasm chunks

## Backward compatibility properties for 3D legacy callers
var chasm_frequency: float:
	get: return chasm_rift_frequency
	set(val): chasm_rift_frequency = val

var chasm_threshold: float:
	get: return chasm_rift_threshold
	set(val): chasm_rift_threshold = val

