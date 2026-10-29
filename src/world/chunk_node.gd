class_name ChunkNode
extends Node3D

## Visual and physics instance of a terrain chunk in the scene tree.
## Supports decoupled dual-layer rendering (surface mesh vs subterranean cave mesh)
## and independent shadow culling to maintain high framerates.

var coord: ChunkCoord
var has_cave_mouth: bool = false

# Primary / Surface visual and water instances
var mesh_instance: MeshInstance3D
var water_instance: MeshInstance3D
var grass_instance: MultiMeshInstance3D

# Subterranean cave visual and water instances
var cave_mesh_instance: MeshInstance3D
var cave_water_instance: MeshInstance3D

# Physics
var static_body: StaticBody3D
var collision_shape: CollisionShape3D
var cave_collision_shape: CollisionShape3D

const MaterialProviderClass = preload("res://src/rendering/terrain_material_provider.gd")

static var _shared_material: Material
static var _shared_cave_material: Material
static var _shared_water_material: Material
static var _shared_subterranean_water_material: Material
static var _shared_grass_material: Material
static var _shared_grass_mesh: Mesh

static func configure_shared_materials(
	surface_mat: Material,
	cave_mat: Material,
	water_mat: Material = null,
	cave_water_mat: Material = null,
	grass_mat: Material = null,
	grass_mesh: Mesh = null
) -> void:
	_shared_material = surface_mat
	_shared_cave_material = cave_mat
	if water_mat != null:
		_shared_water_material = water_mat
	if cave_water_mat != null:
		_shared_subterranean_water_material = cave_water_mat
	if grass_mat != null:
		_shared_grass_material = grass_mat
	if grass_mesh != null:
		_shared_grass_mesh = grass_mesh

static func get_shared_surface_material() -> Material:
	return _shared_material

static func get_shared_cave_material() -> Material:
	return _shared_cave_material

static func get_shared_water_material() -> Material:
	return _shared_water_material

static func get_shared_subterranean_water_material() -> Material:
	return _shared_subterranean_water_material

static func get_shared_grass_material() -> Material:
	if _shared_grass_material == null:
		_shared_grass_material = MaterialProviderClass.get_grass_material()
	return _shared_grass_material

static func get_shared_grass_mesh() -> Mesh:
	if _shared_grass_mesh == null and ResourceLoader.exists("res://assets/models/grass_tuft.tres"):
		_shared_grass_mesh = load("res://assets/models/grass_tuft.tres")
	return _shared_grass_mesh

func _init() -> void:
	if _shared_material == null:
		_shared_material = MaterialProviderClass.get_surface_material()
	if _shared_cave_material == null:
		_shared_cave_material = MaterialProviderClass.get_cave_material()
	if _shared_water_material == null:
		_shared_water_material = MaterialProviderClass.get_water_material()
	if _shared_subterranean_water_material == null:
		_shared_subterranean_water_material = MaterialProviderClass.get_subterranean_water_material()
	if _shared_grass_material == null:
		_shared_grass_material = MaterialProviderClass.get_grass_material()
	if _shared_grass_mesh == null and ResourceLoader.exists("res://assets/models/grass_tuft.tres"):
		_shared_grass_mesh = load("res://assets/models/grass_tuft.tres")

func _ready() -> void:
	_ensure_nodes_exist()

func _ensure_nodes_exist() -> void:
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "SurfaceMeshInstance"
		mesh_instance.material_override = _shared_material
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(mesh_instance)

	if cave_mesh_instance == null:
		cave_mesh_instance = MeshInstance3D.new()
		cave_mesh_instance.name = "CaveMeshInstance"
		cave_mesh_instance.material_override = _shared_cave_material
		cave_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cave_mesh_instance.visible = false
		add_child(cave_mesh_instance)

	if grass_instance == null:
		grass_instance = MultiMeshInstance3D.new()
		grass_instance.name = "GrassMultiMeshInstance"
		grass_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		grass_instance.visible = false
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = get_shared_grass_mesh()
		grass_instance.multimesh = mm
		grass_instance.material_override = get_shared_grass_material()
		add_child(grass_instance)

	if static_body == null:
		static_body = StaticBody3D.new()
		static_body.name = "StaticBody3D"
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "SurfaceCollisionShape"
		static_body.add_child(collision_shape)

		cave_collision_shape = CollisionShape3D.new()
		cave_collision_shape.name = "CaveCollisionShape"
		cave_collision_shape.disabled = true
		static_body.add_child(cave_collision_shape)

		add_child(static_body)

var _cached_prebaked_surface_shape: ConcavePolygonShape3D = null
var _cached_prebaked_cave_shape: ConcavePolygonShape3D = null
var _cached_foliage_data: RefCounted = null
var _collision_distance_enabled: bool = false
var _foliage_distance_enabled: bool = false

