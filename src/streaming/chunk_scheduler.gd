class_name ChunkScheduler
extends RefCounted

## Thread-safe chunk generation and meshing scheduler using WorkerThreadPool.
## Supports two-phase streaming:
## - Phase A (Surface-First): Instantaneous ~22 ms surface generation and meshing
## - Phase B (Subterranean On-Demand): Deferred 3D cave carving and subterranean meshing
## Also maintains full backward compatibility for monolithic full generation tasks.

enum GenerationPhase {
	PHASE_FULL = 0,
	PHASE_SURFACE = 1,
	PHASE_SUBTERRANEAN = 2
}

var _mutex: Mutex = Mutex.new()
var _active_tasks: Dictionary = {}        # task_key -> task_id
var _tasks_to_reclaim: Array[int] = []    # list of all task_ids created
var _canceled_keys: Dictionary = {}       # task_key or chunk_key -> true
var _completed_results: Array[Dictionary] = []

const FoliageGeneratorClass = preload("res://src/generation/foliage_generator.gd")
var foliage_enabled: bool = true
var foliage_config: Resource = null
var _foliage_generator: FoliageGeneratorClass = FoliageGeneratorClass.new()

func _make_task_key(coord: ChunkCoord, phase: int) -> String:
	return "%d:%d" % [coord.to_key(), phase]

func is_chunk_in_flight(coord: ChunkCoord) -> bool:
	var base_key = str(coord.to_key())
	_mutex.lock()
	var in_flight = (
		_active_tasks.has(base_key) or
		_active_tasks.has(base_key + ":0") or
		_active_tasks.has(base_key + ":1") or
		_active_tasks.has(base_key + ":2")
	)
	_mutex.unlock()
	return in_flight

func is_phase_in_flight(coord: ChunkCoord, phase: int) -> bool:
	var task_key = _make_task_key(coord, phase)
	_mutex.lock()
	var in_flight = _active_tasks.has(task_key)
	_mutex.unlock()
	return in_flight

## Phase A: High-speed surface-only generation and meshing (~22 ms)
func schedule_surface_chunk(
	coord: ChunkCoord,
	bounds: WorldBounds,
	generator: TerrainGenerator,
	mesher: Mesher,
	registry: MaterialRegistry,
	high_priority: bool = false
) -> void:
	_schedule_task_internal(
		coord,
		GenerationPhase.PHASE_SURFACE,
		bounds,
		generator,
		mesher,
		registry,
		null,
		high_priority
	)

## Phase B: On-demand subterranean 3D cave carving and meshing
func schedule_subterranean_chunk(
	coord: ChunkCoord,
	bounds: WorldBounds,
	generator: TerrainGenerator,
	mesher: Mesher,
	registry: MaterialRegistry,
	cached_surface_data: SurfaceChunkData = null,
	high_priority: bool = false,
	bake_cave_collision: bool = true
) -> void:
	_schedule_task_internal(
		coord,
		GenerationPhase.PHASE_SUBTERRANEAN,
		bounds,
		generator,
		mesher,
		registry,
		cached_surface_data,
		high_priority,
		bake_cave_collision
	)

## Monolithic full generation (Phase A + Phase B combined)
func schedule_chunk(
	coord: ChunkCoord,
	bounds: WorldBounds,
	generator: TerrainGenerator,
	mesher: Mesher,
	registry: MaterialRegistry
) -> void:
	_schedule_task_internal(
		coord,
		GenerationPhase.PHASE_FULL,
		bounds,
		generator,
		mesher,
		registry,
		null,
		false,
		true
	)

func _schedule_task_internal(
	coord: ChunkCoord,
	phase: int,
	bounds: WorldBounds,
	generator: TerrainGenerator,
	mesher: Mesher,
	registry: MaterialRegistry,
	surface_data: SurfaceChunkData = null,
	high_priority: bool = false,
	bake_cave_collision: bool = true
) -> void:
	var task_key = _make_task_key(coord, phase)
	var base_key = str(coord.to_key())

	_mutex.lock()
	# Avoid duplicate in-flight task for this phase
	if _active_tasks.has(task_key) or _active_tasks.has(base_key):
		_mutex.unlock()
		return

	_canceled_keys.erase(task_key)
	_canceled_keys.erase(base_key)

	var payload = {
		"coord": coord,
		"phase": phase,
		"bounds": bounds,
		"generator": generator,
		"mesher": mesher,
		"registry": registry,
		"surface_data": surface_data,
		"bake_cave_collision": bake_cave_collision,
		"foliage_enabled": foliage_enabled,
		"foliage_config": foliage_config,
		"task_key": task_key,
		"base_key": base_key
	}

	var task_id = WorkerThreadPool.add_task(_process_chunk_task.bind(payload), high_priority)
	_active_tasks[task_key] = task_id
	_tasks_to_reclaim.append(task_id)
	_mutex.unlock()

func cancel_chunk(coord: ChunkCoord) -> void:
	var base_key = str(coord.to_key())
	_mutex.lock()
	_canceled_keys[base_key] = true
	_canceled_keys[base_key + ":0"] = true
	_canceled_keys[base_key + ":1"] = true
	_canceled_keys[base_key + ":2"] = true
	_mutex.unlock()

