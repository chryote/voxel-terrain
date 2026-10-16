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

# Subterranean cave visual and water instances
var cave_mesh_instance: MeshInstance3D
var cave_water_instance: MeshInstance3D

# Physics
var static_body: StaticBody3D
var collision_shape: CollisionShape3D
var cave_collision_shape: CollisionShape3D

static var _shared_material: StandardMaterial3D
static var _shared_cave_material: StandardMaterial3D
static var _shared_water_material: StandardMaterial3D

func _init() -> void:
	if _shared_material == null:
		_shared_material = StandardMaterial3D.new()
		_shared_material.vertex_color_use_as_albedo = true
		_shared_material.roughness = 0.85
		_shared_material.metallic_specular = 0.15

	if _shared_cave_material == null:
		_shared_cave_material = StandardMaterial3D.new()
		_shared_cave_material.vertex_color_use_as_albedo = true
		_shared_cave_material.roughness = 0.90
		_shared_cave_material.metallic_specular = 0.10

	if _shared_water_material == null:
		_shared_water_material = StandardMaterial3D.new()
		_shared_water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shared_water_material.albedo_color = Color(0.12, 0.38, 0.65, 0.75)
		_shared_water_material.roughness = 0.1
		_shared_water_material.metallic = 0.15

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
		# Subterranean geometry is never reached by directional sunlight shadows
		cave_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cave_mesh_instance.visible = false
		add_child(cave_mesh_instance)

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

var _cached_prebaked_cave_shape: ConcavePolygonShape3D = null

func setup(
	p_coord: ChunkCoord,
	origin: Vector3,
	mesh_data: MeshData,
	enable_collision: bool,
	prebaked_surface_shape: ConcavePolygonShape3D = null,
	prebaked_cave_shape: ConcavePolygonShape3D = null
) -> void:
	coord = p_coord
	position = origin
	has_cave_mouth = mesh_data.has_cave_mouth if (mesh_data is DualMeshBundle) else false
	_ensure_nodes_exist()

	# Assign pre-baked surface shape immediately
	if prebaked_surface_shape != null:
		collision_shape.shape = prebaked_surface_shape
	elif mesh_data is DualMeshBundle and mesh_data.surface_shape != null:
		collision_shape.shape = mesh_data.surface_shape

	# Cache cave shape; defer binding to PhysicsServer until cave layer is activated
	if prebaked_cave_shape != null:
		_cached_prebaked_cave_shape = prebaked_cave_shape
	elif mesh_data is DualMeshBundle and mesh_data.cave_shape != null:
		_cached_prebaked_cave_shape = mesh_data.cave_shape

	# 1. Surface Mesh Setup
	var array_mesh = mesh_data.create_array_mesh() if mesh_data != null else null
	mesh_instance.mesh = array_mesh

	# 2. Surface Water Setup
	if mesh_data != null and mesh_data.water_mesh_data != null and not mesh_data.water_mesh_data.is_empty():
		if water_instance == null:
			water_instance = MeshInstance3D.new()
			water_instance.name = "WaterInstance"
			water_instance.material_override = _shared_water_material
			add_child(water_instance)
		water_instance.mesh = mesh_data.water_mesh_data.create_array_mesh()
		water_instance.visible = true
	elif water_instance != null:
		water_instance.visible = false

	# 3. Subterranean Cave Mesh & Cave Water Setup (DualMeshBundle)
	if mesh_data is DualMeshBundle and mesh_data.has_cave_geometry():
		var c_mesh_data: MeshData = mesh_data.cave_mesh_data
		cave_mesh_instance.mesh = c_mesh_data.create_array_mesh()

		if c_mesh_data.water_mesh_data != null and not c_mesh_data.water_mesh_data.is_empty():
			if cave_water_instance == null:
				cave_water_instance = MeshInstance3D.new()
				cave_water_instance.name = "CaveWaterInstance"
				cave_water_instance.material_override = _shared_water_material
				cave_water_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(cave_water_instance)
			cave_water_instance.mesh = c_mesh_data.water_mesh_data.create_array_mesh()
		elif cave_water_instance != null:
			cave_water_instance.visible = false
	else:
		cave_mesh_instance.mesh = null
		cave_mesh_instance.visible = false
		if cave_water_instance != null:
			cave_water_instance.visible = false

	set_collision_enabled(enable_collision)

func set_subterranean_visible(visible: bool) -> void:
	if cave_mesh_instance != null:
		cave_mesh_instance.visible = visible
	if cave_water_instance != null:
		cave_water_instance.visible = visible
	if cave_collision_shape != null:
		if visible and cave_collision_shape.shape == null and _cached_prebaked_cave_shape != null:
			cave_collision_shape.shape = _cached_prebaked_cave_shape
		if not collision_shape.disabled:
			cave_collision_shape.disabled = not visible

func is_subterranean_visible() -> bool:
	return cave_mesh_instance != null and cave_mesh_instance.visible

func has_cave_mesh() -> bool:
	return cave_mesh_instance != null and cave_mesh_instance.mesh != null

func set_collision_enabled(enable: bool) -> void:
	if static_body == null or collision_shape == null:
		return

	if enable:
		# Surface collision shape
		if collision_shape.shape == null and mesh_instance != null and mesh_instance.mesh != null:
			if mesh_instance.mesh.get_surface_count() > 0:
				var shape = mesh_instance.mesh.create_trimesh_shape()
				if shape != null:
					shape.backface_collision = true
				collision_shape.shape = shape
		if collision_shape.shape != null:
			collision_shape.disabled = false
		else:
			collision_shape.disabled = true

		# Cave collision shape (bound only if subterranean collision is active)
		if cave_collision_shape != null and cave_mesh_instance != null and cave_mesh_instance.mesh != null:
			if is_subterranean_visible():
				if cave_collision_shape.shape == null:
					if _cached_prebaked_cave_shape != null:
						cave_collision_shape.shape = _cached_prebaked_cave_shape
					elif cave_mesh_instance.mesh.get_surface_count() > 0:
						var c_shape = cave_mesh_instance.mesh.create_trimesh_shape()
						if c_shape != null:
							c_shape.backface_collision = true
						cave_collision_shape.shape = c_shape
				cave_collision_shape.disabled = false
			else:
				cave_collision_shape.disabled = true
	else:
		collision_shape.disabled = true
		if cave_collision_shape != null:
			cave_collision_shape.disabled = true


func is_collision_enabled() -> bool:
	return collision_shape != null and not collision_shape.disabled and collision_shape.shape != null
