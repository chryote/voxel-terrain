class_name TerrainMaterialProvider
extends RefCounted

## Material factory providing shared ShaderMaterial instances for voxel terrain geometry.
## Keeps ChunkNode and meshing logic completely decoupled from specific visual shaders and themes.
const HALFTONE_SHADER_PATH = "res://shaders/terrain/halftone_terrain.gdshader"
const ASCII_SHADER_PATH = "res://shaders/terrain/ascii_terrain.gdshader"

const GraphicNovelConfigClass = preload("res://src/rendering/graphic_novel_config.gd")
const AsciiAtlasConfigClass = preload("res://src/rendering/ascii_atlas_config.gd")
const AsciiAtlasGeneratorClass = preload("res://src/rendering/ascii_atlas_generator.gd")
const AsciiMaterialMapperClass = preload("res://src/rendering/ascii_material_mapper.gd")
const StrataPaletteRegistryClass = preload("res://src/rendering/strata_palette_registry.gd")
const ToonWaterProviderClass = preload("res://src/rendering/toon_water_material_provider.gd")
const FoliageProviderClass = preload("res://src/rendering/foliage_material_provider.gd")

static var _cached_surface_material: ShaderMaterial = null
static var _cached_cave_material: ShaderMaterial = null
static var _cached_ascii_surface_material: ShaderMaterial = null
static var _cached_ascii_cave_material: ShaderMaterial = null

static func get_grass_material(cfg: Resource = null) -> ShaderMaterial: return FoliageProviderClass.get_grass_material(cfg)
static func get_bush_material(cfg: Resource = null) -> ShaderMaterial: return FoliageProviderClass.get_bush_material(cfg)
static func get_water_material(cfg: Resource = null) -> ShaderMaterial: return ToonWaterProviderClass.get_water_material(cfg)
static func get_ocean_material(cfg: Resource = null) -> ShaderMaterial: return ToonWaterProviderClass.get_ocean_material(cfg)
static func get_subterranean_water_material(cfg: Resource = null) -> ShaderMaterial: return ToonWaterProviderClass.get_subterranean_water_material(cfg)

static func get_surface_material(config: Resource = null) -> ShaderMaterial:
	if config is AsciiAtlasConfigClass: return get_ascii_surface_material(config)
	if config is GraphicNovelConfigClass: return _get_or_update_halftone(config, false)
	if _cached_surface_material != null: return _cached_surface_material
	if _cached_ascii_surface_material != null: return _cached_ascii_surface_material
	if ResourceLoader.exists("res://config/ascii_terrain_theme.tres"):
		return get_ascii_surface_material(load("res://config/ascii_terrain_theme.tres"))
	return _get_or_update_halftone(config, false)

static func get_cave_material(config: Resource = null) -> ShaderMaterial:
	if config is AsciiAtlasConfigClass: return get_ascii_cave_material(config)
	if config is GraphicNovelConfigClass: return _get_or_update_halftone(config, true)
	if _cached_cave_material != null: return _cached_cave_material
	if _cached_ascii_cave_material != null: return _cached_ascii_cave_material
	if ResourceLoader.exists("res://config/ascii_terrain_theme.tres"):
		return get_ascii_cave_material(load("res://config/ascii_terrain_theme.tres"))
	return _get_or_update_halftone(config, true)

static func get_ascii_surface_material(config: Resource = null) -> ShaderMaterial:
	if _cached_ascii_surface_material == null:
		_cached_ascii_surface_material = _create_ascii_material(config, false)
	elif config != null:
		_apply_ascii_uniforms(_cached_ascii_surface_material, config, false)
	return _cached_ascii_surface_material

static func get_ascii_cave_material(config: Resource = null) -> ShaderMaterial:
	if _cached_ascii_cave_material == null:
		_cached_ascii_cave_material = _create_ascii_material(config, true)
	elif config != null:
		_apply_ascii_uniforms(_cached_ascii_cave_material, config, true)
	return _cached_ascii_cave_material

