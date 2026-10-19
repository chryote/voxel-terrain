class_name RenderPerformanceSample
extends RefCounted

## Snapshot of rendering and main-thread performance metrics for a single frame.

var frame_index: int = 0
var draw_calls: int = 0
var process_time_ms: float = 0.0
var frame_delta_ms: float = 0.0
var physics_time_ms: float = 0.0
var primitives: int = 0
var objects_in_frame: int = 0
var loaded_chunks: int = 0
var camera_position: Vector3 = Vector3.ZERO
var is_underground: bool = false
var fps: float = 0.0

func _init(
	p_frame_index: int = 0,
	p_draw_calls: int = 0,
	p_process_time_ms: float = 0.0,
	p_frame_delta_ms: float = 0.0,
	p_physics_time_ms: float = 0.0,
	p_primitives: int = 0,
	p_objects_in_frame: int = 0,
	p_loaded_chunks: int = 0,
	p_camera_position: Vector3 = Vector3.ZERO,
	p_is_underground: bool = false,
	p_fps: float = 0.0
) -> void:
	frame_index = p_frame_index
	draw_calls = p_draw_calls
	process_time_ms = p_process_time_ms
	frame_delta_ms = p_frame_delta_ms
	physics_time_ms = p_physics_time_ms
	primitives = p_primitives
	objects_in_frame = p_objects_in_frame
	loaded_chunks = p_loaded_chunks
	camera_position = p_camera_position
	is_underground = p_is_underground
	fps = p_fps

## Captures live performance metrics from RenderingServer and Performance monitors for current frame.
static func capture_current_frame(
	frame_idx: int,
	frame_delta_ms: float = 0.0,
	loaded_chunks_count: int = 0,
	cam_pos: Vector3 = Vector3.ZERO,
	underground: bool = false
) -> RefCounted:
	var dc = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	if dc <= 0:
		dc = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

	var prims = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	if prims <= 0:
		prims = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))

	var objs = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
	if objs <= 0:
		objs = int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))

	var proc_ms = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var phys_ms = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var current_fps = Performance.get_monitor(Performance.TIME_FPS)
	if current_fps <= 0.0:
		current_fps = float(Engine.get_frames_per_second())

	return new(
		frame_idx,
		dc,
		proc_ms,
		frame_delta_ms,
		phys_ms,
		prims,
		objs,
		loaded_chunks_count,
		cam_pos,
		underground,
		current_fps
	)

func to_dict() -> Dictionary:
	return {
		"frame_index": frame_index,
		"draw_calls": draw_calls,
		"process_time_ms": process_time_ms,
		"frame_delta_ms": frame_delta_ms,
		"physics_time_ms": physics_time_ms,
		"primitives": primitives,
		"objects_in_frame": objects_in_frame,
		"loaded_chunks": loaded_chunks,
		"camera_position": [camera_position.x, camera_position.y, camera_position.z],
		"is_underground": is_underground,
		"fps": fps
	}
