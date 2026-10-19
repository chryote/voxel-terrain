class_name ContinentMapUI
extends Control

## Full continent map interface with topographic relief, tile material coloring,
## subterranean battle arena visualization, real-time player location indicator,
## cursor-centered zoom, bounded pan, level switching, and right-click teleportation.
## Toggled with the 'M' key.

enum MapLevel {
	SURFACE = 0,
	UNDERGROUND = 1
}

signal map_opened()
signal map_closed()
signal level_changed(level: int)
signal teleport_requested(target_pos: Vector3, level: int)

const ContinentMapProviderClass = preload("res://src/map/continent_map_provider.gd")
const ContinentMapColorPaletteClass = preload("res://src/map/continent_map_color_palette.gd")
const PlayerMarkerOverlayClass = preload("res://src/map/player_marker_overlay.gd")
const MapCoordinateConverterClass = preload("res://src/map/map_coordinate_converter.gd")
const MapPanZoomControllerClass = preload("res://src/map/map_pan_zoom_controller.gd")
const CaveMouthDataClass = preload("res://src/map/cave_mouth_data.gd")
const CaveMouthOverlayClass = preload("res://src/map/cave_mouth_overlay.gd")
const ChasmColumnResultClass = preload("res://src/generation/caves/chasm_column_result.gd")

@export var voxel_world: VoxelWorld
@export var player_motor: PlayerMotor

var provider: ContinentMapProviderClass = ContinentMapProviderClass.new()
var pan_zoom: MapPanZoomControllerClass = MapPanZoomControllerClass.new(Vector2(512, 512))
var palette: ContinentMapColorPaletteClass = ContinentMapColorPaletteClass.new()

var current_level: int = MapLevel.SURFACE
var _is_open: bool = false
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _right_mouse_down_pos: Vector2 = Vector2.ZERO

# UI Elements
var _backdrop: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _surface_button: Button
var _underground_button: Button
var _map_viewport_container: Control
var _map_content: Control
var _map_texture_rect: TextureRect
var _cave_mouth_overlay: CaveMouthOverlayClass
var _player_marker: PlayerMarkerOverlayClass
var _loading_label: Label
var _zoom_label: Label
var _stats_label: Label
var _legend_container: Container

# Context Menu Elements
var _context_menu: PanelContainer
var _context_target_label: Label
var _context_level_label: Label
var _context_teleport_btn: Button
var _context_cancel_btn: Button
var _context_target_pos: Vector3 = Vector3.ZERO

func _init() -> void:
	visible = false

func _ready() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)

	_build_ui()

	provider.map_baked.connect(_on_map_texture_baked)
	provider.level_baked.connect(_on_level_baked)

	if player_motor == null:
		player_motor = get_node_or_null("../..") as PlayerMotor

	_find_voxel_world_if_needed()

	# If voxel_world is available, initiate background baking
	if voxel_world != null:
		_start_baking_if_needed()

func _find_voxel_world_if_needed() -> void:
	if voxel_world != null:
		return
	if is_inside_tree() and get_tree() != null:
		var root = get_tree().current_scene
		if root != null:
			voxel_world = root.get_node_or_null("VoxelWorld") as VoxelWorld
		if voxel_world == null and get_tree().root != null:
			voxel_world = get_tree().root.find_child("VoxelWorld", true, false) as VoxelWorld

func _exit_tree() -> void:
	if provider != null:
		provider.clear()

