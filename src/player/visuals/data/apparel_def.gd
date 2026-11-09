class_name ApparelDef
extends Resource

## Data definition for a piece of modular apparel (shirt, vest, parka, hat, etc.).

enum Layer {
	ON_SKIN = 0,
	MIDDLE = 1,
	SHELL = 2,
	HEADGEAR = 3
}

@export var id: StringName = &""
@export var layer: Layer = Layer.ON_SKIN
@export var meshes_by_body_type: Dictionary = {} # StringName (BodyTypeDef.id) -> Mesh
@export var hides_body_parts: PackedStringArray = [] # e.g. ["Torso", "Head"]
@export var palette_mask: Texture2D

func get_mesh_for_body(body_id: StringName) -> Mesh:
	if meshes_by_body_type.has(body_id):
		return meshes_by_body_type[body_id] as Mesh
	if meshes_by_body_type.has(&"default"):
		return meshes_by_body_type[&"default"] as Mesh
	return null

