class_name TestPlayerSpawnToggle
extends "res://tests/framework/test_case.gd"

## Unit tests verifying toggleable player spawn (Surface vs Underground) and F4 debug binding.

func test_spawn_point_surface_vs_underground() -> void:
	var world = VoxelWorld.new()
	world.world_config = WorldConfig.new()
	world.world_config.map_size_chunks = Vector2i(256, 256)
	world.world_config.chunk_size = 16
	world.world_config.view_distance_chunks = 0
	world.world_config.collision_distance_chunks = 1
	world.caves_enabled = true
	world.spawn_on_underground_arena = false

	world._ready()

	var surface_spawn = world.get_surface_spawn_point()
	var underground_spawn = world.get_underground_spawn_point()

	assert_ne(surface_spawn, Vector3.ZERO, "Surface spawn point must not be zero")
	assert_ne(underground_spawn, Vector3.ZERO, "Underground spawn point must not be zero")
	assert_ne(surface_spawn, underground_spawn, "Surface and underground spawn points must be distinct")

	# Surface spawn should be higher up than subterranean arena floor
	assert_true(surface_spawn.y > underground_spawn.y, "Surface spawn Y should be higher than underground arena floor")

	# With spawn_on_underground_arena = false, get_spawn_point must return surface spawn
	assert_eq(world.get_spawn_point(), surface_spawn, "get_spawn_point() must return surface spawn when toggle is false")

	# When toggle is true, get_spawn_point must return underground spawn
	world.spawn_on_underground_arena = true
	assert_eq(world.get_spawn_point(), underground_spawn, "get_spawn_point() must return underground spawn when toggle is true")

	if world.scheduler != null:
		world.scheduler.clear()
	world.free()


func test_toggle_spawn_location_and_teleport() -> void:
	var world = VoxelWorld.new()
	world.world_config = WorldConfig.new()
	world.world_config.map_size_chunks = Vector2i(256, 256)
	world.world_config.chunk_size = 16
	world.world_config.view_distance_chunks = 0
	world.world_config.collision_distance_chunks = 1
	world.caves_enabled = true
	world.spawn_on_underground_arena = false

	var player_dummy = CharacterBody3D.new()
	world.add_child(player_dummy)
	world.focus_target = player_dummy

	world._ready()

	var surface_spawn = world.get_surface_spawn_point()
	var underground_spawn = world.get_underground_spawn_point()

	assert_almost_eq(player_dummy.position.x, surface_spawn.x, 0.1, "Player dummy should start at surface spawn X")
	assert_almost_eq(player_dummy.position.y, surface_spawn.y, 0.1, "Player dummy should start at surface spawn Y")

	# Track signal emission
	var signal_data = {"received": false, "is_underground": false, "pos": Vector3.ZERO}
	world.spawn_mode_changed.connect(func(is_underground: bool, pos: Vector3):
		signal_data["received"] = true
		signal_data["is_underground"] = is_underground
		signal_data["pos"] = pos
	)

	player_dummy.velocity = Vector3(10.0, -15.0, 5.0)

	# Toggle from Surface -> Underground
	var new_pos = world.toggle_spawn_location()
	assert_true(world.spawn_on_underground_arena, "Spawn mode must be underground after toggle")
	assert_eq(new_pos, underground_spawn, "Toggle return value must match underground spawn")
	assert_true(signal_data["received"], "spawn_mode_changed signal must be emitted")
	assert_true(signal_data["is_underground"], "Signal must indicate underground mode")
	assert_eq(signal_data["pos"], underground_spawn, "Signal pos must match underground spawn")
	assert_almost_eq(player_dummy.position.y, underground_spawn.y, 0.1, "Player dummy must be teleported to underground spawn")
	assert_eq(player_dummy.velocity, Vector3.ZERO, "Player dummy velocity must be reset to zero on teleport")

	# Ensure chunk at underground spawn is loaded and collision enabled
	var ug_chunk = world.bounds.world_to_chunk(underground_spawn)
	var chunk_node = world._loaded_chunks.get(ug_chunk.to_key(), null) as ChunkNode
	assert_not_null(chunk_node, "Underground chunk node must exist after teleport")
	assert_true(chunk_node.is_collision_enabled(), "Underground chunk collision must be enabled")

	# Toggle back from Underground -> Surface
	signal_data["received"] = false
	new_pos = world.toggle_spawn_location()
	assert_false(world.spawn_on_underground_arena, "Spawn mode must be surface after second toggle")
	assert_eq(new_pos, surface_spawn, "Toggle return value must match surface spawn")
	assert_true(signal_data["received"], "spawn_mode_changed signal must be emitted on second toggle")
	assert_false(signal_data["is_underground"], "Signal must indicate surface mode")
	assert_almost_eq(player_dummy.position.y, surface_spawn.y, 0.1, "Player dummy must be teleported back to surface spawn")

	if world.scheduler != null:
		world.scheduler.clear()
	world.free()


