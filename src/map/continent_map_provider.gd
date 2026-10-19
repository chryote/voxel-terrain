class_name ContinentMapProvider
extends RefCounted

## Manages asynchronous baking, caching, and delivery of continent map textures
## across multiple levels (Surface and Subterranean Battle Arena).
##
## Employs WorkerThreadPool to avoid blocking the main rendering frame.

enum MapLevel {
	SURFACE = 0,
	UNDERGROUND = 1
}

signal map_baked(texture: ImageTexture)
signal level_baked(level: int, texture: ImageTexture)

const ContinentMapBakerClass = preload("res://src/map/continent_map_baker.gd")
const ContinentMapColorPaletteClass = preload("res://src/map/continent_map_color_palette.gd")
const CaveMouthDataClass = preload("res://src/map/cave_mouth_data.gd")

var _mutex: Mutex = Mutex.new()
var _baker: ContinentMapBakerClass = ContinentMapBakerClass.new()
var _palette: ContinentMapColorPaletteClass = ContinentMapColorPaletteClass.new()

var _cached_textures: Dictionary = {}
var _cached_images: Dictionary = {}
var _cached_cave_mouths: Array = []
var _is_baking_levels: Dictionary = {}
var _task_ids: Dictionary = {}

func is_ready(level: int = MapLevel.SURFACE) -> bool:
	_mutex.lock()
	var ready = _cached_textures.has(level) and _cached_textures[level] != null
	_mutex.unlock()
	return ready

func is_baking(level: int = -1) -> bool:
	_mutex.lock()
	var baking = false
	if level == -1:
		for l in _is_baking_levels:
			if _is_baking_levels[l]:
				baking = true
				break
	else:
		baking = _is_baking_levels.get(level, false)
	_mutex.unlock()
	return baking

func get_texture(level: int = MapLevel.SURFACE) -> ImageTexture:
	_mutex.lock()
	var tex = _cached_textures.get(level, null) as ImageTexture
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
	resolution: int = 512,
	level: int = MapLevel.SURFACE
) -> ImageTexture:
	var img = _baker.bake_map(generator, bounds, resolution, _palette, level)
	if img == null:
		return null

	var tex = ImageTexture.create_from_image(img)
	_mutex.lock()
	_cached_images[level] = img
	_cached_textures[level] = tex
	_cached_cave_mouths = _baker.last_baked_cave_mouths.duplicate()
	_is_baking_levels[level] = false
	_mutex.unlock()

	level_baked.emit(level, tex)
	if level == MapLevel.SURFACE:
		map_baked.emit(tex)
	return tex

func bake_async(
	generator: TerrainGenerator,
	bounds: WorldBounds,
	resolution: int = 512,
	level: int = MapLevel.SURFACE
) -> void:
	_mutex.lock()
	if _is_baking_levels.get(level, false) or (_cached_textures.has(level) and _cached_textures[level] != null):
		_mutex.unlock()
		return
	_is_baking_levels[level] = true
	_mutex.unlock()

	var payload = {
		"generator": generator,
		"bounds": bounds,
		"resolution": resolution,
		"palette": _palette,
		"level": level
	}

	var tid = WorkerThreadPool.add_task(_worker_task.bind(payload))
	_mutex.lock()
	_task_ids[level] = tid
	_mutex.unlock()

func bake_all_async(
	generator: TerrainGenerator,
	bounds: WorldBounds,
	resolution: int = 512
) -> void:
	bake_async(generator, bounds, resolution, MapLevel.SURFACE)
	bake_async(generator, bounds, resolution, MapLevel.UNDERGROUND)

func _worker_task(payload: Dictionary) -> void:
	var level: int = payload.get("level", MapLevel.SURFACE)
	var img = _baker.bake_map(
		payload.generator,
		payload.bounds,
		payload.resolution,
		payload.palette,
		level
	)

	_mutex.lock()
	_cached_images[level] = img
	_cached_cave_mouths = _baker.last_baked_cave_mouths.duplicate()
	_is_baking_levels[level] = false
	_mutex.unlock()

	# Defer texture creation on main thread because ImageTexture must be created on main thread in Godot
	Callable(self, "_on_baking_finished_on_main").bind(level).call_deferred()

func _on_baking_finished_on_main(level: int) -> void:
	var task_to_reclaim = -1
	_mutex.lock()
	if _task_ids.has(level) and WorkerThreadPool.is_task_completed(_task_ids[level]):
		task_to_reclaim = _task_ids[level]
		_task_ids.erase(level)
	var img = _cached_images.get(level, null)
	_mutex.unlock()

	if task_to_reclaim != -1:
		WorkerThreadPool.wait_for_task_completion(task_to_reclaim)

	if img != null:
		var tex = ImageTexture.create_from_image(img)
		_mutex.lock()
		_cached_textures[level] = tex
		_mutex.unlock()
		level_baked.emit(level, tex)
		if level == MapLevel.SURFACE:
			map_baked.emit(tex)

func clear() -> void:
	var tasks_to_wait: Array[int] = []
	_mutex.lock()
	for l in _task_ids:
		tasks_to_wait.append(_task_ids[l])
	_task_ids.clear()
	_cached_textures.clear()
	_cached_images.clear()
	_cached_cave_mouths.clear()
	_is_baking_levels.clear()
	_mutex.unlock()

	for tid in tasks_to_wait:
		if tid != -1:
			WorkerThreadPool.wait_for_task_completion(tid)

