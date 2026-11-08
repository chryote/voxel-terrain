class_name AsciiAtlasGenerator
extends RefCounted

## Pure utility responsible for generating a multi-channel ASCII Glyph Map Atlas.
## R: Glyph Stroke Mask, G: Distance Bevel (Height), B: Cavity AO, A: Solid 1.0.
## Completely headless safe with zero OS window manager dependencies.

const RasterizerClass = preload("res://src/rendering/ascii_glyph_rasterizer.gd")

static func generate_atlas_image(cell_size: int = 16, cols: int = 16, rows: int = 16) -> Image:
	var width = cols * cell_size
	var height = rows * cell_size
	var img = Image.create(width, height, false, Image.FORMAT_RGBA8)

	for gy in range(rows):
		for gx in range(cols):
			var char_code = gx + gy * cols
			var mask_8x8 = RasterizerClass.rasterize_glyph_8x8(char_code)
			var start_x = gx * cell_size
			var start_y = gy * cell_size
			_process_cell_relief(img, start_x, start_y, cell_size, mask_8x8)

	return img

static func _process_cell_relief(img: Image, start_x: int, start_y: int, cell_size: int, mask: PackedByteArray) -> void:
	for ly in range(cell_size):
		for lx in range(cell_size):
			var is_stroke = _sample_mask_8x8(mask, lx, ly, cell_size)
			var r = 1.0 if is_stroke else 0.0
			var g = 1.0 if is_stroke else _compute_bevel_distance(mask, lx, ly, cell_size)
			var b = 1.0 if is_stroke else (0.35 + g * 0.45)
			img.set_pixel(start_x + lx, start_y + ly, Color(r, g, b, 1.0))

static func _sample_mask_8x8(mask: PackedByteArray, lx: int, ly: int, cell_size: int) -> bool:
	var mx = clampi((lx * 8) / cell_size, 0, 7)
	var my = clampi((ly * 8) / cell_size, 0, 7)
	return mask[mx + my * 8] == 1

static func _compute_bevel_distance(mask: PackedByteArray, lx: int, ly: int, cell_size: int) -> float:
	# Checks 1-pixel and 2-pixel Chebyshev neighborhood for distance field gradient
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if dx == 0 and dy == 0:
				continue
			var nx = lx + dx
			var ny = ly + dy
			if nx >= 0 and nx < cell_size and ny >= 0 and ny < cell_size:
				if _sample_mask_8x8(mask, nx, ny, cell_size):
					var dist = maxi(absi(dx), absi(dy))
					return 0.55 if dist == 1 else 0.25
	return 0.0

static func create_atlas_texture(cell_size: int = 16) -> ImageTexture:
	var img = generate_atlas_image(cell_size)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

static func save_atlas_to_file(path: String = "res://assets/textures/ascii_atlas.png", cell_size: int = 16) -> Error:
	var dir_path = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var img = generate_atlas_image(cell_size)
	return img.save_png(path)
