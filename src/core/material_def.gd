class_name MaterialDef
extends Resource

## Definition for a voxel material including its surface and side colors.

@export var id: int = 0
@export var name: String = "air"
@export var top_color: Color = Color.WHITE
@export var side_color: Color = Color.WHITE

func _init(p_id: int = 0, p_name: String = "air", p_top: Color = Color.WHITE, p_side: Color = Color.WHITE) -> void:
	id = p_id
	name = p_name
	top_color = p_top
	side_color = p_side
