class_name CaveMouthLimiter
extends RefCounted

## Pure algorithmic component responsible for filtering, prioritizing, and limiting
## procedural cave mouth generation across the continent by type (CHASM, TUNNEL, DEAD_END).
##
## Adheres to Sustainable Game Development and Single Responsibility Principle:
## - Decoupled from rendering and scene trees.
## - Fully deterministic across platforms and worker threads.
## - Prioritizes the deepest, most prominent natural entrance funnels.

const CaveMouthDataClass = preload("res://src/map/cave_mouth_data.gd")

func limit_mouths(
	candidates: Array,
	config: CaveGeneratorConfig = null
) -> Array:
	## Limits an array of CaveMouthData candidates based on the given CaveGeneratorConfig.
	## If config is null, applies default limits (max 1 chasm, max 2 tunnel, max 3 dead end).
	if config == null:
		return limit_mouths_by_counts(candidates, 1, 2, 3)

	if "limit_cave_mouths" in config and not config.limit_cave_mouths:
		return candidates.duplicate()

	var max_chasm: int = config.max_chasm_mouths if "max_chasm_mouths" in config else 1
	var max_tunnel: int = config.max_tunnel_mouths if "max_tunnel_mouths" in config else 2
	var max_dead_end: int = config.max_dead_end_mouths if "max_dead_end_mouths" in config else 3

	return limit_mouths_by_counts(candidates, max_chasm, max_tunnel, max_dead_end)

func limit_mouths_by_counts(
	candidates: Array,
	max_chasm: int,
	max_tunnel: int,
	max_dead_end: int
) -> Array:
	## Enforces explicit per-type count limits on an array of CaveMouthData objects.
	## If a limit is negative (< 0), that category is considered unlimited.
	## If a limit is 0, that category is completely excluded.
	var chasms: Array = []
	var tunnels: Array = []
	var dead_ends: Array = []

	for item in candidates:
		if item == null:
			continue
		match item.type:
			CaveMouthDataClass.Type.CHASM:
				chasms.append(item)
			CaveMouthDataClass.Type.TUNNEL:
				tunnels.append(item)
			CaveMouthDataClass.Type.DEAD_END:
				dead_ends.append(item)

	# Sort each category by prominence (depth, radius, deterministic position)
	_sort_by_prominence(chasms)
	_sort_by_prominence(tunnels)
	_sort_by_prominence(dead_ends)

	var selected: Array = []

	_append_limited(selected, chasms, max_chasm)
	_append_limited(selected, tunnels, max_tunnel)
	_append_limited(selected, dead_ends, max_dead_end)

	# Stable sort by world position (X ascending, then Z ascending) for consistent downstream iteration
	selected.sort_custom(func(a, b):
		if not is_equal_approx(a.world_pos.x, b.world_pos.x):
			return a.world_pos.x < b.world_pos.x
		return a.world_pos.z < b.world_pos.z
	)

	return selected

func _sort_by_prominence(mouths: Array) -> void:
	## Deterministically sorts cave mouths by prominence:
	## 1. Deepest carve depth descending.
	## 2. Largest effective radius descending.
	## 3. World position X ascending, then Z ascending as deterministic tie-breaker.
	mouths.sort_custom(func(a, b):
		if not is_equal_approx(a.depth, b.depth):
			return a.depth > b.depth
		if not is_equal_approx(a.radius, b.radius):
			return a.radius > b.radius
		if not is_equal_approx(a.world_pos.x, b.world_pos.x):
			return a.world_pos.x < b.world_pos.x
		return a.world_pos.z < b.world_pos.z
	)

func _append_limited(target: Array, source: Array, max_count: int) -> void:
	if max_count < 0:
		target.append_array(source)
		return
	var count = mini(max_count, source.size())
	for i in range(count):
		target.append(source[i])

func count_by_type(mouths: Array) -> Dictionary:
	## Aggregates mouth counts per Type enum for fast verification and diagnostics.
	var counts = {
		CaveMouthDataClass.Type.DEAD_END: 0,
		CaveMouthDataClass.Type.TUNNEL: 0,
		CaveMouthDataClass.Type.CHASM: 0
	}
	for m in mouths:
		if m != null and m.type in counts:
			counts[m.type] += 1
	return counts

func find_nearest_mouth(wx: float, wz: float, mouths: Array, radius_margin: float = 0.0) -> RefCounted:
	## Returns the matching CaveMouthData if (wx, wz) is within (mouth.radius + radius_margin)
	## of any mouth in the list. Returns null otherwise.
	var best_m = null
	var best_dist_sq = INF
	for m in mouths:
		if m == null:
			continue
		var dx = wx - m.world_pos.x
		var dz = wz - m.world_pos.z
		var dist_sq = dx * dx + dz * dz
		var max_r = m.radius + radius_margin
		if dist_sq <= (max_r * max_r) and dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_m = m
	return best_m

func can_box_intersect_mouths(
	min_x: float,
	min_z: float,
	max_x: float,
	max_z: float,
	mouths: Array,
	margin: float = 0.0
) -> bool:
	## O(N) fast 2D circle-AABB intersection test. Used for chunk and coarse-cell culling.
	for m in mouths:
		if m == null:
			continue
		var cx = clampf(m.world_pos.x, min_x, max_x)
		var cz = clampf(m.world_pos.z, min_z, max_z)
		var dx = m.world_pos.x - cx
		var dz = m.world_pos.z - cz
		var eff_r = m.radius + margin
		if (dx * dx + dz * dz) <= (eff_r * eff_r):
			return true
	return false
