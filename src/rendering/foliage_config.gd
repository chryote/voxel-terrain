class_name FoliageConfig
extends Resource

## Configuration resource governing stylized NPR toon grass rendering.
## Controls wind sway, alpha cutout, screen-space Bayer dither fade, and cel-lighting.

const DEFAULT_TEXTURE_PATH = "res://assets/textures/grass_tuft.png"

@export_group("Texture & Cutout")
@export var albedo_texture: Texture2D = null
@export var albedo_tint: Color = Color(1.0, 1.0, 1.0, 1.0)
@export_range(0.05, 0.95, 0.05) var alpha_scissor_threshold: float = 0.5

@export_group("Wind Sway")
@export var wind_enabled: bool = true
@export_range(0.1, 5.0, 0.1) var wind_speed: float = 1.8
@export_range(0.0, 0.5, 0.01) var wind_strength: float = 0.08
@export_range(0.1, 4.0, 0.1) var wind_turbulence: float = 1.2

@export_group("Distance Dither Fade")
@export var distance_fade_enabled: bool = true
@export_range(10.0, 1000.0, 5.0) var distance_fade_start: float = 45.0
@export_range(20.0, 1200.0, 5.0) var distance_fade_max: float = 60.0

@export_group("Cel Lighting")
@export_range(0.0, 1.0, 0.05) var lit_threshold: float = 0.35
@export var shadow_tint: Color = Color(0.22, 0.24, 0.32, 1.0)

static func create_default_config() -> Resource:
	var cfg = new()
	if ResourceLoader.exists(DEFAULT_TEXTURE_PATH):
		cfg.albedo_texture = load(DEFAULT_TEXTURE_PATH)
	return cfg

