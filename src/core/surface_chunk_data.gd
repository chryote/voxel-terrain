class_name SurfaceChunkData
extends RefCounted

## Stores surface-shell column heights and materials for a chunk, including a 1-column apron.

var chunk_size: int = 32
var apron_size: int = 34
var shell_depth: int = 3

var heights: PackedInt32Array
var top_material: PackedByteArray
var side_material: PackedByteArray
var water_heights: PackedInt32Array
var mouth_mask: PackedByteArray
var has_cave_mouth: bool = false

func _init(p_chunk_size: int = 32, p_shell_depth: int = 3) -> void:
	chunk_size = p_chunk_size
	apron_size = chunk_size + 2
	shell_depth = p_shell_depth
	var total_columns = apron_size * apron_size
	
	heights.resize(total_columns)
	heights.fill(0)
	top_material.resize(total_columns)
	top_material.fill(0)
	side_material.resize(total_columns)
	side_material.fill(0)
	water_heights.resize(total_columns)
	water_heights.fill(0)

func _to_index(lx: int, lz: int) -> int:
	return (lx + 1) + (lz + 1) * apron_size

func is_in_bounds(lx: int, lz: int) -> bool:
	return lx >= 0 and lx < chunk_size and lz >= 0 and lz < chunk_size

func is_in_apron(lx: int, lz: int) -> bool:
	return lx >= -1 and lx <= chunk_size and lz >= -1 and lz <= chunk_size

func get_height(lx: int, lz: int) -> int:
	if not is_in_apron(lx, lz):
		return 0
	return heights[_to_index(lx, lz)]

func set_height(lx: int, lz: int, h: int) -> void:
	if is_in_apron(lx, lz):
		heights[_to_index(lx, lz)] = h

func get_water_height(lx: int, lz: int) -> int:
	if not is_in_apron(lx, lz):
		return 0
	return water_heights[_to_index(lx, lz)]

func set_water_height(lx: int, lz: int, h: int) -> void:
	if is_in_apron(lx, lz):
		water_heights[_to_index(lx, lz)] = h

func has_water(lx: int, lz: int) -> bool:
	if not is_in_apron(lx, lz):
		return false
	var idx = _to_index(lx, lz)
	return water_heights[idx] > heights[idx]

func get_top_material(lx: int, lz: int) -> int:
	if not is_in_apron(lx, lz):
		return 0
	return top_material[_to_index(lx, lz)]

func set_top_material(lx: int, lz: int, mat: int) -> void:
	if is_in_apron(lx, lz):
		top_material[_to_index(lx, lz)] = mat

func get_side_material(lx: int, lz: int) -> int:
	if not is_in_apron(lx, lz):
		return 0
	return side_material[_to_index(lx, lz)]

func set_side_material(lx: int, lz: int, mat: int) -> void:
	if is_in_apron(lx, lz):
		side_material[_to_index(lx, lz)] = mat

func is_mouth(lx: int, lz: int) -> bool:
	if not has_cave_mouth or mouth_mask.is_empty():
		return false
	if not is_in_apron(lx, lz):
		return false
	return mouth_mask[_to_index(lx, lz)] != 0

func set_mouth(lx: int, lz: int, val: bool) -> void:
	if not is_in_apron(lx, lz):
		return
	if mouth_mask.is_empty():
		if not val:
			return
		mouth_mask.resize(apron_size * apron_size)
		mouth_mask.fill(0)
	mouth_mask[_to_index(lx, lz)] = 1 if val else 0

func fill(h: int, top_mat: int, side_mat: int, water_h: int = 0) -> void:
	heights.fill(h)
	top_material.fill(top_mat)
	side_material.fill(side_mat)
	water_heights.fill(water_h)
	mouth_mask.clear()
	has_cave_mouth = false
