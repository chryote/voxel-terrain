class_name TestStreamingFrameOptimization
extends "res://tests/framework/test_case.gd"

## Unit tests validating the frame time (Proc) spike mitigations:
## 1. Defer/tune collision activation (collision_distance_chunks = 2)
## 2. Spread/stagger MultiMesh foliage buffer uploads
## 3. Time-sliced chunk boundary collision and distant LOD updates

func _create_sample_foliage_data() -> RefCounted:
	var FoliageDataClass = load("res://src/core/foliage_chunk_data.gd")
	var data = FoliageDataClass.new()
	data.instance_count = 10
	var buf = PackedFloat32Array()
	buf.resize(10 * 12)
	buf.fill(1.0)
	data.transform_buffer = buf

	data.bush_instance_count = 5
	var bush_buf = PackedFloat32Array()
	bush_buf.resize(5 * 12)
	bush_buf.fill(1.0)
	data.bush_transform_buffer = bush_buf
	return data

func _create_test_mesh_data() -> MeshData:
	var c_size = 8
	var data = SurfaceChunkData.new(c_size)
	data.fill(5, 1, 2)
	var reg = MaterialRegistry.create_default_registry()
	var mesher = SurfaceShellMesher.new()
	var mesh = mesher.build_mesh(data, reg)
	mesh.foliage_data = _create_sample_foliage_data()
	return mesh

func test_default_collision_distance_is_two() -> void:
	var cfg = WorldConfig.new()
	assert_eq(cfg.collision_distance_chunks, 2, "Default collision distance should be tuned to 2 chunks")

func test_chunk_node_deferred_foliage_upload() -> void:
	var node = ChunkNode.new()
	var coord = ChunkCoord.new(0, 0)
	var mesh_data = _create_test_mesh_data()

	# Setup with deferred foliage upload = true
	node.setup(coord, Vector3.ZERO, mesh_data, true, null, null, true, false, true)

	assert_true(node.has_pending_foliage_upload(), "ChunkNode must report pending foliage upload")
	assert_true(node.is_foliage_enabled(), "Foliage should be logically enabled")

	# Upload should complete and clear the dirty flag
	node.upload_foliage_buffers()
	assert_false(node.has_pending_foliage_upload(), "Pending foliage upload should be cleared after upload")
	assert_eq(node.grass_instance.multimesh.instance_count, 10, "Grass MultiMesh instance count must match foliage data")
	assert_eq(node.bush_instance.multimesh.instance_count, 5, "Bush MultiMesh instance count must match bush data")

	node.free()

func test_voxel_world_staggered_foliage_uploads() -> void:
	var world = VoxelWorld.new()
	world.world_config = WorldConfig.new()
	world.world_config.max_mesh_apply_budget_ms = 100.0
	world.bounds = world.world_config.create_world_bounds()
	world.generator = ContinentGenerator.new(1337)
	world.mesher = SurfaceShellMesher.new()
	world.material_registry = MaterialRegistry.create_default_registry()
	world.scheduler = ChunkScheduler.new()
	world.streamer = ChunkStreamer.new()

	var chunks_root = Node3D.new()
	world.add_child(chunks_root)
	world._chunks_root = chunks_root

	var mesh_data = _create_test_mesh_data()
	var baker = OffThreadCollisionBaker.new()
	var shapes = baker.bake_shapes_for_bundle(mesh_data)

	# Ingest 4 chunks with foliage
	for i in range(4):
		world._pending_completed_chunks.append({
			"phase": ChunkScheduler.GenerationPhase.PHASE_SURFACE,
			"coord": ChunkCoord.new(i, 0),
			"data": null,
			"mesh_data": mesh_data,
			"surface_shape": shapes.surface_shape,
			"cave_shape": null,
			"has_cave_mouth": false
		})

	world._process_completed_chunks()

	# All 4 chunks should be registered in _pending_foliage_uploads
	assert_eq(world._pending_foliage_uploads.size(), 4, "All 4 chunks should have pending foliage uploads queued")

	# Process 2 foliage uploads (max_foliage_uploads_per_frame = 2)
	world.max_foliage_uploads_per_frame = 2
	world._process_pending_foliage_uploads()

	assert_eq(world._pending_foliage_uploads.size(), 2, "2 chunks should remain in foliage upload queue")

	# Process remaining 2
	world._process_pending_foliage_uploads()
	assert_eq(world._pending_foliage_uploads.size(), 0, "Foliage upload queue should now be empty")

	world.free()

