class_name TestContinentMap
extends "res://tests/framework/test_case.gd"

## Unit test suite for the continent map subsystem:
## Palette, Coordinate Converter, Baker, Provider, and UI interaction.

const ContinentMapColorPaletteClass = preload("res://src/map/continent_map_color_palette.gd")
const MapCoordinateConverterClass = preload("res://src/map/map_coordinate_converter.gd")
const ContinentMapBakerClass = preload("res://src/map/continent_map_baker.gd")
const ContinentMapProviderClass = preload("res://src/map/continent_map_provider.gd")
const ContinentMapUIClass = preload("res://src/map/continent_map_ui.gd")

func test_palette_colors_and_hillshading() -> void:
	var palette = ContinentMapColorPaletteClass.new()

	# Verify valid colors
	var deep_water = palette.get_water_color(0, 24)
	var shallow_water = palette.get_water_color(23, 24)
	var lake_water = palette.get_water_color(50, 24)
	assert_true(deep_water.a == 1.0, "Deep water color must be opaque")
	assert_true(shallow_water.a == 1.0, "Shallow water color must be opaque")
	assert_true(lake_water.a == 1.0, "Lake water color must be opaque")

	# Material classification
	var beach = palette.get_land_color(25, 0.1, 24, 24, 2, 125, 90, false)
	assert_eq(beach, palette.color_beach_sand, "Near sea level land must be classified as beach sand")

	var snow = palette.get_land_color(130, 0.1, 24, 24, 2, 125, 90, false)
	assert_eq(snow, palette.color_alpine_snow, "High altitude land must be classified as alpine snow")

	var cliff = palette.get_land_color(40, 0.85, 24, 24, 2, 125, 90, false)
	assert_eq(cliff, palette.color_mountain_stone, "Steep slopes must be classified as stone")

	# Hillshading directional test
	# A slope rising towards +X and +Z has normal pointing NW (-X, -Z), directly facing NW light
	var sunlit_shade = palette.compute_hillshade(1.0, 1.0)
	var shadowed_shade = palette.compute_hillshade(-1.0, -1.0)
	assert_true(sunlit_shade > shadowed_shade, "Sunlit slope must have higher shade value than shadowed slope (sunlit: %.2f, shadow: %.2f)" % [sunlit_shade, shadowed_shade])

	# Relief elevation boost
	var low_relief = palette.apply_relief(Color(0.5, 0.5, 0.5), 1.0, 25, 24)
	var high_relief = palette.apply_relief(Color(0.5, 0.5, 0.5), 1.0, 120, 24)
	assert_true(high_relief.r > low_relief.r, "High altitude relief must feature subtle hypsometric tinting")

func test_coordinate_converter() -> void:
	var bounds = WorldBounds.new(Vector2i(256, 256), 32, 1.0)
	# min_world = -4096.0, max_world = 4096.0

	# Corner queries
	var uv_min = MapCoordinateConverterClass.world_to_normalized(Vector3(bounds.min_world_x, 0.0, bounds.min_world_z), bounds)
	assert_eq(uv_min, Vector2(0.0, 0.0), "Min world coordinate must map to UV (0, 0)")

	var uv_max = MapCoordinateConverterClass.world_to_normalized(Vector3(bounds.max_world_x, 0.0, bounds.max_world_z), bounds)
	assert_eq(uv_max, Vector2(1.0, 1.0), "Max world coordinate must map to UV (1, 1)")

	var uv_center = MapCoordinateConverterClass.world_to_normalized(Vector3(0.0, 0.0, 0.0), bounds)
	assert_true(absf(uv_center.x - 0.5) < 0.001 and absf(uv_center.y - 0.5) < 0.001, "Origin (0, 0) must map to UV center (0.5, 0.5)")

	# Roundtrip test
	var original_pos = Vector3(1234.0, 0.0, -567.0)
	var uv = MapCoordinateConverterClass.world_to_normalized(original_pos, bounds)
	var recovered_pos = MapCoordinateConverterClass.normalized_to_world(uv, bounds)
	assert_true(absf(recovered_pos.x - original_pos.x) < 0.01, "Roundtrip X conversion must be exact")
	assert_true(absf(recovered_pos.z - original_pos.z) < 0.01, "Roundtrip Z conversion must be exact")

	# Screen pixel projection
	var map_rect = Rect2(100.0, 50.0, 500.0, 500.0)
	var screen_pixel = MapCoordinateConverterClass.world_to_map_pixel(Vector3(0.0, 0.0, 0.0), bounds, map_rect)
	assert_eq(screen_pixel, Vector2(350.0, 300.0), "Map center must project to screen rect center (350, 300)")

	# Bounds checking
	assert_true(MapCoordinateConverterClass.is_within_bounds(Vector3(0.0, 0.0, 0.0), bounds))
	assert_false(MapCoordinateConverterClass.is_within_bounds(Vector3(5000.0, 0.0, 0.0), bounds))

