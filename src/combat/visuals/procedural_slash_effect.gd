class_name ProceduralSlashEffect
extends Node3D

## Manages an animated 3D volumetric VFX slash instance.
## Controls the parametric arc mesh, procedural slash shader progress,
## spark particle bursts, and impact detection.

signal slash_finished

@export var duration: float = 0.28
@export var sweep_angle_deg: float = 135.0
@export var inner_radius: float = 0.75
@export var outer_radius: float = 2.45

var _mesh_instance: MeshInstance3D
var _slash_material: ShaderMaterial
var _spark_particles: CPUParticles3D
var _is_active: bool = false
var _progress: float = 0.0

const SLASH_SHADER = preload("res://shaders/combat/slash_volume.gdshader")
const SlashArcMeshBuilder = preload("res://src/combat/visuals/slash_arc_mesh_builder.gd")
const MeleeAttackContext = preload("res://src/combat/core/melee_attack_context.gd")

func _init() -> void:
	top_level = true # In world space so it doesn't skew with subsequent player movements

func _ready() -> void:
	_setup_visuals()

func _setup_visuals() -> void:
	if _mesh_instance != null:
		return

	# Build 3D volumetric arc mesh
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "SlashArcMesh"
	_mesh_instance.mesh = SlashArcMeshBuilder.build_volumetric_slash_mesh(
		inner_radius,
		outer_radius,
		deg_to_rad(sweep_angle_deg),
		0.22,
		0.025,
		36
	)

	# Shader material
	_slash_material = ShaderMaterial.new()
	_slash_material.shader = SLASH_SHADER
	_slash_material.set_shader_parameter("progress", 0.0)
	_mesh_instance.material_override = _slash_material
	add_child(_mesh_instance)

	# Spark particles along the cutting arc
	_spark_particles = _create_spark_particles()
	_spark_particles.name = "SlashSparkParticles"
	add_child(_spark_particles)

## Plays slash using a card-compiled MeleeAttackContext.
## Configures 3D arc geometry, duration (speed), and shader colors directly from the card.
func play_context(start_transform: Transform3D, ctx: MeleeAttackContext) -> void:
	inner_radius = ctx.inner_radius
	outer_radius = ctx.outer_radius
	sweep_angle_deg = ctx.arc_sweep_degrees

	_setup_visuals()

	# Rebuild mesh with card-defined parameters if different from defaults
	_mesh_instance.mesh = SlashArcMeshBuilder.build_volumetric_slash_mesh(
		ctx.inner_radius,
		ctx.outer_radius,
		deg_to_rad(ctx.arc_sweep_degrees),
		ctx.volume_thickness,
		ctx.outer_height,
		36
	)

	# Apply card-defined shader parameters
	_slash_material.set_shader_parameter("core_color", ctx.core_color)
	_slash_material.set_shader_parameter("edge_color", ctx.edge_color)
	_slash_material.set_shader_parameter("deep_color", ctx.deep_color)
	_slash_material.set_shader_parameter("emission_intensity", ctx.emission_intensity)
	_slash_material.set_shader_parameter("trail_length", ctx.trail_dissolve_rate)

	# Tint spark particles to match card edge color
	if _spark_particles != null:
		_spark_particles.color = ctx.edge_color

	# Dispatch animation with card-defined execution_duration
	play(start_transform, ctx.execution_duration, ctx.tilt_degrees, ctx.is_reversed_sweep)

func play(
	start_transform: Transform3D,
	attack_duration: float = 0.28,
	tilt_deg: float = 0.0,
	reverse_sweep: bool = false
) -> void:
	_setup_visuals()
	duration = attack_duration
	global_transform = start_transform

	# Apply slash plane tilt (e.g. diagonal cut, upswing, downcleave)
	if absf(tilt_deg) > 0.01:
		rotate_object_local(Vector3(0.0, 0.0, 1.0), deg_to_rad(tilt_deg))

	# Reverse sweep for combo alternating (flip horizontally)
	if reverse_sweep:
		scale = Vector3(-1.0, 1.0, 1.0)
	else:
		scale = Vector3(1.0, 1.0, 1.0)

	_is_active = true
	_progress = 0.0
	_slash_material.set_shader_parameter("progress", 0.0)

	# Fire spark burst
	_spark_particles.restart()
	_spark_particles.emitting = true

	# Animate progress via tween
	var tween = create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_on_completed)

func _set_progress(val: float) -> void:
	_progress = val
	if _slash_material != null:
		_slash_material.set_shader_parameter("progress", val)

func _on_completed() -> void:
	_is_active = false
	slash_finished.emit()
	queue_free()

func _create_spark_particles() -> CPUParticles3D:
	var parts = CPUParticles3D.new()
	parts.amount = 24
	parts.lifetime = 0.22
	parts.one_shot = true
	parts.explosiveness = 0.85
	parts.local_coords = true

	# Emission along forward-facing cutting rim
	parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	parts.emission_ring_axis = Vector3(0.0, 1.0, 0.0)
	parts.emission_ring_radius = 1.6
	parts.emission_ring_inner_radius = 1.0
	parts.emission_ring_height = 0.1

	parts.direction = Vector3(0.0, 0.1, -1.0)
	parts.spread = 45.0
	parts.gravity = Vector3(0.0, -9.8, 0.0)
	parts.initial_velocity_min = 4.0
	parts.initial_velocity_max = 9.5

	parts.scale_amount_min = 0.03
	parts.scale_amount_max = 0.07

	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.4, 0.9, 1.0, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.9, 1.2, 1.0)
	mat.emission_energy_multiplier = 4.0
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	parts.material_override = mat

	var quad = QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	parts.mesh = quad

	return parts

## Checks physics collisions within the 3D volume slash path
func check_hit_volume(world_3d: World3D, exclude_rids: Array[RID] = []) -> Dictionary:
	if world_3d == null:
		return {"hit": false}

	var space_state = world_3d.direct_space_state
	var origin = global_position
	var forward = -global_transform.basis.z

	# Cast a multi-point fan along the arc to detect solid bodies or voxel terrain
	var test_angles = [-35.0, -15.0, 0.0, 15.0, 35.0]
	var reach = outer_radius * 0.95

	for angle in test_angles:
		var dir = forward.rotated(global_transform.basis.y, deg_to_rad(angle)).normalized()
		var to_point = origin + dir * reach

		var query = PhysicsRayQueryParameters3D.create(origin, to_point)
		query.exclude = exclude_rids
		query.collide_with_areas = false
		query.collide_with_bodies = true

		var hit = space_state.intersect_ray(query)
		if not hit.is_empty():
			hit["hit"] = true
			hit["target_point"] = hit.position
			return hit

	return {"hit": false, "target_point": origin + forward * reach}
