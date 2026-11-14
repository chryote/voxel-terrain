class_name VoxelAfterimageSpawner
extends RefCounted

## Spawns static silhouette ghost clones of the player's mesh during high-speed lunges and blinks.
## Distributes silhouettes with clear spatial separation along the motion trajectory to prevent clumping.

const LUNGE_GHOSTING_THRESHOLD_SPEED: float = 15.0 # m/s (legacy constant)
const MIN_GHOST_SPATIAL_SPACING: float = 1.25      # minimum meters between ghosts
const MIN_DISPLACEMENT_FOR_AFTERIMAGES: float = 1.2 # minimum meters of movement required to spawn ghosts

## Internal helper: spawns a single ghost instance from snapshotted mesh definitions
static func _spawn_ghost_instance(
	parent: Node,
	mesh_data: Array,
	xform: Transform3D,
	color_tint: Color,
	fade_duration: float,
	weapon_mesh: Mesh = null,
	weapon_local_xform: Transform3D = Transform3D()
) -> Node3D:
	if parent == null or not is_instance_valid(parent):
		return null

	var ghost_root = Node3D.new()
	ghost_root.top_level = true
	parent.add_child(ghost_root)
	if ghost_root.is_inside_tree():
		ghost_root.global_transform = xform
	else:
		ghost_root.transform = xform

	# Material: unshaded emissive trail with additive glow
	var ghost_mat = StandardMaterial3D.new()
	ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ghost_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.albedo_color = color_tint

	for entry in mesh_data:
		var clone_mi = MeshInstance3D.new()
		clone_mi.mesh = entry["mesh"]
		clone_mi.transform = entry["local_transform"]
		clone_mi.material_override = ghost_mat
		ghost_root.add_child(clone_mi)

	# Dynamic move snapshot of the floating weapon
	if weapon_mesh != null:
		var weapon_mi = MeshInstance3D.new()
		weapon_mi.name = "GhostWeaponSnapshot"
		weapon_mi.mesh = weapon_mesh
		weapon_mi.transform = weapon_local_xform
		weapon_mi.material_override = ghost_mat
		ghost_root.add_child(weapon_mi)

	# Fade out and auto-free
	var tree = parent.get_tree() if parent.is_inside_tree() else null
	if tree != null:
		var tween = tree.create_tween()
		tween.tween_property(ghost_mat, "albedo_color:a", 0.0, fade_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func():
			if is_instance_valid(ghost_root):
				ghost_root.queue_free()
		)

	return ghost_root

## Spawns a single ghost silhouette clone at the given transform
static func spawn_single_afterimage(
	parent: Node,
	source_node: Node3D,
	color_tint: Color = Color(0.2, 0.85, 1.0, 0.7),
	fade_duration: float = 0.24,
	custom_transform: Transform3D = Transform3D(),
	weapon_mesh: Mesh = null,
	attack_ctx: RefCounted = null
) -> Node3D:
	if parent == null or not is_instance_valid(parent) or source_node == null:
		return null

	var mesh_data = _extract_mesh_data(source_node)
	var effective_weapon_mesh = _extract_weapon_mesh(source_node, weapon_mesh)
	var weapon_xform = compute_dynamic_weapon_transform(attack_ctx, 0.5)

	var xform = custom_transform
	if xform == Transform3D():
		xform = source_node.global_transform if source_node.is_inside_tree() else source_node.transform
	return _spawn_ghost_instance(parent, mesh_data, xform, color_tint, fade_duration, effective_weapon_mesh, weapon_xform)

