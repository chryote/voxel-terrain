class_name GraphicNovelConfig
extends Resource

## Configuration resource governing the Graphic Novel / Moebius aesthetic pipeline.
## Provides centralized, data-driven tuning for sky banding, ink outlines, and cel-shaded halftones.

@export_group("Banded Sky Palette")
@export var sky_top_color: Color = Color(0.10, 0.14, 0.11, 1.0)
@export var sky_high_color: Color = Color(0.18, 0.25, 0.19, 1.0)
@export var sky_mid_color: Color = Color(0.27, 0.38, 0.28, 1.0)
@export var sky_low_color: Color = Color(0.23, 0.32, 0.24, 1.0)
@export var sky_horizon_color: Color = Color(0.18, 0.24, 0.19, 1.0)
@export var ground_horizon_color: Color = Color(0.12, 0.16, 0.13, 1.0)
@export var ground_bottom_color: Color = Color(0.06, 0.08, 0.06, 1.0)
@export_range(0.0, 1.0) var high_band_threshold: float = 0.38
@export_range(0.0, 1.0) var mid_band_threshold: float = 0.20
@export_range(0.0, 1.0) var low_band_threshold: float = 0.08
@export_range(-0.2, 0.2) var horizon_band_threshold: float = 0.02
@export_range(0.0, 0.1) var band_smoothness: float = 0.012
@export var sun_enabled: bool = true
@export var sun_color: Color = Color(0.80, 0.86, 0.78, 1.0)
@export_range(0.001, 0.1) var sun_disk_size: float = 0.025

@export_group("Post-Process Outlines")
@export var outlines_enabled: bool = true
@export var outline_color: Color = Color(0.04, 0.04, 0.06, 1.0)
@export_range(0.5, 4.0) var outline_thickness: float = 1.2
@export_range(0.001, 0.5) var depth_threshold: float = 0.05
@export_range(0.05, 1.5) var normal_threshold: float = 0.55
@export_range(10.0, 200.0) var outline_fade_start: float = 45.0
@export_range(20.0, 500.0) var max_outline_distance: float = 150.0

@export_group("Vignette Settings")
@export var vignette_enabled: bool = true
@export var vignette_color: Color = Color(0.02, 0.02, 0.03, 1.0)
@export_range(0.0, 1.0) var vignette_intensity: float = 0.45
@export_range(0.0, 1.0) var vignette_radius: float = 0.28
@export_range(0.05, 1.0) var vignette_softness: float = 0.42

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
