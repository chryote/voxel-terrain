class_name HitImpactSpawner
extends RefCounted

## Utility to spawn hit impact spark bursts at collision points.

static func spawn_hit_sparks(parent: Node, hit_pos: Vector3, hit_normal: Vector3 = Vector3.UP) -> void:
	if parent == null or not parent.is_inside_tree():
		return

	var parts = CPUParticles3D.new()
	parts.top_level = true
	parts.global_position = hit_pos
	parts.amount = 16
	parts.lifetime = 0.25
	parts.one_shot = true
	parts.explosiveness = 0.95
	parts.local_coords = false

	# Bounce sparks outward along surface normal
	parts.direction = (hit_normal + Vector3(0.0, 0.4, 0.0)).normalized()
	parts.spread = 55.0
	parts.initial_velocity_min = 3.5
	parts.initial_velocity_max = 7.0
	parts.gravity = Vector3(0.0, -12.0, 0.0)

	parts.scale_amount_min = 0.02
	parts.scale_amount_max = 0.05

	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.9, 0.6, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.2, 0.9, 0.4, 1.0)
	mat.emission_energy_multiplier = 4.0
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	parts.material_override = mat

	var quad = QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	parts.mesh = quad

	parent.add_child(parts)
	parts.restart()
	parts.emitting = true

	# Auto-free after particles die
	var tree = parent.get_tree()
	if tree != null:
		var timer = tree.create_timer(0.35)
		timer.timeout.connect(func(): if is_instance_valid(parts): parts.queue_free())