func _mark_input_handled() -> void:
	if is_inside_tree():
		var vp = get_viewport()
		if vp != null:
			vp.set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_M or event.keycode == KEY_M or event.is_action_pressed("toggle_map"):
			toggle_map()
			_mark_input_handled()
			return

		if _is_open:
			if event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE or event.is_action_pressed("toggle_mouse"):
				if _is_context_menu_open():
					_close_context_menu()
				else:
					close_map()
				_mark_input_handled()
				return
			if event.physical_keycode == KEY_1 or event.keycode == KEY_1:
				switch_level(MapLevel.SURFACE)
				_mark_input_handled()
				return
			if event.physical_keycode == KEY_2 or event.keycode == KEY_2:
				switch_level(MapLevel.UNDERGROUND)
				_mark_input_handled()
				return
			if event.physical_keycode == KEY_TAB or event.keycode == KEY_TAB:
				var next_lvl = MapLevel.UNDERGROUND if current_level == MapLevel.SURFACE else MapLevel.SURFACE
				switch_level(next_lvl)
				_mark_input_handled()
				return
			if event.physical_keycode == KEY_R or event.keycode == KEY_R:
				_close_context_menu()
				pan_zoom.reset()
				_apply_pan_zoom()
				_mark_input_handled()
				return
			if event.physical_keycode == KEY_EQUAL or event.physical_keycode == KEY_KP_ADD:
				_close_context_menu()
				pan_zoom.zoom_at(Vector2(256, 256), 1.25)
				_apply_pan_zoom()
				_mark_input_handled()
				return
			if event.physical_keycode == KEY_MINUS or event.physical_keycode == KEY_KP_SUBTRACT:
				_close_context_menu()
				pan_zoom.zoom_at(Vector2(256, 256), 0.8)
				_apply_pan_zoom()
				_mark_input_handled()
				return

func _process(_delta: float) -> void:
	if not _is_open:
		return

	_update_player_marker()

func is_map_open() -> bool:
	return _is_open

func toggle_map() -> void:
	if _is_open:
		close_map()
	else:
		open_map()

func open_map() -> void:
	if _is_open:
		return
	_is_open = true
	visible = true
	_close_context_menu()

	# Release mouse mode so player can interact with the map dialog
	if player_motor != null and player_motor.player_input != null:
		_previous_mouse_mode = Input.mouse_mode
		player_motor.player_input.input_enabled = false
		player_motor.player_input.release_mouse()
	else:
		_previous_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_find_voxel_world_if_needed()
	_start_baking_if_needed()
	_apply_pan_zoom()
	_update_player_marker()
	_update_level_buttons()
	_update_title_and_legend()
	map_opened.emit()

func close_map() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	pan_zoom.end_drag()
	_close_context_menu()

	# Restore previous mouse mode and player input
	if player_motor != null and player_motor.player_input != null:
		player_motor.player_input.input_enabled = true
		player_motor.player_input.capture_mouse()
	else:
		Input.mouse_mode = _previous_mouse_mode
	map_closed.emit()

func switch_level(level: int) -> void:
	if level != MapLevel.SURFACE and level != MapLevel.UNDERGROUND:
		return
	current_level = level
	_close_context_menu()
	_update_level_buttons()
	_update_title_and_legend()

	if provider.is_ready(current_level):
		_map_texture_rect.texture = provider.get_texture(current_level)
		if _loading_label != null:
			_loading_label.visible = false
	else:
		_map_texture_rect.texture = null
		if _loading_label != null:
			_loading_label.text = "Baking underground arena map..." if current_level == MapLevel.UNDERGROUND else "Baking continent topography..."
			_loading_label.visible = true
		if voxel_world != null and voxel_world.generator != null and voxel_world.bounds != null:
			provider.bake_async(voxel_world.generator, voxel_world.bounds, 512, current_level)

	level_changed.emit(current_level)

func _on_map_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_close_context_menu()
			pan_zoom.zoom_at(event.position, 1.25)
			_apply_pan_zoom()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_close_context_menu()
			pan_zoom.zoom_at(event.position, 0.8)
			_apply_pan_zoom()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_MIDDLE:
			_close_context_menu()
			if event.pressed:
				pan_zoom.start_drag(event.position)
			else:
				pan_zoom.end_drag()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_right_mouse_down_pos = event.position
				pan_zoom.start_drag(event.position)
			else:
				pan_zoom.end_drag()
				if (event.position - _right_mouse_down_pos).length() < 8.0:
					open_context_menu_at(event.position)
			accept_event()

	elif event is InputEventMouseMotion:
		if pan_zoom.is_dragging:
			if _is_context_menu_open():
				_close_context_menu()
			pan_zoom.drag_to(event.position)
			_apply_pan_zoom()
			accept_event()

