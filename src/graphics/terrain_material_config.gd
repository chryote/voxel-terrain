class_name TerrainMaterialConfig
extends Resource

## Configuration resource managing all parameters for terrain shaders,
## multi-layer material palettes, triplanar blending, painting channels,
## and the Studio Ghibli stylized lighting profile.

@export_group("Triplanar Projection")
@export_range(0.01, 2.0, 0.01) var triplanar_scale: float = 0.2
@export_range(1.0, 16.0, 0.5) var triplanar_sharpness: float = 4.0

@export_group("Slope & Elevation Blending")
@export_range(0.1, 0.95, 0.01) var slope_threshold: float = 0.70
@export_range(0.01, 0.5, 0.01) var slope_blend_margin: float = 0.15
@export var beach_height: float = 25.0
@export var beach_blend_margin: float = 3.0
@export var snow_height: float = 140.0
@export var snow_blend_margin: float = 15.0

@export_group("Anti-Tiling & Macro Brush Variation")
@export_range(0.0, 0.5, 0.01) var macro_variation_strength: float = 0.10
@export_range(0.001, 0.1, 0.001) var macro_variation_scale: float = 0.012
@export_range(0.0, 0.2, 0.005) var macro_hue_shift: float = 0.05
@export_range(0.0, 0.3, 0.01) var macro_saturation_shift: float = 0.10

@export_group("Elevation Color Gradients (Depth & Scale)")
@export var gradient_valley_y: float = 25.0
@export var gradient_peak_y: float = 135.0
@export var gradient_valley_tint: Color = Color(0.85, 0.88, 0.98, 1.0) # Cooler, slightly darker
@export var gradient_peak_tint: Color = Color(1.08, 1.04, 0.95, 1.0)   # Warmer, brighter
@export_range(0.0, 1.0, 0.01) var gradient_strength: float = 0.45

@export_group("Soft-Banded Cel Shading (Lighting Model)")
@export var cel_enabled: bool = true
@export_range(0.05, 0.70, 0.01) var cel_shadow_threshold: float = 0.35
@export_range(0.40, 0.95, 0.01) var cel_highlight_threshold: float = 0.72
@export_range(0.01, 0.30, 0.01) var cel_softness: float = 0.08

@export_group("Tinted Ambient Shadows & Light Tints")
@export var shadow_tint: Color = Color(0.42, 0.46, 0.65, 1.0)          # Vibrant cool lavender / sky blue
@export var midtone_tint: Color = Color(1.0, 0.98, 0.95, 1.0)         # Neutral-warm light
@export var highlight_tint: Color = Color(1.15, 1.10, 0.95, 1.0)      # Warm golden sun
@export_range(0.0, 1.0, 0.01) var shadow_ambient_intensity: float = 0.45

@export_group("Directional Rim Lighting (Fresnel)")
@export var rim_enabled: bool = true
@export var rim_color: Color = Color(1.0, 0.95, 0.80, 1.0)            # Warm golden glowing outline
@export_range(1.0, 8.0, 0.1) var rim_power: float = 3.0
@export_range(0.0, 2.0, 0.05) var rim_strength: float = 0.45

@export_group("Biome Tint")
@export var biome_tint: Color = Color.WHITE

@export_group("PBR Base Palette Colors")
@export var grass_color: Color = Color("#567d46")
@export var dirt_color: Color = Color("#6b4f38")
@export var rock_color: Color = Color("#6b6b6b")
@export var sand_color: Color = Color("#d7c58d")
@export var snow_color: Color = Color("#f0f4f8")

@export_group("PBR Base Palette Roughness")
@export_range(0.0, 1.0) var grass_roughness: float = 0.85
@export_range(0.0, 1.0) var dirt_roughness: float = 0.90
@export_range(0.0, 1.0) var rock_roughness: float = 0.75
@export_range(0.0, 1.0) var sand_roughness: float = 0.88
@export_range(0.0, 1.0) var snow_roughness: float = 0.65

@export_group("Paint Layer Overrides (RGBA)")
@export var paint_layer_r_color: Color = Color("#6b4f38") # Dirt / Path
@export_range(0.0, 1.0) var paint_layer_r_roughness: float = 0.92
@export var paint_layer_g_color: Color = Color("#d7c58d") # Sand / Gravel
@export_range(0.0, 1.0) var paint_layer_g_roughness: float = 0.85
@export var paint_layer_b_color: Color = Color("#504e4c") # Cobblestone / Rock
@export_range(0.0, 1.0) var paint_layer_b_roughness: float = 0.70
@export var paint_layer_a_color: Color = Color("#f0f4f8") # Snow / Special
@export_range(0.0, 1.0) var paint_layer_a_roughness: float = 0.60

@export_group("Optional Textures")
@export var use_textures: bool = false
@export var texture_grass_albedo: Texture2D = null
@export var texture_dirt_albedo: Texture2D = null
@export var texture_rock_albedo: Texture2D = null
@export var texture_sand_albedo: Texture2D = null
@export var texture_snow_albedo: Texture2D = null

@export_group("Water Shader Parameters")
@export var water_shallow_color: Color = Color(0.18, 0.55, 0.72, 0.85)
@export var water_deep_color: Color = Color(0.05, 0.22, 0.42, 0.95)
@export var water_foam_color: Color = Color(0.9, 0.95, 1.0, 0.8)
@export_range(0.1, 5.0) var water_speed: float = 1.2
@export_range(0.0, 1.0) var water_amplitude: float = 0.15

@export_group("Cave & Subterranean Parameters")
@export var cave_rock_color: Color = Color(0.18, 0.19, 0.20, 1.0)
@export var cave_basalt_color: Color = Color(0.12, 0.13, 0.14, 1.0)
@export var cave_crystal_color: Color = Color(0.26, 0.78, 0.82, 1.0)
@export_range(0.0, 5.0) var cave_crystal_energy: float = 1.8
@export_range(0.0, 1.0) var cave_wetness: float = 0.35

static func create_default_config() -> TerrainMaterialConfig:
	return TerrainMaterialConfig.new()
