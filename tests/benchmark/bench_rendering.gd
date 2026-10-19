class_name BenchRendering
extends "res://tests/framework/benchmark_case.gd"

## Performance benchmark monitoring Draw Calls (RenderingServer) and Main Thread Process Timings.
## Tracks baseline draw calls, primitive count, and scene complexity for surface and underground environments.

const RenderPerformanceSampleClass = preload("res://tests/benchmark/render_bench/render_performance_sample.gd")
const RenderBenchmarkStatsClass = preload("res://tests/benchmark/render_bench/render_benchmark_stats.gd")

func bench_render_surface_scene_complexity() -> void:
	var world_config = WorldConfig.new()
	world_config.world_seed = 1337
	world_config.view_distance_chunks = 4

	var world = VoxelWorld.new()
	world.world_config = world_config
	world.spawn_on_underground_arena = false

	var tree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		tree.root.add_child(world)
	if not world.is_node_ready():
		world._ready()

	# Pre-load initial chunks around spawn
	var spawn_pos = world.get_spawn_point()
	world._update_streaming(true)
	if world.scheduler != null:
		world.scheduler.poll_completed(world_config.max_mesh_applies_per_frame * 4)
	world._process_completed_chunks()

	var loaded_chunks = world.get_loaded_chunk_count()
	var visible_surface_meshes = 0
	var visible_water_meshes = 0
	var total_mesh_instances = 0

	for key in world._loaded_chunks.keys():
		var node = world._loaded_chunks[key]
		if node is ChunkNode:
			total_mesh_instances += 1
			if node.mesh_instance != null and node.mesh_instance.mesh != null and node.mesh_instance.visible:
				visible_surface_meshes += 1
			if node.water_instance != null and node.water_instance.mesh != null and node.water_instance.visible:
				visible_water_meshes += 1

	var dc = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	if dc <= 0:
		dc = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

	var prims = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	if prims <= 0:
		prims = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))

	var proc_ms = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0

	# Record metrics into BenchmarkCase results dictionary
	_results["surface_visible_draw_surfaces"] = {
		"name": "surface_visible_draw_surfaces",
		"avg_ms": float(visible_surface_meshes + visible_water_meshes),
		"median_ms": float(visible_surface_meshes),
		"p95_ms": float(visible_surface_meshes + visible_water_meshes),
		"min_ms": float(visible_surface_meshes),
		"max_ms": float(visible_surface_meshes + visible_water_meshes),
		"iterations": 1,
		"loaded_chunks": loaded_chunks,
		"visible_surface_meshes": visible_surface_meshes,
		"visible_water_meshes": visible_water_meshes,
		"hardware_draw_calls": dc,
		"hardware_primitives": prims,
		"process_time_ms": proc_ms
	}

	world.queue_free()

func bench_render_arena_scene_complexity() -> void:
	var world_config = WorldConfig.new()
	world_config.world_seed = 1337
	world_config.view_distance_chunks = 4

	var world = VoxelWorld.new()
	world.world_config = world_config
	world.spawn_on_underground_arena = true

	var tree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		tree.root.add_child(world)
	if not world.is_node_ready():
		world._ready()

	# Pre-load initial chunks around spawn
	var spawn_pos = world.get_spawn_point()
	world._update_streaming(true)
	if world.scheduler != null:
		world.scheduler.poll_completed(world_config.max_mesh_applies_per_frame * 4)
	world._process_completed_chunks()

	var loaded_chunks = world.get_loaded_chunk_count()
	var visible_cave_meshes = 0
	var visible_cave_water = 0
	var total_mesh_instances = 0

	for key in world._loaded_chunks.keys():
		var node = world._loaded_chunks[key]
		if node is ChunkNode:
			total_mesh_instances += 1
			if node.cave_mesh_instance != null and node.cave_mesh_instance.mesh != null and node.cave_mesh_instance.visible:
				visible_cave_meshes += 1
			if node.cave_water_instance != null and node.cave_water_instance.mesh != null and node.cave_water_instance.visible:
				visible_cave_water += 1

	var dc = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	if dc <= 0:
		dc = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

	var prims = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	if prims <= 0:
		prims = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))

	var proc_ms = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0

	_results["arena_visible_draw_surfaces"] = {
		"name": "arena_visible_draw_surfaces",
		"avg_ms": float(visible_cave_meshes + visible_cave_water),
		"median_ms": float(visible_cave_meshes),
		"p95_ms": float(visible_cave_meshes + visible_cave_water),
		"min_ms": float(visible_cave_meshes),
		"max_ms": float(visible_cave_meshes + visible_cave_water),
		"iterations": 1,
		"loaded_chunks": loaded_chunks,
		"visible_cave_meshes": visible_cave_meshes,
		"visible_cave_water": visible_cave_water,
		"hardware_draw_calls": dc,
		"hardware_primitives": prims,
		"process_time_ms": proc_ms
	}

	world.queue_free()
