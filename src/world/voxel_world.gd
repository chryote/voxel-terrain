class_name VoxelWorld
extends Node3D

## Composition root for voxel terrain streaming, meshing, and physics.

signal chunk_loaded(coord: ChunkCoord)
signal chunk_unloaded(coord: ChunkCoord)
signal initial_area_ready()

@export var world_config: WorldConfig
@export var generator_config: ContinentGeneratorConfig
@export var cave_config: CaveGeneratorConfig
@export var material_registry: MaterialRegistry
@export var focus_target: Node3D
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
var visibility_coordinator: LayerVisibilityCoordinator = LayerVisibilityCoordinator.new()
var subterranean_coordinator: SubterraneanStreamCoordinator = SubterraneanStreamCoordinator.new()
var _mouth_cache: Dictionary = {} # key -> bool


func _ready() -> void:
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

	bounds = world_config.create_world_bounds()
	if generator == null:
		generator = VolumetricTerrainGenerator.new(world_config.world_seed, generator_config, cave_config)
	if mesher == null:
		var voxel_mesher = VoxelMesher.new()
		voxel_mesher.sea_level = world_config.sea_level
		mesher = voxel_mesher
	streamer = ChunkStreamer.new()
	scheduler = ChunkScheduler.new()

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
		focus_target.global_position = spawn_pos

	for dz in range(-1, 2):
		for dx in range(-1, 2):
			_load_chunk_sync(ChunkCoord.new(spawn_chunk.x + dx, spawn_chunk.z + dz))

	_initial_ready_emitted = true
	initial_area_ready.emit()

	_update_streaming()
	_update_chunk_collisions(true)
	_update_layer_visibility(true)

func _process(_delta: float) -> void:
	_process_completed_chunks()
	_update_streaming()
	_update_chunk_collisions()
	_update_layer_visibility()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if scheduler != null:
			scheduler.clear()

func _exit_tree() -> void:
	if scheduler != null:
		scheduler.clear()

func _get_focus_position() -> Vector3:
	if is_instance_valid(focus_target):
		if focus_target.is_inside_tree():
			return focus_target.global_position
		return focus_target.position
	return Vector3.ZERO


func _load_chunk_sync(coord: ChunkCoord) -> void:
	if not bounds.contains_chunk(coord):
		return
	var key = coord.to_key()
	if _loaded_chunks.has(key):
		return

	var chunk_data = generator.generate(coord, bounds)
	var mesh_data = mesher.build_mesh(chunk_data, material_registry)

	var chunk_node = ChunkNode.new()
	chunk_node.name = "Chunk_%d_%d" % [coord.x, coord.z]
	_chunks_root.add_child(chunk_node)
	_loaded_chunks[key] = chunk_node

	var origin = bounds.chunk_origin(coord)
	var baker = OffThreadCollisionBaker.new()
	var shapes = baker.bake_shapes_for_bundle(mesh_data)
	chunk_node.setup(coord, origin, mesh_data, true, shapes.surface_shape, shapes.cave_shape)
	_mouth_cache[key] = chunk_node.has_cave_mouth
	subterranean_coordinator.register_surface_chunk(coord, chunk_node.has_cave_mouth)
	subterranean_coordinator.mark_subterranean_ready(coord)
	chunk_loaded.emit(coord)