func _apply_pan_zoom() -> void:
	if _map_content != null:
		_map_content.position = pan_zoom.pan_offset
		_map_content.scale = Vector2(pan_zoom.zoom, pan_zoom.zoom)
	if _cave_mouth_overlay != null:
		if voxel_world != null and voxel_world.bounds != null and provider.is_ready(MapLevel.SURFACE):
			_cave_mouth_overlay.set_cave_mouths(provider.get_cave_mouths(), voxel_world.bounds)
		_cave_mouth_overlay.update_transform(pan_zoom.pan_offset, pan_zoom.zoom, pan_zoom.box_size)
	if _player_marker != null:
		_player_marker.update_transform(pan_zoom.pan_offset, pan_zoom.zoom, pan_zoom.box_size)
	if _zoom_label != null:
		_zoom_label.text = "%d%% (%.1fx)" % [int(round(pan_zoom.zoom * 100.0)), pan_zoom.zoom]

func _start_baking_if_needed() -> void:
	if provider.is_ready(current_level):
		_map_texture_rect.texture = provider.get_texture(current_level)
		if _cave_mouth_overlay != null and voxel_world != null:
			_cave_mouth_overlay.set_cave_mouths(provider.get_cave_mouths(), voxel_world.bounds)
			_cave_mouth_overlay.update_transform(pan_zoom.pan_offset, pan_zoom.zoom, pan_zoom.box_size)
		if _loading_label != null:
			_loading_label.visible = false
		return

	if voxel_world != null and voxel_world.generator != null and voxel_world.bounds != null:
		if not provider.is_baking():
			if _loading_label != null:
				_loading_label.text = "Baking continent topography & arena..."
				_loading_label.visible = true
			provider.bake_all_async(voxel_world.generator, voxel_world.bounds, 512)

func _on_map_texture_baked(texture: ImageTexture) -> void:
	_find_voxel_world_if_needed()
	if current_level == MapLevel.SURFACE and _map_texture_rect != null:
		_map_texture_rect.texture = texture
	if _cave_mouth_overlay != null and voxel_world != null:
		_cave_mouth_overlay.set_cave_mouths(provider.get_cave_mouths(), voxel_world.bounds)
		_cave_mouth_overlay.update_transform(pan_zoom.pan_offset, pan_zoom.zoom, pan_zoom.box_size)
	if current_level == MapLevel.SURFACE and _loading_label != null:
		_loading_label.visible = false

func _on_level_baked(level: int, texture: ImageTexture) -> void:
	_find_voxel_world_if_needed()
	if level == current_level:
		if _map_texture_rect != null:
			_map_texture_rect.texture = texture
		if _loading_label != null:
			_loading_label.visible = false
	if _cave_mouth_overlay != null and voxel_world != null:
		_cave_mouth_overlay.set_cave_mouths(provider.get_cave_mouths(), voxel_world.bounds)
		_cave_mouth_overlay.update_transform(pan_zoom.pan_offset, pan_zoom.zoom, pan_zoom.box_size)

func _update_player_marker() -> void:
	if _player_marker == null:
		return
	if voxel_world == null or voxel_world.bounds == null:
		_find_voxel_world_if_needed()
		if voxel_world == null or voxel_world.bounds == null:
			return

	var p_pos = Vector3.ZERO
	var p_yaw = 0.0

	if player_motor != null:
		p_pos = player_motor.global_position
		if player_motor.camera_rig != null:
			p_yaw = player_motor.camera_rig.get_camera_yaw()
		else:
			p_yaw = player_motor.rotation.y

	_player_marker.update_player_state(p_pos, p_yaw, voxel_world.bounds)
	_player_marker.update_transform(pan_zoom.pan_offset, pan_zoom.zoom, pan_zoom.box_size)

	if _stats_label != null:
		var seed_str = str(voxel_world.world_config.world_seed) if voxel_world.world_config != null else "N/A"
		var dim_str = "%d x %d blocks" % [
			int(voxel_world.bounds.max_world_x - voxel_world.bounds.min_world_x),
			int(voxel_world.bounds.max_world_z - voxel_world.bounds.min_world_z)
		]
		var lvl_str = "Surface" if current_level == MapLevel.SURFACE else "Underground Arena"
		_stats_label.text = "Player: (X: %d, Z: %d, Alt: %dm)  |  Level: %s  |  World: %s  |  Seed: %s" % [
			int(round(p_pos.x)),
			int(round(p_pos.z)),
			int(round(p_pos.y)),
			lvl_str,
			dim_str,
			seed_str
		]