## Computes a dynamic 3D transform for the floating weapon snapshot along an attack slash arc.
## Freezes the weapon at progress_t (0.0 to 1.0) along the arc sweep, matching the weapon's
## length, tilt angle, radial position, and cutting edge orientation.
static func compute_dynamic_weapon_transform(
	ctx: RefCounted = null,
	progress_t: float = 0.5,
	chest_height: float = 0.95
) -> Transform3D:
	var sweep_deg: float = 135.0
	var inner_r: float = 0.75
	var outer_r: float = 2.45
	var tilt_deg: float = -10.0
	var is_reversed: bool = false

	if ctx != null:
		if "arc_sweep_degrees" in ctx:
			sweep_deg = ctx.arc_sweep_degrees
		if "inner_radius" in ctx:
			inner_r = ctx.inner_radius
		if "outer_radius" in ctx:
			outer_r = ctx.outer_radius
		if "tilt_degrees" in ctx:
			tilt_deg = ctx.tilt_degrees
		if "is_reversed_sweep" in ctx:
			is_reversed = ctx.is_reversed_sweep

	var arc_rad: float = deg_to_rad(sweep_deg)
	var start_angle: float = -arc_rad * 0.5
	var t_clamped: float = clampf(progress_t, 0.0, 1.0)

	var current_angle: float
	var sweep_sign: float = 1.0
	if not is_reversed:
		current_angle = start_angle + t_clamped * arc_rad
		sweep_sign = 1.0
	else:
		current_angle = (arc_rad * 0.5) - t_clamped * arc_rad
		sweep_sign = -1.0

	# Radial direction in horizontal plane (matching SlashArcMeshBuilder: (sin(a), 0, -cos(a)))
	var dir = Vector3(sin(current_angle), 0.0, -cos(current_angle)).normalized()
	# Tangent vector along cutting sweep velocity (derivative with respect to angle)
	var tangent = Vector3(cos(current_angle), 0.0, sin(current_angle)) * sweep_sign

	# Apply slash plane tilt around the optical/forward axis (matching ProceduralSlashEffect)
	var tilt_rad = deg_to_rad(tilt_deg)
	var tilt_rot = Basis(Vector3(0.0, 0.0, 1.0), tilt_rad)
	var tilted_dir = (tilt_rot * dir).normalized()
	var tilted_tangent = (tilt_rot * tangent).normalized()

	# Orthonormal basis:
	# Weapon local +Y (blade axis extending outward from handle) = tilted_dir
	# Weapon local +X (striking edge facing sweep velocity) = tilted_tangent
	# Weapon local +Z = b_x.cross(b_y)
	var b_y = tilted_dir
	var b_x = tilted_tangent
	var b_z = b_x.cross(b_y).normalized()
	b_x = b_y.cross(b_z).normalized()

	var weapon_basis = Basis(b_x, b_y, b_z)

	# Dynamic attack lean: blade angles into the cut by 12 degrees
	weapon_basis = weapon_basis * Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(12.0 * sweep_sign))

	# Position the weapon handle at inner_radius from chest origin along the radial direction
	var chest_origin = Vector3(0.0, chest_height, 0.0)
	var weapon_pos = chest_origin + tilted_dir * clampf(inner_r, 0.35, 1.25)

	return Transform3D(weapon_basis, weapon_pos)

## Generates a rich Prismatic / Rainbow Dispersion color spectrum.
## Disperses through the full optical rainbow (Magenta -> Violet -> Azure -> Cyan -> Emerald -> Gold -> Orange -> Scarlet).
## If base_color is specified (not WHITE), anchors the dispersion to base_color's hue and sweeps across the chromatic wheel.
static func get_prismatic_palette(count: int, base_color: Color = Color.WHITE) -> Array[Color]:
	var palette: Array[Color] = []
	var n = maxi(count, 1)

	var spectrum_hues = [
		0.83, # Neon Magenta / Pink (~300 deg)
		0.74, # Electric Violet (~266 deg)
		0.58, # Royal Azure Blue (~210 deg)
		0.48, # Bright Cyan (~173 deg)
		0.36, # Radiant Emerald Green (~130 deg)
		0.14, # Intense Solar Gold (~50 deg)
		0.07, # Vivid Orange (~25 deg)
		0.00  # Prismatic Scarlet (~0 deg)
	]

	var is_custom_base = (base_color != Color.WHITE and base_color.a > 0.0)
	var anchor_hue = base_color.h if is_custom_base else 0.83

	for i in range(n):
		var t = float(i) / maxf(float(n - 1), 1.0)
		var hue: float
		if is_custom_base:
			# Disperse 270 degrees around the chromatic wheel from base_color's hue
			hue = fmod(anchor_hue + t * 0.75, 1.0)
		else:
			var idx = int(t * float(spectrum_hues.size() - 1))
			var next_idx = mini(idx + 1, spectrum_hues.size() - 1)
			var local_t = (t * float(spectrum_hues.size() - 1)) - float(idx)
			hue = lerpf(spectrum_hues[idx], spectrum_hues[next_idx], local_t)

		# Alpha cascades: newest ghosts are punchy (0.80), trailing tail fades to 0.35
		var alpha = lerpf(0.80, 0.35, t)

		# HDR-boosted chromatic color for glowing additive rendering
		var base_col = Color.from_hsv(hue, 0.92, 1.0, alpha)
		var hdr_col = Color(base_col.r * 1.30, base_col.g * 1.30, base_col.b * 1.30, alpha)
		palette.append(hdr_col)

	return palette

