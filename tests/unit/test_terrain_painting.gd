class_name TestTerrainPainting
extends "res://tests/framework/test_case.gd"

## Unit tests verifying terrain painting data, splatmap operations,
## brush application with hardness/falloff, multi-chunk dispatching, and painter undo/redo.

const TerrainPaintDataClass = preload("res://src/painting/terrain_paint_data.gd")
const TerrainPaintLayerClass = preload("res://src/painting/terrain_paint_layer.gd")
const PaintStrokeClass = preload("res://src/painting/paint_stroke.gd")
const ChunkPaintManagerClass = preload("res://src/painting/chunk_paint_manager.gd")
const TerrainPainterClass = preload("res://src/painting/terrain_painter.gd")

func test_paint_layers_initialization() -> void:
	var layers = TerrainPaintLayerClass.create_default_layers()
	assert_eq(layers.size(), 4, "Must provide 4 default RGBA paint layers")

	assert_eq(layers[0].layer_id, TerrainPaintLayerClass.CHANNEL_R)
	assert_eq(layers[0].name, "Dirt Path")
	assert_true(layers[0].foliage_suppression, "Paths must suppress foliage")

	assert_eq(layers[1].layer_id, TerrainPaintLayerClass.CHANNEL_G)
	assert_eq(layers[1].name, "Sand")

func test_paint_stroke_serialization() -> void:
	var stroke = PaintStrokeClass.new(
		Vector3(10.0, 5.0, -20.0),
		4.5,
		0.8,
		0.6,
		TerrainPaintLayerClass.CHANNEL_R,
		PaintStrokeClass.Mode.PAINT,
		MaterialDef.ID_DIRT
	)

	var dict = stroke.to_dict()
	assert_almost_eq(dict["x"], 10.0, 0.001)
	assert_almost_eq(dict["radius"], 4.5, 0.001)
	assert_almost_eq(dict["strength"], 0.8, 0.001)

	var restored = PaintStrokeClass.from_dict(dict)
	assert_almost_eq(restored.world_position.x, 10.0, 0.001)
	assert_almost_eq(restored.radius, 4.5, 0.001)
	assert_eq(restored.channel, TerrainPaintLayerClass.CHANNEL_R)

func test_paint_data_get_set_and_brush() -> void:
	var data = TerrainPaintDataClass.new(16)
	assert_eq(data.resolution, 16)
	assert_true(data.is_empty(), "Freshly initialized data must be empty")

	# Set individual pixel weight
	data.set_weight(5, 5, TerrainPaintLayerClass.CHANNEL_R, 0.75)
	assert_almost_eq(data.get_weight(5, 5, TerrainPaintLayerClass.CHANNEL_R), 0.75, 0.01)
	assert_false(data.is_empty(), "Data with painted pixels must not be empty")

	# Brush application with hardness 1.0 (sharp)
	data.clear()
	assert_true(data.is_empty())
	var modified = data.apply_brush(8.0, 8.0, 3.0, 1.0, 1.0, TerrainPaintLayerClass.CHANNEL_R, PaintStrokeClass.Mode.PAINT)
	assert_true(modified, "apply_brush should report modification")

	# Center must be at full strength
	assert_almost_eq(data.get_weight(8, 8, TerrainPaintLayerClass.CHANNEL_R), 1.0, 0.01)
	# Point just inside radius must be painted
	assert_almost_eq(data.get_weight(9, 8, TerrainPaintLayerClass.CHANNEL_R), 1.0, 0.01)
	# Point well outside radius must be 0
	assert_almost_eq(data.get_weight(0, 0, TerrainPaintLayerClass.CHANNEL_R), 0.0, 0.01)

