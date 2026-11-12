class_name BlinkEffectSpawner
extends RefCounted

## Visual spectacle spawner for Instantaneous Translocation (Blink / Warp) (procedural_todo_combo_depth.md).
## 1. Origin: Inward voxel particle implosion.
## 2. Vector: Laser-thin incandescent ray line connecting start and end points for 2 frames.
## 3. Arrival: Cylindrical kinetic shockwave ring puffing outward along ground where player reappears.

static func spawn_blink(parent: Node, origin_pos: Vector3, arrival_pos: Vector3) -> void:
	if parent == null or not parent.is_inside_tree():
		return

	_spawn_origin_implosion(parent, origin_pos)
	_spawn_vector_ray(parent, origin_pos, arrival_pos)
	_spawn_arrival_shockwave(parent, arrival_pos)

## 1. Origin inward voxel particle implosion
static func _spawn_origin_implosion(parent: Node, origin_pos: Vector3) -> void:
	var parts = CPUParticles3D.new()
	parts.top_level = true
	parts.global_position = origin_pos + Vector3(0.0, 0.8, 0.0)
	parts.amount = 28
	parts.lifetime = 0.16
	parts.one_shot = true
	parts.explosiveness = 0.85
	parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	parts.emission_sphere_radius = 0.85
	parts.radial_accel_min = -15.0
	parts.radial_accel_max = -25.0 # Inward suction
	parts.gravity = Vector3.ZERO
	parts.scale_amount_min = 0.03
	parts.scale_amount_max = 0.06

	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.3, 0.9, 1.0, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.5, 1.2, 1.5, 1.0)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	parts.material_override = mat

	var quad = QuadMesh.new()
	quad.size = Vector2(0.04, 0.04)
	parts.mesh = quad

	parent.add_child(parts)
	parts.restart()

	var tree = parent.get_tree()
	if tree != null:
		var timer = tree.create_timer(0.25)
		timer.timeout.connect(func(): if is_instance_valid(parts): parts.queue_free())

## 2. Vector: Laser-thin incandescent ray line connecting start and end points for 2 frames
static func _spawn_vector_ray(parent: Node, start_pos: Vector3, end_pos: Vector3) -> void:
	var ray_node = Node3D.new()
	ray_node.top_level = true
	parent.add_child(ray_node)

	var mesh_inst = MeshInstance3D.new()
	var diff = end_pos - start_pos
	var dist = diff.length()
	if dist < 0.05:
		ray_node.queue_free()
		return

	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.015  # Laser-thin
	cyl.bottom_radius = 0.015
	cyl.height = dist

	mesh_inst.mesh = cyl

	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.2, 1.4, 2.0, 1.0) # Incandescent cyan-white
	mesh_inst.material_override = mat

	# Position cylinder midpoint and align along diff vector
	mesh_inst.position = Vector3(0.0, 0.0, -dist * 0.5)
	mesh_inst.rotation.x = deg_to_rad(90.0)

	ray_node.add_child(mesh_inst)
	ray_node.global_position = start_pos + Vector3(0.0, 0.8, 0.0)
	ray_node.look_at(end_pos + Vector3(0.0, 0.8, 0.0), Vector3.UP)

	# Exists for 2 frames (~0.035s) then disappears
	var tree = parent.get_tree()
	if tree != null:
		var timer = tree.create_timer(0.04)
		timer.timeout.connect(func(): if is_instance_valid(ray_node): ray_node.queue_free())

## 3. Arrival: Cylindrical kinetic shockwave ring puffing outward along the ground
static func _spawn_arrival_shockwave(parent: Node, arrival_pos: Vector3) -> void:
	var ring_node = Node3D.new()
	ring_node.top_level = true
	ring_node.global_position = arrival_pos + Vector3(0.0, 0.05, 0.0)
	parent.add_child(ring_node)

	var mesh_inst = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.35
	torus.outer_radius = 0.45
	torus.rings = 16
	torus.ring_segments = 8
	mesh_inst.mesh = torus

	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.4, 0.85, 1.0, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_inst.material_override = mat
	ring_node.add_child(mesh_inst)

	var tree = parent.get_tree()
	if tree != null:
		var tween = tree.create_tween()
		tween.set_parallel(true)
		# Expands to 2.2m radius and fades out over 0.18s
		tween.tween_property(ring_node, "scale", Vector3(3.5, 0.3, 3.5), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(func(): if is_instance_valid(ring_node): ring_node.queue_free())