# -----------------------------------------------------------------------------
# Context Menu and Teleportation
# -----------------------------------------------------------------------------

func _is_context_menu_open() -> bool:
	return _context_menu != null and _context_menu.visible

func _close_context_menu() -> void:
	if _context_menu != null and _context_menu.visible:
		_context_menu.visible = false

func open_context_menu_at(screen_pos: Vector2) -> void:
	if _context_menu == null:
		return

	var map_pixel = pan_zoom.screen_to_map(screen_pos)
	var target_world_pos = get_teleport_position_for_map_pixel(map_pixel, current_level)
	_context_target_pos = target_world_pos

	if _context_target_label != null:
		_context_target_label.text = "Target: (X: %d, Z: %d, Alt: %dm)" % [
			int(round(target_world_pos.x)),
			int(round(target_world_pos.z)),
			int(round(target_world_pos.y))
		]

	if _context_level_label != null:
		var lvl_name = "Surface" if current_level == MapLevel.SURFACE else "Underground Arena"
		_context_level_label.text = "Destination: %s" % lvl_name

	# Clamp context menu to fit within map viewport container (512 x 512)
	var menu_size = _context_menu.get_combined_minimum_size()
	if menu_size.x <= 0.0 or menu_size.y <= 0.0:
		menu_size = Vector2(170, 95)

	var clamped_x = clampf(screen_pos.x, 4.0, pan_zoom.box_size.x - menu_size.x - 4.0)
	var clamped_y = clampf(screen_pos.y, 4.0, pan_zoom.box_size.y - menu_size.y - 4.0)
	_context_menu.position = Vector2(clamped_x, clamped_y)
	_context_menu.visible = true

func _on_context_teleport_pressed() -> void:
	teleport_to(_context_target_pos)

func teleport_to(target_pos: Vector3) -> void:
	_close_context_menu()

	if voxel_world != null:
		if current_level == MapLevel.UNDERGROUND:
			voxel_world.spawn_on_underground_arena = true
			voxel_world.caves_enabled = true
		else:
			voxel_world.spawn_on_underground_arena = false
		voxel_world.teleport_focus_to(target_pos)

	if player_motor != null:
		if player_motor.is_inside_tree():
			player_motor.global_position = target_pos
		else:
			player_motor.position = target_pos
		if player_motor is CharacterBody3D:
			player_motor.velocity = Vector3.ZERO

	_update_player_marker()
	teleport_requested.emit(target_pos, current_level)
	close_map()

func get_teleport_position_for_map_pixel(map_pixel: Vector2, level: int = current_level) -> Vector3:
	if voxel_world == null or voxel_world.bounds == null:
		return Vector3(map_pixel.x, 20.0, map_pixel.y)

	var bounds = voxel_world.bounds
	var uv = Vector2(
		clampf(map_pixel.x / pan_zoom.box_size.x, 0.0, 1.0),
		clampf(map_pixel.y / pan_zoom.box_size.y, 0.0, 1.0)
	)
	var world_pos = MapCoordinateConverterClass.normalized_to_world(uv, bounds)
	var target_y = 10.0

	if level == MapLevel.SURFACE:
		if voxel_world.generator != null and voxel_world.generator.has_method("height_at"):
			var col = bounds.world_to_column(world_pos)
			target_y = float(voxel_world.generator.height_at(col, bounds)) * bounds.voxel_size + 2.0
			if voxel_world.generator.has_method("water_height_at"):
				var wh = float(voxel_world.generator.water_height_at(col, bounds)) * bounds.voxel_size
				target_y = maxf(target_y, wh + 2.0)
		else:
			target_y = 30.0
	else:
		var found_floor = false
		var cave_carver: CaveCarver = null
		if voxel_world.generator != null:
			if "cave_carver" in voxel_world.generator and voxel_world.generator.cave_carver != null:
				cave_carver = voxel_world.generator.cave_carver
			elif "continent_gen" in voxel_world.generator and voxel_world.generator.continent_gen != null and "cave_carver" in voxel_world.generator.continent_gen:
				cave_carver = voxel_world.generator.continent_gen.cave_carver

		if cave_carver != null and cave_carver.chasm_sampler != null:
			var chasm_col = ChasmColumnResultClass.new()
			var surf_h = 40.0
			if voxel_world.generator.has_method("height_at"):
				var col = bounds.world_to_column(world_pos)
				surf_h = float(voxel_world.generator.height_at(col, bounds)) * bounds.voxel_size
			cave_carver.sample_chasm_column(world_pos.x, world_pos.z, chasm_col, surf_h)
			if chasm_col.is_arena or chasm_col.is_chasm:
				target_y = float(chasm_col.floor_y + 1) * bounds.voxel_size
				found_floor = true

		if not found_floor:
			var arena_spawn = voxel_world.get_underground_spawn_point()
			target_y = arena_spawn.y

	return Vector3(world_pos.x, target_y, world_pos.z)