static func update_materials(config: Resource) -> void:
	if config == null: return
	if config is AsciiAtlasConfigClass:
		if _cached_ascii_surface_material != null: _apply_ascii_uniforms(_cached_ascii_surface_material, config, false)
		if _cached_ascii_cave_material != null: _apply_ascii_uniforms(_cached_ascii_cave_material, config, true)
	else:
		if _cached_surface_material != null: _apply_halftone_uniforms(_cached_surface_material, config, false)
		if _cached_cave_material != null: _apply_halftone_uniforms(_cached_cave_material, config, true)

static func reset() -> void:
	_cached_surface_material = null
	_cached_cave_material = null
	_cached_ascii_surface_material = null
	_cached_ascii_cave_material = null
	ToonWaterProviderClass.reset()
	FoliageProviderClass.reset()

static func _get_or_update_halftone(config: Resource, is_cave: bool) -> ShaderMaterial:
	var cached = _cached_cave_material if is_cave else _cached_surface_material
	if cached == null:
		cached = _create_halftone_material(config, is_cave)
		if is_cave: _cached_cave_material = cached
		else: _cached_surface_material = cached
	elif config != null:
		_apply_halftone_uniforms(cached, config, is_cave)
	return cached

static func _create_halftone_material(config: Resource, is_cave: bool) -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	mat.shader = load(HALFTONE_SHADER_PATH) as Shader
	_apply_halftone_uniforms(mat, config if config != null else GraphicNovelConfigClass.create_default_config(), is_cave)
	return mat

static func _create_ascii_material(config: Resource, is_cave: bool) -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	mat.shader = load(ASCII_SHADER_PATH) as Shader
	_apply_ascii_uniforms(mat, config if config != null else AsciiAtlasConfigClass.create_default_config(), is_cave)
	return mat

static func _apply_halftone_uniforms(mat: ShaderMaterial, config: Resource, is_cave: bool) -> void:
	if mat == null or config == null: return
	var tex = config.get("halftone_texture") as Texture2D
	mat.set_shader_parameter("halftone_texture", tex)
	mat.set_shader_parameter("use_procedural_pattern", bool(config.get("use_procedural_pattern")) or (tex == null))
	mat.set_shader_parameter("halftone_scale", float(config.get("halftone_scale")))
	mat.set_shader_parameter("halftone_intensity", float(config.get("halftone_intensity")))
	mat.set_shader_parameter("lit_threshold", float(config.get("lit_threshold")))
	_apply_shadow_tint(mat, config.get("shadow_tint") as Color, is_cave)
	mat.set_shader_parameter("mist_color", Color(0.32, 0.05, 0.09, 1.0) if is_cave else Color(0.13, 0.17, 0.14, 1.0))
	mat.set_shader_parameter("valley_mist_strength", 0.0 if is_cave else 0.75)
	mat.set_shader_parameter("scratches_enabled", is_cave); mat.set_shader_parameter("scratch_intensity", 0.85 if is_cave else 0.0); mat.set_shader_parameter("scratch_color", Color(0.52, 0.08, 0.13, 1.0) if is_cave else Color(0.0, 0.0, 0.0, 1.0))

