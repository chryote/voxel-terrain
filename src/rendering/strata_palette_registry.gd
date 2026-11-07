class_name StrataPaletteRegistry
extends RefCounted

## Pure component defining scientific & aesthetic sedimentary strata theme groups and color horizons.
## Categorized like Matplotlib colormap families (Soil Pedology, Canyon Badlands, Mineral BIF, Volcanic Tephra).
## Decoupled from scene nodes, world logic, and meshes for testability and zero-overhead GPU application.

const GROUP_SOIL: String = "soil"
const GROUP_BADLANDS: String = "badlands"
const GROUP_MINERAL: String = "mineral"
const GROUP_VOLCANIC: String = "volcanic"
const GROUP_ALIEN: String = "alien"

const DEFAULT_GROUP: String = GROUP_SOIL
const DEFAULT_PRESET: String = "loam_temperate"

static var _THEMES: Dictionary = {}

static func _static_init() -> void:
	_init_themes()

static func get_groups() -> PackedStringArray:
	if _THEMES.is_empty():
		_init_themes()
	return PackedStringArray(_THEMES.keys())

static func get_presets(group: String) -> PackedStringArray:
	if _THEMES.is_empty():
		_init_themes()
	if not _THEMES.has(group):
		return PackedStringArray()
	var presets_dict: Dictionary = _THEMES[group]
	return PackedStringArray(presets_dict.keys())

static func get_palette(group: String, preset: String) -> PackedColorArray:
	if _THEMES.is_empty():
		_init_themes()
	if _THEMES.has(group):
		var group_dict: Dictionary = _THEMES[group]
		if group_dict.has(preset):
			return group_dict[preset]
	return get_default_palette()

static func get_default_palette() -> PackedColorArray:
	if _THEMES.is_empty():
		_init_themes()
	return _THEMES[DEFAULT_GROUP][DEFAULT_PRESET]

static func apply_to_material(mat: ShaderMaterial, config: Resource) -> void:
	if mat == null:
		return
	var enabled = bool(config.get("strata_enabled")) if config != null and config.get("strata_enabled") != null else true
	var group = String(config.get("strata_group")) if config != null and config.get("strata_group") != null else DEFAULT_GROUP
	var preset = String(config.get("strata_preset")) if config != null and config.get("strata_preset") != null else DEFAULT_PRESET
	var freq = float(config.get("strata_frequency")) if config != null and config.get("strata_frequency") != null else 0.35
	var warp = float(config.get("strata_warp_strength")) if config != null and config.get("strata_warp_strength") != null else 0.50

	var pal = get_palette(group, preset)
	mat.set_shader_parameter("strata_enabled", enabled)
	mat.set_shader_parameter("strata_frequency", freq)
	mat.set_shader_parameter("strata_warp_strength", warp)
	mat.set_shader_parameter("strata_color_0", pal[0])
	mat.set_shader_parameter("strata_color_1", pal[1])
	mat.set_shader_parameter("strata_color_2", pal[2])
	mat.set_shader_parameter("strata_color_3", pal[3])

static func _init_themes() -> void:
	_THEMES = {
		GROUP_SOIL: {
			"loam_temperate": PackedColorArray([Color("#1e1917"), Color("#3d2620"), Color("#4a4139"), Color("#292325")]),
			"podzol_boreal": PackedColorArray([Color("#242220"), Color("#382822"), Color("#524b44"), Color("#1a1615")]),
			"peat_wetland": PackedColorArray([Color("#1c1a17"), Color("#2e241e"), Color("#38312a"), Color("#14110f")])
		},
		GROUP_BADLANDS: {
			"canyon_terracotta": PackedColorArray([Color("#2b1814"), Color("#4a241d"), Color("#5e3326"), Color("#3b2a24")]),
			"painted_desert": PackedColorArray([Color("#2d1f23"), Color("#4d2c25"), Color("#59432d"), Color("#382221")]),
			"desert_sandstone": PackedColorArray([Color("#291c15"), Color("#47291b"), Color("#573822"), Color("#63492d")])
		},
		GROUP_MINERAL: {
			"banded_ironstone": PackedColorArray([Color("#1a181b"), Color("#421d1a"), Color("#523429"), Color("#362018")]),
			"copper_oxide": PackedColorArray([Color("#2e1b18"), Color("#252e27"), Color("#452520"), Color("#30382c")]),
			"sulfur_alkali": PackedColorArray([Color("#26211c"), Color("#4d4328"), Color("#544b3e"), Color("#61594b")])
		},
		GROUP_VOLCANIC: {
			"basaltic_tephra": PackedColorArray([Color("#18171a"), Color("#2e2923"), Color("#3b2820"), Color("#26211f")]),
			"calcite_shale": PackedColorArray([Color("#1c1b1e"), Color("#383533"), Color("#33261f"), Color("#4d4945")]),
			"irradiated_tephra": PackedColorArray([Color("#121413"), Color("#1e241f"), Color("#2b3728"), Color("#181d19")])
		},
		GROUP_ALIEN: {
			"crimson_rot": PackedColorArray([Color("#260205"), Color("#7a0c18"), Color("#c21427"), Color("#45050d")]),
			"toxic_bioluminescence": PackedColorArray([Color("#140d18"), Color("#381533"), Color("#2b4a28"), Color("#576622")]),
			"necrotic_biomass": PackedColorArray([Color("#241117"), Color("#4d1e2b"), Color("#66454d"), Color("#241c28")]),
			"irradiated_xenolith": PackedColorArray([Color("#0d1217"), Color("#162e3d"), Color("#285956"), Color("#591c34")]),
			"ammonia_sludge": PackedColorArray([Color("#1a1f18"), Color("#522211"), Color("#1d4a45"), Color("#66541c")])
		}
	}