func test_f4_unhandled_input_handling() -> void:
	var world = VoxelWorld.new()
	world.world_config = WorldConfig.new()
	world.world_config.map_size_chunks = Vector2i(256, 256)
	world.world_config.chunk_size = 16
	world.world_config.view_distance_chunks = 0
	world.world_config.collision_distance_chunks = 1
	world.caves_enabled = true
	world.spawn_on_underground_arena = false

	world._ready()
	assert_false(world.spawn_on_underground_arena, "Initial spawn mode should be surface")

	# Simulate F4 key event
	var event = InputEventKey.new()
	event.keycode = KEY_F4
	event.pressed = true
	event.echo = false

	world._unhandled_input(event)
	assert_true(world.spawn_on_underground_arena, "F4 press must toggle spawn mode to underground")

	# Press F4 again
	world._unhandled_input(event)
	assert_false(world.spawn_on_underground_arena, "Second F4 press must toggle spawn mode back to surface")

	if world.scheduler != null:
		world.scheduler.clear()
	world.free()


func test_player_intent_and_input_toggle_spawn() -> void:
	var intent = PlayerIntent.new()
	assert_false(intent.toggle_spawn_requested, "Initial toggle_spawn_requested should be false")

	intent.toggle_spawn_requested = true
	assert_true(intent.toggle_spawn_requested, "toggle_spawn_requested can be set to true")

	intent.reset()
	assert_false(intent.toggle_spawn_requested, "reset() must clear toggle_spawn_requested to false")


func test_player_hud_spawn_display_and_signal() -> void:
	var hud = PlayerHUD.new()
	var world = VoxelWorld.new()
	world.world_config = WorldConfig.new()
	world.world_config.map_size_chunks = Vector2i(256, 256)
	world.world_config.chunk_size = 16
	world.world_config.view_distance_chunks = 0
	world.world_config.collision_distance_chunks = 1
	world.spawn_on_underground_arena = true

	hud.voxel_world = world
	hud._ready()

	hud._update_debug_text()
	assert_true(hud._debug_label.text.contains("Spawn: Underground Arena [F4 to toggle]"), "Debug text must show Underground Arena")
	assert_true(hud._debug_label.text.contains("F4: Toggle Spawn"), "Debug text controls must list F4: Toggle Spawn")

	# Toggle world and verify HUD text reflects Surface
	world.spawn_on_underground_arena = false
	hud._update_debug_text()
	assert_true(hud._debug_label.text.contains("Spawn: Surface [F4 to toggle]"), "Debug text must show Surface after mode toggle")

	# Trigger spawn_mode_changed signal and verify status banner
	world.spawn_mode_changed.emit(true, Vector3(100.0, 12.0, -50.0))
	assert_true(hud._status_banner.visible, "Status banner must be visible after spawn_mode_changed signal")
	assert_true(hud._status_banner.text.contains("[F4] Spawn Mode: Underground Arena"), "Banner must announce toggled spawn mode")

	if world.scheduler != null:
		world.scheduler.clear()
	world.free()
	hud.free()
