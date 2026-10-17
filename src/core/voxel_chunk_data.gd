class_name VoxelChunkData
extends RefCounted

## Stores 3D volumetric voxel material IDs and water states for a chunk,
## including a 1-voxel apron across horizontal boundaries for zero-lock multithreaded meshing.

const SECTION_HEIGHT: int = 16
const SECTION_MIXED: int = 0
const SECTION_EMPTY: int = 1
const SECTION_SOLID: int = 2

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

var section_count: int = 10
var section_status: PackedByteArray
var has_section_status: bool = false

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

	section_count = ceili(float(max_height) / float(SECTION_HEIGHT))
	section_status.resize(section_count)
	section_status.fill(SECTION_EMPTY)
	has_section_status = true

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
		has_section_status = false

func has_water(lx: int, ly: int, lz: int) -> bool:
	if not is_in_apron(lx, ly, lz):
		return false
	return water_voxels[_to_index(lx, ly, lz)] == 1

func set_water(lx: int, ly: int, lz: int, val: bool) -> void:
	if is_in_apron(lx, ly, lz):
		water_voxels[_to_index(lx, ly, lz)] = 1 if val else 0

func fill_material(mat: int) -> void:
	voxels.fill(mat)
	section_status.fill(SECTION_EMPTY if mat == 0 else SECTION_SOLID)
	has_section_status = true

func fill_water(val: bool) -> void:
	water_voxels.fill(1 if val else 0)

func get_section_count() -> int:
	return section_count

func get_section_status(s: int) -> int:
	if not has_section_status:
		compute_section_status()
	if s >= 0 and s < section_count:
		return section_status[s]
	return SECTION_EMPTY

func set_section_status(s: int, status: int) -> void:
	if s >= 0 and s < section_count:
		section_status[s] = status

func is_section_empty(s: int) -> bool:
	return get_section_status(s) == SECTION_EMPTY

func is_section_solid(s: int) -> bool:
	return get_section_status(s) == SECTION_SOLID

func compute_section_status() -> void:
	if section_count <= 0:
		section_count = ceili(float(max_height) / float(SECTION_HEIGHT))
	if section_status.size() != section_count:
		section_status.resize(section_count)

	for s in range(section_count):
		var start_ly = s * SECTION_HEIGHT
		var end_ly = mini((s + 1) * SECTION_HEIGHT, max_height)
		var start_idx = start_ly * slice_size
		var end_idx = end_ly * slice_size
		var sec_slice = voxels.slice(start_idx, end_idx)
		var zero_count = sec_slice.count(0)

		if zero_count == sec_slice.size():
			section_status[s] = SECTION_EMPTY
		elif zero_count == 0:
			section_status[s] = SECTION_SOLID
		else:
			section_status[s] = SECTION_MIXED

	has_section_status = true

func clear() -> void:
	voxels.fill(0)
	water_voxels.fill(0)
	has_surface_heights = false
	has_cave_mouth = false
	surface_heights.clear()
	section_status.fill(SECTION_EMPTY)
	has_section_status = true

