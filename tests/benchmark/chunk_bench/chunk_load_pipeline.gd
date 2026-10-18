class_name ChunkLoadPipeline
extends RefCounted

## Pure execution service running the real chunk loading pipeline stages
## (Generation -> Meshing -> Collision Baking) with high-resolution microsecond timing.
## Releases large voxel arrays and mesh geometry immediately to guarantee O(1) memory footprint.

const ChunkLoadSampleClass = preload("res://tests/benchmark/chunk_bench/chunk_load_sample.gd")

## Warms up all generator, mesher, noise, and collision pipelines prior to measurement.
func warmup(
	bounds: WorldBounds,
	gen: LayeredTerrainGenerator,
	mesher: Mesher,
	reg: MaterialRegistry,
	baker: OffThreadCollisionBaker
) -> void:
	var dummy_coord = ChunkCoord.new(0, 0)
	var s_data = gen.generate_surface(dummy_coord, bounds)
	var s_mesh = mesher.build_mesh(s_data, reg)
	var _s_shapes = baker.bake_shapes_for_bundle(s_mesh, false)

	var sub_data = gen.generate_subterranean(s_data, dummy_coord, bounds)
	var a_mesh = mesher.build_mesh(sub_data, reg)
	var _a_shapes = baker.bake_shapes_for_bundle(a_mesh, true)

## Executes the 3-stage loading sequence for a surface terrain chunk.
func load_surface_chunk(
	coord: ChunkCoord,
	bounds: WorldBounds,
	gen: LayeredTerrainGenerator,
	mesher: Mesher,
	reg: MaterialRegistry,
	baker: OffThreadCollisionBaker
) -> RefCounted:
	# Stage 1: Surface generation
	var t0 = Time.get_ticks_usec()
	var s_data = gen.generate_surface(coord, bounds)
	var gen_ms = (Time.get_ticks_usec() - t0) / 1000.0

	# Stage 2: Surface shell meshing
	t0 = Time.get_ticks_usec()
	var mesh_data = mesher.build_mesh(s_data, reg)
	var mesh_ms = (Time.get_ticks_usec() - t0) / 1000.0

	# Stage 3: Surface trimesh collision baking
	t0 = Time.get_ticks_usec()
	var _shapes = baker.bake_shapes_for_bundle(mesh_data, false)
	var bake_ms = (Time.get_ticks_usec() - t0) / 1000.0

	var v_count = mesh_data.get_vertex_count() if mesh_data != null else 0
	var tri_count = mesh_data.get_triangle_count() if mesh_data != null else 0

	return ChunkLoadSampleClass.new(
		coord,
		gen_ms,
		mesh_ms,
		bake_ms,
		v_count,
		tri_count,
		0,
		0,
		false,
		false
	)

## Executes the 3-stage loading sequence for an underground arena chunk.
func load_arena_chunk(
	coord: ChunkCoord,
	bounds: WorldBounds,
	gen: LayeredTerrainGenerator,
	mesher: Mesher,
	reg: MaterialRegistry,
	baker: OffThreadCollisionBaker
) -> RefCounted:
	# Stage 1: Full subterranean cave & arena generation
	var t0 = Time.get_ticks_usec()
	var s_data = gen.generate_surface(coord, bounds)
	var sub_data = gen.generate_subterranean(s_data, coord, bounds)
	var gen_ms = (Time.get_ticks_usec() - t0) / 1000.0

	# Stage 2: Dual subterranean shell meshing (surface + floor + ceiling + water + curtain walls)
	t0 = Time.get_ticks_usec()
	var mesh_data = mesher.build_mesh(sub_data, reg)
	var mesh_ms = (Time.get_ticks_usec() - t0) / 1000.0

	# Stage 3: Dual concave trimesh collision baking (surface + subterranean cave shape)
	t0 = Time.get_ticks_usec()
	var _shapes = baker.bake_shapes_for_bundle(mesh_data, true)
	var bake_ms = (Time.get_ticks_usec() - t0) / 1000.0

	var v_count = 0
	var tri_count = 0
	var cave_verts = 0
	var cave_tris = 0
	var is_dual = false

	if mesh_data is DualMeshBundle:
		is_dual = true
		v_count = mesh_data.get_total_vertex_count()
		tri_count = mesh_data.get_total_triangle_count()
		cave_verts = mesh_data.cave_mesh_data.get_vertex_count() if mesh_data.cave_mesh_data != null else 0
		cave_tris = mesh_data.get_cave_triangle_count()
	elif mesh_data != null:
		v_count = mesh_data.get_vertex_count()
		tri_count = mesh_data.get_triangle_count()

	return ChunkLoadSampleClass.new(
		coord,
		gen_ms,
		mesh_ms,
		bake_ms,
		v_count,
		tri_count,
		cave_verts,
		cave_tris,
		true,
		is_dual
	)
