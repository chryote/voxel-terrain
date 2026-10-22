class_name TerrainPaintLayer
extends Resource

## Definition of a terrain paint layer (channel) used by the splat painter.

const CHANNEL_R: int = 0 # Typically Dirt / Path
const CHANNEL_G: int = 1 # Typically Sand / Beach
const CHANNEL_B: int = 2 # Typically Cobblestone / Rock
const CHANNEL_A: int = 3 # Typically Snow / Special

@export var layer_id: int = 0
@export var name: String = "Dirt Path"
@export var color: Color = Color("#6b4f38")
@export_range(0.0, 1.0) var roughness: float = 0.90
@export var target_material_id: int = MaterialDef.ID_DIRT
@export var foliage_suppression: bool = true

func _init(
	p_id: int = 0,
	p_name: String = "Dirt Path",
	p_color: Color = Color("#6b4f38"),
	p_roughness: float = 0.90,
	p_mat_id: int = MaterialDef.ID_DIRT,
	p_suppress_foliage: bool = true
) -> void:
	layer_id = p_id
	name = p_name
	color = p_color
	roughness = p_roughness
	target_material_id = p_mat_id
	foliage_suppression = p_suppress_foliage

static func create_default_layers() -> Array[TerrainPaintLayer]:
	var layers: Array[TerrainPaintLayer] = []
	layers.append(TerrainPaintLayer.new(CHANNEL_R, "Dirt Path", Color("#6b4f38"), 0.92, MaterialDef.ID_DIRT, true))
	layers.append(TerrainPaintLayer.new(CHANNEL_G, "Sand", Color("#d7c58d"), 0.85, MaterialDef.ID_SAND, false))
	layers.append(TerrainPaintLayer.new(CHANNEL_B, "Rock / Cobble", Color("#504e4c"), 0.70, MaterialDef.ID_GRAVEL, true))
	layers.append(TerrainPaintLayer.new(CHANNEL_A, "Snow", Color("#f0f4f8"), 0.60, MaterialDef.ID_SNOW, false))
	return layers