# -----------------------------------------------------------------------------
# UI Construction and Styling
# -----------------------------------------------------------------------------

func _build_ui() -> void:
	# 1. Dark semi-transparent backdrop
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(PRESET_FULL_RECT)
	_backdrop.color = Color(0.04, 0.06, 0.09, 0.82)
	_backdrop.mouse_filter = MOUSE_FILTER_STOP
	_backdrop.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_close_context_menu()
	)
	add_child(_backdrop)

	# 2. Centered dialog panel
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(PRESET_CENTER)
	_panel.grow_horizontal = GROW_DIRECTION_BOTH
	_panel.grow_vertical = GROW_DIRECTION_BOTH

	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.08, 0.11, 0.15, 0.96)
	style_box.border_color = Color(0.24, 0.36, 0.48, 1.0)
	style_box.set_border_width_all(2)
	style_box.set_corner_radius_all(8)
	style_box.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", style_box)
	add_child(_panel)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(main_vbox)

	# 3. Header bar (Title + Controls hint)
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 12)
	main_vbox.add_child(header_hbox)

	_title_label = Label.new()
	_title_label.text = "CONTINENT TOPOGRAPHIC MAP - SURFACE"
	_title_label.add_theme_font_size_override("font_size", 15)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	header_hbox.add_child(_title_label)

	var spacer = Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)

	var close_hint = Label.new()
	close_hint.text = "Scroll: Zoom | Drag: Pan | Right-Click: Teleport | [R] Reset | [M/ESC] Close"
	close_hint.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
	close_hint.add_theme_font_size_override("font_size", 11)
	header_hbox.add_child(close_hint)

	# 4. Level Switch Toolbar
	var toolbar_hbox = HBoxContainer.new()
	toolbar_hbox.add_theme_constant_override("separation", 8)
	main_vbox.add_child(toolbar_hbox)

	var level_caption = Label.new()
	level_caption.text = "Map Level:"
	level_caption.add_theme_font_size_override("font_size", 12)
	level_caption.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
	toolbar_hbox.add_child(level_caption)

	_surface_button = Button.new()
	_surface_button.text = "⛰ Surface [1]"
	_surface_button.custom_minimum_size = Vector2(130, 26)
	_surface_button.focus_mode = FOCUS_NONE
	_surface_button.pressed.connect(func(): switch_level(MapLevel.SURFACE))
	toolbar_hbox.add_child(_surface_button)

	_underground_button = Button.new()
	_underground_button.text = "⚔ Underground Arena [2]"
	_underground_button.custom_minimum_size = Vector2(170, 26)
	_underground_button.focus_mode = FOCUS_NONE
	_underground_button.pressed.connect(func(): switch_level(MapLevel.UNDERGROUND))
	toolbar_hbox.add_child(_underground_button)

	var switch_hint = Label.new()
	switch_hint.text = "[Tab / 1 / 2 to toggle]"
	switch_hint.add_theme_font_size_override("font_size", 11)
	switch_hint.add_theme_color_override("font_color", Color(0.55, 0.65, 0.75))
	toolbar_hbox.add_child(switch_hint)

	_update_level_buttons()

	# 5. Map Container (Square fixed size 512x512)
	var map_aspect_box = CenterContainer.new()
	main_vbox.add_child(map_aspect_box)

	var map_frame = PanelContainer.new()
	var frame_style = StyleBoxFlat.new()
	frame_style.bg_color = Color(0.04, 0.05, 0.07, 1.0)
	frame_style.border_color = Color(0.35, 0.45, 0.55, 0.8)
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(4)
	frame_style.set_content_margin_all(2)
	map_frame.add_theme_stylebox_override("panel", frame_style)
	map_aspect_box.add_child(map_frame)

	_map_viewport_container = Control.new()
	_map_viewport_container.custom_minimum_size = Vector2(512, 512)
	_map_viewport_container.clip_contents = true
	_map_viewport_container.mouse_filter = MOUSE_FILTER_STOP
	_map_viewport_container.gui_input.connect(_on_map_gui_input)
	map_frame.add_child(_map_viewport_container)

	# Map content container scaled and positioned by pan_zoom
	_map_content = Control.new()
	_map_content.custom_minimum_size = Vector2(512, 512)
	_map_content.size = Vector2(512, 512)
	_map_content.mouse_filter = MOUSE_FILTER_IGNORE
	_map_viewport_container.add_child(_map_content)

	_map_texture_rect = TextureRect.new()
	_map_texture_rect.set_anchors_preset(PRESET_FULL_RECT)
	_map_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_map_texture_rect.texture_filter = TEXTURE_FILTER_LINEAR
	_map_texture_rect.mouse_filter = MOUSE_FILTER_IGNORE
	_map_content.add_child(_map_texture_rect)

	# Compass indicator in top-right corner
	var compass_label = Label.new()
	compass_label.text = "▲ N"
	compass_label.position = Vector2(480, 8)
	compass_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	compass_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	compass_label.add_theme_constant_override("shadow_offset_x", 1)
	compass_label.add_theme_constant_override("shadow_offset_y", 1)
	compass_label.add_theme_font_size_override("font_size", 14)
	compass_label.mouse_filter = MOUSE_FILTER_IGNORE
	_map_viewport_container.add_child(compass_label)

	# Zoom level badge in top-left corner
	_zoom_label = Label.new()
	_zoom_label.text = "100% (1.0x)"
	_zoom_label.position = Vector2(10, 8)
	_zoom_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 0.9))
	_zoom_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_zoom_label.add_theme_constant_override("shadow_offset_x", 1)
	_zoom_label.add_theme_constant_override("shadow_offset_y", 1)
	_zoom_label.add_theme_font_size_override("font_size", 12)
	_zoom_label.mouse_filter = MOUSE_FILTER_IGNORE
	_map_viewport_container.add_child(_zoom_label)

	# Loading indicator
	_loading_label = Label.new()
	_loading_label.text = "Baking continent topography..."
	_loading_label.set_anchors_preset(PRESET_CENTER)
	_loading_label.grow_horizontal = GROW_DIRECTION_BOTH
	_loading_label.grow_vertical = GROW_DIRECTION_BOTH
	_loading_label.add_theme_color_override("font_color", Color.WHITE)
	_loading_label.mouse_filter = MOUSE_FILTER_IGNORE
	_map_viewport_container.add_child(_loading_label)

	# Cave mouth overlay
	_cave_mouth_overlay = CaveMouthOverlayClass.new()
	_cave_mouth_overlay.custom_minimum_size = Vector2(512, 512)
	_cave_mouth_overlay.size = Vector2(512, 512)
	_cave_mouth_overlay.map_size = Vector2(512, 512)
	_cave_mouth_overlay.mouse_filter = MOUSE_FILTER_IGNORE
	_map_viewport_container.add_child(_cave_mouth_overlay)

	# Player marker overlay
	_player_marker = PlayerMarkerOverlayClass.new()
	_player_marker.custom_minimum_size = Vector2(512, 512)
	_player_marker.size = Vector2(512, 512)
	_player_marker.map_size = Vector2(512, 512)
	_player_marker.z_index = 5
	_player_marker.mouse_filter = MOUSE_FILTER_IGNORE
	_map_viewport_container.add_child(_player_marker)

	# Context menu popup (initially hidden)
	_build_context_menu(_map_viewport_container)

	# 6. Status / Coordinates Bar
	_stats_label = Label.new()
	_stats_label.text = "Player: (X: 0, Z: 0, Alt: 0m)"
	_stats_label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.95))
	_stats_label.add_theme_font_size_override("font_size", 12)
	main_vbox.add_child(_stats_label)

	# 7. Map Legend
	_legend_container = HFlowContainer.new()
	_legend_container.add_theme_constant_override("h_separation", 10)
	_legend_container.add_theme_constant_override("v_separation", 4)
	main_vbox.add_child(_legend_container)

	_update_title_and_legend()

