class_name HeadTypeDef
extends Resource

## Data definition for a pawn head archetype (e.g. average_male, narrow, broad).

@export var id: StringName = &"default_head"
@export var head_mesh: Mesh
@export var hair_mount_offset: Vector3 = Vector3(0.0, 0.25, 0.0)
@export var face_textures: Dictionary = {}

