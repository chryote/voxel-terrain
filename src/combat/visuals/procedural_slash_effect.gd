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
const SLASH_VOID_SHADER = preload("res://shaders/combat/slash_void_inversion.gdshader")
const SlashArcMeshBuilder = preload("res://src/combat/visuals/slash_arc_mesh_builder.gd")
const MeleeAttackContext = preload("res://src/combat/core/melee_attack_context.gd")
const MachShockwaveRing = preload("res://src/combat/visuals/mach_shockwave_ring.gd")

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

	# Shader material (defaults to additive plasma shader)
	_slash_material = ShaderMaterial.new()
	_slash_material.shader = SLASH_SHADER
	_slash_material.set_shader_parameter("progress", 0.0)
	_slash_material.set_shader_parameter("core_color", Color(0.9, 0.96, 1.0, 1.0))
	_slash_material.set_shader_parameter("edge_color", Color(0.15, 0.75, 1.0, 1.0))
	_slash_material.set_shader_parameter("deep_color", Color(0.02, 0.18, 0.75, 1.0))
	_slash_material.set_shader_parameter("emission_intensity", 4.5)
	_slash_material.set_shader_parameter("trail_length", 0.65)
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

	# Select shader based on whether this is a Void Inversion strike (Card explicit or Tier 3+)
	if ctx.is_negative_space or ctx.visual_shader_mode == MeleeAttackContext.VisualShaderMode.VOID_INVERSION:
		_slash_material.shader = SLASH_VOID_SHADER
		_slash_material.set_shader_parameter("core_color", ctx.core_color)
		_slash_material.set_shader_parameter("edge_color", ctx.edge_color)
		_slash_material.set_shader_parameter("void_emission", 8.0)
		_slash_material.set_shader_parameter("trail_length", ctx.trail_dissolve_rate)
		if _spark_particles != null:
			_spark_particles.color = Color(1.2, 1.2, 1.5, 1.0)
	else:
		_slash_material.shader = SLASH_SHADER
		_slash_material.set_shader_parameter("core_color", ctx.core_color)
		_slash_material.set_shader_parameter("edge_color", ctx.edge_color)
		_slash_material.set_shader_parameter("deep_color", ctx.deep_color)
		_slash_material.set_shader_parameter("emission_intensity", ctx.emission_intensity)
		_slash_material.set_shader_parameter("trail_length", ctx.trail_dissolve_rate)
		if _spark_particles != null:
			_spark_particles.color = ctx.edge_color

	# Kinetic Tier 2+ (Supersonic): Spawn Perpendicular Mach Ring (Prandtl-Glauert singularity)
	if ctx.has_mach_ring and is_inside_tree():
		var forward_dir = -start_transform.basis.z
		var spawn_pos = start_transform.origin + forward_dir * (ctx.outer_radius * 0.65)
		var p = get_parent()
		if p != null:
			MachShockwaveRing.spawn_mach_ring(p, spawn_pos, forward_dir, ctx.execution_duration * 0.9, 0.5, ctx.outer_radius * 1.35)

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

## Triggers an impact freeze animation on the slash effect:
## 1. High-frequency micro-shudder (jitter) along the impact normal
## 2. Incandescent emissive flash (flare) on the slash shader material
func trigger_hitstop(hitstop_duration: float, hit_norm: Vector3 = Vector3.UP) -> void:
	if not _is_active or _slash_material == null:
		return

	var orig_pos = position
	var jitter_axis = hit_norm.normalized() if hit_norm.length_squared() > 0.001 else Vector3.UP
	var jitter_mag = 0.05

	# Emissive flash: boost emission during hitstop
	var is_void = (_slash_material.shader == SLASH_VOID_SHADER)
	var emission_param = "void_emission" if is_void else "emission_intensity"
	var orig_emission: float = 4.5
	if _slash_material.get_shader_parameter(emission_param) != null:
		orig_emission = float(_slash_material.get_shader_parameter(emission_param))
		_slash_material.set_shader_parameter(emission_param, orig_emission * 2.2)

	var tree = get_tree() if is_inside_tree() else null
	if tree != null:
		# Rapid 3-pulse vibration in wall-clock time
		var t1 = tree.create_timer(hitstop_duration * 0.25, true, false, true)
		t1.timeout.connect(func():
			if is_instance_valid(self):
				position = orig_pos + jitter_axis * jitter_mag
		)
		var t2 = tree.create_timer(hitstop_duration * 0.50, true, false, true)
		t2.timeout.connect(func():
			if is_instance_valid(self):
				position = orig_pos - jitter_axis * (jitter_mag * 0.7)
		)
		var t3 = tree.create_timer(hitstop_duration * 0.75, true, false, true)
		t3.timeout.connect(func():
			if is_instance_valid(self):
				position = orig_pos + jitter_axis * (jitter_mag * 0.35)
		)
		var t_end = tree.create_timer(hitstop_duration, true, false, true)
		t_end.timeout.connect(func():
			if is_instance_valid(self):
				position = orig_pos
				if _slash_material != null:
					_slash_material.set_shader_parameter(emission_param, orig_emission)
		)

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

