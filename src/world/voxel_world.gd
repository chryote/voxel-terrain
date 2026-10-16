class_name VoxelWorld
extends Node3D

## Composition root for voxel terrain streaming, meshing, and physics.

signal chunk_loaded(coord: ChunkCoord)
signal chunk_unloaded(coord: ChunkCoord)
signal initial_area_ready()

@export var world_config: WorldConfig
@export var generator_config: ContinentGeneratorConfig
@export var material_registry: MaterialRegistry
@export var focus_target: Node3D

var bounds: WorldBounds
var generator: TerrainGenerator
var mesher: Mesher
var streamer: ChunkStreamer
var scheduler: ChunkScheduler

var water_plane: WaterPlane
var world_boundary: WorldBoundary
var _chunks_root: Node3D

var _loaded_chunks: Dictionary = {} # key -> ChunkNode
var _initial_ready_emitted: bool = false
var _last_collision_chunk: ChunkCoord = null


func _ready() -> void:
	if world_config == null:
		world_config = WorldConfig.new()
	if generator_config == null:
		generator_config = ContinentGeneratorConfig.new()
	if material_registry == null:
		material_registry = MaterialRegistry.create_default_registry()

	bounds = world_config.create_world_bounds()
	generator = ContinentGenerator.new(world_config.world_seed, generator_config)
	mesher = SurfaceShellMesher.new()
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

func _process(_delta: float) -> void:
	_process_completed_chunks()
	_update_streaming()
	_update_chunk_collisions()


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
	chunk_node.setup(coord, origin, mesh_data, true)
	chunk_loaded.emit(coord)

func _process_completed_chunks() -> void:
	var focus_pos = _get_focus_position()
	var focus_chunk = bounds.world_to_chunk(focus_pos)

	var completed = scheduler.poll_completed(world_config.max_mesh_applies_per_frame)
	for item in completed:
		var coord: ChunkCoord = item.coord
		var mesh_data: MeshData = item.mesh_data
		var key = coord.to_key()

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
		chunk_node.setup(coord, origin, mesh_data, enable_collision)
		chunk_loaded.emit(coord)

func _update_streaming() -> void:
	var focus_pos = _get_focus_position()
	var focus_chunk = bounds.world_to_chunk(focus_pos)

	# 1. Enqueue new chunks to load
	var to_load = streamer.get_chunks_to_load(
		focus_chunk,
		_loaded_chunks,
		world_config.view_distance_chunks,
		bounds
	)

	for coord in to_load:
		if not scheduler.is_chunk_in_flight(coord):
			scheduler.schedule_chunk(coord, bounds, generator, mesher, material_registry)

	# 2. Unload chunks out of range
	var to_unload = streamer.get_chunks_to_unload(
		focus_chunk,
		_loaded_chunks,
		world_config.view_distance_chunks
	)

	for coord in to_unload:
		var key = coord.to_key()
		scheduler.cancel_chunk(coord)
		if _loaded_chunks.has(key):
			var node = _loaded_chunks[key]
			_loaded_chunks.erase(key)
			if is_instance_valid(node):
				node.queue_free()
			chunk_unloaded.emit(coord)

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
	# Search outward from center for high dry land
	for radius in range(0, 100):
		for dx in range(-radius, radius + 1):
			for dz in [-radius, radius]:
				var col = Vector2i(dx, dz)
				var h = generator.height_at(col, bounds)
				if h > world_config.sea_level + 2:
					var wpos = bounds.column_to_world(col, float(h) + 1.0)
					return wpos
	return Vector3(0.0, float(world_config.sea_level + 5) * world_config.voxel_size, 0.0)

func get_world_bounds() -> WorldBounds:
	return bounds

func get_loaded_chunk_count() -> int:
	return _loaded_chunks.size()
