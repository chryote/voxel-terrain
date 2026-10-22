class_name FoliageDef
extends Resource

## Data definition for procedural foliage instances (grass clumps, shrubs, trees, rocks).

@export var id: int = 0
@export var name: String = "Grass Tuft"
@export var mesh: Mesh = null
@export_range(0.1, 5.0) var scale_min: float = 0.8
@export_range(0.1, 10.0) var scale_max: float = 1.2
@export var random_yaw: bool = true
@export_range(0.0, 90.0) var max_slope_degrees: float = 35.0
@export var allowed_material_ids: Array[int] = [MaterialDef.ID_GRASS]
@export var min_elevation: float = 24.5
@export var max_elevation: float = 130.0
@export var tint_color: Color = Color.WHITE
@export_range(0.0, 1.0) var wind_sway: float = 0.1

func _init(
	p_id: int = 0,
	p_name: String = "Grass Tuft",
	p_scale_min: float = 0.8,
	p_scale_max: float = 1.2,
	p_max_slope: float = 35.0,
	p_allowed_mats: Array[int] = [MaterialDef.ID_GRASS],
	p_min_elev: float = 24.5,
	p_max_elev: float = 130.0,
	p_tint: Color = Color.WHITE
) -> void:
	id = p_id
	name = p_name
	scale_min = p_scale_min
	scale_max = p_scale_max
	max_slope_degrees = p_max_slope
	allowed_material_ids = p_allowed_mats
	min_elevation = p_min_elev
	max_elevation = p_max_elev
	tint_color = p_tint

func is_valid_surface(mat_id: int, elevation: float, slope_degrees: float) -> bool:
	if not allowed_material_ids.is_empty() and not allowed_material_ids.has(mat_id):
		return false
	if elevation < min_elevation or elevation > max_elevation:
		return false
	if slope_degrees > max_slope_degrees:
		return false
	return true
