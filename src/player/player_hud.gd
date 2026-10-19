class_name PlayerHUD
extends Control

## Third-person shooter interface: crosshair, hit markers, and debug overlay.

@export var player_motor: PlayerMotor
@export var voxel_world: VoxelWorld:
	set(val):
		if voxel_world != null and voxel_world.spawn_mode_changed.is_connected(_on_spawn_mode_changed):
			voxel_world.spawn_mode_changed.disconnect(_on_spawn_mode_changed)
		voxel_world = val
		if voxel_world != null:
			if not voxel_world.spawn_mode_changed.is_connected(_on_spawn_mode_changed):
				voxel_world.spawn_mode_changed.connect(_on_spawn_mode_changed)

var show_debug: bool = true
var _hit_marker_time: float = 0.0
var _status_timer: float = 0.0

var _debug_label: Label
var _status_banner: Label

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)

	_debug_label = Label.new()
	_debug_label.position = Vector2(16, 16)
	_debug_label.add_theme_color_override("font_color", Color.WHITE)
	_debug_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_debug_label.add_theme_constant_override("shadow_offset_x", 1)
	_debug_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_debug_label)

	_status_banner = Label.new()
	_status_banner.anchor_left = 0.5
	_status_banner.anchor_top = 0.0
	_status_banner.anchor_right = 0.5
	_status_banner.anchor_bottom = 0.0
	_status_banner.offset_left = -250
	_status_banner.offset_top = 32
	_status_banner.offset_right = 250
	_status_banner.offset_bottom = 64
	_status_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_banner.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	_status_banner.add_theme_color_override("font_shadow_color", Color.BLACK)
	_status_banner.add_theme_constant_override("shadow_offset_x", 1)
	_status_banner.add_theme_constant_override("shadow_offset_y", 1)
	_status_banner.visible = false
	add_child(_status_banner)

	if player_motor != null:
		player_motor.fired.connect(_on_player_fired)

	if voxel_world != null and not voxel_world.spawn_mode_changed.is_connected(_on_spawn_mode_changed):
		voxel_world.spawn_mode_changed.connect(_on_spawn_mode_changed)

func _process(delta: float) -> void:
	if _hit_marker_time > 0.0:
		_hit_marker_time -= delta
		queue_redraw()

	if _status_timer > 0.0:
		_status_timer -= delta
		if _status_timer <= 0.0 and _status_banner != null:
			_status_banner.visible = false

	if Input.is_action_just_pressed("toggle_debug"):
		show_debug = not show_debug
		_debug_label.visible = show_debug

	if show_debug and _debug_label.visible:
		_update_debug_text()

	queue_redraw()

func _on_player_fired(hit: Dictionary) -> void:
	if hit.get("hit", false):
		_hit_marker_time = 0.14
		queue_redraw()

func _on_spawn_mode_changed(is_underground: bool, spawn_pos: Vector3) -> void:
	if _status_banner != null:
		var mode_name = "Underground Arena" if is_underground else "Surface"
		_status_banner.text = "[F4] Spawn Mode: %s (%d, %d, %d)" % [
			mode_name, int(spawn_pos.x), int(spawn_pos.y), int(spawn_pos.z)
		]
		_status_banner.visible = true
		_status_timer = 2.5

func _update_debug_text() -> void:
	var fps = Engine.get_frames_per_second()
	var pos_str = "(0.0, 0.0, 0.0)"
	var chunk_str = "(0, 0)"
	var loaded_count = 0
	var is_aim = false
	var shoulder = "Right"
	var spawn_str = "Unknown"

	if player_motor != null:
		var p = player_motor.global_position
		pos_str = "(%.1f, %.1f, %.1f)" % [p.x, p.y, p.z]
		if player_motor.camera_rig != null:
			is_aim = player_motor.camera_rig.is_aiming
			shoulder = "Right" if player_motor.camera_rig.shoulder_side > 0.0 else "Left"

	if voxel_world != null:
		loaded_count = voxel_world.get_loaded_chunk_count()
		if player_motor != null and voxel_world.bounds != null:
			var c = voxel_world.bounds.world_to_chunk(player_motor.global_position)
			chunk_str = "(%d, %d)" % [c.x, c.z]
		spawn_str = "Underground Arena" if voxel_world.spawn_on_underground_arena else "Surface"

	_debug_label.text = """[Voxel Continent Framework]
FPS: %d
Pos: %s
Chunk: %s
Loaded Chunks: %d
Aiming: %s | Shoulder: %s
Spawn: %s [F4 to toggle]

Controls:
WASD: Move | Shift: Sprint | Space: Jump
RMB: Aim Zoom | LMB: Fire (Hitscan)
V: Swap Shoulder | Tab/Esc: Toggle Mouse | F3: Toggle Info | F4: Toggle Spawn | M: Map""" % [
		fps, pos_str, chunk_str, loaded_count, str(is_aim), shoulder, spawn_str
	]

func _draw() -> void:
	var center = get_viewport_rect().size * 0.5
	var is_aiming = false
	if player_motor != null and player_motor.camera_rig != null:
		is_aiming = player_motor.camera_rig.is_aiming

	var reticle_gap = 4.0 if is_aiming else 8.0
	var reticle_len = 5.0
	var color = Color(1.0, 1.0, 1.0, 0.9)

	# Center dot
	draw_circle(center, 1.5, color)

	# 4 Crosshair ticks
	draw_line(center - Vector2(reticle_gap + reticle_len, 0.0), center - Vector2(reticle_gap, 0.0), color, 1.5)
	draw_line(center + Vector2(reticle_gap, 0.0), center + Vector2(reticle_gap + reticle_len, 0.0), color, 1.5)
	draw_line(center - Vector2(0.0, reticle_gap + reticle_len), center - Vector2(0.0, reticle_gap), color, 1.5)
	draw_line(center + Vector2(0.0, reticle_gap), center + Vector2(0.0, reticle_gap + reticle_len), color, 1.5)

	# Hit marker (red 'X' flash when hit registered)
	if _hit_marker_time > 0.0:
		var hm_color = Color(1.0, 0.2, 0.2, 0.95)
		var hm_dist = 6.0
		var hm_len = 5.0
		var d = Vector2(1.0, 1.0).normalized()
		var d2 = Vector2(-1.0, 1.0).normalized()

		draw_line(center + d * hm_dist, center + d * (hm_dist + hm_len), hm_color, 2.0)
		draw_line(center - d * hm_dist, center - d * (hm_dist + hm_len), hm_color, 2.0)
		draw_line(center + d2 * hm_dist, center + d2 * (hm_dist + hm_len), hm_color, 2.0)
		draw_line(center - d2 * hm_dist, center - d2 * (hm_dist + hm_len), hm_color, 2.0)
