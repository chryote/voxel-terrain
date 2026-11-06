class_name ExtremeDistanceMaterialProvider
extends RefCounted

## Material provider for extreme distance macro terrain LOD.
## Delivers a shared ShaderMaterial supporting dynamic clipping and NPR cel lighting.
## Decoupled from scene nodes, world logic, and streaming.

const SHADER_PATH = "res://shaders/terrain/distant_macro_terrain.gdshader"
const StrataPaletteRegistryClass = preload("res://src/rendering/strata_palette_registry.gd")

static var _cached_material: ShaderMaterial = null

static func get_material(theme: Resource = null) -> ShaderMaterial:
	if _cached_material == null:
		_cached_material = create_material(theme)
	elif theme != null:
		apply_uniforms(_cached_material, theme)
	return _cached_material

static func create_material(theme: Resource = null) -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	var shader = load(SHADER_PATH) as Shader
	mat.shader = shader
	if theme != null:
		apply_uniforms(mat, theme)
	return mat

static func apply_uniforms(mat: ShaderMaterial, theme: Resource) -> void:
	if mat == null or theme == null:
		return

	if theme.get("shadow_tint") != null:
		mat.set_shader_parameter("shadow_tint", theme.get("shadow_tint"))
	if theme.get("lit_threshold") != null:
		mat.set_shader_parameter("lit_threshold", float(theme.get("lit_threshold")))
	if theme.get("macro_variation_scale") != null:
		mat.set_shader_parameter("macro_variation_scale", float(theme.get("macro_variation_scale")))
	if theme.get("haze_color") != null:
		mat.set_shader_parameter("haze_color", theme.get("haze_color"))
	if theme.get("haze_intensity") != null:
		mat.set_shader_parameter("haze_intensity", float(theme.get("haze_intensity")))
	if theme.get("haze_start_distance") != null:
		mat.set_shader_parameter("haze_start_distance", float(theme.get("haze_start_distance")))
	if theme.get("haze_max_distance") != null:
		mat.set_shader_parameter("haze_max_distance", float(theme.get("haze_max_distance")))
	if theme.get("atmosphere_enabled") != null:
		mat.set_shader_parameter("atmosphere_enabled", bool(theme.get("atmosphere_enabled")))
	if theme.get("mono_color_enabled") != null:
		mat.set_shader_parameter("mono_color_enabled", bool(theme.get("mono_color_enabled")))
	if theme.get("mono_color_blend") != null:
		mat.set_shader_parameter("mono_color_blend", float(theme.get("mono_color_blend")))
	if theme.get("mono_blue_low") != null:
		mat.set_shader_parameter("mono_blue_low", theme.get("mono_blue_low"))
	if theme.get("mono_blue_mid") != null:
		mat.set_shader_parameter("mono_blue_mid", theme.get("mono_blue_mid"))
	if theme.get("mono_blue_high") != null:
		mat.set_shader_parameter("mono_blue_high", theme.get("mono_blue_high"))
	if theme.get("mono_distance_start") != null:
		mat.set_shader_parameter("mono_distance_start", float(theme.get("mono_distance_start")))
	if theme.get("mono_distance_full") != null:
		mat.set_shader_parameter("mono_distance_full", float(theme.get("mono_distance_full")))
	if theme.get("pixel_art_enabled") != null:
		mat.set_shader_parameter("pixel_art_enabled", bool(theme.get("pixel_art_enabled")))
	if theme.get("pixel_size") != null:
		mat.set_shader_parameter("pixel_size", float(theme.get("pixel_size")))
	if theme.get("terrace_step") != null:
		mat.set_shader_parameter("terrace_step", float(theme.get("terrace_step")))
	if theme.get("depth_step_distance") != null:
		mat.set_shader_parameter("depth_step_distance", float(theme.get("depth_step_distance")))
	if theme.get("palette_shadow") != null:
		mat.set_shader_parameter("palette_shadow", theme.get("palette_shadow"))
	if theme.get("palette_base") != null:
		mat.set_shader_parameter("palette_base", theme.get("palette_base"))
	if theme.get("palette_lit") != null:
		mat.set_shader_parameter("palette_lit", theme.get("palette_lit"))
	if theme.get("palette_highlight") != null:
		mat.set_shader_parameter("palette_highlight", theme.get("palette_highlight"))

	StrataPaletteRegistryClass.apply_to_material(mat, theme)

static func reset() -> void:
	_cached_material = null