func test_continent_map_baker_generation_and_determinism() -> void:
	var bounds = WorldBounds.new(Vector2i(32, 32), 32, 1.0)
	var config = ContinentGeneratorConfig.new()
	var gen1 = ContinentGenerator.new(1337, config)
	var gen2 = ContinentGenerator.new(1337, config)

	var baker = ContinentMapBakerClass.new()
	var res = 64
	var img1 = baker.bake_map(gen1, bounds, res)
	var img2 = baker.bake_map(gen2, bounds, res)

	assert_not_null(img1, "Baker must produce non-null Image")
	assert_eq(img1.get_width(), res, "Image width must match requested resolution")
	assert_eq(img1.get_height(), res, "Image height must match requested resolution")
	assert_eq(img1.get_format(), Image.FORMAT_RGBA8, "Image format must be RGBA8")

	# Bit-for-bit determinism test
	assert_eq(img1.get_data(), img2.get_data(), "Identical seeds must bake identical continent map images")

	# Verify non-trivial colors
	var found_water = false
	var found_land = false
	for y in range(res):
		for x in range(res):
			var c = img1.get_pixel(x, y)
			assert_true(c.a == 1.0, "All map pixels must be opaque")
			if c.b > c.r and c.b > c.g:
				found_water = true
			if c.g > c.b or c.r > c.b:
				found_land = true

	assert_true(found_water, "Map must feature water bodies")
	assert_true(found_land, "Map must feature terrestrial topography")

func test_continent_map_provider_sync_and_caching() -> void:
	var bounds = WorldBounds.new(Vector2i(32, 32), 32, 1.0)
	var config = ContinentGeneratorConfig.new()
	var gen = ContinentGenerator.new(4242, config)

	var provider = ContinentMapProviderClass.new()
	assert_false(provider.is_ready(), "Provider must initially not be ready")
	assert_null(provider.get_texture(), "Provider must initially return null texture")

	var tex = provider.bake_sync(gen, bounds, 32)
	assert_not_null(tex, "bake_sync must return valid ImageTexture")
	assert_true(provider.is_ready(), "Provider must be ready after bake_sync")
	assert_eq(provider.get_texture(), tex, "get_texture must return cached ImageTexture")

	provider.clear()
	assert_false(provider.is_ready(), "Provider must not be ready after clear")

func test_continent_map_ui_modal_state() -> void:
	var ui = ContinentMapUIClass.new()
	assert_false(ui.is_map_open(), "Map UI must initially be closed")
	assert_false(ui.visible, "Map UI must initially be invisible")

	ui.open_map()
	assert_true(ui.is_map_open(), "Map UI must be open after open_map()")
	assert_true(ui.visible, "Map UI must be visible after open_map()")

	ui.close_map()
	assert_false(ui.is_map_open(), "Map UI must be closed after close_map()")
	assert_false(ui.visible, "Map UI must be hidden after close_map()")

	ui.toggle_map()
	assert_true(ui.is_map_open(), "Map UI must toggle open")
	ui.toggle_map()
	assert_false(ui.is_map_open(), "Map UI must toggle closed")
	ui.queue_free()

