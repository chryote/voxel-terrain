class_name ContinentMapColorPalette
extends RefCounted

## Pure component defining cartographic colors, hillshading lighting,
## and topographic hypsometric tinting for continent maps.
##
## Decoupled from scene nodes and rendering backends for testability.

# Material Colors
var color_deep_ocean: Color = Color("#132e48")
var color_shallow_ocean: Color = Color("#2a6894")
var color_water_body: Color = Color("#2e7ca8")
var color_beach_sand: Color = Color("#d8c78c")
var color_alpine_snow: Color = Color("#f4f7fb")
var color_mountain_stone: Color = Color("#787878")
var color_slope_dirt: Color = Color("#6b4f38")
var color_plains_grass: Color = Color("#567d46")
var color_gravel_bed: Color = Color("#6e6b63")

# Cartographic standard NW light direction (315° azimuth, ~45° altitude)
var light_direction: Vector3 = Vector3(-0.6, 1.2, -0.6).normalized()
var relief_strength: float = 0.45
var ambient_base: float = 0.68
var elevation_boost_factor: float = 0.12

func get_water_color(h: int, sea_level: int) -> Color:
	if h < sea_level:
		var depth = clampf(float(sea_level - h) / 20.0, 0.0, 1.0)
		return color_shallow_ocean.lerp(color_deep_ocean, depth)
	return color_water_body

func get_land_color(h: int, slope_grade: float, water_h: int, sea_level: int, sand_offset: int, snow_height: int, stone_height: int, is_river_or_lake: bool) -> Color:
	if h <= (sea_level + sand_offset) or (is_river_or_lake and h <= (water_h + 1)):
		return color_beach_sand
	if h >= snow_height:
		return color_alpine_snow
	if h >= stone_height:
		return color_mountain_stone
	if slope_grade >= 0.75:
		return color_mountain_stone
	if slope_grade >= 0.40:
		return color_slope_dirt
	return color_plains_grass

func compute_hillshade(dh_dx: float, dh_dz: float, steepness_multiplier: float = 3.0) -> float:
	var normal = Vector3(-dh_dx * steepness_multiplier, 1.0, -dh_dz * steepness_multiplier).normalized()
	var dot = clampf(normal.dot(light_direction), 0.0, 1.0)
	return ambient_base + relief_strength * (dot - 0.5)

func apply_relief(base_color: Color, shade: float, elevation: int, sea_level: int) -> Color:
	var elev_boost = clampf(float(elevation - sea_level) / 180.0, 0.0, elevation_boost_factor)
	return Color(
		clampf(base_color.r * shade + elev_boost, 0.0, 1.0),
		clampf(base_color.g * shade + elev_boost, 0.0, 1.0),
		clampf(base_color.b * shade + elev_boost, 0.0, 1.0),
		1.0
	)