## Inner helper node that attaches to the tree and drops afterimages in the real body's physical wake
class AfterimageWakeTracker extends Node:
	var _parent: Node
	var _source_node: Node3D
	var _remaining_time: float = 0.25
	var _max_count: int = 5
	var _min_spacing: float = 1.25
	var _fade_duration: float = 0.35
	var _last_drop_pos: Vector3 = Vector3.ZERO
	var _dropped_count: int = 0
	var _mesh_data: Array[Dictionary] = []
	var _colors: Array[Color] = []
	var _spawn_callable: Callable
	var _weapon_mesh: Mesh = null
	var _attack_ctx: RefCounted = null
	var _weapon_xform_func: Callable

	func setup(
		p_parent: Node,
		p_source: Node3D,
		p_mesh_data: Array[Dictionary],
		p_colors: Array[Color],
		p_spawn_callable: Callable,
		p_duration: float,
		p_max: int,
		p_spacing: float,
		p_fade: float,
		p_weapon_mesh: Mesh = null,
		p_attack_ctx: RefCounted = null,
		p_weapon_xform_func: Callable = Callable()
	) -> void:
		_parent = p_parent
		_source_node = p_source
		_mesh_data = p_mesh_data
		_colors = p_colors
		_spawn_callable = p_spawn_callable
		_remaining_time = maxf(p_duration + 0.12, 0.24)
		_max_count = maxi(p_max, 1)
		_min_spacing = maxf(p_spacing, MIN_GHOST_SPATIAL_SPACING)
		_fade_duration = p_fade
		_last_drop_pos = p_source.global_position if p_source.is_inside_tree() else p_source.position
		_weapon_mesh = p_weapon_mesh
		_attack_ctx = p_attack_ctx
		_weapon_xform_func = p_weapon_xform_func

	func _process(delta: float) -> void:
		if not is_instance_valid(_source_node) or not is_instance_valid(_parent):
			queue_free()
			return

		_remaining_time -= delta
		var current_pos = _source_node.global_position if _source_node.is_inside_tree() else _source_node.position
		var dist_moved = (current_pos - _last_drop_pos).length()

		# Whenever the real body has advanced at least _min_spacing from the last drop point:
		if dist_moved >= _min_spacing and _dropped_count < _max_count:
			# Drop the silhouette at _last_drop_pos, facing with source_node's orientation
			var basis = _source_node.global_transform.basis if _source_node.is_inside_tree() else _source_node.transform.basis
			var ghost_xform = Transform3D(basis, _last_drop_pos)
			var tint = _colors[_dropped_count % _colors.size()]

			var progress_t = clampf(float(_dropped_count + 1) / float(_max_count + 1), 0.15, 0.90)
			var weapon_xform = Transform3D()
			if _weapon_xform_func.is_valid():
				weapon_xform = _weapon_xform_func.call(_attack_ctx, progress_t)

			if _spawn_callable.is_valid():
				_spawn_callable.call(_parent, _mesh_data, ghost_xform, tint, _fade_duration, _weapon_mesh, weapon_xform)

			_last_drop_pos = current_pos
			_dropped_count += 1

		if _remaining_time <= 0.0 or _dropped_count >= _max_count:
			queue_free()

## Actively drops afterimages in the real body's physical wake as it moves across space
static func spawn_wake_trail(
	parent: Node,
	source_node: Node3D,
	duration: float = 0.25,
	max_count: int = 5,
	base_color: Color = Color.WHITE,
	min_spacing: float = MIN_GHOST_SPATIAL_SPACING,
	fade_duration: float = 0.35,
	fallback_end_pos: Vector3 = Vector3.ZERO,
	weapon_mesh: Mesh = null,
	attack_ctx: RefCounted = null
) -> Node:
	if parent == null or source_node == null or not is_instance_valid(parent):
		return null

	var effective_weapon_mesh = _extract_weapon_mesh(source_node, weapon_mesh)

	var tree = parent.get_tree() if parent.is_inside_tree() else null
	if tree == null and fallback_end_pos != Vector3.ZERO:
		var start_pos = source_node.global_position if source_node.is_inside_tree() else source_node.position
		spawn_trajectory_sequence(parent, source_node, start_pos, fallback_end_pos, duration, max_count, base_color, fade_duration, effective_weapon_mesh, attack_ctx)
		return null

	var mesh_data = _extract_mesh_data(source_node)
	var colors = get_prismatic_palette(max_count, base_color)
	var tracker = AfterimageWakeTracker.new()
	tracker.setup(
		parent,
		source_node,
		mesh_data,
		colors,
		Callable(_spawn_ghost_instance),
		duration,
		max_count,
		min_spacing,
		fade_duration,
		effective_weapon_mesh,
		attack_ctx,
		Callable(compute_dynamic_weapon_transform)
	)
	parent.add_child(tracker)
	return tracker

