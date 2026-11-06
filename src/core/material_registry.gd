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
	if mat == null:
		return Color.WHITE
	var c = mat.top_color
	c.a = float(id) / 255.0
	return c

func get_side_color(id: int) -> Color:
	var mat = get_material(id)
	if mat == null:
		return Color.WHITE
	var c = mat.side_color
	c.a = float(id) / 255.0
	return c

static func create_default_registry() -> MaterialRegistry:
	var reg = MaterialRegistry.new()
	reg.register_material(MaterialDef.new(MaterialDef.ID_AIR, "air", Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
	reg.register_material(MaterialDef.new(MaterialDef.ID_GRASS, "grass", Color("#363836"), Color("#362a23")))
	reg.register_material(MaterialDef.new(MaterialDef.ID_DIRT, "dirt", Color("#302e2c"), Color("#2e221c")))
	reg.register_material(MaterialDef.new(MaterialDef.ID_STONE, "stone", Color("#454442"), Color("#363533")))
	reg.register_material(MaterialDef.new(MaterialDef.ID_SAND, "sand", Color("#665b49"), Color("#544a3b")))
	reg.register_material(MaterialDef.new(MaterialDef.ID_SNOW, "snow", Color("#87827a"), Color("#6e6962")))
	reg.register_material(MaterialDef.new(MaterialDef.ID_SEABED, "seabed", Color("#212522"), Color("#181b19")))
	reg.register_material(MaterialDef.new(MaterialDef.ID_GRAVEL, "gravel", Color("#33302c"), Color("#282522")))
	reg.register_material(MaterialDef.new(MaterialDef.ID_CAVE_WALL, "cave_wall", Color("#2e2b2f"), Color("#232024")))
	reg.register_material(MaterialDef.new(MaterialDef.ID_CHASM_BASALT, "chasm_basalt", Color("#19181a"), Color("#121113")))
	reg.register_material(MaterialDef.new(MaterialDef.ID_CAVE_CRYSTAL, "cave_crystal", Color("#3d6b68"), Color("#2b4f4d")))
	return reg
