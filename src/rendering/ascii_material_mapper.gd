class_name AsciiMaterialMapper
extends RefCounted

## Pure component responsible for mapping MaterialDef IDs to tactile ASCII coarseness glyphs.
## Bakes a compact 16x4 GPU LUT texture for O(1) branchless shader sampling.

const BAND_SHADOW: int = 0
const BAND_MIDTONE: int = 1
const BAND_HIGHLIGHT: int = 2
const BAND_GRAZING: int = 3

const MaterialDefClass = preload("res://src/core/material_def.gd")

# Lookup mapping material_id -> [shadow, midtone, highlight, grazing] character codes
static var _RAMP_TABLE: Dictionary = {}

static func _static_init() -> void:
	_init_ramp_table()

static func get_density_ramp(material_id: int) -> PackedInt32Array:
	if _RAMP_TABLE.is_empty():
		_init_ramp_table()
	var ramp = _RAMP_TABLE.get(material_id, null)
	if ramp != null:
		return ramp
	# Fallback: generic printable hash/dot ramp
	return PackedInt32Array([35, 42, 46, 35]) # #, *, ., #

static func get_glyph_for_material(material_id: int, band: int = BAND_MIDTONE) -> int:
	var ramp = get_density_ramp(material_id)
	var clamped_band = clampi(band, BAND_SHADOW, BAND_GRAZING)
	return ramp[clamped_band]

static func bake_material_lut_image() -> Image:
	var img = Image.create(16, 4, false, Image.FORMAT_RGBA8)
	for mat_id in range(16):
		var ramp = get_density_ramp(mat_id)
		for band in range(4):
			var glyph_code = ramp[band]
			var norm_val = float(glyph_code) / 255.0
			img.set_pixel(mat_id, band, Color(norm_val, 0.0, 0.0, 1.0))
	return img

static func create_lut_texture() -> ImageTexture:
	var img = bake_material_lut_image()
	return ImageTexture.create_from_image(img)

static func save_lut_to_file(path: String = "res://assets/textures/ascii_material_lut.png") -> Error:
	var dir_path = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var img = bake_material_lut_image()
	return img.save_png(path)

static func _init_ramp_table() -> void:
	# ID_AIR (0): Space
	_RAMP_TABLE[MaterialDefClass.ID_AIR] = PackedInt32Array([32, 32, 32, 32])
	# ID_GRASS (1): Ledge drop-off, centered turf dot, blade ticks, flower pluses (!!, ·, ", +)
	_RAMP_TABLE[MaterialDefClass.ID_GRASS] = PackedInt32Array([19, 249, 34, 43])
	# ID_DIRT (2): Crumbly granular loam aggregate (8, *, ., :)
	_RAMP_TABLE[MaterialDefClass.ID_DIRT] = PackedInt32Array([56, 42, 46, 58])
	# ID_STONE (3): Rigid crystalline fracture cleavage planes (#, X, [, =)
	_RAMP_TABLE[MaterialDefClass.ID_STONE] = PackedInt32Array([35, 88, 91, 61])
	# ID_SAND (4): Fine quartz granules and dune ripple crests (~, ., ·, -)
	_RAMP_TABLE[MaterialDefClass.ID_SAND] = PackedInt32Array([126, 46, 249, 45])
	# ID_SNOW (5): Powder flakes and glistening ice crystal points (+, *, ·, 120)
	_RAMP_TABLE[MaterialDefClass.ID_SNOW] = PackedInt32Array([43, 42, 249, 120])
	# ID_SEABED (6): Silty sedimentary mud and undulating algae (_, ~, =, -)
	_RAMP_TABLE[MaterialDefClass.ID_SEABED] = PackedInt32Array([95, 126, 61, 45])
	# ID_GRAVEL (7): Loose angular crushed stone fragments (8, %, ., *)
	_RAMP_TABLE[MaterialDefClass.ID_GRAVEL] = PackedInt32Array([56, 37, 46, 42])
	# ID_CAVE_WALL (8): Heavy subterranean jointed bedrock (▓, H, !, |)
	_RAMP_TABLE[MaterialDefClass.ID_CAVE_WALL] = PackedInt32Array([178, 72, 33, 124])
	# ID_CHASM_BASALT (9): Dense volcanic columnar pillars (█, I, !, ])
	_RAMP_TABLE[MaterialDefClass.ID_CHASM_BASALT] = PackedInt32Array([219, 73, 33, 93])
	# ID_CAVE_CRYSTAL (10): Faceted prismatic crystal lattices (X, 4, ^, 118)
	_RAMP_TABLE[MaterialDefClass.ID_CAVE_CRYSTAL] = PackedInt32Array([88, 4, 94, 118])
