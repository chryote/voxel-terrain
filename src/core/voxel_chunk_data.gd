class_name VoxelChunkData
extends RefCounted

## Pure data container for a 3D volumetric chunk with a 1-voxel horizontal apron.
## Thread-safe for generation and meshing across background worker threads.

var chunk_size: int = 32
var apron_size: int = 34
var height: int = 128

var voxels: PackedByteArray
var _total_voxels: int = 0
var _stride_y: int = 0
var _stride_z: int = 0

func _init(p_chunk_size: int = 32, p_height: int = 128) -> void:
	chunk_size = maxi(4, p_chunk_size)
	height = maxi(8, p_height)
	apron_size = chunk_size + 2

	_stride_y = apron_size
	_stride_z = apron_size * height
	_total_voxels = apron_size * height * apron_size

	voxels.resize(_total_voxels)
	voxels.fill(0)

func _to_index(lx: int, ly: int, lz: int) -> int:
	return (lx + 1) + (ly * _stride_y) + ((lz + 1) * _stride_z)

func is_in_bounds(lx: int, ly: int, lz: int) -> bool:
	return lx >= 0 and lx < chunk_size and ly >= 0 and ly < height and lz >= 0 and lz < chunk_size

func is_in_apron(lx: int, ly: int, lz: int) -> bool:
	return lx >= -1 and lx <= chunk_size and ly >= 0 and ly < height and lz >= -1 and lz <= chunk_size

func get_voxel(lx: int, ly: int, lz: int) -> int:
	if not is_in_apron(lx, ly, lz):
		return 0
	return voxels[_to_index(lx, ly, lz)]

func set_voxel(lx: int, ly: int, lz: int, material_id: int) -> void:
	if is_in_apron(lx, ly, lz):
		voxels[_to_index(lx, ly, lz)] = material_id

func is_solid(lx: int, ly: int, lz: int) -> bool:
	return get_voxel(lx, ly, lz) != 0

func fill(material_id: int) -> void:
	voxels.fill(material_id)

func fill_layer(ly: int, material_id: int) -> void:
	if ly < 0 or ly >= height:
		return
	for lz in range(-1, chunk_size + 1):
		for lx in range(-1, chunk_size + 1):
			voxels[_to_index(lx, ly, lz)] = material_id

func get_highest_solid_y(lx: int, lz: int) -> int:
	if not (lx >= -1 and lx <= chunk_size and lz >= -1 and lz <= chunk_size):
		return -1
	for ly in range(height - 1, -1, -1):
		if voxels[_to_index(lx, ly, lz)] != 0:
			return ly
	return -1

func get_total_voxel_count() -> int:
	return _total_voxels

func get_memory_bytes() -> int:
	return _total_voxels
