class_name MainScene
extends Node3D

## Main scene manager: spawns player on continent surface and links HUD.

@onready var voxel_world: VoxelWorld = $VoxelWorld
@onready var player: PlayerMotor = $Player
@onready var atmosphere_controller = $SubterraneanAtmosphereController

const ContinentMapUIClass = preload("res://src/map/continent_map_ui.gd")
const SubterraneanAtmosphereControllerClass = preload("res://src/rendering/subterranean_atmosphere_controller.gd")

func _ready() -> void:
	var hud: PlayerHUD = player.get_node_or_null("CanvasLayer/PlayerHUD")
	if hud != null:
		hud.voxel_world = voxel_world

	var map_ui: ContinentMapUIClass = player.get_node_or_null("CanvasLayer/ContinentMapUI")
	if map_ui != null:
		map_ui.voxel_world = voxel_world

	if atmosphere_controller != null:
		var ash_emitter = player.get_node_or_null("AshFallEmitter") as GPUParticles3D
		if ash_emitter != null:
			atmosphere_controller.ash_emitter = ash_emitter
		var rot_fog = player.get_node_or_null("RotFogVolume") as FogVolume
		if rot_fog != null:
			atmosphere_controller.rot_fog_volume = rot_fog
		var start_ug = voxel_world.spawn_on_underground_arena and voxel_world.caves_enabled
		atmosphere_controller.set_underground_mode(start_ug, true)

	# Position player on active spawn point (surface or underground arena)
	var spawn_pos = voxel_world.get_spawn_point()
	player.global_position = spawn_pos
