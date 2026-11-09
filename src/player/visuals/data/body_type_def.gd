class_name BodyTypeDef
extends Resource

## Data definition for a pawn body archetype (e.g. standard_male, female, hulk, fat, thin).

@export var id: StringName = &"fallback_pill"
@export var torso_mesh: Mesh
@export var neck_mount_offset: Vector3 = Vector3(0.0, 0.45, 0.0)
@export var scale_modifier: Vector3 = Vector3.ONE
@export var is_fallback: bool = false