func test_paint_data_image_and_texture_generation() -> void:
	var data = TerrainPaintDataClass.new(16)
	data.set_weights_at(2, 2, Color(1.0, 0.5, 0.25, 0.0))

	var img = data.create_image()
	assert_not_null(img, "Image must be generated")
	assert_eq(img.get_width(), 16)
	assert_eq(img.get_height(), 16)
	assert_eq(img.get_format(), Image.FORMAT_RGBA8)

	var pixel = img.get_pixel(2, 2)
	assert_almost_eq(pixel.r, 1.0, 0.02)
	assert_almost_eq(pixel.g, 0.5, 0.02)

	var tex = data.get_or_create_texture()
	assert_not_null(tex, "ImageTexture must be generated")
	assert_true(tex is ImageTexture)

func test_chunk_paint_manager_cross_chunk_brush() -> void:
	var mgr = ChunkPaintManagerClass.new(32, 1.0, 32)

	# Paint directly on chunk boundary (x = 32.0, z = 16.0) with radius 5.0
	# Should intersect chunk (0, 0) and chunk (1, 0)
	var affected = mgr.paint_world(
		Vector3(32.0, 0.0, 16.0),
		5.0,
		0.8,
		0.5,
		TerrainPaintLayerClass.CHANNEL_R,
		PaintStrokeClass.Mode.PAINT
	)

	assert_true(affected.size() > 1, "Brush overlapping chunk border must affect multiple chunks")
	var has_c0 = false
	var has_c1 = false
	for c in affected:
		if c.x == 0 and c.z == 0:
			has_c0 = true
		if c.x == 1 and c.z == 0:
			has_c1 = true
	assert_true(has_c0, "Chunk (0, 0) must be affected")
	assert_true(has_c1, "Chunk (1, 0) must be affected")

func test_chunk_paint_manager_discrete_material_painting() -> void:
	var mgr = ChunkPaintManagerClass.new(16, 1.0, 16)
	var s_data = SurfaceChunkData.new(16, 3)
	s_data.fill(30, MaterialDef.ID_GRASS, MaterialDef.ID_DIRT)

	var coord = ChunkCoord.new(0, 0)
	var modified = mgr.paint_discrete_material(s_data, coord, Vector3(8.0, 30.0, 8.0), 3.0, MaterialDef.ID_GRAVEL)
	assert_true(modified, "paint_discrete_material must modify surface data")

	# Center column must now be gravel
	assert_eq(s_data.get_top_material(8, 8), MaterialDef.ID_GRAVEL)
	# Far column remains grass
	assert_eq(s_data.get_top_material(0, 0), MaterialDef.ID_GRASS)

func test_terrain_painter_undo_redo() -> void:
	var mgr = ChunkPaintManagerClass.new(16, 1.0, 16)
	var painter = TerrainPainterClass.new(mgr)
	painter.set_brush(4.0, 1.0, 1.0, TerrainPaintLayerClass.CHANNEL_R)

	assert_false(painter.can_undo(), "Cannot undo initially")
	assert_false(painter.can_redo(), "Cannot redo initially")

	# Perform a stroke
	var coord = ChunkCoord.new(0, 0)
	painter.begin_stroke(Vector3(8.0, 0.0, 8.0))
	painter.end_stroke()

	var data = mgr.get_paint_data(coord)
	assert_not_null(data)
	assert_almost_eq(data.get_weight(8, 8, TerrainPaintLayerClass.CHANNEL_R), 1.0, 0.05)
	assert_true(painter.can_undo(), "Should be able to undo after stroke")

	# Undo
	var undo_success = painter.undo()
	assert_true(undo_success, "Undo should succeed")
	var undone_data = mgr.get_or_create_paint_data(coord)
	assert_almost_eq(undone_data.get_weight(8, 8, TerrainPaintLayerClass.CHANNEL_R), 0.0, 0.05)
	assert_true(painter.can_redo(), "Should be able to redo after undo")

	# Redo
	var redo_success = painter.redo()
	assert_true(redo_success, "Redo should succeed")
	var redone_data = mgr.get_paint_data(coord)
	assert_almost_eq(redone_data.get_weight(8, 8, TerrainPaintLayerClass.CHANNEL_R), 1.0, 0.05)
