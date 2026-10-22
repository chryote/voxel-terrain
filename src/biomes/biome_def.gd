class_name BiomeDef
extends Resource

## Data definition for a terrain biome, specifying climate envelopes,
## surface materials, foliage densities, and visual tints.

@export var id: int = 0
@export var name: String = "Plains"
@export_range(-1.0, 1.0) var temperature: float = 0.0
@export_range(-1.0, 1.0) var humidity: float = 0.0
@export var min_elevation: float = -100.0
@export var max_elevation: float = 300.0

@export var surface_material_id: int = MaterialDef.ID_GRASS
@export var subsurface_material_id: int = MaterialDef.ID_DIRT
@export_range(0.0, 1.0) var foliage_density: float = 0.5
@export var allowed_foliage_ids: Array[int] = []

@export var tint_color: Color = Color.WHITE
@export var water_tint: Color = Color.WHITE

func _init(
	p_id: int = 0,
	p_name: String = "Plains",
	p_temp: float = 0.0,
	p_humidity: float = 0.0,
	p_min_elev: float = -100.0,
	p_max_elev: float = 300.0,
	p_surface_mat: int = MaterialDef.ID_GRASS,
	p_subsurf_mat: int = MaterialDef.ID_DIRT,
	p_foliage_density: float = 0.5,
	p_tint: Color = Color.WHITE
) -> void:
	id = p_id
	name = p_name
	temperature = p_temp
	humidity = p_humidity
	min_elevation = p_min_elev
	max_elevation = p_max_elev
	surface_material_id = p_surface_mat
	subsurface_material_id = p_subsurf_mat
	foliage_density = p_foliage_density
	tint_color = p_tint

## Calculates distance squared in climate space (temperature, humidity)
func climate_distance_sq(target_temp: float, target_humidity: float) -> float:
	var dt = temperature - target_temp
	var dh = humidity - target_humidity
	return dt * dt + dh * dh