func _build_context_menu(parent: Control) -> void:
	_context_menu = PanelContainer.new()
	_context_menu.visible = false
	_context_menu.z_index = 25
	_context_menu.mouse_filter = MOUSE_FILTER_STOP

	var ctx_style = StyleBoxFlat.new()
	ctx_style.bg_color = Color(0.07, 0.10, 0.15, 0.98)
	ctx_style.border_color = Color(0.38, 0.58, 0.82, 1.0)
	ctx_style.set_border_width_all(2)
	ctx_style.set_corner_radius_all(6)
	ctx_style.set_content_margin_all(8)
	_context_menu.add_theme_stylebox_override("panel", ctx_style)

	var ctx_vbox = VBoxContainer.new()
	ctx_vbox.add_theme_constant_override("separation", 6)
	_context_menu.add_child(ctx_vbox)

	_context_target_label = Label.new()
	_context_target_label.text = "Target: (X: 0, Z: 0, Alt: 0m)"
	_context_target_label.add_theme_font_size_override("font_size", 11)
	_context_target_label.add_theme_color_override("font_color", Color(0.9, 0.94, 1.0))
	ctx_vbox.add_child(_context_target_label)

	_context_level_label = Label.new()
	_context_level_label.text = "Destination: Surface"
	_context_level_label.add_theme_font_size_override("font_size", 10)
	_context_level_label.add_theme_color_override("font_color", Color(0.65, 0.78, 0.92))
	ctx_vbox.add_child(_context_level_label)

	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 6)
	ctx_vbox.add_child(btn_hbox)

	_context_teleport_btn = Button.new()
	_context_teleport_btn.text = "⚡ Teleport Here"
	_context_teleport_btn.focus_mode = FOCUS_NONE
	_context_teleport_btn.add_theme_font_size_override("font_size", 11)

	var tp_style = StyleBoxFlat.new()
	tp_style.bg_color = Color(0.18, 0.42, 0.72, 1.0)
	tp_style.border_color = Color(0.45, 0.75, 1.0, 1.0)
	tp_style.set_border_width_all(1)
	tp_style.set_corner_radius_all(4)
	tp_style.set_content_margin_all(4)
	_context_teleport_btn.add_theme_stylebox_override("normal", tp_style)
	_context_teleport_btn.pressed.connect(_on_context_teleport_pressed)
	btn_hbox.add_child(_context_teleport_btn)

	_context_cancel_btn = Button.new()
	_context_cancel_btn.text = "Cancel"
	_context_cancel_btn.focus_mode = FOCUS_NONE
	_context_cancel_btn.add_theme_font_size_override("font_size", 11)

	var cancel_style = StyleBoxFlat.new()
	cancel_style.bg_color = Color(0.15, 0.18, 0.24, 1.0)
	cancel_style.border_color = Color(0.3, 0.38, 0.48, 0.8)
	cancel_style.set_border_width_all(1)
	cancel_style.set_corner_radius_all(4)
	cancel_style.set_content_margin_all(4)
	_context_cancel_btn.add_theme_stylebox_override("normal", cancel_style)
	_context_cancel_btn.pressed.connect(_close_context_menu)
	btn_hbox.add_child(_context_cancel_btn)

	parent.add_child(_context_menu)

