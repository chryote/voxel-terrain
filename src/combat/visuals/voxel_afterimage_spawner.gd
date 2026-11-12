class_name VoxelAfterimageSpawner
extends RefCounted

## Spawns static silhouette ghost clones of the player's mesh during high-speed lunges (procedural_todo_combo_depth.md).
## When lunging faster than 15 m/s, spawns 4 silhouette clones every 0.03s
## that fade to transparent with an emissive cyan/gold trail.

const LUNGE_GHOSTING_THRESHOLD_SPEED: float = 15.0 # m/s

## Spawns a single ghost silhouette clone at the given transform
static func spawn_single_afterimage(
	parent: Node,
	source_node: Node3D,
	color_tint: Color = Color(0.2, 0.85, 1.0, 0.7),
	fade_duration: float = 0.24
) -> Node3D:
	if parent == null or not parent.is_inside_tree() or source_node == null:
		return null

	var ghost_root = Node3D.new()
	ghost_root.top_level = true
	ghost_root.global_transform = source_node.global_transform
	parent.add_child(ghost_root)

	# Material: unshaded emissive trail
	var ghost_mat = StandardMaterial3D.new()
	ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ghost_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.albedo_color = color_tint

	var cloned_any_mesh = false

	# Recursively search source_node for visible MeshInstance3D nodes
	var mesh_instances = _find_all_mesh_instances(source_node)
	for mi in mesh_instances:
		if mi.visible and mi.mesh != null:
			var clone_mi = MeshInstance3D.new()
			clone_mi.mesh = mi.mesh
			clone_mi.transform = source_node.global_transform.affine_inverse() * mi.global_transform
			clone_mi.material_override = ghost_mat
			ghost_root.add_child(clone_mi)
			cloned_any_mesh = true

	# Fallback if no mesh instances found: pill silhouette
	if not cloned_any_mesh:
		var fallback_mi = MeshInstance3D.new()
		var cap = CapsuleMesh.new()
		cap.radius = 0.35
		cap.height = 1.4
		fallback_mi.mesh = cap
		fallback_mi.position = Vector3(0.0, 0.7, 0.0)
		fallback_mi.material_override = ghost_mat
		ghost_root.add_child(fallback_mi)

	# Fade out and auto-free
	var tree = parent.get_tree()
	if tree != null:
		var tween = tree.create_tween()
		tween.tween_property(ghost_mat, "albedo_color:a", 0.0, fade_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func():
			if is_instance_valid(ghost_root):
				ghost_root.queue_free()
		)

	return ghost_root

## Spawns a series of afterimage clones along a high-speed lunge
static func spawn_lunge_sequence(
	parent: Node,
	source_node: Node3D,
	lunge_velocity: float,
	count: int = 4,
	interval_sec: float = 0.03
) -> void:
	if parent == null or source_node == null:
		return
	if lunge_velocity < LUNGE_GHOSTING_THRESHOLD_SPEED:
		return

	var tree = parent.get_tree()
	if tree == null:
		return

	# Trail colors shift from cyan to incandescent gold
	var colors = [
		Color(0.2, 0.85, 1.0, 0.75), # Cyan
		Color(0.3, 0.90, 0.9, 0.65), # Cyan-teal
		Color(1.0, 0.85, 0.3, 0.60), # Gold
		Color(1.0, 0.65, 0.1, 0.50)  # Amber
	]

	for i in range(count):
		var delay = float(i) * interval_sec
		var tint = colors[i % colors.size()]
		if delay <= 0.001:
			spawn_single_afterimage(parent, source_node, tint)
		else:
			var timer = tree.create_timer(delay)
			timer.timeout.connect(func():
				if is_instance_valid(source_node) and is_instance_valid(parent):
					spawn_single_afterimage(parent, source_node, tint)
			)

static func _find_all_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		result.append_array(_find_all_mesh_instances(child))
	return result

