class_name VoxelWorld
extends Node3D

## Composition root for voxel terrain streaming, meshing, and physics.

signal chunk_loaded(coord: ChunkCoord)
signal chunk_unloaded(coord: ChunkCoord)
signal initial_area_ready()
signal spawn_mode_changed(is_underground: bool, spawn_position: Vector3)

@export var world_config: WorldConfig
@export var generator_config: ContinentGeneratorConfig
@export var cave_config: CaveGeneratorConfig
@export var material_registry: MaterialRegistry
@export var terrain_theme: Resource = null
@export var focus_target: Node3D
@export var spawn_on_underground_arena: bool = true
@export var caves_enabled: bool = true:
	set(val):
		caves_enabled = val
		if cave_config != null:
			cave_config.enabled = val
		if subterranean_coordinator != null:
			subterranean_coordinator.enabled = val
		if not is_inside_tree():
			return
		if not caves_enabled:
			for node in _loaded_chunks.values():
				if node is ChunkNode and node.is_subterranean_visible():
					node.set_subterranean_visible(false)
@export var cave_water_enabled: bool = false:
	set(val):
		cave_water_enabled = val
		if cave_config != null:
			cave_config.cave_water_enabled = val
		if mesher != null and "cave_water_enabled" in mesher:
			mesher.cave_water_enabled = val
		if not is_inside_tree():
			return
		for node in _loaded_chunks.values():
			if node is ChunkNode and node.cave_water_instance != null:
				node.cave_water_instance.visible = val and node.is_subterranean_visible()

@export var foliage_enabled: bool = true:
	set(val):
		foliage_enabled = val
		if scheduler != null:
			scheduler.foliage_enabled = val
		_update_chunk_collisions(true)
@export var foliage_distance_chunks: int = 2: ## Chunk distance for high-detail foliage
	set(val):
		foliage_distance_chunks = val
		_update_chunk_collisions(true)
@export var foliage_max_distance_chunks: int = 8: ## Maximum chunk distance past near distance rendered with lowest detail
	set(val):
		foliage_max_distance_chunks = maxi(val, foliage_distance_chunks)
		_sync_foliage_fade_distance()
		_update_chunk_collisions(true)
@export var foliage_lod_density: float = 0.25: ## Subsampling density ratio for distant lowest-detail chunks
	set(val):
		foliage_lod_density = clampf(val, 0.05, 1.0)
		ChunkNode.set_shared_lod_density(foliage_lod_density)
		_update_chunk_collisions(true)
@export var foliage_generator_config: Resource = null
@export var foliage_theme: Resource = null

const SpawnFinder = preload("res://src/world/spawn_finder.gd")

var bounds: WorldBounds
var generator: TerrainGenerator
var mesher: Mesher
var streamer: ChunkStreamer
var scheduler: ChunkScheduler
var _spawn_finder: SpawnFinder = SpawnFinder.new()

var water_plane: WaterPlane
var world_boundary: WorldBoundary
var _chunks_root: Node3D

var _loaded_chunks: Dictionary = {} # key -> ChunkNode
var _initial_ready_emitted: bool = false
var _last_collision_chunk: ChunkCoord = null
var _last_streaming_chunk: ChunkCoord = null
var _last_streaming_position: Vector3 = Vector3(INF, INF, INF)
var _last_was_subterranean: bool = false
@export var streaming_recheck_distance_meters: float = 4.0
var visibility_coordinator: LayerVisibilityCoordinator = LayerVisibilityCoordinator.new()
var subterranean_coordinator: SubterraneanStreamCoordinator = SubterraneanStreamCoordinator.new()
var _mouth_cache: Dictionary = {} # key -> bool
var _pending_completed_chunks: Array[Dictionary] = []
var _chunk_node_pool: Array[ChunkNode] = []

func _acquire_chunk_node(coord: ChunkCoord) -> ChunkNode:
	var chunk_node: ChunkNode
	if not _chunk_node_pool.is_empty():
		chunk_node = _chunk_node_pool.pop_back()
		chunk_node.name = "Chunk_%d_%d" % [coord.x, coord.z]
		chunk_node.visible = true
	else:
		chunk_node = ChunkNode.new()
		chunk_node.name = "Chunk_%d_%d" % [coord.x, coord.z]
		_chunks_root.add_child(chunk_node)
	return chunk_node