func _update_level_buttons() -> void:
	if _surface_button == null or _underground_button == null:
		return

	var is_surface = (current_level == MapLevel.SURFACE)

	var active_surf = StyleBoxFlat.new()
	active_surf.bg_color = Color(0.18, 0.42, 0.72, 1.0)
	active_surf.border_color = Color(0.5, 0.8, 1.0, 1.0)
	active_surf.set_border_width_all(2)
	active_surf.set_corner_radius_all(4)
	active_surf.set_content_margin_all(4)

	var active_under = StyleBoxFlat.new()
	active_under.bg_color = Color(0.72, 0.40, 0.14, 1.0)
	active_under.border_color = Color(0.98, 0.68, 0.32, 1.0)
	active_under.set_border_width_all(2)
	active_under.set_corner_radius_all(4)
	active_under.set_content_margin_all(4)

	var inactive = StyleBoxFlat.new()
	inactive.bg_color = Color(0.10, 0.13, 0.18, 0.9)
	inactive.border_color = Color(0.25, 0.33, 0.44, 0.8)
	inactive.set_border_width_all(1)
	inactive.set_corner_radius_all(4)
	inactive.set_content_margin_all(4)

	if is_surface:
		_surface_button.add_theme_stylebox_override("normal", active_surf)
		_surface_button.add_theme_stylebox_override("hover", active_surf)
		_surface_button.add_theme_stylebox_override("pressed", active_surf)
		_surface_button.add_theme_color_override("font_color", Color.WHITE)

		_underground_button.add_theme_stylebox_override("normal", inactive)
		_underground_button.add_theme_stylebox_override("hover", inactive)
		_underground_button.add_theme_stylebox_override("pressed", inactive)
		_underground_button.add_theme_color_override("font_color", Color(0.68, 0.76, 0.85))
	else:
		_surface_button.add_theme_stylebox_override("normal", inactive)
		_surface_button.add_theme_stylebox_override("hover", inactive)
		_surface_button.add_theme_stylebox_override("pressed", inactive)
		_surface_button.add_theme_color_override("font_color", Color(0.68, 0.76, 0.85))

		_underground_button.add_theme_stylebox_override("normal", active_under)
		_underground_button.add_theme_stylebox_override("hover", active_under)
		_underground_button.add_theme_stylebox_override("pressed", active_under)
		_underground_button.add_theme_color_override("font_color", Color.WHITE)

