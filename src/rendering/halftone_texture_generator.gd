class_name HalftoneTextureGenerator
extends RefCounted

## Pure utility to generate seamless 2D halftone dot pattern textures.
## Safe to execute in headless test runners or editor environments.

static func generate_dot_pattern(size: int = 64, dot_radius_ratio: float = 0.35) -> Image:
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half = float(size) * 0.5
	var center1 = Vector2(half, half)
	var radius = half * dot_radius_ratio

	# We place dots at centers (0.5, 0.5) and at corners (0,0), (1,0), (0,1), (1,1)
	# with wrap-around to form a classic 45-degree rotated Ben-Day pattern.
	var centers = [
		Vector2(half, half),
		Vector2(0.0, 0.0),
		Vector2(float(size), 0.0),
		Vector2(0.0, float(size)),
		Vector2(float(size), float(size))
	]

	for y in range(size):
		for x in range(size):
			var pos = Vector2(float(x), float(y))
			var min_dist = 999999.0
			for c in centers:
				var d = pos.distance_to(c)
				if d < min_dist:
					min_dist = d
			
			# Antialiased dot edge with 1-pixel soft boundary
			var alpha: float
			if min_dist <= radius - 0.75:
				alpha = 1.0
			elif min_dist >= radius + 0.75:
				alpha = 0.0
			else:
				alpha = 1.0 - (min_dist - (radius - 0.75)) / 1.5

			# Store dot mask in RGB, white dot with black background or inverted for shadow mask
			var val = clampf(alpha, 0.0, 1.0)
			img.set_pixel(x, y, Color(val, val, val, 1.0))

	return img

static func save_pattern_to_file(path: String = "res://assets/textures/halftone_pattern.png", size: int = 64) -> Error:
	var dir_path = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var img = generate_dot_pattern(size)
	return img.save_png(path)