static func _apply_ascii_uniforms(mat: ShaderMaterial, config: Resource, is_cave: bool) -> void:
	if mat == null or config == null: return
	var atlas_tex = _resolve_texture(config.get("atlas_texture"), "res://assets/textures/ascii_atlas.png", Callable(AsciiAtlasGeneratorClass, "create_atlas_texture"))
	var lut_tex = _resolve_texture(config.get("material_glyph_lut"), "res://assets/textures/ascii_material_lut.png", Callable(AsciiMaterialMapperClass, "create_lut_texture"))
	mat.set_shader_parameter("ascii_atlas", atlas_tex)
	mat.set_shader_parameter("material_lut", lut_tex)
	mat.set_shader_parameter("atlas_grid", Vector2i(int(config.get("grid_columns")), int(config.get("grid_rows"))))
	mat.set_shader_parameter("glyphs_per_voxel", float(config.get("glyphs_per_voxel")))
	mat.set_shader_parameter("glyph_contrast", float(config.get("glyph_contrast")))
	mat.set_shader_parameter("depth_relief_strength", float(config.get("depth_relief_strength")))
	mat.set_shader_parameter("cavity_shadow_intensity", float(config.get("cavity_shadow_intensity")))
	mat.set_shader_parameter("macro_variation_scale", float(config.get("macro_variation_scale")))
	mat.set_shader_parameter("parallax_strength", float(config.get("parallax_strength")))
	mat.set_shader_parameter("lit_threshold", float(config.get("lit_threshold")))
	_apply_shadow_tint(mat, config.get("shadow_tint") as Color, is_cave)
	if is_cave:
		_apply_cave_crimson_rot_theme(mat)
	else:
		StrataPaletteRegistryClass.apply_to_material(mat, config)
		var s_en = config.get("stains_enabled")
		mat.set_shader_parameter("stains_enabled", bool(s_en) if s_en != null else true)
		mat.set_shader_parameter("stain_scale", float(config.get("stain_scale")) if config.get("stain_scale") != null else 0.08)
		mat.set_shader_parameter("stain_threshold", float(config.get("stain_threshold")) if config.get("stain_threshold") != null else 0.45)
		mat.set_shader_parameter("stain_intensity", float(config.get("stain_intensity")) if config.get("stain_intensity") != null else 0.70)
		mat.set_shader_parameter("stain_color_dark", config.get("stain_color_dark") if config.get("stain_color_dark") != null else Color(0.06, 0.07, 0.05, 0.90))
		mat.set_shader_parameter("stain_color_green", config.get("stain_color_green") if config.get("stain_color_green") != null else Color(0.24, 0.38, 0.20, 0.90))
		mat.set_shader_parameter("mist_color", Color(0.13, 0.15, 0.16, 1.0))
		mat.set_shader_parameter("scratches_enabled", false); mat.set_shader_parameter("scratch_intensity", 0.0); mat.set_shader_parameter("valley_mist_strength", 0.75)

static func _apply_cave_crimson_rot_theme(mat: ShaderMaterial) -> void:
	var pal = StrataPaletteRegistryClass.get_palette("alien", "crimson_rot")
	mat.set_shader_parameter("strata_enabled", true)
	mat.set_shader_parameter("strata_frequency", 0.40)
	mat.set_shader_parameter("strata_warp_strength", 0.55)
	mat.set_shader_parameter("strata_color_0", pal[0]); mat.set_shader_parameter("strata_color_1", pal[1])
	mat.set_shader_parameter("strata_color_2", pal[2]); mat.set_shader_parameter("strata_color_3", pal[3])
	mat.set_shader_parameter("stains_enabled", true)
	mat.set_shader_parameter("stain_scale", 0.09)
	mat.set_shader_parameter("stain_threshold", 0.38)
	mat.set_shader_parameter("stain_intensity", 0.85)
	mat.set_shader_parameter("stain_color_dark", Color(0.38, 0.05, 0.09, 0.95))
	mat.set_shader_parameter("stain_color_green", Color(0.85, 0.08, 0.14, 0.95))
	mat.set_shader_parameter("mist_color", Color(0.45, 0.04, 0.08, 1.0))
	mat.set_shader_parameter("cavity_shadow_intensity", 0.55)
	mat.set_shader_parameter("glyph_contrast", 0.45)
	mat.set_shader_parameter("scratches_enabled", true); mat.set_shader_parameter("scratch_intensity", 0.85); mat.set_shader_parameter("scratch_color", Color(0.52, 0.08, 0.13, 1.0)); mat.set_shader_parameter("valley_mist_strength", 0.0); mat.set_shader_parameter("shadow_tint", Color(0.75, 0.10, 0.16, 1.0))

static func _resolve_texture(tex: Texture2D, path: String, fallback: Callable) -> Texture2D:
	if tex != null: return tex
	if ResourceLoader.exists(path):
		var loaded = load(path) as Texture2D
		if loaded != null: return loaded
	return fallback.call() as Texture2D

static func _apply_shadow_tint(mat: ShaderMaterial, tint: Color, is_cave: bool) -> void:
	var t = Color(tint.r * 0.25, tint.g * 0.02, tint.b * 0.04, 1.0) if is_cave else tint
	mat.set_shader_parameter("shadow_tint", t)
