class_name ChunkScheduler
extends RefCounted

## Thread-safe chunk generation and meshing scheduler using WorkerThreadPool.
## Manages task handles and ensures all WorkerThreadPool tasks are properly reclaimed.

var _mutex: Mutex = Mutex.new()
var _active_tasks: Dictionary = {}        # key -> task_id
var _tasks_to_reclaim: Array[int] = []    # list of all task_ids created
var _canceled_keys: Dictionary = {}       # key -> true
var _completed_results: Array[Dictionary] = []

func is_chunk_in_flight(coord: ChunkCoord) -> bool:
	_mutex.lock()
	var in_flight = _active_tasks.has(coord.to_key())
	_mutex.unlock()
	return in_flight

func schedule_chunk(
	coord: ChunkCoord,
	bounds: WorldBounds,
	generator: TerrainGenerator,
	mesher: Mesher,
	registry: MaterialRegistry
) -> void:
	var key = coord.to_key()
	_mutex.lock()
	if _active_tasks.has(key):
		_mutex.unlock()
		return
	_canceled_keys.erase(key)

	var payload = {
		"coord": coord,
		"bounds": bounds,
		"generator": generator,
		"mesher": mesher,
		"registry": registry
	}

	var task_id = WorkerThreadPool.add_task(_process_chunk_task.bind(payload))
	_active_tasks[key] = task_id
	_tasks_to_reclaim.append(task_id)
	_mutex.unlock()

func cancel_chunk(coord: ChunkCoord) -> void:
	var key = coord.to_key()
	_mutex.lock()
	if _active_tasks.has(key):
		_canceled_keys[key] = true
	_mutex.unlock()

func _process_chunk_task(payload: Dictionary) -> void:
	var coord: ChunkCoord = payload.coord
	var bounds: WorldBounds = payload.bounds
	var generator: TerrainGenerator = payload.generator
	var mesher: Mesher = payload.mesher
	var registry: MaterialRegistry = payload.registry

	var chunk_data = generator.generate(coord, bounds)
	var mesh_data = mesher.build_mesh(chunk_data, registry)

	var collision_baker = OffThreadCollisionBaker.new()
	var shapes = collision_baker.bake_shapes_for_bundle(mesh_data)
	if mesh_data is DualMeshBundle:
		mesh_data.surface_shape = shapes.surface_shape
		mesh_data.cave_shape = shapes.cave_shape

	var key = coord.to_key()
	_mutex.lock()
	if not _canceled_keys.has(key):
		_completed_results.append({
			"coord": coord,
			"data": chunk_data,
			"mesh_data": mesh_data,
			"surface_shape": shapes.surface_shape,
			"cave_shape": shapes.cave_shape
		})
	_active_tasks.erase(key)
	_canceled_keys.erase(key)
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
	_mutex.unlock()
