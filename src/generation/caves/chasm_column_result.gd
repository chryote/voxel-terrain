class_name ChasmColumnResult
extends RefCounted

## Value object representing the vertical span of a subterranean chasm at an (x, z) column.
## Designed to be allocated once and reused across sampling loops to eliminate GC pressure.

var is_chasm: bool = false
var floor_y: int = 0
var ceil_y: int = 0
var is_pillar: bool = false
var is_wall: bool = false
var is_arena: bool = false
var is_arena_ledge: bool = false
var is_basalt_column: bool = false
var raw_rift: float = 0.0

func reset() -> void:
	is_chasm = false
	floor_y = 0
	ceil_y = 0
	is_pillar = false
	is_wall = false
	is_arena = false
	is_arena_ledge = false
	is_basalt_column = false
	raw_rift = 0.0