func test_chunk_collision_boundary_time_slicing() -> void:
	var world = VoxelWorld.new()
	world.world_config = WorldConfig.new()
	world.world_config.collision_distance_chunks = 2
	world.bounds = world.world_config.create_world_bounds()

	var focus_dummy = Node3D.new()
	focus_dummy.position = Vector3(0.0, 10.0, 0.0)
	world.focus_target = focus_dummy

	var mesh_data = _create_test_mesh_data()
	var baker = OffThreadCollisionBaker.new()
	var shapes = baker.bake_shapes_for_bundle(mesh_data)

	# Create 40 chunk nodes: 9 near chunks (dist <= 1) and 31 distant chunks (dist >= 3)
	var near_nodes: Array[ChunkNode] = []
	var distant_nodes: Array[ChunkNode] = []

	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var c = ChunkCoord.new(dx, dz)
			var node = ChunkNode.new()
			node.setup(c, Vector3.ZERO, mesh_data, false, shapes.surface_shape, null)
			world._loaded_chunks[c.to_key()] = node
			near_nodes.append(node)

	for i in range(31):
		var c = ChunkCoord.new(4 + (i % 6), 4 + int(float(i) / 6.0))
		var node = ChunkNode.new()
		node.setup(c, Vector3.ZERO, mesh_data, false, shapes.surface_shape, null)
		world._loaded_chunks[c.to_key()] = node
		distant_nodes.append(node)

	assert_eq(world.get_loaded_chunk_count(), 40, "Total loaded chunks should be 40 (> 32 to trigger time-slicing)")

	# Force collision update with player at (0, 0)
	world._update_chunk_collisions()

	# Near chunks (dist <= 2) must be immediately enabled without delay
	for node in near_nodes:
		assert_true(node.is_collision_enabled(), "Near chunk within collision distance must be immediately enabled")

	# Distant chunks must be queued into _pending_collision_updates for slice processing
	assert_true(world._pending_collision_updates.size() > 0, "Distant chunks should be queued for sliced updates")

	focus_dummy.free()
	for n in near_nodes:
		n.free()
	for n in distant_nodes:
		n.free()
	world.free()

func test_player_hud_fps_cap_modifier() -> void:
	var hud = PlayerHUD.new()
	hud._ready()

	# Default should be 120 FPS
	assert_eq(Engine.max_fps, 120, "HUD default max_fps should be 120")

	hud._update_debug_text()
	assert_true(hud._debug_label.text.contains("[Cap: 120]"), "Debug text should display [Cap: 120]")
	assert_true(hud._debug_label.text.contains("F6: Cap FPS"), "Debug text controls should list F6: Cap FPS")

	# Cycle 1: 120 -> 165
	var cap = hud.cycle_fps_cap()
	assert_eq(cap, 165, "First cycle should advance to 165 FPS")
	assert_eq(Engine.max_fps, 165, "Engine.max_fps should be 165")
	assert_true(hud._status_banner.visible, "Status banner should show on cycle")
	assert_true(hud._status_banner.text.contains("165 FPS"), "Banner should display 165 FPS")

	# Cycle 2: 165 -> 0 (Uncapped)
	cap = hud.cycle_fps_cap()
	assert_eq(cap, 0, "Second cycle should advance to 0 (Uncapped)")
	assert_eq(Engine.max_fps, 0, "Engine.max_fps should be 0")
	assert_true(hud._status_banner.text.contains("Uncapped"), "Banner should display Uncapped")

	hud._update_debug_text()
	assert_true(hud._debug_label.text.contains("[Uncapped]"), "Debug text should show [Uncapped]")

	# Cycle 3: 0 -> 60
	cap = hud.cycle_fps_cap()
	assert_eq(cap, 60, "Third cycle should advance to 60 FPS")
	assert_eq(Engine.max_fps, 60, "Engine.max_fps should be 60")

	# Cycle 4: 60 -> 120
	cap = hud.cycle_fps_cap()
	assert_eq(cap, 120, "Fourth cycle should return to 120 FPS")
	assert_eq(Engine.max_fps, 120, "Engine.max_fps should be 120")

	# Test F6 simulated key event
	var event = InputEventKey.new()
	event.keycode = KEY_F6
	event.pressed = true
	event.echo = false
	hud._unhandled_input(event)
	assert_eq(Engine.max_fps, 165, "F6 key press via _unhandled_input should advance FPS cap to 165")

	# Reset engine max_fps to clean up
	hud.set_fps_cap(120)
	assert_eq(Engine.max_fps, 120, "set_fps_cap(120) should set engine max_fps back to 120")

	hud.free()

