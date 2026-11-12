class_name CataclysmEventSpawner
extends RefCounted

## Manages the 1-Billion Joule Cataclysm Event visuals (procedural_todo_combo_depth.md).
## Dispatches:
## 1. 1-frame full-screen inverted color flash.
## 2. Radial shockwave rings expanding across the arena.
## 3. Lingering gravitational implosion spark.

static func trigger_cataclysm(tree_root: Node, impact_pos: Vector3, impact_normal: Vector3 = Vector3.UP) -> void:
	if tree_root == null or not tree_root.is_inside_tree():
		return

	spawn_screen_flash(tree_root)
	spawn_radial_shockwave(tree_root, impact_pos, impact_normal)
	spawn_gravitational_implosion(tree_root, impact_pos)

## 1. Full-screen inverted / incandescent color flash (1-2 frames)
static func spawn_screen_flash(parent: Node) -> void:
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 120
	parent.add_child(canvas_layer)

	var rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(1.0, 1.0, 1.0, 0.90) # Incandescent flash
	canvas_layer.add_child(rect)

	var tree = parent.get_tree()
	if tree != null:
		var tween = tree.create_tween()
		# Fast fade out over 0.06s (approx 2-3 frames at 60Hz)
		tween.tween_property(rect, "color:a", 0.0, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func():
			if is_instance_valid(canvas_layer):
				canvas_layer.queue_free()
		)

## 2. Radial shockwave rings expanding across the arena ground
static func spawn_radial_shockwave(parent: Node, pos: Vector3, normal: Vector3 = Vector3.UP) -> void:
	var ring_node = Node3D.new()
	ring_node.top_level = true
	ring_node.global_position = pos
	parent.add_child(ring_node)

	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "ArenaShockwaveMesh"
	ring_node.add_child(mesh_inst)

	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.85, 0.95, 1.0, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_inst.material_override = mat

	# Generate flat expanding ring on ground plane
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments = 36
	for i in range(segments):
		var th0 = float(i) * TAU / float(segments)
		var th1 = float(i + 1) * TAU / float(segments)
		var v0_in = Vector3(cos(th0) * 0.8, 0.05, sin(th0) * 0.8)
		var v1_in = Vector3(cos(th1) * 0.8, 0.05, sin(th1) * 0.8)
		var v0_out = Vector3(cos(th0) * 1.0, 0.05, sin(th0) * 1.0)
		var v1_out = Vector3(cos(th1) * 1.0, 0.05, sin(th1) * 1.0)

		st.add_vertex(v0_in)
		st.add_vertex(v0_out)
		st.add_vertex(v1_out)

		st.add_vertex(v0_in)
		st.add_vertex(v1_out)
		st.add_vertex(v1_in)
	mesh_inst.mesh = st.commit()

	# Animate expansion across arena (scale to 24.0m radius over 0.28s)
	var tree = parent.get_tree()
	if tree != null:
		var tween = tree.create_tween()
		tween.set_parallel(true)
		tween.tween_property(ring_node, "scale", Vector3(24.0, 1.0, 24.0), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(func():
			if is_instance_valid(ring_node):
				ring_node.queue_free()
		)

## 3. Lingering gravitational implosion spark (black singularity sphere + inward suction)
static func spawn_gravitational_implosion(parent: Node, pos: Vector3) -> void:
	var singularity = Node3D.new()
	singularity.top_level = true
	singularity.global_position = pos + Vector3(0.0, 0.5, 0.0)
	parent.add_child(singularity)

	# Pitch black micro-sphere
	var core_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	core_mesh.mesh = sphere

	var core_mat = StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = Color(0.0, 0.0, 0.0, 1.0) # Absolute black void
	core_mesh.material_override = core_mat
	singularity.add_child(core_mesh)

	# Inward suction particles
	var suction = CPUParticles3D.new()
	suction.amount = 32
	suction.lifetime = 0.25
	suction.explosiveness = 0.3
	suction.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	suction.emission_sphere_radius = 2.0
	suction.radial_accel_min = -18.0
	suction.radial_accel_max = -28.0 # Strong pull towards center
	suction.gravity = Vector3.ZERO
	suction.scale_amount_min = 0.03
	suction.scale_amount_max = 0.06

	var part_mat = StandardMaterial3D.new()
	part_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	part_mat.albedo_color = Color(1.0, 1.0, 1.2, 0.9)
	part_mat.emission_enabled = true
	part_mat.emission = Color(1.2, 1.2, 1.5, 1.0)
	part_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	suction.material_override = part_mat

	var quad = QuadMesh.new()
	quad.size = Vector2(0.04, 0.04)
	suction.mesh = quad
	singularity.add_child(suction)
	suction.restart()

	var tree = parent.get_tree()
	if tree != null:
		# Singularity hangs for 0.18s, then shrinks into nothing
		var tween = tree.create_tween()
		tween.tween_interval(0.18)
		tween.tween_property(singularity, "scale", Vector3.ZERO, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_callback(func():
			if is_instance_valid(singularity):
				singularity.queue_free()
		)

