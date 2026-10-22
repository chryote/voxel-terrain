class_name ChunkPaintManager
extends RefCounted

## Coordinates terrain paint data across all chunks in the world.
## Handles multi-chunk brush clipping, splatmap texture generation,
## and cross-chunk seam blending.

const TerrainPaintDataClass = preload("res://src/painting/terrain_paint_data.gd")
const TerrainPaintLayerClass = preload("res://src/painting/terrain_paint_layer.gd")
const PaintStrokeClass = preload("res://src/painting/paint_stroke.gd")

var chunk_size: int = 32
var voxel_size: float = 1.0
var splat_resolution: int = 32
var layers: Array[TerrainPaintLayer] = []

var _chunk_paint_data: Dictionary = {} # int (packed chunk key) -> TerrainPaintData

func _init(p_chunk_size: int = 32, p_voxel_size: float = 1.0, p_splat_res: int = 32) -> void:
	chunk_size = maxi(4, p_chunk_size)
	voxel_size = maxf(0.1, p_voxel_size)
	splat_resolution = maxi(4, p_splat_res)
	layers = TerrainPaintLayerClass.create_default_layers()

func get_or_create_paint_data(coord: ChunkCoord) -> TerrainPaintData:
	if coord == null:
		return null
	var key = coord.to_key()
	if not _chunk_paint_data.has(key):
		_chunk_paint_data[key] = TerrainPaintDataClass.new(splat_resolution)
	return _chunk_paint_data[key]

func get_paint_data(coord: ChunkCoord) -> TerrainPaintData:
	if coord == null:
		return null
	return _chunk_paint_data.get(coord.to_key(), null)

func has_paint_data(coord: ChunkCoord) -> bool:
	if coord == null:
		return false
	return _chunk_paint_data.has(coord.to_key())

func get_splat_texture(coord: ChunkCoord) -> ImageTexture:
	var data = get_paint_data(coord)
	if data == null:
		return null
	return data.get_or_create_texture()

func clear_all() -> void:
	_chunk_paint_data.clear()

## Applies a brush stroke across world space, dispatching to all affected chunks
func paint_world(
	world_pos: Vector3,
	radius: float,
	strength: float,
	hardness: float,
	channel: int,
	mode: int = 0
) -> Array[ChunkCoord]:
	var affected_chunks: Array[ChunkCoord] = []
	if radius <= 0.0:
		return affected_chunks

	var chunk_world_size = float(chunk_size) * voxel_size
	var pixels_per_meter = float(splat_resolution) / chunk_world_size
	var radius_pixels = radius * pixels_per_meter

	var min_cx = int(floor((world_pos.x - radius) / chunk_world_size))
	var max_cx = int(floor((world_pos.x + radius) / chunk_world_size))
	var min_cz = int(floor((world_pos.z - radius) / chunk_world_size))
	var max_cz = int(floor((world_pos.z + radius) / chunk_world_size))

	for cz in range(min_cz, max_cz + 1):
		for cx in range(min_cx, max_cx + 1):
			var coord = ChunkCoord.new(cx, cz)
			var data = get_or_create_paint_data(coord)

			var chunk_origin_x = float(cx) * chunk_world_size
			var chunk_origin_z = float(cz) * chunk_world_size

			# Convert world brush center to chunk-local pixel coords
			var local_px = (world_pos.x - chunk_origin_x) * pixels_per_meter
			var local_pz = (world_pos.z - chunk_origin_z) * pixels_per_meter

			var modified = data.apply_brush(
				local_px,
				local_pz,
				radius_pixels,
				hardness,
				strength,
				channel,
				mode
			)

			if modified:
				affected_chunks.append(coord)

	return affected_chunks

## Paints discrete voxel materials directly into SurfaceChunkData (for meshers & physics)
func paint_discrete_material(
	surface_data: SurfaceChunkData,
	coord: ChunkCoord,
	world_pos: Vector3,
	radius: float,
	material_id: int
) -> bool:
	if surface_data == null or coord == null or radius <= 0.0:
		return false

	var chunk_world_size = float(chunk_size) * voxel_size
	var chunk_origin_x = float(coord.x) * chunk_world_size
	var chunk_origin_z = float(coord.z) * chunk_world_size

	var local_x = (world_pos.x - chunk_origin_x) / voxel_size
	var local_z = (world_pos.z - chunk_origin_z) / voxel_size
	var radius_cols = radius / voxel_size
	var radius_sq = radius_cols * radius_cols

	var min_lx = clampi(int(floor(local_x - radius_cols)), 0, chunk_size - 1)
	var max_lx = clampi(int(ceil(local_x + radius_cols)), 0, chunk_size - 1)
	var min_lz = clampi(int(floor(local_z - radius_cols)), 0, chunk_size - 1)
	var max_lz = clampi(int(ceil(local_z + radius_cols)), 0, chunk_size - 1)

	var modified = false
	for lz in range(min_lz, max_lz + 1):
		var dz = float(lz) - local_z
		var dz_sq = dz * dz
		for lx in range(min_lx, max_lx + 1):
			var dx = float(lx) - local_x
			if dx * dx + dz_sq <= radius_sq:
				var cur_mat = surface_data.get_top_material(lx, lz)
				if cur_mat != material_id:
					surface_data.set_top_material(lx, lz, material_id)
					modified = true

	return modified

func export_paint_state() -> Dictionary:
	var state: Dictionary = {}
	for key in _chunk_paint_data:
		var data: TerrainPaintData = _chunk_paint_data[key]
		if not data.is_empty():
			state[key] = data.to_dict()
	return state

func import_paint_state(state: Dictionary) -> void:
	clear_all()
	for key in state:
		var d = state[key]
		var data = TerrainPaintDataClass.new(splat_resolution)
		data.from_dict(d)
		_chunk_paint_data[key] = data
