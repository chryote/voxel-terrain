class_name VoxelChunkData
extends RefCounted

## Stores 3D volumetric voxel material IDs and water states for a chunk,
## including a 1-voxel apron across horizontal boundaries for zero-lock multithreaded meshing.

var chunk_size: int = 32
var apron_size: int = 34
var max_height: int = 160
var slice_size: int = 1156
var total_voxels: int = 184960

var voxels: PackedByteArray
var water_voxels: PackedByteArray
var surface_heights: PackedInt32Array
var has_surface_heights: bool = false
var has_cave_mouth: bool = false

func _init(p_chunk_size: int = 32, p_max_height: int = 160) -> void:
	chunk_size = p_chunk_size
	apron_size = chunk_size + 2
	max_height = p_max_height
	slice_size = apron_size * apron_size
	total_voxels = slice_size * max_height

	voxels.resize(total_voxels)
	voxels.fill(0)
	water_voxels.resize(total_voxels)
	water_voxels.fill(0)

func _to_column_index(lx: int, lz: int) -> int:
	return (lx + 1) + (lz + 1) * apron_size

func has_surface_data() -> bool:
	return has_surface_heights and not surface_heights.is_empty()

func get_surface_height(lx: int, lz: int) -> int:
	if not has_surface_data():
		return max_height
	if lx < -1 or lx > chunk_size or lz < -1 or lz > chunk_size:
		return max_height
	return surface_heights[_to_column_index(lx, lz)]

func set_surface_height(lx: int, lz: int, h: int) -> void:
	if surface_heights.is_empty():
		surface_heights.resize(slice_size)
		surface_heights.fill(max_height)
	has_surface_heights = true
	if lx >= -1 and lx <= chunk_size and lz >= -1 and lz <= chunk_size:
		surface_heights[_to_column_index(lx, lz)] = h


func _to_index(lx: int, ly: int, lz: int) -> int:
	return (lx + 1) + (lz + 1) * apron_size + ly * slice_size

func is_in_bounds(lx: int, ly: int, lz: int) -> bool:
	return lx >= 0 and lx < chunk_size and ly >= 0 and ly < max_height and lz >= 0 and lz < chunk_size

func is_in_apron(lx: int, ly: int, lz: int) -> bool:
	return lx >= -1 and lx <= chunk_size and ly >= 0 and ly < max_height and lz >= -1 and lz <= chunk_size

func get_voxel(lx: int, ly: int, lz: int) -> int:
	if not is_in_apron(lx, ly, lz):
		return 0
	return voxels[_to_index(lx, ly, lz)]

func set_voxel(lx: int, ly: int, lz: int, mat: int) -> void:
	if is_in_apron(lx, ly, lz):
		voxels[_to_index(lx, ly, lz)] = mat

func has_water(lx: int, ly: int, lz: int) -> bool:
	if not is_in_apron(lx, ly, lz):
		return false
	return water_voxels[_to_index(lx, ly, lz)] == 1

func set_water(lx: int, ly: int, lz: int, val: bool) -> void:
	if is_in_apron(lx, ly, lz):
		water_voxels[_to_index(lx, ly, lz)] = 1 if val else 0

func fill_material(mat: int) -> void:
	voxels.fill(mat)

func fill_water(val: bool) -> void:
	water_voxels.fill(1 if val else 0)

func clear() -> void:
	voxels.fill(0)
	water_voxels.fill(0)
	has_surface_heights = false
	has_cave_mouth = false
	surface_heights.clear()