func _update_title_and_legend() -> void:
	if _title_label != null:
		if current_level == MapLevel.SURFACE:
			_title_label.text = "CONTINENT TOPOGRAPHIC MAP - SURFACE"
		else:
			_title_label.text = "CONTINENT TOPOGRAPHIC MAP - UNDERGROUND ARENA"

	if _legend_container == null:
		return

	for child in _legend_container.get_children():
		child.queue_free()

	if current_level == MapLevel.SURFACE:
		_add_legend_item("Ocean", Color("#1b3f63"))
		_add_legend_item("Water", Color("#2e7ca8"))
		_add_legend_item("Beach", Color("#d8c78c"))
		_add_legend_item("Plains", Color("#567d46"))
		_add_legend_item("Hills", Color("#6b4f38"))
		_add_legend_item("Stone", Color("#787878"))
		_add_legend_item("Snow", Color("#f4f7fb"))
		_add_legend_item("Dead Cave (C)", CaveMouthDataClass.COLOR_DEAD_END)
		_add_legend_item("Tunnel Cave (C)", CaveMouthDataClass.COLOR_TUNNEL)
		_add_legend_item("Chasm Cave (C)", CaveMouthDataClass.COLOR_CHASM)
		_add_legend_item("Player", Color(0.92, 0.12, 0.12))
	else:
		_add_legend_item("Bedrock", palette.color_underground_rock)
		_add_legend_item("Cavern Floor", palette.color_chasm_floor)
		_add_legend_item("Arena Pit", palette.color_arena_floor)
		_add_legend_item("Spectator Ledges", palette.color_arena_ledge)
		_add_legend_item("Basalt Colonnade", palette.color_basalt_column)
		_add_legend_item("Pillars", palette.color_pillar)
		_add_legend_item("Cavern Water", palette.color_subterranean_water)
		_add_legend_item("Cave Entrances (C)", CaveMouthDataClass.COLOR_CHASM)
		_add_legend_item("Player", Color(0.92, 0.12, 0.12))

func _add_legend_item(title: String, color: Color) -> void:
	var item_box = HBoxContainer.new()
	item_box.add_theme_constant_override("separation", 4)

	var chip = ColorRect.new()
	chip.custom_minimum_size = Vector2(10, 10)
	chip.color = color
	item_box.add_child(chip)

	var label = Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.75, 0.82, 0.9))
	item_box.add_child(label)

	_legend_container.add_child(item_box)
