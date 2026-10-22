class_name TerrainPaintData
extends RefCounted

## Stores 4-channel (RGBA) splatmap weights for a terrain chunk at a fixed resolution.
## Directly converts to Godot Image / ImageTexture for GPU shader sampling.

const PaintStrokeClass = preload("res://src/painting/paint_stroke.gd")

var resolution: int = 32
var weights: PackedByteArray
var _is_dirty: bool = false
var _cached_texture: ImageTexture = null

func _init(p_resolution: int = 32) -> void:
	resolution = maxi(4, p_resolution)
	var byte_count = resolution * resolution * 4
	weights = PackedByteArray()
	weights.resize(byte_count)
	weights.fill(0)
	_is_dirty = false

func _pixel_index(x: int, z: int) -> int:
	return (x + z * resolution) * 4

func is_in_bounds(x: int, z: int) -> bool:
	return x >= 0 and x < resolution and z >= 0 and z < resolution

func get_weight(x: int, z: int, channel: int) -> float:
	if not is_in_bounds(x, z) or channel < 0 or channel > 3:
		return 0.0
	var idx = _pixel_index(x, z) + channel
	return float(weights[idx]) / 255.0

func set_weight(x: int, z: int, channel: int, weight: float) -> void:
	if not is_in_bounds(x, z) or channel < 0 or channel > 3:
		return
	var idx = _pixel_index(x, z) + channel
	var byte_val = clampi(int(round(clampf(weight, 0.0, 1.0) * 255.0)), 0, 255)
	if weights[idx] != byte_val:
		weights[idx] = byte_val
		_is_dirty = true

func get_weights_at(x: int, z: int) -> Color:
	if not is_in_bounds(x, z):
		return Color(0, 0, 0, 0)
	var idx = _pixel_index(x, z)
	return Color(
		float(weights[idx]) / 255.0,
		float(weights[idx + 1]) / 255.0,
		float(weights[idx + 2]) / 255.0,
		float(weights[idx + 3]) / 255.0
	)

func set_weights_at(x: int, z: int, color: Color) -> void:
	if not is_in_bounds(x, z):
		return
	var idx = _pixel_index(x, z)
	weights[idx] = clampi(int(round(clampf(color.r, 0.0, 1.0) * 255.0)), 0, 255)
	weights[idx + 1] = clampi(int(round(clampf(color.g, 0.0, 1.0) * 255.0)), 0, 255)
	weights[idx + 2] = clampi(int(round(clampf(color.b, 0.0, 1.0) * 255.0)), 0, 255)
	weights[idx + 3] = clampi(int(round(clampf(color.a, 0.0, 1.0) * 255.0)), 0, 255)
	_is_dirty = true

## Applies a continuous brush stroke onto the chunk splatmap
func apply_brush(
	local_x: float,
	local_z: float,
	radius: float,
	hardness: float,
	strength: float,
	channel: int,
	mode: int = 0 # PaintStroke.Mode.PAINT
) -> bool:
	if radius <= 0.0 or channel < 0 or channel > 3:
		return false

	var min_x = clampi(int(floor(local_x - radius)), 0, resolution - 1)
	var max_x = clampi(int(ceil(local_x + radius)), 0, resolution - 1)
	var min_z = clampi(int(floor(local_z - radius)), 0, resolution - 1)
	var max_z = clampi(int(ceil(local_z + radius)), 0, resolution - 1)

	var radius_sq = radius * radius
	var clamped_hardness = clampf(hardness, 0.0, 1.0)
	var modified = false

	for pz in range(min_z, max_z + 1):
		var dz = float(pz) - local_z
		var dz_sq = dz * dz
		for px in range(min_x, max_x + 1):
			var dx = float(px) - local_x
			var dist_sq = dx * dx + dz_sq
			if dist_sq > radius_sq:
				continue

			var dist = sqrt(dist_sq)
			var norm_dist = dist / radius
			var falloff: float
			if clamped_hardness >= 0.99:
				falloff = 1.0
			else:
				# Smooth cubic Hermite falloff based on hardness
				var edge0 = clamped_hardness
				var edge1 = 1.0
				var x_val = clampf((norm_dist - edge0) / (edge1 - edge0), 0.0, 1.0)
				falloff = 1.0 - (x_val * x_val * (3.0 - 2.0 * x_val))

			var cur_weight = get_weight(px, pz, channel)
			var new_weight = cur_weight

			match mode:
				0: # PAINT
					new_weight = clampf(cur_weight + falloff * strength, 0.0, 1.0)
				1: # ERASE
					new_weight = clampf(cur_weight - falloff * strength, 0.0, 1.0)
				2: # SMOOTH
					var avg = _sample_neighborhood_average(px, pz, channel)
					new_weight = lerpf(cur_weight, avg, falloff * strength)
				3: # REPLACE
					new_weight = lerpf(cur_weight, strength, falloff)

			if not is_equal_approx(cur_weight, new_weight):
				set_weight(px, pz, channel, new_weight)
				modified = true

	return modified

func _sample_neighborhood_average(x: int, z: int, channel: int) -> float:
	var total = 0.0
	var count = 0
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var nx = x + dx
			var nz = z + dz
			if is_in_bounds(nx, nz):
				total += get_weight(nx, nz, channel)
				count += 1
	return total / float(maxi(1, count))

func is_empty() -> bool:
	for b in weights:
		if b != 0:
			return false
	return true

func clear() -> void:
	weights.fill(0)
	_is_dirty = true

func create_image() -> Image:
	return Image.create_from_data(resolution, resolution, false, Image.FORMAT_RGBA8, weights)

func get_or_create_texture() -> ImageTexture:
	var img = create_image()
	if _cached_texture == null:
		_cached_texture = ImageTexture.create_from_image(img)
	elif _is_dirty:
		_cached_texture.update(img)
	_is_dirty = false
	return _cached_texture

func to_dict() -> Dictionary:
	return {
		"resolution": resolution,
		"weights": weights
	}

func from_dict(d: Dictionary) -> void:
	resolution = d.get("resolution", 32)
	weights = d.get("weights", PackedByteArray())
	var expected_size = resolution * resolution * 4
	if weights.size() != expected_size:
		weights.resize(expected_size)
		weights.fill(0)
	_is_dirty = true