func _recycle_chunk_node(chunk_node: ChunkNode) -> void:
	if not is_instance_valid(chunk_node):
		return
	chunk_node.prepare_for_pool()
	_chunk_node_pool.push_back(chunk_node)

func _cleanup_chunk_pool() -> void:
	for node in _chunk_node_pool:
		if is_instance_valid(node):
			node.queue_free()
	_chunk_node_pool.clear()


func _apply_terrain_theme() -> void:
	var theme_to_use = terrain_theme
	if theme_to_use == null and ResourceLoader.exists("res://config/ascii_terrain_theme.tres"):
		theme_to_use = load("res://config/ascii_terrain_theme.tres")
	if theme_to_use != null:
		var ProviderClass = preload("res://src/rendering/terrain_material_provider.gd")
		var surf_mat = ProviderClass.get_surface_material(theme_to_use)
		var cave_mat = ProviderClass.get_cave_material(theme_to_use)
		ChunkNode.configure_shared_materials(surf_mat, cave_mat)

func _ready() -> void:
	_apply_terrain_theme()
	if world_config == null:
		world_config = WorldConfig.new()
	if generator_config == null:
		generator_config = ContinentGeneratorConfig.new()
	if cave_config == null:
		cave_config = CaveGeneratorConfig.new()
	if material_registry == null:
		material_registry = MaterialRegistry.create_default_registry()

	# Synchronize caves_enabled master switch across configs and coordinators
	if not world_config.caves_enabled:
		caves_enabled = false
	cave_config.enabled = caves_enabled
	subterranean_coordinator.enabled = caves_enabled

	if not world_config.cave_water_enabled:
		cave_water_enabled = false
	cave_config.cave_water_enabled = cave_water_enabled

	bounds = world_config.create_world_bounds()
	if generator == null:
		generator = VolumetricTerrainGenerator.new(world_config.world_seed, generator_config, cave_config)
	if "cave_carver" in generator and generator.cave_carver != null:
		if "continent_gen" in generator and generator.continent_gen != null and generator.continent_gen.mask != null:
			generator.cave_carver.set_continent_mask(generator.continent_gen.mask, bounds)
	if generator is LayeredTerrainGenerator:
		generator.init_cave_mouths(bounds)
		if generator.cave_carver != null and generator.cave_carver.worm_registry != null:
			subterranean_coordinator.worm_registry = generator.cave_carver.worm_registry
	if mesher == null:
		var voxel_mesher = VoxelMesher.new()
		voxel_mesher.sea_level = world_config.sea_level
		voxel_mesher.cave_water_enabled = cave_water_enabled
		mesher = voxel_mesher
	elif "cave_water_enabled" in mesher:
		mesher.cave_water_enabled = cave_water_enabled
	streamer = ChunkStreamer.new()
	scheduler = ChunkScheduler.new()
	scheduler.foliage_enabled = foliage_enabled
	if foliage_generator_config != null:
		scheduler.foliage_config = foliage_generator_config
	elif ResourceLoader.exists("res://config/default_foliage_generator.tres"):
		scheduler.foliage_config = load("res://config/default_foliage_generator.tres")

	var fol_theme = foliage_theme
	if fol_theme == null and ResourceLoader.exists("res://config/foliage_config.tres"):
		fol_theme = load("res://config/foliage_config.tres")
	ChunkNode.set_shared_lod_density(foliage_lod_density)
	if fol_theme != null:
		var ProviderClass = preload("res://src/rendering/terrain_material_provider.gd")
		ChunkNode.configure_shared_materials(
			ChunkNode.get_shared_surface_material(),
			ChunkNode.get_shared_cave_material(),
			ChunkNode.get_shared_water_material(),
			ChunkNode.get_shared_subterranean_water_material(),
			ProviderClass.get_grass_material(fol_theme),
			ChunkNode.get_shared_grass_mesh(),
			ChunkNode.get_shared_grass_mesh_lod()
		)
		_sync_foliage_fade_distance()

	_chunks_root = Node3D.new()
	_chunks_root.name = "Chunks"
	add_child(_chunks_root)

	world_boundary = WorldBoundary.new()
	world_boundary.name = "Boundary"
	add_child(world_boundary)
	world_boundary.setup(bounds)

	water_plane = WaterPlane.new()
	water_plane.name = "WaterPlane"
	add_child(water_plane)
	water_plane.setup(bounds, float(world_config.sea_level) * world_config.voxel_size)

	# Synchronously pre-load spawn chunk and 3x3 neighborhood so collision exists before frame 0 physics
	var spawn_pos = get_spawn_point()
	var spawn_chunk = bounds.world_to_chunk(spawn_pos)
	if is_instance_valid(focus_target):
		if focus_target.is_inside_tree():
			focus_target.global_position = spawn_pos
		else:
			focus_target.position = spawn_pos

	for dz in range(-1, 2):
		for dx in range(-1, 2):
			_load_chunk_sync(ChunkCoord.new(spawn_chunk.x + dx, spawn_chunk.z + dz))

	_initial_ready_emitted = true
	initial_area_ready.emit()

	_update_streaming(true)
	_update_layer_visibility(true)
	_update_chunk_collisions(true)

