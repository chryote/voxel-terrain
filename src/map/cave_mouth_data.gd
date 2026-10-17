class_name CaveMouthData
extends RefCounted

## Value object representing a discrete surface cave mouth discovered on the continent map.
## Carries its geographic world position, projected map coordinate, and classified cave type.

enum Type {
	DEAD_END = 0,    ## Shallow dead-end cave with no subterranean connection (Red font)
	TUNNEL = 1,      ## Cave mouth opening into an interconnected 3D worm tunnel network (Yellow font)
	CHASM = 2        ## Cave mouth descending or leading into a deep underground chasm void (Green font)
}

const COLOR_DEAD_END: Color = Color(0.96, 0.22, 0.22, 1.0) # Vivid Red
const COLOR_TUNNEL: Color = Color(0.98, 0.86, 0.12, 1.0)   # Bright Golden Yellow
const COLOR_CHASM: Color = Color(0.22, 0.96, 0.38, 1.0)    # Vivid Emerald Green

var world_pos: Vector3 = Vector3.ZERO
var map_pixel: Vector2 = Vector2.ZERO
var type: Type = Type.DEAD_END
var depth: float = 0.0
var radius: float = 0.0
var surface_elevation: float = 0.0

func _init(
	p_world_pos: Vector3 = Vector3.ZERO,
	p_map_pixel: Vector2 = Vector2.ZERO,
	p_type: Type = Type.DEAD_END,
	p_depth: float = 0.0,
	p_radius: float = 0.0,
	p_surface_elevation: float = 0.0
) -> void:
	world_pos = p_world_pos
	map_pixel = p_map_pixel
	type = p_type
	depth = p_depth
	radius = p_radius
	surface_elevation = p_surface_elevation

static func get_type_name(t: Type) -> String:
	match t:
		Type.DEAD_END:
			return "Dead Cave"
		Type.TUNNEL:
			return "Tunnel Cave"
		Type.CHASM:
			return "Chasm Cave"
	return "Cave"

static func get_type_color(t: Type) -> Color:
	match t:
		Type.DEAD_END:
			return COLOR_DEAD_END
		Type.TUNNEL:
			return COLOR_TUNNEL
		Type.CHASM:
			return COLOR_CHASM
	return Color.WHITE
