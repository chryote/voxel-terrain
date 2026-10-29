class_name FoliageGenerator
extends RefCounted

## Pure procedural scatter generator for grass and non-collision foliage clutter.
## Deterministic, thread-safe, and runs off-thread without scene tree dependencies.

const FoliageChunkDataClass = preload("res://src/core/foliage_chunk_data.gd")
const FoliageConfigClass = preload("res://src/generation/foliage_generator_config.gd")

func generate(
	coord: ChunkCoord,
	surface_data: SurfaceChunkData,
	config: Resource = null
) -> FoliageChunkData:
	var foliage_data = FoliageChunkDataClass.new()
	if surface_data == null or coord == null:
		return foliage_data

	var cfg: FoliageGeneratorConfig = config as FoliageGeneratorConfig
	if cfg == null:
		cfg = FoliageConfigClass.new()
	if not cfg.enabled:
		return foliage_data

	var chunk_size = surface_data.chunk_size
	var chunk_wx = coord.x * chunk_size
	var chunk_wz = coord.z * chunk_size
	var seed_val = cfg.world_seed

	for lz in range(chunk_size):
		for lx in range(chunk_size):
			if surface_data.get_top_material(lx, lz) != cfg.target_material_id:
				continue

			var wx = chunk_wx + lx
			var wz = chunk_wz + lz
			_scatter_voxel_foliage(lx, lz, wx, wz, surface_data, cfg, seed_val, foliage_data)

	return foliage_data

func _scatter_voxel_foliage(
	lx: int,
	lz: int,
	wx: int,
	wz: int,
	surface_data: SurfaceChunkData,
	cfg: FoliageGeneratorConfig,
	seed_val: int,
	out_data: FoliageChunkData
) -> void:
	var spawn_hash = _hash_coord(wx, wz, seed_val, 0)
	if _hash_to_float(spawn_hash) > cfg.density_probability:
		return

	var count_hash = _hash_coord(wx, wz, seed_val, 1)
	var max_tufts = maxi(1, cfg.max_tufts_per_voxel)
	var tuft_count = 1 + (count_hash % max_tufts)
	var h = float(surface_data.get_height(lx, lz))

	for t_idx in range(tuft_count):
		var t = _build_tuft_transform(lx, lz, wx, wz, h, t_idx, cfg, seed_val)
		out_data.add_instance(t)

func _build_tuft_transform(
	lx: int,
	lz: int,
	wx: int,
	wz: int,
	h: float,
	t_idx: int,
	cfg: FoliageGeneratorConfig,
	seed_val: int
) -> Transform3D:
	var jx_hash = _hash_coord(wx, wz, seed_val, 2 + t_idx * 4)
	var jz_hash = _hash_coord(wx, wz, seed_val, 3 + t_idx * 4)
	var rot_hash = _hash_coord(wx, wz, seed_val, 4 + t_idx * 4)
	var scale_hash = _hash_coord(wx, wz, seed_val, 5 + t_idx * 4)

	var dx = (_hash_to_float(jx_hash) * 2.0 - 1.0) * cfg.jitter_spread
	var dz = (_hash_to_float(jz_hash) * 2.0 - 1.0) * cfg.jitter_spread
	var scale_factor = lerpf(cfg.min_scale, cfg.max_scale, _hash_to_float(scale_hash))
	var angle = _hash_to_float(rot_hash) * TAU if cfg.random_y_rotation else 0.0

	var origin = Vector3(float(lx) + 0.5 + dx, h, float(lz) + 0.5 + dz)
	var basis = Basis().rotated(Vector3.UP, angle).scaled(Vector3(scale_factor, scale_factor, scale_factor))
	return Transform3D(basis, origin)

static func _hash_coord(x: int, z: int, seed_val: int, salt: int = 0) -> int:
	var h: int = (seed_val ^ (x * 73856093) ^ (z * 19349663) ^ (salt * 83492791)) & 0x7FFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF
	return ((h ^ (h >> 16)) & 0x7FFFFFFF)

static func _hash_to_float(hash_val: int) -> float:
	return float(hash_val % 100000) / 100000.0
