class_name ContinentMapUI
extends Control

## Full continent map interface with topographic relief, tile material coloring,
## real-time player location indicator, cursor-centered zoom, and bounded pan.
## Toggled with the 'M' key.

signal map_opened()
signal map_closed()

const ContinentMapProviderClass = preload("res://src/map/continent_map_provider.gd")
const PlayerMarkerOverlayClass = preload("res://src/map/player_marker_overlay.gd")
const MapCoordinateConverterClass = preload("res://src/map/map_coordinate_converter.gd")
const MapPanZoomControllerClass = preload("res://src/map/map_pan_zoom_controller.gd")
const CaveMouthDataClass = preload("res://src/map/cave_mouth_data.gd")
const CaveMouthOverlayClass = preload("res://src/map/cave_mouth_overlay.gd")

@export var voxel_world: VoxelWorld
@export var player_motor: PlayerMotor

var provider: ContinentMapProviderClass = ContinentMapProviderClass.new()
var pan_zoom: MapPanZoomControllerClass = MapPanZoomControllerClass.new(Vector2(512, 512))

var _is_open: bool = false
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED

# UI Elements
var _backdrop: ColorRect
var _panel: PanelContainer
var _map_content: Control
var _map_texture_rect: TextureRect
var _cave_mouth_overlay: CaveMouthOverlayClass
var _player_marker: PlayerMarkerOverlayClass
var _loading_label: Label
var _zoom_label: Label
var _stats_label: Label
var _legend_container: Container

func _init() -> void:
	visible = false

func _ready() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)

	_build_ui()

	provider.map_baked.connect(_on_map_texture_baked)

	if player_motor == null:
		player_motor = get_node_or_null("../..") as PlayerMotor

	_find_voxel_world_if_needed()

	# If voxel_world is available, initiate background baking
	if voxel_world != null:
		_start_baking_if_needed()

func _find_voxel_world_if_needed() -> void:
	if voxel_world != null:
		return
	if get_tree() != null:
		var root = get_tree().current_scene
		if root != null:
			voxel_world = root.get_node_or_null("VoxelWorld") as VoxelWorld
		if voxel_world == null and get_tree().root != null:
			voxel_world = get_tree().root.find_child("VoxelWorld", true, false) as VoxelWorld

func _exit_tree() -> void:
	if provider != null:
		provider.clear()

func _mark_input_handled() -> void:
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
				close_map()
				_mark_input_handled()
				return
			if event.physical_keycode == KEY_R or event.keycode == KEY_R:
				pan_zoom.reset()
				_apply_pan_zoom()
				_mark_input_handled()
				return
			if event.physical_keycode == KEY_EQUAL or event.physical_keycode == KEY_KP_ADD:
				pan_zoom.zoom_at(Vector2(256, 256), 1.25)
				_apply_pan_zoom()
				_mark_input_handled()
				return
			if event.physical_keycode == KEY_MINUS or event.physical_keycode == KEY_KP_SUBTRACT:
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
	map_opened.emit()

func close_map() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	pan_zoom.end_drag()

	# Restore previous mouse mode and player input
	if player_motor != null and player_motor.player_input != null:
		player_motor.player_input.input_enabled = true
		player_motor.player_input.capture_mouse()
	else:
		Input.mouse_mode = _previous_mouse_mode
	map_closed.emit()

func _on_map_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			pan_zoom.zoom_at(event.position, 1.25)
			_apply_pan_zoom()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			pan_zoom.zoom_at(event.position, 0.8)
			_apply_pan_zoom()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				pan_zoom.start_drag(event.position)
			else:
				pan_zoom.end_drag()
			accept_event()

	elif event is InputEventMouseMotion:
		if pan_zoom.is_dragging:
			pan_zoom.drag_to(event.position)
			_apply_pan_zoom()
			accept_event()

func _apply_pan_zoom() -> void:
	if _map_content != null:
		_map_content.position = pan_zoom.pan_offset
		_map_content.scale = Vector2(pan_zoom.zoom, pan_zoom.zoom)
	if _cave_mouth_overlay != null:
		if voxel_world != null and voxel_world.bounds != null and provider.is_ready():
			_cave_mouth_overlay.set_cave_mouths(provider.get_cave_mouths(), voxel_world.bounds)
		_cave_mouth_overlay.update_transform(pan_zoom.pan_offset, pan_zoom.zoom, pan_zoom.box_size)
	if _player_marker != null:
		_player_marker.update_transform(pan_zoom.pan_offset, pan_zoom.zoom, pan_zoom.box_size)
	if _zoom_label != null:
		_zoom_label.text = "%d%% (%.1fx)" % [int(round(pan_zoom.zoom * 100.0)), pan_zoom.zoom]