func _process(_delta: float) -> void:
	_process_completed_chunks()
	_update_streaming()
	_update_chunk_collisions()
	_update_layer_visibility()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if scheduler != null:
			scheduler.clear()
		_pending_completed_chunks.clear()
		_cleanup_chunk_pool()
		_last_streaming_chunk = null
		_last_streaming_position = Vector3(INF, INF, INF)
		_last_was_subterranean = false

func _exit_tree() -> void:
	if scheduler != null:
		scheduler.clear()
	_pending_completed_chunks.clear()
	_cleanup_chunk_pool()
	_last_streaming_chunk = null
	_last_streaming_position = Vector3(INF, INF, INF)
	_last_was_subterranean = false

var _spawn_point: Vector3 = Vector3.ZERO
var _spawn_point_cached: bool = false
var _surface_spawn_point: Vector3 = Vector3.ZERO
var _surface_spawn_cached: bool = false
var _underground_spawn_point: Vector3 = Vector3.ZERO
var _underground_spawn_cached: bool = false

func _get_focus_position() -> Vector3:
	if is_instance_valid(focus_target):
		if focus_target.is_inside_tree():
			return focus_target.global_position
		return focus_target.position
	if _spawn_point_cached:
		return _spawn_point
	return Vector3.ZERO

func _get_focus_forward() -> Vector3:
	if is_inside_tree() and get_viewport() != null:
		var cam = get_viewport().get_camera_3d()
		if is_instance_valid(cam):
			return -cam.global_transform.basis.z.normalized()
	if is_instance_valid(focus_target):
		var rig = focus_target.camera_rig if ("camera_rig" in focus_target) else focus_target.get_node_or_null("camera_rig")
		if is_instance_valid(rig):
			var cam = rig.camera if ("camera" in rig) else rig.get_node_or_null("camera")
			if is_instance_valid(cam):
				if cam.is_inside_tree():
					return -cam.global_transform.basis.z.normalized()
				return -cam.transform.basis.z.normalized()
			if rig.has_method("get_camera_yaw"):
				var yaw = rig.get_camera_yaw()
				return -Vector3(sin(yaw), 0.0, cos(yaw)).normalized()
			if rig.is_inside_tree():
				return -rig.global_transform.basis.z.normalized()
			return -rig.transform.basis.z.normalized()
		if focus_target.is_inside_tree():
			return -focus_target.global_transform.basis.z.normalized()
		return -focus_target.transform.basis.z.normalized()
	return Vector3.FORWARD