## Spawns afterimages spaced evenly along a physical displacement path (lunge, dash, or blink).
## Enforces minimum spatial spacing (MIN_GHOST_SPATIAL_SPACING) to completely prevent clumping.
static func spawn_trajectory_sequence(
	parent: Node,
	source_node: Node3D,
	start_pos: Vector3,
	end_pos: Vector3,
	duration: float = 0.16,
	count: int = 4,
	base_color: Color = Color.WHITE,
	fade_duration: float = 0.28,
	weapon_mesh: Mesh = null,
	attack_ctx: RefCounted = null
) -> void:
	if parent == null or source_node == null or not is_instance_valid(parent):
		return

	var diff = end_pos - start_pos
	var total_dist = diff.length()

	# Completely suppress afterimages if movement distance is too small to prevent overlapping with player body
	if total_dist < MIN_DISPLACEMENT_FOR_AFTERIMAGES:
		return

	# Pre-extract visible mesh instances and relative transforms from source_node
	var mesh_data = _extract_mesh_data(source_node)
	var effective_weapon_mesh = _extract_weapon_mesh(source_node, weapon_mesh)

	# Determine effective count so that spacing is at least MIN_GHOST_SPATIAL_SPACING
	var max_allowed_by_distance = maxi(int(total_dist / MIN_GHOST_SPATIAL_SPACING), 1)
	var effective_count = clampi(count, 1, max_allowed_by_distance)

	var tree = parent.get_tree() if parent.is_inside_tree() else null
	var base_basis = source_node.global_transform.basis if source_node.is_inside_tree() else source_node.transform.basis

	# Prismatic / Rainbow Dispersion Palette
	var colors = get_prismatic_palette(effective_count, base_color)

	var is_instant = (duration <= 0.05)

	for i in range(effective_count):
		# Fraction along the trajectory (spaced between start and end, with last ghost staying behind arrival pos)
		var fraction = float(i) / float(effective_count)
		var ghost_pos = start_pos + diff * fraction
		var ghost_xform = Transform3D(base_basis, ghost_pos)

		var tint = colors[i % colors.size()]

		var progress_t = clampf(float(i + 1) / float(effective_count + 1), 0.15, 0.90)
		var weapon_xform = compute_dynamic_weapon_transform(attack_ctx, progress_t)

		var effective_fade = fade_duration
		if is_instant:
			# For instantaneous blinks: spawn all silhouettes immediately along warp vector
			# with cascading fadeout (origin fades out earlier than destination)
			effective_fade = fade_duration * (0.75 + 0.25 * fraction)
			_spawn_ghost_instance(parent, mesh_data, ghost_xform, tint, effective_fade, effective_weapon_mesh, weapon_xform)
		else:
			# For lunges: stagger spawns in sync with character travel
			var spawn_delay = duration * fraction
			if spawn_delay <= 0.001 or tree == null:
				_spawn_ghost_instance(parent, mesh_data, ghost_xform, tint, effective_fade, effective_weapon_mesh, weapon_xform)
			else:
				var timer = tree.create_timer(spawn_delay)
				timer.timeout.connect(_spawn_ghost_instance.bind(parent, mesh_data, ghost_xform, tint, effective_fade, effective_weapon_mesh, weapon_xform))

## Legacy helper: spawns afterimage sequence while enforcing spatial separation
static func spawn_lunge_sequence(
	parent: Node,
	source_node: Node3D,
	lunge_velocity: float,
	count: int = 4,
	interval_sec: float = 0.03,
	weapon_mesh: Mesh = null,
	attack_ctx: RefCounted = null
) -> void:
	if parent == null or source_node == null or not is_instance_valid(parent):
		return

	var start_pos = source_node.global_position if source_node.is_inside_tree() else source_node.position
	var source_basis = source_node.global_transform.basis if source_node.is_inside_tree() else source_node.transform.basis
	var forward = -source_basis.z.normalized()
	var duration = interval_sec * float(count)
	var est_distance = maxf(lunge_velocity * duration, MIN_GHOST_SPATIAL_SPACING * float(count))
	var end_pos = start_pos + forward * est_distance

	spawn_trajectory_sequence(parent, source_node, start_pos, end_pos, duration, count, Color.WHITE, 0.28, weapon_mesh, attack_ctx)

