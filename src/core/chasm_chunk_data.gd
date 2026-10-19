class_name ChasmChunkData
extends RefCounted

## 2.5D column-based representation of deep subterranean chasms and combat arenas.
## Eliminates full 3D volumetric array allocation (185k voxels) by mathematically
## bounding subterranean voids between 2D floor and ceiling heightfields with vertical walls.
## Provides O(1) virtual voxel access for compatibility with queries and collision checks.

const FLAG_CHASM: int = 1
const FLAG_PILLAR: int = 2
const FLAG_WALL: int = 4
const FLAG_ARENA: int = 8
const FLAG_ARENA_LEDGE: int = 16
const FLAG_BASALT_COLUMN: int = 32

var chunk_size: int = 32
var apron_size: int = 34
var max_height: int = 160
var slice_size: int = 1156
var total_voxels: int = 184960
var chasm_water_level: int = 4
var cave_water_enabled: bool = true

var surface_data: SurfaceChunkData = null
var floor_heights: PackedInt32Array
var ceil_heights: PackedInt32Array
var chasm_flags: PackedByteArray
var materials: PackedByteArray

var has_cave_mouth: bool = false
var has_chasm: bool = false
var has_arena: bool = false

func has_arena_columns() -> bool:
	return has_arena

func _init(p_chunk_size: int = 32, p_max_height: int = 160, p_surface_data: SurfaceChunkData = null) -> void:
	chunk_size = p_chunk_size
	apron_size = chunk_size + 2
	max_height = p_max_height
	slice_size = apron_size * apron_size
	total_voxels = slice_size * max_height

	floor_heights.resize(slice_size)
	floor_heights.fill(0)
	ceil_heights.resize(slice_size)
	ceil_heights.fill(0)
	chasm_flags.resize(slice_size)
	chasm_flags.fill(0)
	materials.resize(slice_size)
	materials.fill(MaterialDef.ID_CHASM_BASALT)

	surface_data = p_surface_data

func _to_column_index(lx: int, lz: int) -> int:
	return (lx + 1) + (lz + 1) * apron_size

func get_floor(lx: int, lz: int) -> int:
	return floor_heights[_to_column_index(lx, lz)]

func set_floor(lx: int, lz: int, h: int) -> void:
	floor_heights[_to_column_index(lx, lz)] = h

func get_ceil(lx: int, lz: int) -> int:
	return ceil_heights[_to_column_index(lx, lz)]

func set_ceil(lx: int, lz: int, h: int) -> void:
	ceil_heights[_to_column_index(lx, lz)] = h

func get_flags(lx: int, lz: int) -> int:
	return chasm_flags[_to_column_index(lx, lz)]

func set_flags(lx: int, lz: int, flags: int) -> void:
	chasm_flags[_to_column_index(lx, lz)] = flags

func is_chasm(lx: int, lz: int) -> bool:
	return (chasm_flags[_to_column_index(lx, lz)] & FLAG_CHASM) != 0

func is_pillar(lx: int, lz: int) -> bool:
	return (chasm_flags[_to_column_index(lx, lz)] & FLAG_PILLAR) != 0

func is_wall(lx: int, lz: int) -> bool:
	return (chasm_flags[_to_column_index(lx, lz)] & FLAG_WALL) != 0

func is_arena(lx: int, lz: int) -> bool:
	return (chasm_flags[_to_column_index(lx, lz)] & FLAG_ARENA) != 0

func is_arena_ledge(lx: int, lz: int) -> bool:
	return (chasm_flags[_to_column_index(lx, lz)] & FLAG_ARENA_LEDGE) != 0

func is_basalt_column(lx: int, lz: int) -> bool:
	return (chasm_flags[_to_column_index(lx, lz)] & FLAG_BASALT_COLUMN) != 0

func get_column_material(lx: int, lz: int) -> int:
	return materials[_to_column_index(lx, lz)]

func set_column_material(lx: int, lz: int, mat: int) -> void:
	materials[_to_column_index(lx, lz)] = mat

func has_surface_data() -> bool:
	return surface_data != null

func get_surface_height(lx: int, lz: int) -> int:
	if surface_data != null:
		return surface_data.get_height(lx, lz)
	return max_height

func is_in_bounds(lx: int, ly: int, lz: int) -> bool:
	return lx >= 0 and lx < chunk_size and ly >= 0 and ly < max_height and lz >= 0 and lz < chunk_size

func is_in_apron(lx: int, ly: int, lz: int) -> bool:
	return lx >= -1 and lx <= chunk_size and ly >= 0 and ly < max_height and lz >= -1 and lz <= chunk_size

func get_voxel(lx: int, ly: int, lz: int) -> int:
	if not is_in_apron(lx, ly, lz):
		return 0
	if ly <= 2:
		return MaterialDef.ID_STONE

	var col_idx = _to_column_index(lx, lz)
	var surf_h = surface_data.heights[col_idx] if surface_data != null else max_height
	if ly > surf_h:
		return 0

	# Subterranean chasm check
	var flag = chasm_flags[col_idx]
	var fl = floor_heights[col_idx]
	var cl = ceil_heights[col_idx]
	var mat = materials[col_idx]

	if (flag & FLAG_CHASM) != 0 and (flag & FLAG_PILLAR) == 0:
		if ly > fl and ly < cl:
			return 0 # Air void!
		if ly == fl:
			return mat # Chasm basalt floor
		if ly == cl:
			return mat # Chasm ceiling
	elif (flag & (FLAG_PILLAR | FLAG_WALL)) != 0:
		if ly >= fl and ly <= cl:
			return mat

	# Surface rock and soil layers
	if surface_data != null:
		if ly == surf_h:
			return surface_data.top_material[col_idx]
		if ly >= max(3, surf_h - 3):
			return surface_data.side_material[col_idx]

	return MaterialDef.ID_STONE

func has_water(lx: int, ly: int, lz: int) -> bool:
	if not is_in_apron(lx, ly, lz):
		return false
	var col_idx = _to_column_index(lx, lz)
	var flag = chasm_flags[col_idx]
	var fl = floor_heights[col_idx]
	var cl = ceil_heights[col_idx]

	if (flag & FLAG_CHASM) != 0 and (flag & FLAG_PILLAR) == 0:
		if ly > fl and ly < cl and ly <= chasm_water_level:
			return true

	if surface_data != null:
		var surf_h = surface_data.heights[col_idx]
		var water_h = surface_data.water_heights[col_idx]
		if ly > surf_h and ly <= water_h:
			return true

	return false
