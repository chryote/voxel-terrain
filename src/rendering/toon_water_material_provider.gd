class_name ToonWaterMaterialProvider
extends RefCounted

## Pure material provider and uniform binder for NPR toon water geometry.
## Manages shared ShaderMaterial caching for surface ocean/lakes and subterranean cave pools.
## Completely decoupled from scene nodes and world logic.

const SHADER_PATH = "res://shaders/water/toon_water.gdshader"
const ConfigClass = preload("res://src/rendering/toon_water_config.gd")

static var _cached_surface_material: ShaderMaterial = null
static var _cached_ocean_material: ShaderMaterial = null
static var _cached_subterranean_material: ShaderMaterial = null

static func get_water_material(config: Resource = null) -> ShaderMaterial:
	if _cached_surface_material == null:
		_cached_surface_material = _create_water_material(config, "default")
	elif config != null:
		apply_to_material(_cached_surface_material, config)
	return _cached_surface_material

static func get_ocean_material(config: Resource = null) -> ShaderMaterial:
	if _cached_ocean_material == null:
		_cached_ocean_material = _create_water_material(config, "ocean")
	elif config != null:
		apply_to_material(_cached_ocean_material, config)
	return _cached_ocean_material

static func get_subterranean_water_material(config: Resource = null) -> ShaderMaterial:
	if _cached_subterranean_material == null:
		_cached_subterranean_material = _create_water_material(config, "subterranean")
	elif config != null:
		apply_to_material(_cached_subterranean_material, config)
	return _cached_subterranean_material

static func reset() -> void:
	_cached_surface_material = null
	_cached_ocean_material = null
	_cached_subterranean_material = null

static func _create_water_material(config: Resource, preset_type: String) -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	var shader = load(SHADER_PATH) as Shader
	if shader != null:
		mat.shader = shader
	if config == null:
		if preset_type == "ocean":
			config = ConfigClass.create_ocean_config()
		elif preset_type == "subterranean":
			config = ConfigClass.create_subterranean_config()
		else:
			config = ConfigClass.create_default_config()
	apply_to_material(mat, config)
	return mat

static func apply_to_material(mat: ShaderMaterial, config: Resource) -> void:
	if mat == null or config == null:
		return
	_apply_foam_parameters(mat, config)
	_apply_depth_parameters(mat, config)
	_apply_ripple_parameters(mat, config)
	_apply_side_parameters(mat, config)

static func _apply_foam_parameters(mat: ShaderMaterial, config: Resource) -> void:
	var f_en = config.get("foam_enabled")
	var f_thick = config.get("foam_thickness")
	var f_col = config.get("foam_color")
	mat.set_shader_parameter("foam_enabled", bool(f_en) if f_en != null else true)
	mat.set_shader_parameter("foam_thickness", float(f_thick) if f_thick != null else 0.35)
	mat.set_shader_parameter("foam_color", f_col if f_col != null else Color(1.0, 1.0, 1.0, 1.0))

static func _apply_depth_parameters(mat: ShaderMaterial, config: Resource) -> void:
	var s_col = config.get("shallow_color")
	var m_col = config.get("mid_color")
	var d_col = config.get("deep_color")
	var s_th = config.get("shallow_threshold")
	var d_th = config.get("deep_threshold")
	mat.set_shader_parameter("shallow_color", s_col if s_col != null else Color(0.23, 0.64, 0.86, 0.85))
	mat.set_shader_parameter("mid_color", m_col if m_col != null else Color(0.12, 0.38, 0.62, 0.90))
	mat.set_shader_parameter("deep_color", d_col if d_col != null else Color(0.07, 0.16, 0.26, 0.95))
	mat.set_shader_parameter("shallow_threshold", float(s_th) if s_th != null else 1.5)
	mat.set_shader_parameter("deep_threshold", float(d_th) if d_th != null else 5.0)

static func _apply_ripple_parameters(mat: ShaderMaterial, config: Resource) -> void:
	var r_en = config.get("ripples_enabled")
	var pix_d = config.get("pixel_density")
	var r_sc = config.get("ripple_scale")
	var r_rad = config.get("ripple_radius")
	var r_sp = config.get("ripple_speed")
	var r_th = config.get("ripple_threshold")
	var r_col = config.get("ripple_color")
	mat.set_shader_parameter("ripples_enabled", bool(r_en) if r_en != null else true)
	mat.set_shader_parameter("pixel_density", float(pix_d) if pix_d != null else 8.0)
	mat.set_shader_parameter("ripple_scale", float(r_sc) if r_sc != null else 0.08)
	mat.set_shader_parameter("ripple_radius", float(r_rad) if r_rad != null else 0.65)
	mat.set_shader_parameter("ripple_speed", float(r_sp) if r_sp != null else 0.08)
	mat.set_shader_parameter("ripple_threshold", float(r_th) if r_th != null else 0.05)
	mat.set_shader_parameter("ripple_color", r_col if r_col != null else Color(0.45, 0.65, 0.75, 0.65))

static func _apply_side_parameters(mat: ShaderMaterial, config: Resource) -> void:
	var s_spd = config.get("side_fluid_speed")
	mat.set_shader_parameter("side_fluid_speed", float(s_spd) if s_spd != null else 2.2)
