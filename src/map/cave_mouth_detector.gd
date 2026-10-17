class_name CaveMouthDetector
extends RefCounted

## Pure analysis component responsible for discovering and classifying discrete surface cave mouths
## across the procedural continent.
##
## Classifies mouths into three distinct gameplay types:
## 1. DEAD_END: Shallow entrance bowl or alcove with no subterranean cave connection (Red font).
## 2. TUNNEL: Entrance funnel opening into an interconnected 3D worm tunnel network (Yellow font).
## 3. CHASM: Entrance funnel leading or descending directly into a deep underground chasm void (Green font).

const MapCoordinateConverterClass = preload("res://src/map/map_coordinate_converter.gd")
const CaveMouthDataClass = preload("res://src/map/cave_mouth_data.gd")

func detect_cave_mouths(
	generator: TerrainGenerator,
	bounds: WorldBounds,
	resolution: int = 512
) -> Array:
	var result: Array = []
	if generator == null or bounds == null or resolution <= 0:
		return result

	var cave_carver: CaveCarver = null
	if "cave_carver" in generator:
		cave_carver = generator.cave_carver

	if cave_carver == null or not cave_carver.config.enabled:
		return result

	var sea_level = 24
	if "config" in generator and generator.config != null and ("sea_level" in generator.config):
		sea_level = generator.config.sea_level

	var min_x = bounds.min_world_x
	var max_x = bounds.max_world_x
	var min_z = bounds.min_world_z
	var max_z = bounds.max_world_z

	var mouth_sampler = cave_carver.mouth_sampler
	var threshold = cave_carver.config.mouth_threshold

	# Sample step across world: fine enough to hit every mouth cluster, fast enough for <50ms execution
	var world_span_x = max_x - min_x
	var world_span_z = max_z - min_z
	var step = clampf(minf(world_span_x, world_span_z) / 320.0, 8.0, 24.0)

	var candidate_peaks: Array[Vector3] = [] # (wx, wz, raw_noise)
	var min_separation_dist = maxf(48.0, cave_carver.config.mouth_radius * 4.0)

	var wz = min_z + step * 0.5
	while wz < max_z:
		var wx = min_x + step * 0.5
		while wx < max_x:
			var raw_n = mouth_sampler.sample_raw_noise(wx, wz)
			if raw_n >= threshold:
				var col = bounds.world_to_column(Vector3(wx, 0.0, wz))
				var surface_h = float(generator.height_at(col, bounds))

				if mouth_sampler.is_dry_land(surface_h, sea_level):
					# Check 4-neighbor gradient to find local peak
					var is_local_max = true
					for off in [Vector2(-step, 0), Vector2(step, 0), Vector2(0, -step), Vector2(0, step)]:
						var neighbor_n = mouth_sampler.sample_raw_noise(wx + off.x, wz + off.y)
						if neighbor_n > raw_n:
							is_local_max = false
							break

					if is_local_max:
						# Refine peak to local continuous summit via 2-step gradient ascent
						var peak_x = wx
						var peak_z = wz
						var peak_val = raw_n
						for _iter in range(3):
							var d = 2.0
							var gx = (mouth_sampler.sample_raw_noise(peak_x + d, peak_z) - mouth_sampler.sample_raw_noise(peak_x - d, peak_z)) / (d * 2.0)
							var gz = (mouth_sampler.sample_raw_noise(peak_x, peak_z + d) - mouth_sampler.sample_raw_noise(peak_x, peak_z - d)) / (d * 2.0)
							var g_mag = sqrt(gx * gx + gz * gz)
							if g_mag < 0.0001:
								break
							var step_len = minf(g_mag * 1500.0, step * 0.5)
							var nx = peak_x + (gx / g_mag) * step_len
							var nz = peak_z + (gz / g_mag) * step_len
							var n_val = mouth_sampler.sample_raw_noise(nx, nz)
							if n_val > peak_val:
								peak_x = nx
								peak_z = nz
								peak_val = n_val
							else:
								break

						# Ensure not too close to an already discovered peak
						var is_duplicate = false
						for p in candidate_peaks:
							var dist = Vector2(peak_x - p.x, peak_z - p.y).length()
							if dist < min_separation_dist:
								is_duplicate = true
								break

						if not is_duplicate:
							candidate_peaks.append(Vector3(peak_x, peak_z, peak_val))

			wx += step
		wz += step

	# Classify each unique discovered cave mouth
	var map_rect = Rect2(0.0, 0.0, float(resolution), float(resolution))
	for p in candidate_peaks:
		var peak_wx = p.x
		var peak_wz = p.y
		var col = bounds.world_to_column(Vector3(peak_wx, 0.0, peak_wz))
		var surface_h = float(generator.height_at(col, bounds))

		var mouth_info = mouth_sampler.sample_mouth(peak_wx, peak_wz, surface_h, sea_level)
		if not mouth_info.is_mouth or mouth_info.carve_depth < 2.5:
			continue

		var mouth_type = classify_cave_mouth(peak_wx, peak_wz, surface_h, sea_level, cave_carver)
		var world_pos = Vector3(peak_wx, surface_h, peak_wz)
		var map_pixel = MapCoordinateConverterClass.world_to_map_pixel(world_pos, bounds, map_rect)

		var data = CaveMouthDataClass.new(
			world_pos,
			map_pixel,
			mouth_type,
			mouth_info.carve_depth,
			mouth_info.effective_radius,
			surface_h
		)
		result.append(data)

	return result

