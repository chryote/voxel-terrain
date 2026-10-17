class_name ContinentMapProvider
extends RefCounted

## Manages asynchronous baking, caching, and delivery of continent map textures.
##
## Employs WorkerThreadPool to avoid blocking the main rendering frame.

signal map_baked(texture: ImageTexture)

const ContinentMapBakerClass = preload("res://src/map/continent_map_baker.gd")
const ContinentMapColorPaletteClass = preload("res://src/map/continent_map_color_palette.gd")
const CaveMouthDataClass = preload("res://src/map/cave_mouth_data.gd")

var _mutex: Mutex = Mutex.new()
var _baker: ContinentMapBakerClass = ContinentMapBakerClass.new()
var _palette: ContinentMapColorPaletteClass = ContinentMapColorPaletteClass.new()

var _cached_texture: ImageTexture = null
var _cached_image: Image = null
var _cached_cave_mouths: Array = []
var _is_baking: bool = false
var _task_id: int = -1

func is_ready() -> bool:
	_mutex.lock()
	var ready = (_cached_texture != null)
	_mutex.unlock()
	return ready

func is_baking() -> bool:
	_mutex.lock()
	var baking = _is_baking
	_mutex.unlock()
	return baking

func get_texture() -> ImageTexture:
	_mutex.lock()
	var tex = _cached_texture
	_mutex.unlock()
	return tex

func get_cave_mouths() -> Array:
	_mutex.lock()
	var mouths: Array = _cached_cave_mouths.duplicate()
	_mutex.unlock()
	return mouths

func bake_sync(
	generator: TerrainGenerator,
	bounds: WorldBounds,
	resolution: int = 512
) -> ImageTexture:
	var img = _baker.bake_map(generator, bounds, resolution, _palette)
	if img == null:
		return null

	var tex = ImageTexture.create_from_image(img)
	_mutex.lock()
	_cached_image = img
	_cached_texture = tex
	_cached_cave_mouths = _baker.last_baked_cave_mouths.duplicate()
	_is_baking = false
	_mutex.unlock()

	map_baked.emit(tex)
	return tex

func bake_async(
	generator: TerrainGenerator,
	bounds: WorldBounds,
	resolution: int = 512
) -> void:
	_mutex.lock()
	if _is_baking or _cached_texture != null:
		_mutex.unlock()
		return
	_is_baking = true
	_mutex.unlock()

	var payload = {
		"generator": generator,
		"bounds": bounds,
		"resolution": resolution,
		"palette": _palette
	}

	_task_id = WorkerThreadPool.add_task(_worker_task.bind(payload))

func _worker_task(payload: Dictionary) -> void:
	var img = _baker.bake_map(
		payload.generator,
		payload.bounds,
		payload.resolution,
		payload.palette
	)

	_mutex.lock()
	_cached_image = img
	_cached_cave_mouths = _baker.last_baked_cave_mouths.duplicate()
	_is_baking = false
	_mutex.unlock()

	# Defer texture creation on main thread because ImageTexture must be created on main thread in Godot
	Callable(self, "_on_baking_finished_on_main").call_deferred()

func _on_baking_finished_on_main() -> void:
	var task_to_reclaim = -1
	_mutex.lock()
	if _task_id != -1 and WorkerThreadPool.is_task_completed(_task_id):
		task_to_reclaim = _task_id
		_task_id = -1
	var img = _cached_image
	_mutex.unlock()

	if task_to_reclaim != -1:
		WorkerThreadPool.wait_for_task_completion(task_to_reclaim)

	if img != null:
		var tex = ImageTexture.create_from_image(img)
		_mutex.lock()
		_cached_texture = tex
		_mutex.unlock()
		map_baked.emit(tex)

func clear() -> void:
	var task_to_wait = -1
	_mutex.lock()
	task_to_wait = _task_id
	_task_id = -1
	_cached_texture = null
	_cached_image = null
	_cached_cave_mouths.clear()
	_is_baking = false
	_mutex.unlock()

	if task_to_wait != -1:
		WorkerThreadPool.wait_for_task_completion(task_to_wait)