func test_map_pan_zoom_controller() -> void:
	var MapPanZoomClass = preload("res://src/map/map_pan_zoom_controller.gd")
	var pz = MapPanZoomClass.new(Vector2(512, 512), 1.0, 8.0)

	assert_eq(pz.zoom, 1.0, "Initial zoom must be 1.0")
	assert_eq(pz.pan_offset, Vector2.ZERO, "Initial pan offset must be ZERO")

	# Zoom at center (256, 256) to 2.0x
	pz.zoom_at(Vector2(256, 256), 2.0)
	assert_eq(pz.zoom, 2.0, "Zoom must scale to 2.0")
	assert_eq(pz.pan_offset, Vector2(-256, -256), "Center zoom must center map offset at (-256, -256)")

	# Verify point under cursor is preserved
	var pt_center = pz.screen_to_map(Vector2(256, 256))
	assert_true(absf(pt_center.x - 256.0) < 0.01 and absf(pt_center.y - 256.0) < 0.01,
		"Center screen position must correspond to center map coordinate")

	# Test dragging
	pz.start_drag(Vector2(100, 100))
	pz.drag_to(Vector2(150, 120))
	assert_eq(pz.pan_offset, Vector2(-206, -236), "Drag delta must translate pan offset")
	pz.end_drag()

	# Test boundary clamping at 2.0x zoom:
	# Allowed range is [512 * (1 - 2), 0] = [-512, 0]
	pz.start_drag(Vector2(0, 0))
	pz.drag_to(Vector2(2000, 2000))
	assert_eq(pz.pan_offset, Vector2(0.0, 0.0), "Pan must clamp to maximum 0.0 at upper/left boundary")

	pz.drag_to(Vector2(-2000, -2000))
	assert_eq(pz.pan_offset, Vector2(-512.0, -512.0), "Pan must clamp to minimum -512.0 at lower/right boundary")
	pz.end_drag()

	# Test zoom at specific cursor position (e.g. 100, 150)
	var cursor = Vector2(100.0, 150.0)
	var map_coord_before = pz.screen_to_map(cursor)
	pz.zoom_at(cursor, 1.5)
	var map_coord_after = pz.screen_to_map(cursor)
	assert_true(absf(map_coord_before.x - map_coord_after.x) < 0.01 and absf(map_coord_before.y - map_coord_after.y) < 0.01,
		"Point under cursor must remain invariant before and after zoom")

	# Test reset
	pz.reset()
	assert_eq(pz.zoom, 1.0, "Reset must restore zoom to 1.0")
	assert_eq(pz.pan_offset, Vector2.ZERO, "Reset must restore pan offset to ZERO")

func test_continent_map_ui_pan_and_zoom_integration() -> void:
	var ui = ContinentMapUIClass.new()
	assert_not_null(ui.pan_zoom, "ContinentMapUI must have pan_zoom controller")
	assert_eq(ui.pan_zoom.zoom, 1.0, "Default zoom must be 1.0")

	ui.open_map()

	# Simulate zoom in at cursor (128, 128)
	var mb_wheel = InputEventMouseButton.new()
	mb_wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	mb_wheel.pressed = true
	mb_wheel.position = Vector2(128, 128)
	ui._on_map_gui_input(mb_wheel)

	assert_true(ui.pan_zoom.zoom > 1.0, "Wheel up must increase zoom")
	var zoomed_level = ui.pan_zoom.zoom

	# Simulate drag
	var mb_down = InputEventMouseButton.new()
	mb_down.button_index = MOUSE_BUTTON_LEFT
	mb_down.pressed = true
	mb_down.position = Vector2(200, 200)
	ui._on_map_gui_input(mb_down)
	assert_true(ui.pan_zoom.is_dragging, "Left click must start dragging")

	var mm = InputEventMouseMotion.new()
	mm.position = Vector2(180, 190)
	ui._on_map_gui_input(mm)

	var mb_up = InputEventMouseButton.new()
	mb_up.button_index = MOUSE_BUTTON_LEFT
	mb_up.pressed = false
	mb_up.position = Vector2(180, 190)
	ui._on_map_gui_input(mb_up)
	assert_false(ui.pan_zoom.is_dragging, "Release must stop dragging")

	# Simulate reset key 'R'
	var key_r = InputEventKey.new()
	key_r.keycode = KEY_R
	key_r.pressed = true
	ui._unhandled_input(key_r)
	assert_eq(ui.pan_zoom.zoom, 1.0, "Key R must reset zoom back to 1.0")
	assert_eq(ui.pan_zoom.pan_offset, Vector2.ZERO, "Key R must reset offset back to ZERO")

	ui.close_map()
	ui.queue_free()

