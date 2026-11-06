class_name ToonWaterConfig
extends Resource

## Configuration resource governing stylized NPR toon water shading.
## Controls hard-edge depth foam, stepped color horizons, and cellular graphic ripples.

@export_group("Foam Line")
@export var foam_enabled: bool = true
@export var foam_color: Color = Color(0.52, 0.49, 0.44, 1.0)
@export_range(0.02, 2.0, 0.01) var foam_thickness: float = 0.35

@export_group("Stepped Depth Colors")
@export var shallow_color: Color = Color(0.24, 0.27, 0.25, 0.88)
@export var mid_color: Color = Color(0.16, 0.19, 0.20, 0.92)
@export var deep_color: Color = Color(0.08, 0.10, 0.12, 0.96)
@export_range(0.2, 5.0, 0.1) var shallow_threshold: float = 1.5
@export_range(1.0, 20.0, 0.5) var deep_threshold: float = 5.0

@export_group("Stylized Ripples")
@export var ripples_enabled: bool = true
@export_range(1.0, 32.0, 1.0) var pixel_density: float = 8.0
@export_range(0.01, 1.0, 0.01) var ripple_scale: float = 0.08
@export_range(0.1, 1.2, 0.01) var ripple_radius: float = 0.65
@export_range(0.01, 1.0, 0.01) var ripple_speed: float = 0.08
@export_range(0.01, 0.25, 0.005) var ripple_threshold: float = 0.05
@export var ripple_color: Color = Color(0.38, 0.39, 0.36, 0.45)

@export_group("Side Face Fluid")
@export_range(0.5, 5.0, 0.1) var side_fluid_speed: float = 2.2

static func create_default_config() -> Resource:
	return new()

static func create_ocean_config() -> Resource:
	var cfg = new()
	cfg.foam_enabled = false
	cfg.ripples_enabled = false
	cfg.foam_thickness = 0.0
	cfg.shallow_color = Color(0.22, 0.25, 0.24, 0.90)
	cfg.mid_color = Color(0.15, 0.18, 0.19, 0.94)
	cfg.deep_color = Color(0.09, 0.11, 0.13, 0.98)
	cfg.shallow_threshold = 2.0
	cfg.deep_threshold = 12.0
	return cfg

static func create_subterranean_config() -> Resource:
	var cfg = new()
	cfg.foam_color = Color(0.42, 0.44, 0.43, 1.0)
	cfg.foam_thickness = 0.25
	cfg.shallow_color = Color(0.12, 0.18, 0.20, 0.92)
	cfg.mid_color = Color(0.07, 0.11, 0.13, 0.96)
	cfg.deep_color = Color(0.03, 0.05, 0.06, 0.99)
	cfg.shallow_threshold = 1.0
	cfg.deep_threshold = 3.5
	cfg.ripple_speed = 0.02
	cfg.ripple_threshold = 0.03
	return cfg

static func create_preset(name: String) -> Resource:
	match name:
		"ocean", "sea":
			return create_ocean_config()
		"subterranean", "cave":
			return create_subterranean_config()
		"alpine_lake":
			var cfg = new()
			cfg.shallow_color = Color(0.35, 0.78, 0.92, 0.80)
			cfg.mid_color = Color(0.18, 0.52, 0.78, 0.88)
			cfg.deep_color = Color(0.09, 0.28, 0.48, 0.94)
			cfg.foam_thickness = 0.40
			return cfg
		"toxic_chasm":
			var cfg = new()
			cfg.foam_color = Color(0.75, 1.0, 0.65, 1.0)
			cfg.shallow_color = Color(0.32, 0.75, 0.28, 0.90)
			cfg.mid_color = Color(0.18, 0.48, 0.22, 0.95)
			cfg.deep_color = Color(0.08, 0.24, 0.12, 0.98)
			cfg.ripple_color = Color(0.85, 1.0, 0.75, 0.90)
			return cfg
		_:
			return create_default_config()