func _start_baking_if_needed() -> void:
	if provider.is_ready():
		_map_texture_rect.texture = provider.get_texture()
		if _cave_mouth_overlay != null and voxel_world != null:
			_cave_mouth_overlay.set_cave_mouths(provider.get_cave_mouths(), voxel_world.bounds)
			_cave_mouth_overlay.update_transform(pan_zoom.pan_offset, pan_zoom.zoom, pan_zoom.box_size)
		_loading_label.visible = false
		return

	if voxel_world != null and voxel_world.generator != null and voxel_world.bounds != null:
		if not provider.is_baking():
			_loading_label.visible = true
			provider.bake_async(voxel_world.generator, voxel_world.bounds, 512)

func _on_map_texture_baked(texture: ImageTexture) -> void:
	_find_voxel_world_if_needed()
	if _map_texture_rect != null:
		_map_texture_rect.texture = texture
	if _cave_mouth_overlay != null and voxel_world != null:
		_cave_mouth_overlay.set_cave_mouths(provider.get_cave_mouths(), voxel_world.bounds)
		_cave_mouth_overlay.update_transform(pan_zoom.pan_offset, pan_zoom.zoom, pan_zoom.box_size)
	if _loading_label != null:
		_loading_label.visible = false

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
		_stats_label.text = "Player: (X: %d, Z: %d, Alt: %dm)  |  World: %s  |  Seed: %s" % [
			int(round(p_pos.x)),
			int(round(p_pos.z)),
			int(round(p_pos.y)),
			dim_str,
			seed_str
		]

func _build_ui() -> void:
	# 1. Dark semi-transparent backdrop
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(PRESET_FULL_RECT)
	_backdrop.color = Color(0.04, 0.06, 0.09, 0.82)
	_backdrop.mouse_filter = MOUSE_FILTER_STOP
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
	style_box.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", style_box)
	add_child(_panel)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(main_vbox)

	# 3. Header bar (Title + Controls hint)
	var header_hbox = HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	var title_label = Label.new()
	title_label.text = "CONTINENT TOPOGRAPHIC MAP"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	header_hbox.add_child(title_label)

	var spacer = Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)

	var close_hint = Label.new()
	close_hint.text = "Scroll: Zoom | Drag: Pan | [R] Reset | [M/ESC] Close"
	close_hint.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
	close_hint.add_theme_font_size_override("font_size", 12)
	header_hbox.add_child(close_hint)

	# 4. Map Container (Square fixed size 512x512)
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

	var map_viewport_container = Control.new()
	map_viewport_container.custom_minimum_size = Vector2(512, 512)
	map_viewport_container.clip_contents = true
	map_viewport_container.mouse_filter = MOUSE_FILTER_STOP
	map_viewport_container.gui_input.connect(_on_map_gui_input)
	map_frame.add_child(map_viewport_container)

	# Map content container scaled and positioned by pan_zoom
	_map_content = Control.new()
	_map_content.custom_minimum_size = Vector2(512, 512)
	_map_content.size = Vector2(512, 512)
	_map_content.mouse_filter = MOUSE_FILTER_IGNORE
	map_viewport_container.add_child(_map_content)

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
	map_viewport_container.add_child(compass_label)

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
	map_viewport_container.add_child(_zoom_label)

	# Loading indicator
	_loading_label = Label.new()
	_loading_label.text = "Baking continent topography..."
	_loading_label.set_anchors_preset(PRESET_CENTER)
	_loading_label.grow_horizontal = GROW_DIRECTION_BOTH
	_loading_label.grow_vertical = GROW_DIRECTION_BOTH
	_loading_label.add_theme_color_override("font_color", Color.WHITE)
	_loading_label.mouse_filter = MOUSE_FILTER_IGNORE
	map_viewport_container.add_child(_loading_label)

	# Cave mouth overlay
	_cave_mouth_overlay = CaveMouthOverlayClass.new()
	_cave_mouth_overlay.custom_minimum_size = Vector2(512, 512)
	_cave_mouth_overlay.size = Vector2(512, 512)
	_cave_mouth_overlay.map_size = Vector2(512, 512)
	_cave_mouth_overlay.mouse_filter = MOUSE_FILTER_IGNORE
	map_viewport_container.add_child(_cave_mouth_overlay)

	# Player marker overlay
	_player_marker = PlayerMarkerOverlayClass.new()
	_player_marker.custom_minimum_size = Vector2(512, 512)
	_player_marker.size = Vector2(512, 512)
	_player_marker.map_size = Vector2(512, 512)
	_player_marker.z_index = 5
	_player_marker.mouse_filter = MOUSE_FILTER_IGNORE
	map_viewport_container.add_child(_player_marker)

	# 5. Status / Coordinates Bar
	_stats_label = Label.new()
	_stats_label.text = "Player: (X: 0, Z: 0, Alt: 0m)"
	_stats_label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.95))
	_stats_label.add_theme_font_size_override("font_size", 12)
	main_vbox.add_child(_stats_label)

	# 6. Map Legend
	_legend_container = HFlowContainer.new()
	_legend_container.add_theme_constant_override("h_separation", 10)
	_legend_container.add_theme_constant_override("v_separation", 4)
	main_vbox.add_child(_legend_container)

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