func test_player_marker_overlay() -> void:
	var PlayerMarkerOverlayClass = preload("res://src/map/player_marker_overlay.gd")
	var overlay = PlayerMarkerOverlayClass.new()
	assert_not_null(overlay, "PlayerMarkerOverlay must instantiate")
	assert_eq(overlay.map_size, Vector2(512, 512), "Default map_size must be 512x512")

	var bounds = WorldBounds.new(Vector2i(64, 64), 32, 1.0)
	overlay.update_player_state(Vector3(0.0, 50.0, 0.0), PI * 0.25, bounds)
	assert_eq(overlay.player_world_pos, Vector3(0.0, 50.0, 0.0))
	assert_eq(overlay.player_yaw, PI * 0.25)
	assert_eq(overlay.bounds, bounds)

	# Transform update
	overlay.update_transform(Vector2(-100.0, 50.0), 2.0, Vector2(512, 512))
	assert_eq(overlay.pan_offset, Vector2(-100.0, 50.0))
	assert_eq(overlay.zoom, 2.0)
	assert_eq(overlay.map_size, Vector2(512, 512))

	# UI integration test
	var ui = ContinentMapUIClass.new()
	ui._build_ui()
	assert_not_null(ui._player_marker, "ContinentMapUI must instantiate _player_marker")
	assert_eq(ui._player_marker.map_size, Vector2(512, 512), "_player_marker must have 512x512 map_size")
	assert_eq(ui._player_marker.z_index, 5, "_player_marker must have elevated z_index")
	ui.queue_free()
	overlay.queue_free()

func test_underground_arena_palette_and_relief() -> void:
	var palette = ContinentMapColorPaletteClass.new()

	var arena_floor = palette.get_underground_color(true, false, false, false, false, false, 6)
	var arena_ledge = palette.get_underground_color(true, true, false, false, false, false, 8)
	var basalt = palette.get_underground_color(true, true, false, false, true, false, 8)
	var pillar = palette.get_underground_color(false, false, true, true, false, false, 10)
	var water = palette.get_underground_color(false, false, true, false, false, true, 4)
	var chasm = palette.get_underground_color(false, false, true, false, false, false, 6)
	var bedrock = palette.get_underground_color(false, false, false, false, false, false, 0)

	assert_eq(arena_floor, palette.color_arena_floor, "Arena core floor must match arena color token")
	assert_eq(arena_ledge, palette.color_arena_ledge, "Arena ledge must match ledge color token")
	assert_eq(basalt, palette.color_basalt_column, "Basalt column must match basalt color token")
	assert_eq(pillar, palette.color_pillar, "Support pillar must match pillar color token")
	assert_eq(water, palette.color_subterranean_water, "Subterranean water must match water color token")
	assert_eq(chasm, palette.color_chasm_floor, "Chasm floor must match chasm color token")
	assert_eq(bedrock, palette.color_underground_rock, "Solid bedrock must match underground rock color token")

	assert_true(arena_floor.a == 1.0 and bedrock.a == 1.0, "Subterranean colors must be opaque")

	# Relief test on floor elevation
	var low_relief = palette.apply_underground_relief(Color(0.4, 0.4, 0.4), 1.0, 4, true)
	var high_relief = palette.apply_underground_relief(Color(0.4, 0.4, 0.4), 1.0, 24, true)
	assert_true(high_relief.r > low_relief.r, "Elevated arena floor must feature hypsometric relief boost")

func test_continent_map_baker_underground_generation_and_determinism() -> void:
	var bounds = WorldBounds.new(Vector2i(32, 32), 32, 1.0)
	var config = ContinentGeneratorConfig.new()
	var gen1 = ContinentGenerator.new(4242, config)
	var gen2 = ContinentGenerator.new(4242, config)

	var baker = ContinentMapBakerClass.new()
	var res = 64
	var img1 = baker.bake_underground_map(gen1, bounds, res)
	var img2 = baker.bake_underground_map(gen2, bounds, res)

	assert_not_null(img1, "Underground baker must produce non-null Image")
	assert_eq(img1.get_width(), res, "Image width must match requested resolution")
	assert_eq(img1.get_height(), res, "Image height must match requested resolution")
	assert_eq(img1.get_format(), Image.FORMAT_RGBA8, "Image format must be RGBA8")

	# Bit-for-bit determinism test
	assert_eq(img1.get_data(), img2.get_data(), "Identical seeds must bake identical underground map images")

	# Verify non-trivial subterranean features
	var found_bedrock = false
	var palette = ContinentMapColorPaletteClass.new()
	for y in range(res):
		for x in range(res):
			var c = img1.get_pixel(x, y)
			assert_true(c.a == 1.0, "All map pixels must be opaque")
			if c == palette.color_underground_rock:
				found_bedrock = true

	assert_true(found_bedrock, "Underground map must feature encasing bedrock")