func _load_chunk_sync(coord: ChunkCoord) -> void:
	if not bounds.contains_chunk(coord):
		return
	var key = coord.to_key()
	if _loaded_chunks.has(key):
		return

	var chunk_data = generator.generate(coord, bounds)
	var mesh_data = mesher.build_mesh(chunk_data, material_registry)
	if foliage_enabled:
		var s_data: SurfaceChunkData = chunk_data as SurfaceChunkData
		if s_data == null and "surface_data" in chunk_data:
			s_data = chunk_data.surface_data as SurfaceChunkData
		if s_data != null and scheduler != null and scheduler._foliage_generator != null:
			mesh_data.foliage_data = scheduler._foliage_generator.generate(coord, chunk_data, scheduler.foliage_config)

	var chunk_node = _acquire_chunk_node(coord)
	_loaded_chunks[key] = chunk_node

	var origin = bounds.chunk_origin(coord)
	var baker = OffThreadCollisionBaker.new()
	var shapes = baker.bake_shapes_for_bundle(mesh_data)
	var focus_chunk_sync = bounds.world_to_chunk(_get_focus_position())
	var dist_sync = focus_chunk_sync.chebyshev_distance_to(coord)
	var enable_fol_sync = foliage_enabled and (dist_sync <= foliage_max_distance_chunks)
	var is_low_detail_sync = (dist_sync > foliage_distance_chunks)
	chunk_node.setup(coord, origin, mesh_data, true, shapes.surface_shape, shapes.cave_shape, enable_fol_sync, is_low_detail_sync)
	_mouth_cache[key] = chunk_node.has_cave_mouth
	subterranean_coordinator.register_surface_chunk(coord, chunk_node.has_cave_mouth)
	subterranean_coordinator.mark_subterranean_ready(coord)
	chunk_loaded.emit(coord)

func _process_completed_chunks() -> void:
	var focus_pos = _get_focus_position()
	var focus_chunk = bounds.world_to_chunk(focus_pos)

	var max_poll = world_config.max_mesh_applies_per_frame if world_config != null else 4
	var completed = scheduler.poll_completed(max_poll)
	if not completed.is_empty():
		_pending_completed_chunks.append_array(completed)

	if _pending_completed_chunks.is_empty():
		return

	var budget_ms = world_config.max_mesh_apply_budget_ms if world_config != null else 1.0
	var budget_usec = int(budget_ms * 1000.0)
	var start_time_usec = Time.get_ticks_usec()
	var needs_visibility_update = false
	var chunks_processed = 0

	while not _pending_completed_chunks.is_empty():
		var item = _pending_completed_chunks.pop_front()
		chunks_processed += 1
		var coord: ChunkCoord = item.coord
		var mesh_data: MeshData = item.mesh_data
		var key = coord.to_key()
		var phase: int = item.get("phase", ChunkScheduler.GenerationPhase.PHASE_FULL)

		if phase == ChunkScheduler.GenerationPhase.PHASE_SUBTERRANEAN:
			if _loaded_chunks.has(key):
				var node: ChunkNode = _loaded_chunks[key]
				var cave_shape = item.get("cave_shape", null)
				node.apply_subterranean_bundle(mesh_data, cave_shape)
				_mouth_cache[key] = node.has_cave_mouth
				subterranean_coordinator.mark_subterranean_ready(coord)
				if visibility_coordinator.last_state == LayerVisibilityCoordinator.PlayerLayerState.SUBTERRANEAN:
					node.set_subterranean_visible(true)
				needs_visibility_update = true
			if chunks_processed >= 1 and (Time.get_ticks_usec() - start_time_usec) >= budget_usec:
				break
			continue

		var dist_to_focus = focus_chunk.chebyshev_distance_to(coord)
		var enable_collision = (dist_to_focus <= world_config.collision_distance_chunks)
		var enable_foliage = foliage_enabled and (dist_to_focus <= foliage_max_distance_chunks)
		var is_low_detail = (dist_to_focus > foliage_distance_chunks)

		var chunk_node: ChunkNode
		if _loaded_chunks.has(key):
			chunk_node = _loaded_chunks[key]
		else:
			chunk_node = _acquire_chunk_node(coord)
			_loaded_chunks[key] = chunk_node

		var origin = bounds.chunk_origin(coord)
		var surf_shape = item.get("surface_shape", null)
		var cave_shape = item.get("cave_shape", null)
		chunk_node.setup(coord, origin, mesh_data, enable_collision, surf_shape, cave_shape, enable_foliage, is_low_detail)
		_mouth_cache[key] = chunk_node.has_cave_mouth

		var s_data = item.get("data", null) as SurfaceChunkData
		subterranean_coordinator.register_surface_chunk(coord, chunk_node.has_cave_mouth, s_data)

		if phase == ChunkScheduler.GenerationPhase.PHASE_FULL:
			subterranean_coordinator.mark_subterranean_ready(coord)
		elif chunk_node.has_cave_mouth and caves_enabled:
			scheduler.schedule_subterranean_chunk(coord, bounds, generator, mesher, material_registry, s_data, true)
			subterranean_coordinator.mark_subterranean_queued(coord)

		chunk_loaded.emit(coord)

		# Guarantee at least 1 chunk per frame is processed, but stop if budget is exceeded
		if chunks_processed >= 1 and (Time.get_ticks_usec() - start_time_usec) >= budget_usec:
			break

	if needs_visibility_update:
		_update_layer_visibility(true)

