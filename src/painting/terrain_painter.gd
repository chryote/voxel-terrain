class_name TerrainPainter
extends RefCounted

## High-level painting tool interface supporting continuous stroke interpolation,
## undo/redo command history, and discrete or continuous brush application.

const ChunkPaintManagerClass = preload("res://src/painting/chunk_paint_manager.gd")
const PaintStrokeClass = preload("res://src/painting/paint_stroke.gd")

var paint_manager: ChunkPaintManager

var brush_radius: float = 4.0
var brush_strength: float = 0.5
var brush_hardness: float = 0.5
var active_channel: int = 0
var mode: PaintStroke.Mode = PaintStroke.Mode.PAINT
var active_material_id: int = MaterialDef.ID_DIRT
var spacing_meters: float = 1.0

var _last_stroke_pos: Vector3 = Vector3(INF, INF, INF)
var _is_stroking: bool = false
var _undo_stack: Array[Dictionary] = [] # Snapshot of ChunkPaintManager state before stroke
var _redo_stack: Array[Dictionary] = []
var _max_undo_steps: int = 20

func _init(p_manager: ChunkPaintManager = null) -> void:
	paint_manager = p_manager if p_manager != null else ChunkPaintManagerClass.new()

func set_brush(radius: float, strength: float, hardness: float, channel: int, p_mode: PaintStroke.Mode = PaintStroke.Mode.PAINT) -> void:
	brush_radius = maxf(0.1, radius)
	brush_strength = clampf(strength, 0.0, 1.0)
	brush_hardness = clampf(hardness, 0.0, 1.0)
	active_channel = clampi(channel, 0, 3)
	mode = p_mode

func begin_stroke(world_pos: Vector3) -> Array[ChunkCoord]:
	_record_undo_state()
	_redo_stack.clear()
	_is_stroking = true
	_last_stroke_pos = world_pos
	return paint_manager.paint_world(world_pos, brush_radius, brush_strength, brush_hardness, active_channel, mode)

func stroke_to(target_pos: Vector3) -> Array[ChunkCoord]:
	if not _is_stroking:
		return begin_stroke(target_pos)

	var affected: Array[ChunkCoord] = []
	var dist = _last_stroke_pos.distance_to(target_pos)
	var step_size = maxf(0.5, spacing_meters)

	if dist < step_size:
		return affected

	var steps = int(floor(dist / step_size))
	var dir = (target_pos - _last_stroke_pos).normalized()

	for i in range(1, steps + 1):
		var p = _last_stroke_pos + dir * (float(i) * step_size)
		var chunks = paint_manager.paint_world(p, brush_radius, brush_strength, brush_hardness, active_channel, mode)
		for c in chunks:
			if not affected.has(c):
				affected.append(c)

	_last_stroke_pos = target_pos
	return affected

func end_stroke() -> void:
	_is_stroking = false
	_last_stroke_pos = Vector3(INF, INF, INF)

func _record_undo_state() -> void:
	if paint_manager == null:
		return
	if _undo_stack.size() >= _max_undo_steps:
		_undo_stack.pop_front()
	_undo_stack.append(paint_manager.export_paint_state())

func can_undo() -> bool:
	return not _undo_stack.is_empty()

func can_redo() -> bool:
	return not _redo_stack.is_empty()

func undo() -> bool:
	if not can_undo() or paint_manager == null:
		return false
	_redo_stack.append(paint_manager.export_paint_state())
	var prev_state = _undo_stack.pop_back()
	paint_manager.import_paint_state(prev_state)
	return true

func redo() -> bool:
	if not can_redo() or paint_manager == null:
		return false
	_undo_stack.append(paint_manager.export_paint_state())
	var next_state = _redo_stack.pop_back()
	paint_manager.import_paint_state(next_state)
	return true
