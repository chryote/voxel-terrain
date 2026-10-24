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
			"loam_temperate": PackedColorArray([Color("#3b261a"), Color("#593e2b"), Color("#6c4e38"), Color("#462f20")]),
			"podzol_boreal": PackedColorArray([Color("#4a3a30"), Color("#5c3722"), Color("#7a6352"), Color("#36251b")]),
			"peat_wetland": PackedColorArray([Color("#3a332d"), Color("#4d3728"), Color("#5a4332"), Color("#2d211a")])
		},
		GROUP_BADLANDS: {
			"canyon_terracotta": PackedColorArray([Color("#532619"), Color("#783723"), Color("#9c4928"), Color("#88583c")]),
			"painted_desert": PackedColorArray([Color("#503239"), Color("#844837"), Color("#926a3a"), Color("#6c3a37")]),
			"desert_sandstone": PackedColorArray([Color("#482d1c"), Color("#7a3f20"), Color("#93592b"), Color("#a2743c")])
		},
		GROUP_MINERAL: {
			"banded_ironstone": PackedColorArray([Color("#262327"), Color("#662923"), Color("#7c4b37"), Color("#8a4025")]),
			"copper_oxide": PackedColorArray([Color("#4a2822"), Color("#38483a"), Color("#6b362c"), Color("#495642")]),
			"sulfur_alkali": PackedColorArray([Color("#3e352b"), Color("#796939"), Color("#84755d"), Color("#968a73")])
		},
		GROUP_VOLCANIC: {
			"basaltic_tephra": PackedColorArray([Color("#252427"), Color("#473f35"), Color("#5a3d2e"), Color("#3c3430")]),
			"calcite_shale": PackedColorArray([Color("#28262a"), Color("#524d4a"), Color("#4b382d"), Color("#706a64")])
		},
		GROUP_ALIEN: {
            "toxic_bioluminescence": PackedColorArray([Color("#1c0f24"), Color("#5c1b52"), Color("#0fd64b"), Color("#bce823")]),
            "necrotic_biomass": PackedColorArray([Color("#3a1721"), Color("#822e46"), Color("#b37482"), Color("#3b2b40")]),
            "irradiated_xenolith": PackedColorArray([Color("#0a151f"), Color("#184c6e"), Color("#0de3d4"), Color("#db1866")]),
            "ammonia_sludge": PackedColorArray([Color("#232b21"), Color("#ab330a"), Color("#1c9c8e"), Color("#d1a817")])
        }
	}
