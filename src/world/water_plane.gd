class_name WaterPlane
extends MeshInstance3D

## Visual ocean water plane covering the continent at sea level.

const MaterialProviderClass = preload("res://src/rendering/terrain_material_provider.gd")

var sea_level_height: float = 9.0

func setup(bounds: WorldBounds, p_sea_level_height: float) -> void:
	sea_level_height = p_sea_level_height
	var total_w = bounds.max_world_x - bounds.min_world_x
	var total_d = bounds.max_world_z - bounds.min_world_z

	var p_mesh = PlaneMesh.new()
	p_mesh.size = Vector2(total_w, total_d)
	mesh = p_mesh

	position = Vector3(
		(bounds.min_world_x + bounds.max_world_x) * 0.5,
		sea_level_height,
		(bounds.min_world_z + bounds.max_world_z) * 0.5
	)

	material_override = MaterialProviderClass.get_ocean_material()

func set_ocean_visible(p_visible: bool) -> void:
	if visible != p_visible:
		visible = p_visible

