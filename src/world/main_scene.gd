class_name MainScene
extends Node3D

## Main scene manager: spawns player on continent surface and links HUD.

@onready var voxel_world: VoxelWorld = $VoxelWorld
@onready var player: PlayerMotor = $Player

const ContinentMapUIClass = preload("res://src/map/continent_map_ui.gd")

func _ready() -> void:
	var hud: PlayerHUD = player.get_node_or_null("CanvasLayer/PlayerHUD")
	if hud != null:
		hud.voxel_world = voxel_world

	var map_ui: ContinentMapUIClass = player.get_node_or_null("CanvasLayer/ContinentMapUI")
	if map_ui != null:
		map_ui.voxel_world = voxel_world

	# Position player on safe surface column
	var spawn_pos = voxel_world.get_spawn_point()
	player.global_position = spawn_pos