func setup(
	p_coord: ChunkCoord,
	origin: Vector3,
	mesh_data: MeshData,
	enable_collision: bool,
	prebaked_surface_shape: ConcavePolygonShape3D = null,
	prebaked_cave_shape: ConcavePolygonShape3D = null,
	enable_foliage: bool = false
) -> void:
	coord = p_coord
	position = origin
	has_cave_mouth = mesh_data.has_cave_mouth if mesh_data != null else false
	_ensure_nodes_exist()
	visible = true

	# Cache surface shape; defer binding to PhysicsServer until collision is enabled
	if prebaked_surface_shape != null:
		_cached_prebaked_surface_shape = prebaked_surface_shape
	elif mesh_data is DualMeshBundle and mesh_data.surface_shape != null:
		_cached_prebaked_surface_shape = mesh_data.surface_shape
	else:
		_cached_prebaked_surface_shape = null

	# Cache cave shape; defer binding to PhysicsServer until cave layer is activated
	if prebaked_cave_shape != null:
		_cached_prebaked_cave_shape = prebaked_cave_shape
	elif mesh_data is DualMeshBundle and mesh_data.cave_shape != null:
		_cached_prebaked_cave_shape = mesh_data.cave_shape
	else:
		_cached_prebaked_cave_shape = null

	# 1. Surface Mesh Setup
	var array_mesh = mesh_data.create_array_mesh() if mesh_data != null else null
	mesh_instance.mesh = array_mesh

	# 2. Surface Water Setup
	if mesh_data != null and mesh_data.water_mesh_data != null and not mesh_data.water_mesh_data.is_empty():
		if water_instance == null:
			water_instance = MeshInstance3D.new()
			water_instance.name = "WaterInstance"
			water_instance.material_override = _shared_water_material
			water_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(water_instance)
		water_instance.mesh = mesh_data.water_mesh_data.create_array_mesh()
		water_instance.visible = true
	elif water_instance != null:
		water_instance.visible = false
		water_instance.mesh = null

	# 3. Subterranean Cave Mesh & Cave Water Setup (DualMeshBundle)
	if mesh_data is DualMeshBundle and mesh_data.has_cave_geometry():
		var c_mesh_data: MeshData = mesh_data.cave_mesh_data
		cave_mesh_instance.mesh = c_mesh_data.create_array_mesh()

		if c_mesh_data.water_mesh_data != null and not c_mesh_data.water_mesh_data.is_empty():
			if cave_water_instance == null:
				cave_water_instance = MeshInstance3D.new()
				cave_water_instance.name = "CaveWaterInstance"
				cave_water_instance.material_override = _shared_subterranean_water_material
				cave_water_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(cave_water_instance)
			cave_water_instance.mesh = c_mesh_data.water_mesh_data.create_array_mesh()
		elif cave_water_instance != null:
			cave_water_instance.visible = false
			cave_water_instance.mesh = null
	else:
		cave_mesh_instance.mesh = null
		cave_mesh_instance.visible = false
		if cave_water_instance != null:
			cave_water_instance.visible = false
			cave_water_instance.mesh = null

	# 4. Foliage Setup
	_foliage_distance_enabled = enable_foliage
	if mesh_data != null and mesh_data.foliage_data != null and not mesh_data.foliage_data.is_empty():
		_cached_foliage_data = mesh_data.foliage_data
		if grass_instance != null and grass_instance.multimesh != null:
			if grass_instance.multimesh.mesh == null:
				grass_instance.multimesh.mesh = get_shared_grass_mesh()
			grass_instance.multimesh.instance_count = _cached_foliage_data.instance_count
			grass_instance.multimesh.buffer = _cached_foliage_data.transform_buffer
			grass_instance.visible = _foliage_distance_enabled and is_surface_visible()
	else:
		_cached_foliage_data = null
		if grass_instance != null and grass_instance.multimesh != null:
			grass_instance.multimesh.instance_count = 0
			grass_instance.visible = false

	set_collision_enabled(enable_collision)

func prepare_for_pool() -> void:
	coord = null
	has_cave_mouth = false
	_collision_distance_enabled = false
	_foliage_distance_enabled = false
	_cached_prebaked_surface_shape = null
	_cached_prebaked_cave_shape = null
	_cached_foliage_data = null

	if mesh_instance != null:
		mesh_instance.mesh = null
	if cave_mesh_instance != null:
		cave_mesh_instance.mesh = null
		cave_mesh_instance.visible = false
	if water_instance != null:
		water_instance.mesh = null
		water_instance.visible = false
	if cave_water_instance != null:
		cave_water_instance.mesh = null
		cave_water_instance.visible = false
	if grass_instance != null:
		if grass_instance.multimesh != null:
			grass_instance.multimesh.instance_count = 0
		grass_instance.visible = false

	if collision_shape != null:
		collision_shape.shape = null
		collision_shape.disabled = true
	if cave_collision_shape != null:
		cave_collision_shape.shape = null
		cave_collision_shape.disabled = true

	visible = false

