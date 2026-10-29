class_name FoliageMaterialProvider
extends RefCounted

## Pure material provider and uniform binder for NPR toon grass foliage geometry.
## Manages shared ShaderMaterial caching for instanced foliage across ChunkNode instances.
## Completely decoupled from scene nodes and world logic.

const SHADER_PATH = "res://shaders/foliage/toon_grass.gdshader"
const ConfigClass = preload("res://src/rendering/foliage_config.gd")

static var _cached_grass_material: ShaderMaterial = null

static func get_grass_material(config: Resource = null) -> ShaderMaterial:
	if _cached_grass_material == null:
		_cached_grass_material = _create_grass_material(config)
	elif config != null:
		apply_to_material(_cached_grass_material, config)
	return _cached_grass_material

static func reset() -> void:
	_cached_grass_material = null

static func _create_grass_material(config: Resource = null) -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	if ResourceLoader.exists(SHADER_PATH):
		mat.shader = load(SHADER_PATH)
	else:
		push_error("Toon grass shader not found at: %s" % SHADER_PATH)

	var cfg = config if config != null else ConfigClass.create_default_config()
	apply_to_material(mat, cfg)
	return mat

static func apply_to_material(mat: ShaderMaterial, config: Resource) -> void:
	if mat == null or config == null:
		return

	_bind_texture_uniforms(mat, config)
	_bind_wind_uniforms(mat, config)
	_bind_fade_and_light_uniforms(mat, config)

static func _bind_texture_uniforms(mat: ShaderMaterial, config: Resource) -> void:
	if "albedo_texture" in config and config.albedo_texture != null:
		mat.set_shader_parameter("albedo_texture", config.albedo_texture)
	if "albedo_tint" in config:
		mat.set_shader_parameter("albedo_tint", config.albedo_tint)
	if "alpha_scissor_threshold" in config:
		mat.set_shader_parameter("alpha_scissor_threshold", config.alpha_scissor_threshold)

static func _bind_wind_uniforms(mat: ShaderMaterial, config: Resource) -> void:
	if "wind_enabled" in config:
		mat.set_shader_parameter("wind_enabled", config.wind_enabled)
	if "wind_speed" in config:
		mat.set_shader_parameter("wind_speed", config.wind_speed)
	if "wind_strength" in config:
		mat.set_shader_parameter("wind_strength", config.wind_strength)
	if "wind_turbulence" in config:
		mat.set_shader_parameter("wind_turbulence", config.wind_turbulence)

static func _bind_fade_and_light_uniforms(mat: ShaderMaterial, config: Resource) -> void:
	if "distance_fade_enabled" in config:
		mat.set_shader_parameter("distance_fade_enabled", config.distance_fade_enabled)
	if "distance_fade_start" in config:
		mat.set_shader_parameter("distance_fade_start", config.distance_fade_start)
	if "distance_fade_max" in config:
		mat.set_shader_parameter("distance_fade_max", config.distance_fade_max)
	if "lit_threshold" in config:
		mat.set_shader_parameter("lit_threshold", config.lit_threshold)
	if "shadow_tint" in config:
		mat.set_shader_parameter("shadow_tint", config.shadow_tint)