func _update_streaming(force: bool = false) -> void:
	var focus_pos = _get_focus_position()
	var focus_chunk = bounds.world_to_chunk(focus_pos)
	var surf_h = get_height_at(focus_pos.x, focus_pos.z)
	var is_player_subterranean = (focus_pos.y < (surf_h - 4.0)) or (focus_pos.y <= 12.0)

	var chunk_changed = (_last_streaming_chunk == null or not focus_chunk.equals(_last_streaming_chunk))
	var pos_delta_sq = focus_pos.distance_squared_to(_last_streaming_position)
	var pos_threshold_sq = streaming_recheck_distance_meters * streaming_recheck_distance_meters
	var pos_changed = (pos_delta_sq >= pos_threshold_sq)
	var sub_state_changed = (is_player_subterranean != _last_was_subterranean)

	if not force and not chunk_changed and not pos_changed and not sub_state_changed:
		return

	_last_streaming_chunk = focus_chunk
	_last_streaming_position = focus_pos
	_last_was_subterranean = is_player_subterranean

	# 1. Enqueue new chunks to load (Phase A surface-first)
	var to_load = streamer.get_chunks_to_load(
		focus_chunk,
		_loaded_chunks,
		world_config.view_distance_chunks,
		bounds
	)

	for coord in to_load:
		if not scheduler.is_chunk_in_flight(coord):
			if is_player_subterranean and caves_enabled:
				scheduler.schedule_chunk(coord, bounds, generator, mesher, material_registry)
			else:
				scheduler.schedule_surface_chunk(coord, bounds, generator, mesher, material_registry)

	# 2. Demand-driven subterranean promotion for surface-only chunks
	if caves_enabled:
		var look_dir = _get_focus_forward()
		var to_promote = subterranean_coordinator.get_chunks_to_promote(focus_pos, focus_chunk, surf_h, _mouth_cache, look_dir, true)

		for p_coord in to_promote:
			if not scheduler.is_phase_in_flight(p_coord, ChunkScheduler.GenerationPhase.PHASE_SUBTERRANEAN):
				var cached_surf = subterranean_coordinator.get_cached_surface_data(p_coord)
				# OffThreadCollisionBaker compiles shapes on worker threads in < 1 ms.
				# Always bake cave collision off-thread so chunk_node never has a null cache.
				scheduler.schedule_subterranean_chunk(p_coord, bounds, generator, mesher, material_registry, cached_surf, false, true)
				subterranean_coordinator.mark_subterranean_queued(p_coord)

	# 3. Unload chunks out of range
	var to_unload = streamer.get_chunks_to_unload(
		focus_chunk,
		_loaded_chunks,
		world_config.view_distance_chunks
	)

	for coord in to_unload:
		var key = coord.to_key()
		scheduler.cancel_chunk(coord)
		subterranean_coordinator.unregister_chunk(coord)
		if not _pending_completed_chunks.is_empty():
			_pending_completed_chunks = _pending_completed_chunks.filter(
				func(item: Dictionary) -> bool:
					var c: ChunkCoord = item.get("coord", null)
					return c == null or not c.equals(coord)
			)
		if _loaded_chunks.has(key):
			var node = _loaded_chunks[key]
			_loaded_chunks.erase(key)
			_mouth_cache.erase(key)
			if is_instance_valid(node):
				_recycle_chunk_node(node)
			chunk_unloaded.emit(coord)

func _get_camera_position() -> Vector3:
	if is_inside_tree() and get_viewport() != null:
		var cam = get_viewport().get_camera_3d()
		if is_instance_valid(cam):
			return cam.global_position
	if is_instance_valid(focus_target):
		if "camera_rig" in focus_target and is_instance_valid(focus_target.camera_rig):
			if "camera" in focus_target.camera_rig and is_instance_valid(focus_target.camera_rig.camera):
				return focus_target.camera_rig.camera.global_position
	return _get_focus_position()

