class_name ContinentMapBaker
extends ContinentMapBakerNative

## Pure component responsible for baking a complete topographic and material map
## of a procedural continent into an Image.
## Accelerated natively by ContinentMapBakerNative via godot-cpp GDExtension.
##
## Decoupled from scene nodes, UI, and rendering servers for thread-safety and testing.

const ContinentMapColorPaletteClass = preload("res://src/map/continent_map_color_palette.gd")
const CaveMouthDataClass = preload("res://src/map/cave_mouth_data.gd")
const CaveMouthDetectorClass = preload("res://src/map/cave_mouth_detector.gd")
const ChasmColumnResultClass = preload("res://src/generation/caves/chasm_column_result.gd")
const MIN_UNDERGROUND_ISLAND_PIXELS: int = 600 ## Reference threshold at 512x512 resolution below which isolated subterranean cavern pockets are culled to solid bedrock

enum MapLevel {
	SURFACE = 0,
	UNDERGROUND = 1
}

var detector: CaveMouthDetectorClass = CaveMouthDetectorClass.new()
var last_baked_cave_mouths: Array = []

func bake_map(
	generator: TerrainGenerator,
	bounds: WorldBounds,
	resolution: int = 512,
	palette: ContinentMapColorPaletteClass = null,
	level: int = MapLevel.SURFACE
) -> Image:
	if level == MapLevel.UNDERGROUND:
		return bake_underground_map(generator, bounds, resolution, palette)

	if bounds == null or generator == null or resolution <= 0:
		return null

	if palette == null:
		palette = ContinentMapColorPaletteClass.new()

	var img = bake_surface_map_native(generator, bounds, resolution, palette)

	# Cave Mouth Detection (shared cache)
	if last_baked_cave_mouths.is_empty():
		last_baked_cave_mouths = detector.detect_cave_mouths(generator, bounds, resolution)

	return img

func bake_underground_map(
	generator: TerrainGenerator,
	bounds: WorldBounds,
	resolution: int = 512,
	palette: ContinentMapColorPaletteClass = null,
	min_island_pixels: int = MIN_UNDERGROUND_ISLAND_PIXELS
) -> Image:
	if bounds == null or generator == null or resolution <= 0:
		return null

	if palette == null:
		palette = ContinentMapColorPaletteClass.new()

	var img = bake_underground_map_native(generator, bounds, resolution, palette, min_island_pixels)

	# Cave Mouth Detection (shared cache)
	if last_baked_cave_mouths.is_empty():
		last_baked_cave_mouths = detector.detect_cave_mouths(generator, bounds, resolution)

	return img

func _cull_small_underground_islands(
	p_flags: PackedByteArray,
	p_floor_heights: PackedInt32Array,
	p_resolution: int,
	p_min_island_pixels: int
) -> int:
	## High-performance BFS component culling: resets isolated subterranean pockets smaller
	## than p_min_island_pixels back to solid bedrock (zero-allocation flat integer queue).
	var total_pixels = p_resolution * p_resolution
	var visited = PackedByteArray()
	visited.resize(total_pixels)

	var queue = PackedInt32Array()
	queue.resize(total_pixels)

	var culled_pixels = 0

	for y in range(p_resolution):
		var row_offset = y * p_resolution
		for x in range(p_resolution):
			var start_idx = row_offset + x
			if p_flags[start_idx] != 0 and visited[start_idx] == 0:
				var head = 0
				var tail = 0
				queue[tail] = start_idx
				tail += 1
				visited[start_idx] = 1

				while head < tail:
					var curr_idx = queue[head]
					head += 1

					var cx = curr_idx % p_resolution
					var cy = curr_idx / p_resolution

					# 4-directional flood fill
					if cx > 0:
						var n_idx = curr_idx - 1
						if p_flags[n_idx] != 0 and visited[n_idx] == 0:
							visited[n_idx] = 1
							queue[tail] = n_idx
							tail += 1
					if cx < p_resolution - 1:
						var n_idx = curr_idx + 1
						if p_flags[n_idx] != 0 and visited[n_idx] == 0:
							visited[n_idx] = 1
							queue[tail] = n_idx
							tail += 1
					if cy > 0:
						var n_idx = curr_idx - p_resolution
						if p_flags[n_idx] != 0 and visited[n_idx] == 0:
							visited[n_idx] = 1
							queue[tail] = n_idx
							tail += 1
					if cy < p_resolution - 1:
						var n_idx = curr_idx + p_resolution
						if p_flags[n_idx] != 0 and visited[n_idx] == 0:
							visited[n_idx] = 1
							queue[tail] = n_idx
							tail += 1

				if tail < p_min_island_pixels:
					for i in range(tail):
						var c_idx = queue[i]
						p_flags[c_idx] = 0
						p_floor_heights[c_idx] = 0
					culled_pixels += tail

	return culled_pixels