func classify_cave_mouth(
	wx: float,
	wz: float,
	surface_h: float,
	sea_level: int,
	cave_carver: CaveCarver
) -> int:
	## Classifies cave mouth into CHASM, TUNNEL, or DEAD_END.
	if cave_carver == null:
		return CaveMouthDataClass.Type.DEAD_END

	var mouth_info = cave_carver.mouth_sampler.sample_mouth(wx, wz, surface_h, sea_level)
	if not mouth_info.is_mouth:
		return CaveMouthDataClass.Type.DEAD_END

	var chasm_sampler = cave_carver.chasm_sampler
	var tunnel_sampler = cave_carver.tunnel_sampler
	var chasm_col = ChasmColumnResult.new()

	var r = mouth_info.effective_radius
	var sample_offsets: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(r * 0.5, 0.0),
		Vector2(-r * 0.5, 0.0),
		Vector2(0.0, r * 0.5),
		Vector2(0.0, -r * 0.5),
		Vector2(r * 0.4, r * 0.4),
		Vector2(-r * 0.4, r * 0.4),
		Vector2(r * 0.4, -r * 0.4),
		Vector2(-r * 0.4, -r * 0.4)
	]

	# -------------------------------------------------------------------------
	# 1. Check for connection to Underground Chasm (Highest Priority: Green)
	# -------------------------------------------------------------------------
	for off in sample_offsets:
		var sx = wx + off.x
		var sz = wz + off.y
		chasm_sampler.sample_column(sx, sz, chasm_col)

		if chasm_col.is_chasm and not chasm_col.is_pillar:
			return CaveMouthDataClass.Type.CHASM

	# -------------------------------------------------------------------------
	# 2. Check for connection to Interconnected 3D Worm Tunnels (Medium Priority: Yellow)
	# -------------------------------------------------------------------------
	for off in sample_offsets:
		var sx = wx + off.x
		var sz = wz + off.y

		for ty in range(int(surface_h), 2, -1):
			if tunnel_sampler.get_tunnel_carve(sx, float(ty), sz) > 0.05:
				return CaveMouthDataClass.Type.TUNNEL

	# -------------------------------------------------------------------------
	# 3. Neither chasm nor tunnel connects: Dead Cave (Red)
	# -------------------------------------------------------------------------
	return CaveMouthDataClass.Type.DEAD_END