## Extracts the weapon mesh from the source node or its attached FloatingWeaponController.
static func _extract_weapon_mesh(source_node: Node3D, override_mesh: Mesh = null) -> Mesh:
	if override_mesh != null:
		return override_mesh
	if source_node == null:
		return null

	# 1. Direct call if source_node has get_weapon_mesh()
	if source_node.has_method("get_weapon_mesh"):
		var m = source_node.call("get_weapon_mesh")
		if m is Mesh:
			return m

	# 2. Check for floating_weapon or floating_sword property or child node
	var fw = null
	if "floating_weapon" in source_node and source_node.get("floating_weapon") != null:
		fw = source_node.get("floating_weapon")
	elif "floating_sword" in source_node and source_node.get("floating_sword") != null:
		fw = source_node.get("floating_sword")
	elif source_node.has_node("FloatingWeaponController"):
		fw = source_node.get_node("FloatingWeaponController")
	elif source_node.has_node("FloatingSwordController"):
		fw = source_node.get_node("FloatingSwordController")

	if fw != null and is_instance_valid(fw):
		if fw.has_method("get_weapon_mesh"):
			var m = fw.call("get_weapon_mesh")
			if m is Mesh:
				return m
		var mi = _find_first_weapon_mesh_instance(fw)
		if mi != null and mi.mesh != null:
			return mi.mesh

	# 3. Direct child search in source_node for weapon mesh instances
	var mi_direct = _find_first_weapon_mesh_instance(source_node)
	if mi_direct != null and mi_direct.mesh != null:
		return mi_direct.mesh

	return null

static func _find_first_weapon_mesh_instance(node: Node) -> MeshInstance3D:
	if node == null:
		return null
	if node is MeshInstance3D:
		var n_low = node.name.to_lower()
		if n_low.contains("weapon") or n_low.contains("sword"):
			return node as MeshInstance3D
	for child in node.get_children():
		var found = _find_first_weapon_mesh_instance(child)
		if found != null:
			return found
	return null

static func _extract_mesh_data(source_node: Node3D) -> Array[Dictionary]:
	var mesh_data: Array[Dictionary] = []
	if source_node == null:
		return mesh_data

	# Prefer extracting purely from visual_assembler (pawn body) if available on player
	var search_root: Node = source_node
	if "visual_assembler" in source_node and source_node.get("visual_assembler") != null:
		search_root = source_node.get("visual_assembler")
	elif source_node.has_node("PawnVisualAssembler"):
		search_root = source_node.get_node("PawnVisualAssembler")

	var mesh_instances = _find_all_mesh_instances(search_root)
	var inv_source_xform = (source_node.global_transform if source_node.is_inside_tree() else source_node.transform).affine_inverse()
	for mi in mesh_instances:
		var is_vis = mi.is_visible_in_tree() if mi.is_inside_tree() else mi.visible
		if is_vis and mi.mesh != null:
			if _is_weapon_or_accessory(mi):
				continue
			var mi_xform = mi.global_transform if mi.is_inside_tree() else mi.transform
			mesh_data.append({
				"mesh": mi.mesh,
				"local_transform": inv_source_xform * mi_xform
			})

	if mesh_data.is_empty():
		var cap = CapsuleMesh.new()
		cap.radius = 0.35
		cap.height = 1.4
		mesh_data.append({
			"mesh": cap,
			"local_transform": Transform3D(Basis(), Vector3(0.0, 0.7, 0.0))
		})
	return mesh_data

static func _find_all_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node == null:
		return result
	if node is MeshInstance3D:
		if not _is_weapon_or_accessory(node):
			result.append(node as MeshInstance3D)
	for child in node.get_children():
		if _is_weapon_or_accessory(child):
			continue
		result.append_array(_find_all_mesh_instances(child))
	return result

static func _is_weapon_or_accessory(node: Node) -> bool:
	var curr: Node = node
	while curr != null:
		var name_lower = curr.name.to_lower()
		if name_lower.contains("weapon") or name_lower.contains("sword") or name_lower.contains("floating") or name_lower.contains("camera"):
			return true
		curr = curr.get_parent()
	return false

