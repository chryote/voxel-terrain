class_name PaintStroke
extends RefCounted

## Immutable or recorded brush stroke used for undo/redo history,
## procedural road generation, and paint replication.

enum Mode {
	PAINT = 0,
	ERASE = 1,
	SMOOTH = 2,
	REPLACE = 3
}

var world_position: Vector3
var radius: float = 3.0
var strength: float = 0.5
var hardness: float = 0.5
var channel: int = 0
var mode: Mode = Mode.PAINT
var target_material_id: int = MaterialDef.ID_DIRT
var timestamp_ms: int = 0

func _init(
	p_pos: Vector3 = Vector3.ZERO,
	p_radius: float = 3.0,
	p_strength: float = 0.5,
	p_hardness: float = 0.5,
	p_channel: int = 0,
	p_mode: Mode = Mode.PAINT,
	p_mat_id: int = MaterialDef.ID_DIRT
) -> void:
	world_position = p_pos
	radius = p_radius
	strength = p_strength
	hardness = p_hardness
	channel = p_channel
	mode = p_mode
	target_material_id = p_mat_id
	timestamp_ms = Time.get_ticks_msec()

func to_dict() -> Dictionary:
	return {
		"x": world_position.x,
		"y": world_position.y,
		"z": world_position.z,
		"radius": radius,
		"strength": strength,
		"hardness": hardness,
		"channel": channel,
		"mode": mode,
		"material_id": target_material_id,
		"timestamp": timestamp_ms
	}

static func from_dict(d: Dictionary) -> PaintStroke:
	var stroke = PaintStroke.new(
		Vector3(d.get("x", 0.0), d.get("y", 0.0), d.get("z", 0.0)),
		d.get("radius", 3.0),
		d.get("strength", 0.5),
		d.get("hardness", 0.5),
		d.get("channel", 0),
		d.get("mode", Mode.PAINT),
		d.get("material_id", MaterialDef.ID_DIRT)
	)
	stroke.timestamp_ms = d.get("timestamp", 0)
	return stroke