func test_continent_map_provider_multi_level_sync_and_caching() -> void:
	var bounds = WorldBounds.new(Vector2i(32, 32), 32, 1.0)
	var config = ContinentGeneratorConfig.new()
	var gen = ContinentGenerator.new(5555, config)

	var provider = ContinentMapProviderClass.new()
	assert_false(provider.is_ready(ContinentMapProviderClass.MapLevel.SURFACE), "Surface must initially not be ready")
	assert_false(provider.is_ready(ContinentMapProviderClass.MapLevel.UNDERGROUND), "Underground must initially not be ready")

	# Bake surface
	var surf_tex = provider.bake_sync(gen, bounds, 32, ContinentMapProviderClass.MapLevel.SURFACE)
	assert_not_null(surf_tex, "Surface bake_sync must return valid ImageTexture")
	assert_true(provider.is_ready(ContinentMapProviderClass.MapLevel.SURFACE), "Surface must be ready")
	assert_false(provider.is_ready(ContinentMapProviderClass.MapLevel.UNDERGROUND), "Underground must still not be ready")
	assert_eq(provider.get_texture(ContinentMapProviderClass.MapLevel.SURFACE), surf_tex)

	# Bake underground
	var under_tex = provider.bake_sync(gen, bounds, 32, ContinentMapProviderClass.MapLevel.UNDERGROUND)
	assert_not_null(under_tex, "Underground bake_sync must return valid ImageTexture")
	assert_true(provider.is_ready(ContinentMapProviderClass.MapLevel.UNDERGROUND), "Underground must be ready")
	assert_eq(provider.get_texture(ContinentMapProviderClass.MapLevel.UNDERGROUND), under_tex)

	# Textures should be distinct
	assert_ne(surf_tex, under_tex, "Surface and underground textures must be distinct instances")

	provider.clear()
	assert_false(provider.is_ready(ContinentMapProviderClass.MapLevel.SURFACE))
	assert_false(provider.is_ready(ContinentMapProviderClass.MapLevel.UNDERGROUND))

func test_continent_map_ui_level_switching() -> void:
	var ui = ContinentMapUIClass.new()
	ui._build_ui()

	assert_eq(ui.current_level, ContinentMapUIClass.MapLevel.SURFACE, "Default map level must be SURFACE")
	assert_true(ui._title_label.text.contains("SURFACE"), "Header title must state SURFACE")

	# Switch to Underground
	ui.switch_level(ContinentMapUIClass.MapLevel.UNDERGROUND)
	assert_eq(ui.current_level, ContinentMapUIClass.MapLevel.UNDERGROUND, "Level must switch to UNDERGROUND")
	assert_true(ui._title_label.text.contains("UNDERGROUND ARENA"), "Header title must state UNDERGROUND ARENA")

	# Switch back to Surface
	ui.switch_level(ContinentMapUIClass.MapLevel.SURFACE)
	assert_eq(ui.current_level, ContinentMapUIClass.MapLevel.SURFACE, "Level must switch back to SURFACE")

	# Key shortcuts simulation
	var key2 = InputEventKey.new()
	key2.keycode = KEY_2
	key2.pressed = true
	ui.open_map()
	ui._unhandled_input(key2)
	assert_eq(ui.current_level, ContinentMapUIClass.MapLevel.UNDERGROUND, "KEY_2 must switch to UNDERGROUND")

	var key1 = InputEventKey.new()
	key1.keycode = KEY_1
	key1.pressed = true
	ui._unhandled_input(key1)
	assert_eq(ui.current_level, ContinentMapUIClass.MapLevel.SURFACE, "KEY_1 must switch to SURFACE")

	var key_tab = InputEventKey.new()
	key_tab.keycode = KEY_TAB
	key_tab.pressed = true
	ui._unhandled_input(key_tab)
	assert_eq(ui.current_level, ContinentMapUIClass.MapLevel.UNDERGROUND, "KEY_TAB must toggle to UNDERGROUND")
	ui._unhandled_input(key_tab)
	assert_eq(ui.current_level, ContinentMapUIClass.MapLevel.SURFACE, "KEY_TAB must toggle back to SURFACE")

	ui.close_map()
	ui.queue_free()

