class_name MaterialRegistry
extends Resource

## Registry mapping material IDs to their definitions and colors.

@export var materials: Array[MaterialDef] = []
var _lookup: Dictionary = {}

func _init() -> void:
	_rebuild_lookup()

func _rebuild_lookup() -> void:
	_lookup.clear()
	for mat in materials:
		if mat != null:
			_lookup[mat.id] = mat

func register_material(mat: MaterialDef) -> void:
	if mat == null:
		return
	_lookup[mat.id] = mat
	if not materials.has(mat):
		materials.append(mat)

func get_material(id: int) -> MaterialDef:
	if _lookup.is_empty() and materials.size() > 0:
		_rebuild_lookup()
	return _lookup.get(id, null)

func get_top_color(id: int) -> Color:
	var mat = get_material(id)
	return mat.top_color if mat != null else Color.WHITE

func get_side_color(id: int) -> Color:
	var mat = get_material(id)
	return mat.side_color if mat != null else Color.WHITE

static func create_default_registry() -> MaterialRegistry:
	var reg = MaterialRegistry.new()
	reg.register_material(MaterialDef.new(MaterialDef.ID_AIR, "air", Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
	reg.register_material(MaterialDef.new(MaterialDef.ID_GRASS, "grass", Color("#567d46"), Color("#6b4f38")))
	reg.register_material(MaterialDef.new(MaterialDef.ID_DIRT, "dirt", Color("#6b4f38"), Color("#593e2b")))
	reg.register_material(MaterialDef.new(MaterialDef.ID_STONE, "stone", Color("#787878"), Color("#646464")))
	reg.register_material(MaterialDef.new(MaterialDef.ID_SAND, "sand", Color("#d7c58d"), Color("#c4b179")))
	reg.register_material(MaterialDef.new(MaterialDef.ID_SNOW, "snow", Color("#f0f4f8"), Color("#d8e2ec")))
	reg.register_material(MaterialDef.new(MaterialDef.ID_SEABED, "seabed", Color("#3b4e43"), Color("#2e3d34")))
	reg.register_material(MaterialDef.new(MaterialDef.ID_GRAVEL, "gravel", Color("#5a574f"), Color("#4b4841")))
	return reg