func is_in_underground_chasm(pos: Vector3) -> bool:
	if not caves_enabled:
		return false
	if generator == null or not ("cave_carver" in generator) or generator.cave_carver == null:
		return false
	var surf_h = get_height_at(pos.x, pos.z)
	var col = generator.cave_carver.sample_chasm_column(pos.x, pos.z, null, surf_h)
	if col == null or not col.is_chasm:
		return false
	var chasm_floor = float(col.floor_y)
	var chasm_ceil = float(col.ceil_y)
	if pos.y < (surf_h - 2.0) and pos.y >= (chasm_floor - 2.0) and pos.y <= chasm_ceil:
		return true
	return false

func is_subterranean_position(pos: Vector3) -> bool:
	if not caves_enabled:
		return false
	var surf_h = get_height_at(pos.x, pos.z)
	if is_in_underground_chasm(pos):
		return true
	var sea_threshold = (float(world_config.sea_level) * world_config.voxel_size + 3.0) if world_config != null else 12.0
	if surf_h > sea_threshold and pos.y < (surf_h - 3.0):
		return true
	return false

func _update_layer_visibility(force: bool = false) -> void:
	if not caves_enabled:
		for node in _loaded_chunks.values():
			if node is ChunkNode and node.is_subterranean_visible():
				node.set_subterranean_visible(false)
		if water_plane != null:
			water_plane.set_ocean_visible(true)
		return

	var focus_pos = _get_focus_position()
	var cam_pos = _get_camera_position()
	var in_chasm = is_in_underground_chasm(focus_pos) or is_in_underground_chasm(cam_pos)
	var focus_chunk = bounds.world_to_chunk(focus_pos)
	var surf_h = get_height_at(focus_pos.x, focus_pos.z)
	var sea_level_h = float(world_config.sea_level) * world_config.voxel_size if world_config != null else 9.0
	var current_state = visibility_coordinator.update_chunk_visibility(
		focus_pos,
		focus_chunk,
		surf_h,
		_loaded_chunks,
		_mouth_cache,
		force,
		sea_level_h,
		in_chasm
	)

	if water_plane != null:
		var is_subterranean = (current_state == LayerVisibilityCoordinator.PlayerLayerState.SUBTERRANEAN) or in_chasm
		water_plane.set_ocean_visible(not is_subterranean)


func _sync_foliage_fade_distance() -> void:
	var fol_mat = ChunkNode.get_shared_grass_material() as ShaderMaterial
	if fol_mat == null:
		return
	if foliage_theme != null and ("distance_fade_enabled" in foliage_theme) and not foliage_theme.distance_fade_enabled:
		fol_mat.set_shader_parameter("distance_fade_enabled", false)
		return
	fol_mat.set_shader_parameter("distance_fade_enabled", true)
	var c_size = world_config.chunk_size if world_config != null else 32
	var v_size = world_config.voxel_size if world_config != null else 1.0
	var view_dist = world_config.view_distance_chunks if world_config != null else 8
	var max_chunks = mini(foliage_max_distance_chunks, view_dist)
	var max_meters = float(max_chunks * c_size) * v_size
	var fade_start = maxf(20.0, max_meters * 0.8)
	fol_mat.set_shader_parameter("distance_fade_start", fade_start)
	fol_mat.set_shader_parameter("distance_fade_max", max_meters)

func _update_chunk_collisions(force: bool = false) -> void:
	if bounds == null or world_config == null or _loaded_chunks == null:
		return
	var focus_pos = _get_focus_position()
	var focus_chunk = bounds.world_to_chunk(focus_pos)

	if not force and _last_collision_chunk != null and _last_collision_chunk.equals(focus_chunk):
		return
	_last_collision_chunk = focus_chunk

	var col_dist = world_config.collision_distance_chunks
	var fol_near_dist = foliage_distance_chunks
	var fol_max_dist = foliage_max_distance_chunks
	for chunk_node in _loaded_chunks.values():
		if chunk_node is ChunkNode:
			var dist = focus_chunk.chebyshev_distance_to(chunk_node.coord)
			chunk_node.set_collision_enabled(dist <= col_dist)
			var enable_fol = foliage_enabled and (dist <= fol_max_dist)
			var is_low_detail = (dist > fol_near_dist)
			chunk_node.set_foliage_enabled(enable_fol, is_low_detail)


