class_name TerrainMaterialProvider
extends RefCounted

## Material factory providing shared ShaderMaterial instances for voxel terrain geometry.
## Keeps ChunkNode and meshing logic completely decoupled from specific visual shaders and themes.

const SHADER_PATH = "res://shaders/terrain/halftone_terrain.gdshader"
const GraphicNovelConfigClass = preload("res://src/rendering/graphic_novel_config.gd")

static var _cached_surface_material: ShaderMaterial = null
static var _cached_cave_material: ShaderMaterial = null

## Retrieves or creates the shared surface terrain material configured from a GraphicNovelConfig.
static func get_surface_material(config: Resource = null) -> ShaderMaterial:
	if _cached_surface_material == null:
		_cached_surface_material = _create_material(config, false)
	elif config != null:
		_apply_uniforms(_cached_surface_material, config, false)
	return _cached_surface_material

## Retrieves or creates the shared subterranean cave material configured from a GraphicNovelConfig.
static func get_cave_material(config: Resource = null) -> ShaderMaterial:
	if _cached_cave_material == null:
		_cached_cave_material = _create_material(config, true)
	elif config != null:
		_apply_uniforms(_cached_cave_material, config, true)
	return _cached_cave_material

## Updates all active cached materials in-place with a new configuration.
static func update_materials(config: Resource) -> void:
	if config == null:
		return
	if _cached_surface_material != null:
		_apply_uniforms(_cached_surface_material, config, false)
	if _cached_cave_material != null:
		_apply_uniforms(_cached_cave_material, config, true)

## Resets cached materials (used during teardown or unit testing).
static func reset() -> void:
	_cached_surface_material = null
	_cached_cave_material = null

static func _create_material(config: Resource, is_cave: bool) -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	var shader = load(SHADER_PATH) as Shader
	if shader != null:
		mat.shader = shader
	if config == null:
		config = GraphicNovelConfigClass.create_default_config()
	_apply_uniforms(mat, config, is_cave)
	return mat

static func _apply_uniforms(mat: ShaderMaterial, config: Resource, is_cave: bool) -> void:
	if mat == null or config == null:
		return

	var tex = config.get("halftone_texture") as Texture2D
	var use_proc = bool(config.get("use_procedural_pattern"))
	if tex != null:
		mat.set_shader_parameter("halftone_texture", tex)
		mat.set_shader_parameter("use_procedural_pattern", false)
	else:
		mat.set_shader_parameter("use_procedural_pattern", use_proc or (tex == null))

	mat.set_shader_parameter("halftone_scale", float(config.get("halftone_scale")))
	mat.set_shader_parameter("halftone_intensity", float(config.get("halftone_intensity")))
	mat.set_shader_parameter("lit_threshold", float(config.get("lit_threshold")))

	var shadow_tint = config.get("shadow_tint") as Color
	if is_cave:
		# Cave walls use a slightly deeper shadow tint for dark underground atmosphere
		var cave_tint = Color(
			shadow_tint.r * 0.7,
			shadow_tint.g * 0.7,
			shadow_tint.b * 0.8,
			1.0
		)
		mat.set_shader_parameter("shadow_tint", cave_tint)
	else:
		mat.set_shader_parameter("shadow_tint", shadow_tint)
