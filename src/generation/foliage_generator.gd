class_name FoliageGenerator
extends RefCounted

## Pure procedural scatter generator for grass and non-collision foliage clutter.
## Deterministic, thread-safe, and runs off-thread without scene tree dependencies.

const FoliageChunkDataClass = preload("res://src/core/foliage_chunk_data.gd")
const FoliageConfigClass = preload("res://src/generation/foliage_generator_config.gd")

func generate(
	coord: ChunkCoord,
	data: RefCounted,
	config: Resource = null
) -> FoliageChunkData:
	var foliage_data = FoliageChunkDataClass.new()
	if data == null or coord == null:
		return foliage_data

	var surface_data: SurfaceChunkData = data as SurfaceChunkData
	var voxel_data = null
	if surface_data == null and ("surface_data" in data):
		surface_data = data.surface_data as SurfaceChunkData
		voxel_data = data

	if surface_data == null:
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
			if surface_data.is_mouth(lx, lz):
				continue
			if surface_data.get_top_material(lx, lz) != cfg.target_material_id:
				continue
			if voxel_data != null:
				var col_h = surface_data.get_height(lx, lz)
				if col_h <= 0 or voxel_data.get_voxel(lx, col_h - 1, lz) == 0:
					continue

			var wx = chunk_wx + lx
			var wz = chunk_wz + lz
			_scatter_voxel_foliage(lx, lz, wx, wz, surface_data, cfg, seed_val, foliage_data)
			if cfg.bushes_enabled:
				_scatter_voxel_bush(lx, lz, wx, wz, surface_data, cfg, seed_val, foliage_data)

	if cfg.enabled and (foliage_data.instance_count > 1 or foliage_data.bush_instance_count > 1):
		var shuffle_seed: int = seed_val ^ (coord.x * 73856093) ^ (coord.z * 19349663)
		foliage_data.shuffle_deterministically(shuffle_seed)

	return foliage_data

func _scatter_voxel_foliage(
	lx: int, lz: int, wx: int, wz: int,
	surface_data: SurfaceChunkData, cfg: FoliageGeneratorConfig, seed_val: int, out_data: FoliageChunkData
) -> void:
	if _hash_to_float(_hash_coord(wx, wz, seed_val, 0)) > cfg.density_probability:
		return
	var tuft_count = 1 + (_hash_coord(wx, wz, seed_val, 1) % maxi(1, cfg.max_tufts_per_voxel))
	var h = float(surface_data.get_height(lx, lz))
	for t_idx in range(tuft_count):
		var t = _build_transform(lx, lz, wx, wz, h, 2 + t_idx * 4, cfg.jitter_spread, cfg.min_scale, cfg.max_scale, cfg.random_y_rotation, seed_val)
		out_data.add_instance(t)

func _scatter_voxel_bush(
	lx: int, lz: int, wx: int, wz: int,
	surface_data: SurfaceChunkData, cfg: FoliageGeneratorConfig, seed_val: int, out_data: FoliageChunkData
) -> void:
	if _hash_to_float(_hash_coord(wx, wz, seed_val, 100)) > cfg.bush_density_probability:
		return
	var h = float(surface_data.get_height(lx, lz))
	var t = _build_transform(lx, lz, wx, wz, h, 101, cfg.bush_jitter_spread, cfg.bush_min_scale, cfg.bush_max_scale, cfg.random_y_rotation, seed_val)
	out_data.add_bush_instance(t)

func _build_transform(
	lx: int, lz: int, wx: int, wz: int, h: float,
	salt_base: int, jitter: float, min_s: float, max_s: float, rand_rot: bool, seed_val: int
) -> Transform3D:
	var dx = (_hash_to_float(_hash_coord(wx, wz, seed_val, salt_base + 0)) * 2.0 - 1.0) * jitter
	var dz = (_hash_to_float(_hash_coord(wx, wz, seed_val, salt_base + 1)) * 2.0 - 1.0) * jitter
	var angle = _hash_to_float(_hash_coord(wx, wz, seed_val, salt_base + 2)) * TAU if rand_rot else 0.0
	var scale_factor = lerpf(min_s, max_s, _hash_to_float(_hash_coord(wx, wz, seed_val, salt_base + 3)))
	var origin = Vector3(float(lx) + 0.5 + dx, h, float(lz) + 0.5 + dz)
	var basis = Basis().rotated(Vector3.UP, angle).scaled(Vector3(scale_factor, scale_factor, scale_factor))
	return Transform3D(basis, origin)

static func _hash_coord(x: int, z: int, seed_val: int, salt: int = 0) -> int:
	var h: int = (seed_val ^ (x * 73856093) ^ (z * 19349663) ^ (salt * 83492791)) & 0x7FFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF
	return ((h ^ (h >> 16)) & 0x7FFFFFFF)

static func _hash_to_float(hash_val: int) -> float:
	return float(hash_val % 100000) / 100000.0