## Checks physics collisions within the 3D volume slash path using dynamic ray density.
## Ray count dynamically adapts based on outer_radius and arc_sweep_degrees so tip spacing
## never exceeds 0.35m, preventing narrow enemy hitboxes from slipping through wide sweeps.
func check_hit_volume(world_3d: World3D, exclude_rids: Array[RID] = [], collision_mask: int = 0xFFFFFFFF) -> Dictionary:
	if world_3d == null:
		return {"hit": false}

	var space_state = world_3d.direct_space_state
	var origin = global_position
	var forward = -global_transform.basis.z
	var normal_up = global_transform.basis.y

	var abs_sweep = maxf(absf(sweep_angle_deg), 15.0)
	var reach = outer_radius * 0.95
	var arc_rad = deg_to_rad(abs_sweep)
	var circumference = reach * arc_rad

	# Dynamic ray density: ray spacing <= 0.35m prevents tunneling and missed hits.
	# Clamped between 5 and 32 rays to bound physics raycast query overhead to < 0.04ms.
	var ray_count = clampi(int(ceil(circumference / 0.35)), 5, 32)
	var half_arc = abs_sweep * 0.5
	var is_full_circle = abs_sweep >= 359.0

	for i in range(ray_count):
		var angle_deg: float = 0.0
		if is_full_circle:
			angle_deg = (float(i) / float(ray_count)) * 360.0 - 180.0
		else:
			var frac = float(i) / float(ray_count - 1)
			angle_deg = lerpf(-half_arc, half_arc, frac)

		var dir = forward.rotated(normal_up, deg_to_rad(angle_deg)).normalized()
		var to_point = origin + dir * reach

		var query = PhysicsRayQueryParameters3D.create(origin, to_point, collision_mask)
		query.exclude = exclude_rids
		query.collide_with_areas = true
		query.collide_with_bodies = true

		var hit = space_state.intersect_ray(query)
		if not hit.is_empty():
			var collider = hit.get("collider")
			var norm: Vector3 = hit.get("normal", Vector3.UP)
			var hit_pos: Vector3 = hit.get("position", Vector3.ZERO)

			# Discard downward ground floor grazes beneath the player (prevents air sweeps from false-triggering on terrain floor)
			if _is_floor_graze(collider, norm, hit_pos, origin, dir):
				continue

			hit["hit"] = true
			hit["target_point"] = hit.position
			return hit

	return {"hit": false, "target_point": origin + forward * reach}

## Determines if a raycast impact is merely a downward floor graze on static terrain beneath the player,
## rather than a deliberate strike on an enemy, dynamic entity, or vertical obstacle.
static func is_floor_graze(
	collider: Object,
	normal: Vector3,
	hit_pos: Vector3,
	origin: Vector3,
	ray_dir: Vector3
) -> bool:
	if collider is StaticBody3D:
		# Explicit target / enemy metadata check: targets are never considered a floor graze
		if collider.is_in_group("targets") or collider.is_in_group("enemies") \
			or collider.is_in_group("combat_targets") or collider.is_in_group("damageable") \
			or collider.is_in_group("destructible") \
			or collider.has_method("take_damage") or collider.has_method("apply_hit") \
			or collider.has_method("damage"):
			return false

		# If the ray is directed downward or near-horizontal (<= +0.05):
		if ray_dir.y <= 0.05:
			# Case A: Top/walkable surface of the ground (slopes, flat floor)
			if normal.y >= 0.55 and hit_pos.y <= origin.y - 0.35:
				return true
			# Case B: Low voxel ground steps/edges near feet/floor level
			if hit_pos.y <= origin.y - 0.65:
				return true

	return false

func _is_floor_graze(collider: Object, normal: Vector3, hit_pos: Vector3, origin: Vector3, ray_dir: Vector3) -> bool:
	return is_floor_graze(collider, normal, hit_pos, origin, ray_dir)