func test_continent_map_ui_right_click_context_menu_and_teleport() -> void:
	var ui = ContinentMapUIClass.new()
	ui._build_ui()
	ui.open_map()

	assert_not_null(ui._context_menu, "Context menu node must exist")
	assert_false(ui._is_context_menu_open(), "Context menu must initially be closed")

	# Simulate right-click at screen coordinate (200, 200)
	var rb_down = InputEventMouseButton.new()
	rb_down.button_index = MOUSE_BUTTON_RIGHT
	rb_down.pressed = true
	rb_down.position = Vector2(200, 200)
	ui._on_map_gui_input(rb_down)

	var rb_up = InputEventMouseButton.new()
	rb_up.button_index = MOUSE_BUTTON_RIGHT
	rb_up.pressed = false
	rb_up.position = Vector2(200, 200)
	ui._on_map_gui_input(rb_up)

	assert_true(ui._is_context_menu_open(), "Context menu must open upon right click on map")
	assert_true(ui._context_menu.visible, "Context menu must be visible")
	assert_true(ui._context_target_label.text.contains("Target:"), "Context menu must display target coordinates")

	# Test closing context menu via ESC
	var esc = InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	ui._unhandled_input(esc)
	assert_false(ui._is_context_menu_open(), "ESC must close context menu first without closing map")
	assert_true(ui.is_map_open(), "Map must remain open when dismissing context menu")

	# Re-open context menu and test teleportation
	ui.open_context_menu_at(Vector2(256, 256))
	assert_true(ui._is_context_menu_open(), "Context menu must re-open")

	# Track teleport signal
	var teleport_tracker = [false, Vector3.ZERO]
	ui.teleport_requested.connect(func(pos, lvl):
		teleport_tracker[0] = true
		teleport_tracker[1] = pos
	)

	# Simulate clicking teleport button
	ui._on_context_teleport_pressed()

	assert_true(teleport_tracker[0], "Teleport requested signal must be emitted")
	assert_false(ui._is_context_menu_open(), "Context menu must be closed after teleport")
	assert_false(ui.is_map_open(), "Map must close after teleporting player")

	ui.queue_free()

func test_continent_map_underground_small_island_culling() -> void:
	## Validates that Pass 1.5 in ContinentMapBaker culls isolated subterranean pockets
	## smaller than min_island_pixels back to solid bedrock.
	var bounds = WorldBounds.new(Vector2i(32, 32), 32, 1.0)
	var config = ContinentGeneratorConfig.new()
	var gen = ContinentGenerator.new(1337, config)
	var palette = ContinentMapColorPaletteClass.new()
	var baker = ContinentMapBakerClass.new()

	var res = 128
	# 1. Bake with culling disabled (min_island_pixels = 0)
	var img_uncull = baker.bake_underground_map(gen, bounds, res, palette, 0)
	assert_not_null(img_uncull, "Unculled image must be valid")

	# 2. Bake with culling enabled (min_island_pixels = 25)
	var img_culled = baker.bake_underground_map(gen, bounds, res, palette, 25)
	assert_not_null(img_culled, "Culled image must be valid")

	# Count bedrock pixels in both
	var bedrock_uncull = 0
	var bedrock_culled = 0
	for y in range(res):
		for x in range(res):
			if img_uncull.get_pixel(x, y) == palette.color_underground_rock:
				bedrock_uncull += 1
			if img_culled.get_pixel(x, y) == palette.color_underground_rock:
				bedrock_culled += 1

	# Culled image must have more bedrock because small islands were converted to bedrock
	assert_true(bedrock_culled >= bedrock_uncull, "Culled underground map must have equal or more bedrock (%d >= %d)" % [bedrock_culled, bedrock_uncull])

	# Test direct helper method _cull_small_underground_islands
	var dummy_flags = PackedByteArray([4, 0, 0, 0, 4, 0, 0, 0, 0]) # two disconnected 1-pixel islands at (0,0) and (1,1)
	var dummy_heights = PackedInt32Array([10, 0, 0, 0, 10, 0, 0, 0, 0])
	var culled_count = baker._cull_small_underground_islands(dummy_flags, dummy_heights, 3, 3)
	assert_eq(culled_count, 2, "Must cull both 1-pixel islands since both components (< 3) are smaller than threshold")
	assert_eq(dummy_flags[0], 0, "Culled pixel flag at (0,0) must be 0")
	assert_eq(dummy_flags[4], 0, "Culled pixel flag at (1,1) must be 0")
	assert_eq(dummy_heights[0], 0, "Culled pixel height must be 0")
	assert_eq(dummy_heights[4], 0, "Culled pixel height must be 0")



