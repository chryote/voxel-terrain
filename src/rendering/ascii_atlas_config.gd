class_name AsciiAtlasConfig
extends Resource

## Configuration resource governing ASCII Map Atlas texturing on voxel faces.
## Controls glyph frequency per voxel, faux-depth relief, cavity shadowing, and lighting integration.

@export_group("Atlas Layout")
@export var atlas_texture: Texture2D = null
@export var grid_columns: int = 16
@export var grid_rows: int = 16
@export var cell_size_px: int = 16

@export_group("Voxel Face Mapping")
@export_range(1.0, 24.0, 0.5) var glyphs_per_voxel: float = 10.0
@export var material_glyph_lut: Texture2D = null

@export_group("Faux-Depth & Subtlety")
@export_range(0.05, 1.0, 0.05) var glyph_contrast: float = 0.30
@export_range(0.0, 1.0, 0.05) var depth_relief_strength: float = 0.15
@export_range(0.0, 1.0, 0.05) var cavity_shadow_intensity: float = 0.25
@export_range(0.02, 0.5, 0.01) var macro_variation_scale: float = 0.08
@export_range(0.0, 0.05, 0.005) var parallax_strength: float = 0.015

@export_group("Cel-Lighting Integration")
@export_range(0.0, 1.0, 0.05) var lit_threshold: float = 0.30
@export var shadow_tint: Color = Color(0.22, 0.24, 0.32, 1.0)

@export_group("Sedimentary Strata")
@export var strata_enabled: bool = true
@export var strata_group: String = "soil"
@export var strata_preset: String = "loam_temperate"
@export_range(0.05, 1.0, 0.05) var strata_frequency: float = 0.35
@export_range(0.0, 1.0, 0.05) var strata_warp_strength: float = 0.50

static func create_default_config() -> Resource:
	var cfg = new()
	return cfg
