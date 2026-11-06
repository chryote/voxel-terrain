class_name WorldConfig
extends Resource

## Configuration resource for world dimensions, streaming distances, and limits.

@export_group("World Dimensions")
@export var world_seed: int = 1337
@export var map_size_chunks: Vector2i = Vector2i(256, 256):
	set(val):
		map_size_chunks = Vector2i(
			clampi(val.x, 2, WorldBounds.MAX_MAP_SIZE_CHUNKS),
			clampi(val.y, 2, WorldBounds.MAX_MAP_SIZE_CHUNKS)
		)
@export_range(4, 64) var chunk_size: int = 32
@export_range(0.1, 10.0) var voxel_size: float = 1.0
@export var sea_level: int = 24
@export var max_height: int = 256

@export_group("Streaming & Budget")
@export_range(1, 32) var view_distance_chunks: int = 8
@export_range(0, 16) var collision_distance_chunks: int = 2
@export_range(1, 32) var max_mesh_applies_per_frame: int = 4
@export_range(0.2, 5.0, 0.1) var max_mesh_apply_budget_ms: float = 1.0
@export_range(1, 16) var shell_depth: int = 3

@export_group("World Features")
@export var caves_enabled: bool = true ## Master switch for procedural subterranean caves and chasms
@export var cave_water_enabled: bool = true ## Master switch for subterranean cave water table
var cave_water_table_enabled: bool:
	get: return cave_water_enabled
	set(val): cave_water_enabled = val

@export_group("Extreme Distance LOD")
@export var extreme_lod_enabled: bool = true ## Master switch for continent-wide lowest polygon billboard LOD
@export_range(16, 512, 16) var extreme_lod_resolution: int = 128 ## Subdivisions of continent macro mesh
@export var extreme_lod_clip_margin: float = 16.0 ## Transition and overlap margin in meters
@export var extreme_lod_haze_enabled: bool = true ## Subtle atmospheric distance haze
@export var extreme_lod_haze_color: Color = Color(0.42, 0.50, 0.62, 1.0) ## Subtle muted atmospheric blue
@export_range(0.0, 1.0, 0.05) var extreme_lod_haze_intensity: float = 0.55 ## Peak atmospheric haze blend amount
@export_range(50.0, 2000.0, 50.0) var extreme_lod_haze_start: float = 300.0 ## Start distance in meters
@export_range(500.0, 8000.0, 100.0) var extreme_lod_haze_max_distance: float = 3500.0 ## Full haze distance in meters
@export var extreme_lod_mono_enabled: bool = true ## Unify distant patchwork patterns into monochromatic blue hue family
@export_range(0.0, 1.0, 0.05) var extreme_lod_mono_blend: float = 0.95 ## Monochromatic blend strength
@export var extreme_lod_mono_blue_low: Color = Color(0.42, 0.50, 0.62, 1.0) ## Low elevation / shadow grey-blue hue
@export var extreme_lod_mono_blue_mid: Color = Color(0.42, 0.50, 0.62, 1.0) ## Mid elevation / plateau grey-blue hue
@export var extreme_lod_mono_blue_high: Color = Color(0.42, 0.50, 0.62, 1.0) ## High elevation / peaks grey-blue hue

@export_group("Extreme Distance Pixel Art")
@export var extreme_lod_pixel_art_enabled: bool = true ## Render distant macro terrain as stylized retro pixel art landscape
@export_range(1.0, 16.0, 1.0) var extreme_lod_pixel_size: float = 4.0 ## Screen-space virtual pixel size
@export_range(2.0, 64.0, 2.0) var extreme_lod_terrace_step: float = 16.0 ## Vertical height contour step in meters
@export_range(200.0, 3000.0, 100.0) var extreme_lod_depth_step_distance: float = 800.0 ## Distance per atmospheric depth tier

func create_world_bounds() -> WorldBounds:
	return WorldBounds.new(map_size_chunks, chunk_size, voxel_size)
