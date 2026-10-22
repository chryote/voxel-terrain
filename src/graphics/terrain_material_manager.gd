class_name TerrainMaterialManager
extends RefCounted

## Manages creation, uniform binding, and chunk material assignment
## for custom terrain, cave, and water shaders.

const TERRAIN_SHADER_PATH = "res://src/graphics/shaders/terrain.gdshader"
const WATER_SHADER_PATH = "res://src/graphics/shaders/terrain_water.gdshader"
const CAVE_SHADER_PATH = "res://src/graphics/shaders/terrain_cave.gdshader"

var config: TerrainMaterialConfig

var _terrain_shader: Shader
var _water_shader: Shader
var _cave_shader: Shader

var _shared_surface_material: ShaderMaterial
var _shared_cave_material: ShaderMaterial
var _shared_water_material: ShaderMaterial

func _init(p_config: TerrainMaterialConfig = null) -> void:
	config = p_config if p_config != null else TerrainMaterialConfig.new()
	_load_shaders()
	_build_shared_materials()

func _load_shaders() -> void:
	if ResourceLoader.exists(TERRAIN_SHADER_PATH):
		_terrain_shader = load(TERRAIN_SHADER_PATH) as Shader
	if ResourceLoader.exists(WATER_SHADER_PATH):
		_water_shader = load(WATER_SHADER_PATH) as Shader
	if ResourceLoader.exists(CAVE_SHADER_PATH):
		_cave_shader = load(CAVE_SHADER_PATH) as Shader

func _build_shared_materials() -> void:
	if _terrain_shader != null:
		_shared_surface_material = ShaderMaterial.new()
		_shared_surface_material.shader = _terrain_shader
		_sync_surface_uniforms(_shared_surface_material)

	if _cave_shader != null:
		_shared_cave_material = ShaderMaterial.new()
		_shared_cave_material.shader = _cave_shader
		_sync_cave_uniforms(_shared_cave_material)

	if _water_shader != null:
		_shared_water_material = ShaderMaterial.new()
		_shared_water_material.shader = _water_shader
		_sync_water_uniforms(_shared_water_material)

func _sync_surface_uniforms(mat: ShaderMaterial) -> void:
	if mat == null or config == null:
		return
	mat.set_shader_parameter("triplanar_scale", config.triplanar_scale)
	mat.set_shader_parameter("triplanar_sharpness", config.triplanar_sharpness)
	mat.set_shader_parameter("slope_threshold", config.slope_threshold)
	mat.set_shader_parameter("slope_blend_margin", config.slope_blend_margin)
	mat.set_shader_parameter("beach_height", config.beach_height)
	mat.set_shader_parameter("beach_blend_margin", config.beach_blend_margin)
	mat.set_shader_parameter("snow_height", config.snow_height)
	mat.set_shader_parameter("snow_blend_margin", config.snow_blend_margin)
	mat.set_shader_parameter("macro_variation_strength", config.macro_variation_strength)
	mat.set_shader_parameter("macro_variation_scale", config.macro_variation_scale)
	mat.set_shader_parameter("biome_tint", Vector3(config.biome_tint.r, config.biome_tint.g, config.biome_tint.b))

	mat.set_shader_parameter("grass_color", config.grass_color)
	mat.set_shader_parameter("dirt_color", config.dirt_color)
	mat.set_shader_parameter("rock_color", config.rock_color)
	mat.set_shader_parameter("sand_color", config.sand_color)
	mat.set_shader_parameter("snow_color", config.snow_color)

	mat.set_shader_parameter("grass_roughness", config.grass_roughness)
	mat.set_shader_parameter("dirt_roughness", config.dirt_roughness)
	mat.set_shader_parameter("rock_roughness", config.rock_roughness)
	mat.set_shader_parameter("sand_roughness", config.sand_roughness)
	mat.set_shader_parameter("snow_roughness", config.snow_roughness)

	mat.set_shader_parameter("paint_layer_r_color", config.paint_layer_r_color)
	mat.set_shader_parameter("paint_layer_r_roughness", config.paint_layer_r_roughness)
	mat.set_shader_parameter("paint_layer_g_color", config.paint_layer_g_color)
	mat.set_shader_parameter("paint_layer_g_roughness", config.paint_layer_g_roughness)
	mat.set_shader_parameter("paint_layer_b_color", config.paint_layer_b_color)
	mat.set_shader_parameter("paint_layer_b_roughness", config.paint_layer_b_roughness)
	mat.set_shader_parameter("paint_layer_a_color", config.paint_layer_a_color)
	mat.set_shader_parameter("paint_layer_a_roughness", config.paint_layer_a_roughness)

	mat.set_shader_parameter("use_textures", config.use_textures)
	if config.use_textures:
		mat.set_shader_parameter("texture_grass_albedo", config.texture_grass_albedo)
		mat.set_shader_parameter("texture_dirt_albedo", config.texture_dirt_albedo)
		mat.set_shader_parameter("texture_rock_albedo", config.texture_rock_albedo)
		mat.set_shader_parameter("texture_sand_albedo", config.texture_sand_albedo)
		mat.set_shader_parameter("texture_snow_albedo", config.texture_snow_albedo)

func _sync_cave_uniforms(mat: ShaderMaterial) -> void:
	if mat == null or config == null:
		return
	mat.set_shader_parameter("rock_color", config.cave_rock_color)
	mat.set_shader_parameter("basalt_color", config.cave_basalt_color)
	mat.set_shader_parameter("crystal_color", config.cave_crystal_color)
	mat.set_shader_parameter("crystal_emission_energy", config.cave_crystal_energy)
	mat.set_shader_parameter("wetness", config.cave_wetness)

func _sync_water_uniforms(mat: ShaderMaterial) -> void:
	if mat == null or config == null:
		return
	mat.set_shader_parameter("shallow_color", config.water_shallow_color)
	mat.set_shader_parameter("deep_color", config.water_deep_color)
	mat.set_shader_parameter("foam_color", config.water_foam_color)
	mat.set_shader_parameter("wave_speed", config.water_speed)
	mat.set_shader_parameter("wave_amplitude", config.water_amplitude)

func get_shared_surface_material() -> ShaderMaterial:
	return _shared_surface_material

func get_shared_cave_material() -> ShaderMaterial:
	return _shared_cave_material

func get_shared_water_material() -> ShaderMaterial:
	return _shared_water_material

## Creates a chunk-specific material instance configured with chunk world origin and splatmap
func create_chunk_surface_material(coord: ChunkCoord, chunk_size_world: float, splat_map: Texture2D = null) -> ShaderMaterial:
	if _terrain_shader == null:
		return null
	var mat = ShaderMaterial.new()
	mat.shader = _terrain_shader
	_sync_surface_uniforms(mat)

	if coord != null:
		var origin_x = float(coord.x) * chunk_size_world
		var origin_z = float(coord.z) * chunk_size_world
		mat.set_shader_parameter("chunk_origin", Vector2(origin_x, origin_z))
	mat.set_shader_parameter("chunk_size_world", chunk_size_world)

	if splat_map != null:
		mat.set_shader_parameter("use_splat_map", true)
		mat.set_shader_parameter("splat_map", splat_map)
	else:
		mat.set_shader_parameter("use_splat_map", false)

	return mat

## Creates a fallback standard material with vertex colors for headless / low-end
func create_fallback_standard_material() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.85
	mat.metallic_specular = 0.15
	return mat
