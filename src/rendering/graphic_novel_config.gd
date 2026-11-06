class_name GraphicNovelConfig
extends Resource

## Configuration resource governing the Graphic Novel / Moebius aesthetic pipeline.
## Provides centralized, data-driven tuning for sky banding, ink outlines, and cel-shaded halftones.

@export_group("Banded Sky Palette")
@export var sky_top_color: Color = Color(0.11, 0.13, 0.16, 1.0)
@export var sky_high_color: Color = Color(0.20, 0.23, 0.28, 1.0)
@export var sky_mid_color: Color = Color(0.29, 0.35, 0.41, 1.0)
@export var sky_low_color: Color = Color(0.25, 0.29, 0.34, 1.0)
@export var sky_horizon_color: Color = Color(0.19, 0.21, 0.25, 1.0)
@export var ground_horizon_color: Color = Color(0.13, 0.14, 0.17, 1.0)
@export var ground_bottom_color: Color = Color(0.06, 0.07, 0.08, 1.0)
@export_range(0.0, 1.0) var high_band_threshold: float = 0.38
@export_range(0.0, 1.0) var mid_band_threshold: float = 0.20
@export_range(0.0, 1.0) var low_band_threshold: float = 0.08
@export_range(-0.2, 0.2) var horizon_band_threshold: float = 0.02
@export_range(0.0, 0.1) var band_smoothness: float = 0.012
@export var sun_enabled: bool = true
@export var sun_color: Color = Color(0.78, 0.83, 0.90, 1.0)
@export_range(0.001, 0.1) var sun_disk_size: float = 0.025

@export_group("Post-Process Outlines")
@export var outlines_enabled: bool = true
@export var outline_color: Color = Color(0.04, 0.04, 0.06, 1.0)
@export_range(0.5, 4.0) var outline_thickness: float = 1.2
@export_range(0.001, 0.5) var depth_threshold: float = 0.05
@export_range(0.05, 1.5) var normal_threshold: float = 0.55
@export_range(10.0, 200.0) var outline_fade_start: float = 45.0
@export_range(20.0, 500.0) var max_outline_distance: float = 150.0

@export_group("Cel-Shading & Halftone Terrain")
@export var halftone_texture: Texture2D = null
@export_range(0.01, 1.0) var halftone_scale: float = 0.15
@export_range(0.0, 1.0) var lit_threshold: float = 0.30
@export var shadow_tint: Color = Color(0.18, 0.16, 0.17, 1.0)
@export_range(0.0, 1.0) var halftone_intensity: float = 0.75
@export var use_procedural_pattern: bool = false

static func create_default_config() -> RefCounted:
	var cfg = new()
	return cfg
