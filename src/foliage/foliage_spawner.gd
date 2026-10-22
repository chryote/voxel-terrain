class_name FoliageSpawner
extends RefCounted

## Procedural spawner that places instanced foliage across chunks based on
## surface height, slope angle, terrain material, biome density, and paint exclusions.

const FoliageRegistryClass = preload("res://src/foliage/foliage_registry.gd")
const FoliageChunkDataClass = preload("res://src/foliage/foliage_chunk_data.gd")
const BiomeDefClass = preload("res://src/biomes/biome_def.gd")
const TerrainPaintDataClass = preload("res://src/painting/terrain_paint_data.gd")

var registry: FoliageRegistry

func _init(p_registry: FoliageRegistry = null) -> void:
	registry = p_registry if p_registry != null else FoliageRegistryClass.create_default_registry()

## Generates FoliageChunkData for a chunk. Safe to run concurrently on WorkerThreadPool.
func generate_foliage_chunk(
	surface_data: SurfaceChunkData,
	coord: ChunkCoord,
	biome: BiomeDef = null,
	paint_data: TerrainPaintData = null,
	voxel_size: float = 1.0
) -> FoliageChunkData:
	var foliage_data = FoliageChunkDataClass.new()
	if surface_data == null or coord == null or registry == null:
		return foliage_data

	var density = biome.foliage_density if biome != null else 0.5
	if density <= 0.01:
		return foliage_data

	var chunk_size = surface_data.chunk_size
	# Deterministic PRNG seeded by chunk coordinates and prime hash
	var rng = RandomNumberGenerator.new()
	var chunk_seed = int((coord.x * 73856093) ^ (coord.z * 19349663) ^ 83492791)
	rng.seed = chunk_seed

	# Grid spacing scaled inversely with density (0.5 density -> ~3m spacing)
	var cell_size = clampf(lerpf(6.0, 1.5, density), 1.5, 6.0)
	var cells_axis = int(floor(float(chunk_size) / cell_size))

	for cz in range(cells_axis):
		for cx in range(cells_axis):
			# Skip based on density probability
			if rng.randf() > density:
				continue

			var local_x = (float(cx) + rng.randf_range(0.2, 0.8)) * cell_size
			var local_z = (float(cz) + rng.randf_range(0.2, 0.8)) * cell_size

			var col_x = clampi(int(floor(local_x)), 0, chunk_size - 1)
			var col_z = clampi(int(floor(local_z)), 0, chunk_size - 1)

			var h = float(surface_data.get_height(col_x, col_z))
			var mat = surface_data.get_top_material(col_x, col_z)

			# Check terrain painting exclusion (roads and stone suppress foliage)
			if paint_data != null:
				var path_weight = paint_data.get_weight(col_x, col_z, 0) # R channel = Dirt Path
				var rock_weight = paint_data.get_weight(col_x, col_z, 2) # B channel = Rock
				if (path_weight + rock_weight) > 0.35:
					continue

			# Calculate surface normal from neighbor columns
			var h_w = float(surface_data.get_height(col_x - 1, col_z))
			var h_e = float(surface_data.get_height(col_x + 1, col_z))
			var h_n = float(surface_data.get_height(col_x, col_z - 1))
			var h_s = float(surface_data.get_height(col_x, col_z + 1))
			var norm = Vector3(h_w - h_e, 2.0, h_n - h_s).normalized()
			var slope_deg = rad_to_deg(acos(clampf(norm.y, 0.0, 1.0)))

			# Select eligible foliage type
			var foliage_type = _select_foliage_type(mat, h, slope_deg, biome, rng)
			if foliage_type == null:
				continue

			# Construct transform
			var world_y = h * voxel_size
			var local_pos = Vector3(local_x * voxel_size, world_y, local_z * voxel_size)

			var scale_factor = rng.randf_range(foliage_type.scale_min, foliage_type.scale_max)
			var basis = Basis.from_scale(Vector3(scale_factor, scale_factor, scale_factor))

			if foliage_type.random_yaw:
				var yaw = rng.randf_range(0.0, TAU)
				basis = basis.rotated(Vector3.UP, yaw)

			var xform = Transform3D(basis, local_pos)
			foliage_data.add_instance(foliage_type.id, xform, foliage_type.tint_color)

	return foliage_data

func _select_foliage_type(
	mat: int,
	elevation: float,
	slope_deg: float,
	biome: BiomeDef,
	rng: RandomNumberGenerator
) -> FoliageDef:
	var candidates: Array[FoliageDef] = []
	for f in registry.foliage_items:
		if f != null and f.is_valid_surface(mat, elevation, slope_deg):
			candidates.append(f)

	if candidates.is_empty():
		return null
	var idx = rng.randi_range(0, candidates.size() - 1)
	return candidates[idx]
