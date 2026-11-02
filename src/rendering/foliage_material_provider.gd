class_name FoliageMaterialProvider
extends RefCounted

## Pure material provider and uniform binder for NPR toon grass and bush foliage geometry.
## Manages shared ShaderMaterial caching for instanced foliage across ChunkNode instances.
## Completely decoupled from scene nodes and world logic.

const SHADER_PATH = "res://shaders/foliage/toon_grass.gdshader"
const ConfigClass = preload("res://src/rendering/foliage_config.gd")

static var _cached_grass_material: ShaderMaterial = null
static var _cached_bush_material: ShaderMaterial = null

static func get_grass_material(config: Resource = null) -> ShaderMaterial:
	if _cached_grass_material == null:
		_cached_grass_material = _create_material(config, false)
	elif config != null:
		apply_to_material(_cached_grass_material, config, false)
	return _cached_grass_material

static func get_bush_material(config: Resource = null) -> ShaderMaterial:
	if _cached_bush_material == null:
		_cached_bush_material = _create_material(config, true)
	elif config != null:
		apply_to_material(_cached_bush_material, config, true)
	return _cached_bush_material

static func reset() -> void:
	_cached_grass_material = null
	_cached_bush_material = null

static func _create_material(config: Resource = null, is_bush: bool = false) -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	if ResourceLoader.exists(SHADER_PATH):
		mat.shader = load(SHADER_PATH)
	else:
		push_error("Toon foliage shader not found at: %s" % SHADER_PATH)

	var cfg = config if config != null else ConfigClass.create_default_config()
	apply_to_material(mat, cfg, is_bush)
	return mat

static func apply_to_material(mat: ShaderMaterial, config: Resource, is_bush: bool = false) -> void:
	if mat == null or config == null:
		return
	_bind_texture_uniforms(mat, config, is_bush)
	_bind_wind_and_light_uniforms(mat, config)

static func _bind_texture_uniforms(mat: ShaderMaterial, config: Resource, is_bush: bool) -> void:
	var tex_prop = "bush_albedo_texture" if is_bush else "albedo_texture"
	var tint_prop = "bush_albedo_tint" if is_bush else "albedo_tint"
	if tex_prop in config and config.get(tex_prop) != null:
		mat.set_shader_parameter("albedo_texture", config.get(tex_prop))
	elif is_bush and ResourceLoader.exists("res://assets/textures/bush.png"):
		mat.set_shader_parameter("albedo_texture", load("res://assets/textures/bush.png"))
	if tint_prop in config:
		mat.set_shader_parameter("albedo_tint", config.get(tint_prop))
	if "alpha_scissor_threshold" in config:
		mat.set_shader_parameter("alpha_scissor_threshold", config.alpha_scissor_threshold)

static func _bind_wind_and_light_uniforms(mat: ShaderMaterial, config: Resource) -> void:
	var props = [
		"wind_enabled", "wind_speed", "wind_strength", "wind_turbulence",
		"distance_fade_enabled", "distance_fade_start", "distance_fade_max",
		"lit_threshold", "shadow_tint"
	]
	for p in props:
		if p in config:
			mat.set_shader_parameter(p, config.get(p))