func _process_completed_chunks() -> void:
	var focus_pos = _get_focus_position()
	var focus_chunk = bounds.world_to_chunk(focus_pos)

	var completed = scheduler.poll_completed(world_config.max_mesh_applies_per_frame)
	for item in completed:
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
			continue

		var dist_to_focus = focus_chunk.chebyshev_distance_to(coord)
		var enable_collision = (dist_to_focus <= world_config.collision_distance_chunks)

		var chunk_node: ChunkNode
		if _loaded_chunks.has(key):
			chunk_node = _loaded_chunks[key]
		else:
			chunk_node = ChunkNode.new()
			chunk_node.name = "Chunk_%d_%d" % [coord.x, coord.z]
			_chunks_root.add_child(chunk_node)
			_loaded_chunks[key] = chunk_node

		var origin = bounds.chunk_origin(coord)
		var surf_shape = item.get("surface_shape", null)
		var cave_shape = item.get("cave_shape", null)
		chunk_node.setup(coord, origin, mesh_data, enable_collision, surf_shape, cave_shape)
		_mouth_cache[key] = chunk_node.has_cave_mouth

		var s_data = item.get("data", null) as SurfaceChunkData
		subterranean_coordinator.register_surface_chunk(coord, chunk_node.has_cave_mouth, s_data)

		if phase == ChunkScheduler.GenerationPhase.PHASE_FULL:
			subterranean_coordinator.mark_subterranean_ready(coord)
		elif chunk_node.has_cave_mouth and caves_enabled:
			scheduler.schedule_subterranean_chunk(coord, bounds, generator, mesher, material_registry, s_data, true)
			subterranean_coordinator.mark_subterranean_queued(coord)

		chunk_loaded.emit(coord)

func _update_streaming() -> void:
	var focus_pos = _get_focus_position()
	var focus_chunk = bounds.world_to_chunk(focus_pos)
	var surf_h = get_height_at(focus_pos.x, focus_pos.z)
	var is_player_subterranean = focus_pos.y < (surf_h - 4.0)

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
		var to_promote = subterranean_coordinator.get_chunks_to_promote(focus_pos, focus_chunk, surf_h, _mouth_cache)
		for p_coord in to_promote:
			if not scheduler.is_phase_in_flight(p_coord, ChunkScheduler.GenerationPhase.PHASE_SUBTERRANEAN):
				var cached_surf = subterranean_coordinator.get_cached_surface_data(p_coord)
				scheduler.schedule_subterranean_chunk(p_coord, bounds, generator, mesher, material_registry, cached_surf)
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
		if _loaded_chunks.has(key):
			var node = _loaded_chunks[key]
			_loaded_chunks.erase(key)
			_mouth_cache.erase(key)
			if is_instance_valid(node):
				node.queue_free()
			chunk_unloaded.emit(coord)

func _update_layer_visibility(force: bool = false) -> void:
	if not caves_enabled:
		for node in _loaded_chunks.values():
			if node is ChunkNode and node.is_subterranean_visible():
				node.set_subterranean_visible(false)
		return

	var focus_pos = _get_focus_position()
	var focus_chunk = bounds.world_to_chunk(focus_pos)
	var surf_h = get_height_at(focus_pos.x, focus_pos.z)
	visibility_coordinator.update_chunk_visibility(
		focus_pos,
		focus_chunk,
		surf_h,
		_loaded_chunks,
		_mouth_cache,
		force
	)

func _update_chunk_collisions(force: bool = false) -> void:
	var focus_pos = _get_focus_position()
	var focus_chunk = bounds.world_to_chunk(focus_pos)

	if not force and _last_collision_chunk != null and _last_collision_chunk.equals(focus_chunk):
		return
	_last_collision_chunk = focus_chunk

	var col_dist = world_config.collision_distance_chunks
	for chunk_node in _loaded_chunks.values():
		if chunk_node is ChunkNode:
			var dist = focus_chunk.chebyshev_distance_to(chunk_node.coord)
			chunk_node.set_collision_enabled(dist <= col_dist)


# -----------------------------------------------------------------------------
# TerrainQuery interface implementation
# -----------------------------------------------------------------------------
func get_height_at(world_x: float, world_z: float) -> float:
	var col = bounds.world_to_column(Vector3(world_x, 0.0, world_z))
	var h = generator.height_at(col, bounds)
	return float(h) * bounds.voxel_size

func get_spawn_point() -> Vector3:
	if generator == null or bounds == null or world_config == null:
		return Vector3(0.0, 30.0, 0.0)
	return _spawn_finder.find_spawn_point(generator, bounds, world_config.sea_level)

func get_world_bounds() -> WorldBounds:
	return bounds

func get_loaded_chunk_count() -> int:
	return _loaded_chunks.size()