func _process_chunk_task(payload: Dictionary) -> void:
	var coord: ChunkCoord = payload.coord
	var phase: int = payload.phase
	var bounds: WorldBounds = payload.bounds
	var generator: TerrainGenerator = payload.generator
	var mesher: Mesher = payload.mesher
	var registry: MaterialRegistry = payload.registry
	var task_key: String = payload.task_key
	var base_key: String = payload.base_key
	var fol_enabled: bool = payload.get("foliage_enabled", true)
	var fol_config: Resource = payload.get("foliage_config", null)

	var chunk_data: RefCounted = null
	var mesh_data: MeshData = null
	var has_mouth: bool = false

	match phase:
		GenerationPhase.PHASE_SURFACE:
			if generator is LayeredTerrainGenerator:
				var s_gen: LayeredTerrainGenerator = generator
				var s_data = s_gen.generate_surface(coord, bounds)
				chunk_data = s_data
				has_mouth = s_data.has_cave_mouth
			else:
				chunk_data = generator.generate(coord, bounds)
				has_mouth = chunk_data.has_cave_mouth if ("has_cave_mouth" in chunk_data) else false

			mesh_data = mesher.build_mesh(chunk_data, registry)
			if fol_enabled and chunk_data is SurfaceChunkData:
				mesh_data.foliage_data = _foliage_generator.generate(coord, chunk_data, fol_config)

		GenerationPhase.PHASE_SUBTERRANEAN:
			var cached_surf: SurfaceChunkData = payload.get("surface_data", null)
			if generator is LayeredTerrainGenerator:
				var s_gen: LayeredTerrainGenerator = generator
				var v_data = s_gen.generate_subterranean(cached_surf, coord, bounds)
				chunk_data = v_data
				has_mouth = v_data.has_cave_mouth
			else:
				chunk_data = generator.generate(coord, bounds)
				has_mouth = chunk_data.has_cave_mouth if ("has_cave_mouth" in chunk_data) else false

			mesh_data = mesher.build_mesh(chunk_data, registry)
			if fol_enabled and chunk_data != null:
				mesh_data.foliage_data = _foliage_generator.generate(coord, chunk_data, fol_config)

		GenerationPhase.PHASE_FULL:
			chunk_data = generator.generate(coord, bounds)
			has_mouth = chunk_data.has_cave_mouth if ("has_cave_mouth" in chunk_data) else false
			mesh_data = mesher.build_mesh(chunk_data, registry)
			if fol_enabled and chunk_data != null:
				mesh_data.foliage_data = _foliage_generator.generate(coord, chunk_data, fol_config)

	# Off-thread collision baking (ConcavePolygonShape3D created on worker thread)
	var collision_baker = OffThreadCollisionBaker.new()
	var bake_cave = payload.get("bake_cave_collision", true)
	var shapes = collision_baker.bake_shapes_for_bundle(mesh_data, bake_cave)
	if mesh_data is DualMeshBundle:
		mesh_data.surface_shape = shapes.surface_shape
		mesh_data.cave_shape = shapes.cave_shape

	_mutex.lock()
	var is_canceled = _canceled_keys.has(task_key) or _canceled_keys.has(base_key)
	if not is_canceled:
		_completed_results.append({
			"phase": phase,
			"coord": coord,
			"data": chunk_data,
			"mesh_data": mesh_data,
			"surface_shape": shapes.surface_shape,
			"cave_shape": shapes.cave_shape,
			"has_cave_mouth": has_mouth
		})

	_active_tasks.erase(task_key)
	_active_tasks.erase(base_key)
	_canceled_keys.erase(task_key)
	_mutex.unlock()

func poll_completed(max_count: int = 4) -> Array[Dictionary]:
	reclaim_finished_tasks()
	var results: Array[Dictionary] = []
	_mutex.lock()
	var take = mini(max_count, _completed_results.size())
	for _i in range(take):
		results.append(_completed_results.pop_front())
	_mutex.unlock()
	return results

func reclaim_finished_tasks() -> void:
	_mutex.lock()
	var remaining: Array[int] = []
	for task_id in _tasks_to_reclaim:
		if WorkerThreadPool.is_task_completed(task_id):
			WorkerThreadPool.wait_for_task_completion(task_id)
		else:
			remaining.append(task_id)
	_tasks_to_reclaim = remaining
	_mutex.unlock()

func wait_all_tasks() -> void:
	var tasks_copy: Array[int] = []
	_mutex.lock()
	tasks_copy = _tasks_to_reclaim.duplicate()
	_tasks_to_reclaim.clear()
	_mutex.unlock()

	for task_id in tasks_copy:
		WorkerThreadPool.wait_for_task_completion(task_id)


func get_active_task_count() -> int:
	_mutex.lock()
	var count = _active_tasks.size()
	_mutex.unlock()
	return count

func get_pending_result_count() -> int:
	_mutex.lock()
	var count = _completed_results.size()
	_mutex.unlock()
	return count

func clear() -> void:
	wait_all_tasks()
	_mutex.lock()
	_canceled_keys.clear()
	_completed_results.clear()
	_active_tasks.clear()
	_mutex.unlock()
