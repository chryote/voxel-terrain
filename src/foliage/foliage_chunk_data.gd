class_name FoliageChunkData
extends RefCounted

## Pure data container holding instanced transforms and colors for all foliage in a chunk.
## Generated safely off-thread and passed to FoliageChunkNode / MultiMeshInstance3D.

var transforms_by_type: Dictionary = {} # int (foliage_id) -> Array[Transform3D]
var colors_by_type: Dictionary = {}     # int (foliage_id) -> Array[Color]

func add_instance(type_id: int, transform: Transform3D, color: Color = Color.WHITE) -> void:
	if not transforms_by_type.has(type_id):
		transforms_by_type[type_id] = []
		colors_by_type[type_id] = []
	transforms_by_type[type_id].append(transform)
	colors_by_type[type_id].append(color)

func get_instances(type_id: int) -> Array:
	return transforms_by_type.get(type_id, [])

func get_colors(type_id: int) -> Array:
	return colors_by_type.get(type_id, [])

func get_types() -> Array:
	return transforms_by_type.keys()

func get_instance_count(type_id: int) -> int:
	if transforms_by_type.has(type_id):
		return transforms_by_type[type_id].size()
	return 0

func get_total_count() -> int:
	var total = 0
	for list in transforms_by_type.values():
		total += list.size()
	return total

func is_empty() -> bool:
	return transforms_by_type.is_empty()

func clear() -> void:
	transforms_by_type.clear()
	colors_by_type.clear()