# -----------------------------------------------------------------------------
# TerrainQuery interface implementation
# -----------------------------------------------------------------------------
func get_height_at(world_x: float, world_z: float) -> float:
	var col = bounds.world_to_column(Vector3(world_x, 0.0, world_z))
	var h = generator.height_at(col, bounds)
	return float(h) * bounds.voxel_size

func get_surface_spawn_point() -> Vector3:
	if not _surface_spawn_cached:
		if generator == null or bounds == null or world_config == null:
			return Vector3(0.0, 30.0, 0.0)
		_surface_spawn_point = _spawn_finder.find_spawn_point(generator, bounds, world_config.sea_level)
		_surface_spawn_cached = true
	return _surface_spawn_point

func get_underground_spawn_point() -> Vector3:
	if not _underground_spawn_cached:
		if generator == null or bounds == null or world_config == null:
			return Vector3(0.0, 10.0, 0.0)
		_underground_spawn_point = _spawn_finder.find_underground_arena_spawn_point(generator, bounds, world_config.sea_level)
		_underground_spawn_cached = true
	return _underground_spawn_point

func get_spawn_point() -> Vector3:
	if spawn_on_underground_arena and caves_enabled:
		_spawn_point = get_underground_spawn_point()
	else:
		_spawn_point = get_surface_spawn_point()
	_spawn_point_cached = true
	return _spawn_point

func clear_spawn_cache() -> void:
	_surface_spawn_cached = false
	_underground_spawn_cached = false
	_spawn_point_cached = false

func toggle_spawn_location() -> Vector3:
	spawn_on_underground_arena = not spawn_on_underground_arena
	if spawn_on_underground_arena and not caves_enabled:
		caves_enabled = true
	var target_pos = get_spawn_point()
	teleport_focus_to(target_pos)
	spawn_mode_changed.emit(spawn_on_underground_arena, target_pos)
	return target_pos

func teleport_focus_to(target_pos: Vector3) -> void:
	_spawn_point = target_pos
	_spawn_point_cached = true

	if bounds != null and generator != null and mesher != null and _chunks_root != null:
		var target_chunk = bounds.world_to_chunk(target_pos)
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var coord = ChunkCoord.new(target_chunk.x + dx, target_chunk.z + dz)
				if not bounds.contains_chunk(coord):
					continue
				var key = coord.to_key()
				if not _loaded_chunks.has(key):
					_load_chunk_sync(coord)
				else:
					var node = _loaded_chunks[key] as ChunkNode
					if node != null:
						node.set_collision_enabled(true)
						if spawn_on_underground_arena and caves_enabled:
							if node.cave_collision_shape == null or node.cave_collision_shape.shape == null:
								var c_data = generator.generate(coord, bounds)
								var m_data = mesher.build_mesh(c_data, material_registry)
								var baker = OffThreadCollisionBaker.new()
								var shapes = baker.bake_shapes_for_bundle(m_data)
								node.apply_subterranean_bundle(m_data, shapes.cave_shape)
								subterranean_coordinator.mark_subterranean_ready(coord)

	if is_instance_valid(focus_target):
		if focus_target.is_inside_tree():
			focus_target.global_position = target_pos
		else:
			focus_target.position = target_pos
		if focus_target is CharacterBody3D:
			focus_target.velocity = Vector3.ZERO

	if is_inside_tree():
		_update_streaming(true)
		_update_layer_visibility(true)
		_update_chunk_collisions(true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F4 or event.keycode == KEY_F4 or event.is_action_pressed("toggle_spawn"):
			toggle_spawn_location()
			var vp = get_viewport()
			if vp != null:
				vp.set_input_as_handled()

func get_world_bounds() -> WorldBounds:
	return bounds

func get_loaded_chunk_count() -> int:
	return _loaded_chunks.size()

func get_pending_completed_chunk_count() -> int:
	return _pending_completed_chunks.size()

func clear_pending_chunks() -> void:
	_pending_completed_chunks.clear()

func get_pooled_chunk_count() -> int:
	return _chunk_node_pool.size()

