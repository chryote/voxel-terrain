class_name ChunkNode
extends Node3D

## Visual and physics instance of a terrain chunk in the scene tree.

var coord: ChunkCoord
var mesh_instance: MeshInstance3D
var water_instance: MeshInstance3D
var static_body: StaticBody3D
var collision_shape: CollisionShape3D

static var _shared_material: StandardMaterial3D
static var _shared_water_material: StandardMaterial3D

func _init() -> void:
	if _shared_material == null:
		_shared_material = StandardMaterial3D.new()
		_shared_material.vertex_color_use_as_albedo = true
		_shared_material.roughness = 0.85
		_shared_material.metallic_specular = 0.15

	if _shared_water_material == null:
		_shared_water_material = StandardMaterial3D.new()
		_shared_water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shared_water_material.albedo_color = Color(0.12, 0.38, 0.65, 0.75)
		_shared_water_material.roughness = 0.1
		_shared_water_material.metallic = 0.15

func _ready() -> void:
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.material_override = _shared_material
		add_child(mesh_instance)

	if static_body == null:
		static_body = StaticBody3D.new()
		collision_shape = CollisionShape3D.new()
		static_body.add_child(collision_shape)
		add_child(static_body)

func setup(
	p_coord: ChunkCoord,
	origin: Vector3,
	mesh_data: MeshData,
	enable_collision: bool
) -> void:
	coord = p_coord
	position = origin

	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.material_override = _shared_material
		add_child(mesh_instance)

	if static_body == null:
		static_body = StaticBody3D.new()
		collision_shape = CollisionShape3D.new()
		static_body.add_child(collision_shape)
		add_child(static_body)

	var array_mesh = mesh_data.create_array_mesh() if mesh_data != null else null
	mesh_instance.mesh = array_mesh

	# Setup elevated water visual mesh (if chunk contains elevated water above sea level)
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

	set_collision_enabled(enable_collision)

func set_collision_enabled(enable: bool) -> void:
	if static_body == null or collision_shape == null:
		return

	if enable:
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
	else:
		collision_shape.disabled = true

func is_collision_enabled() -> bool:
	return collision_shape != null and not collision_shape.disabled and collision_shape.shape != null