func apply_subterranean_bundle(
	mesh_data: MeshData,
	prebaked_cave_shape: ConcavePolygonShape3D = null
) -> void:
	if mesh_data == null:
		return
	_ensure_nodes_exist()

	if mesh_data is DualMeshBundle:
		has_cave_mouth = mesh_data.has_cave_mouth
		if mesh_data.has_cave_geometry():
			var c_mesh_data: MeshData = mesh_data.cave_mesh_data
			cave_mesh_instance.mesh = c_mesh_data.create_array_mesh()

			if c_mesh_data.water_mesh_data != null and not c_mesh_data.water_mesh_data.is_empty():
				if cave_water_instance == null:
					cave_water_instance = MeshInstance3D.new()
					cave_water_instance.name = "CaveWaterInstance"
					cave_water_instance.material_override = _shared_subterranean_water_material
					cave_water_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					add_child(cave_water_instance)
				cave_water_instance.mesh = c_mesh_data.water_mesh_data.create_array_mesh()
			elif cave_water_instance != null:
				cave_water_instance.visible = false

		if mesh_data.has_cave_mouth and not mesh_data.is_empty():
			mesh_instance.mesh = mesh_data.create_array_mesh()
			if mesh_data.surface_shape != null:
				_cached_prebaked_surface_shape = mesh_data.surface_shape
				if _collision_distance_enabled:
					collision_shape.shape = mesh_data.surface_shape

	if prebaked_cave_shape != null:
		_cached_prebaked_cave_shape = prebaked_cave_shape
	elif mesh_data is DualMeshBundle and mesh_data.cave_shape != null:
		_cached_prebaked_cave_shape = mesh_data.cave_shape

	if is_subterranean_visible() and _collision_distance_enabled:
		if cave_collision_shape != null:
			if cave_collision_shape.shape == null and _cached_prebaked_cave_shape != null:
				cave_collision_shape.shape = _cached_prebaked_cave_shape
			if cave_collision_shape.shape != null:
				cave_collision_shape.disabled = false
			else:
				cave_collision_shape.disabled = true

func set_subterranean_visible(sub_visible: bool) -> void:
	if cave_mesh_instance != null:
		cave_mesh_instance.visible = sub_visible
	if cave_water_instance != null:
		cave_water_instance.visible = sub_visible
	if cave_collision_shape != null:
		if sub_visible:
			if cave_collision_shape.shape == null and _cached_prebaked_cave_shape != null:
				cave_collision_shape.shape = _cached_prebaked_cave_shape
			if _collision_distance_enabled and cave_collision_shape.shape != null:
				cave_collision_shape.disabled = false
			else:
				cave_collision_shape.disabled = true
		else:
			cave_collision_shape.disabled = true

func is_subterranean_visible() -> bool:
	return cave_mesh_instance != null and cave_mesh_instance.visible

func is_surface_visible() -> bool:
	return mesh_instance != null and mesh_instance.visible

func set_foliage_enabled(enable: bool) -> void:
	_foliage_distance_enabled = enable
	if grass_instance != null:
		var has_data = (_cached_foliage_data != null and not _cached_foliage_data.is_empty())
		grass_instance.visible = enable and has_data and is_surface_visible()

func is_foliage_enabled() -> bool:
	return _foliage_distance_enabled and grass_instance != null and grass_instance.visible

func has_cave_mesh() -> bool:
	return cave_mesh_instance != null and cave_mesh_instance.mesh != null

func set_collision_enabled(enable: bool) -> void:
	if static_body == null or collision_shape == null:
		return
	_collision_distance_enabled = enable

	if enable:
		if collision_shape.shape == null:
			if _cached_prebaked_surface_shape != null:
				collision_shape.shape = _cached_prebaked_surface_shape
			elif mesh_instance != null and mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
				var shape = mesh_instance.mesh.create_trimesh_shape()
				if shape != null:
					shape.backface_collision = true
				collision_shape.shape = shape
		if collision_shape.shape != null:
			collision_shape.disabled = false
		else:
			collision_shape.disabled = true

		if cave_collision_shape != null:
			if is_subterranean_visible():
				if cave_collision_shape.shape == null and _cached_prebaked_cave_shape != null:
					cave_collision_shape.shape = _cached_prebaked_cave_shape
				if cave_collision_shape.shape != null:
					cave_collision_shape.disabled = false
				else:
					cave_collision_shape.disabled = true
			else:
				cave_collision_shape.disabled = true
	else:
		collision_shape.disabled = true
		if cave_collision_shape != null:
			cave_collision_shape.disabled = true

func is_collision_enabled() -> bool:
	var surf_active = (collision_shape != null and not collision_shape.disabled and collision_shape.shape != null)
	var cave_active = (cave_collision_shape != null and not cave_collision_shape.disabled and cave_collision_shape.shape != null)
	return surf_active or cave_active
