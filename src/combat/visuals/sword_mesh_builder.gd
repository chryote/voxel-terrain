class_name SwordMeshBuilder
extends RefCounted

## Generates a procedural stylized 3D sword mesh and visual node hierarchy.
## Creates high-detail geometry (blade, crossguard, grip, pommel, glowing runes)
## without needing external DCC assets.

static func create_sword_node() -> Node3D:
	var root = Node3D.new()
	root.name = "SwordVisualRoot"

	# Main sword mesh instance
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "SwordMeshInstance"
	mesh_inst.mesh = build_sword_mesh()
	root.add_child(mesh_inst)

	# Ambient magic motes floating around the blade
	var aura_particles = _create_blade_aura_particles()
	aura_particles.name = "BladeAuraParticles"
	root.add_child(aura_particles)

	return root

static func build_sword_mesh() -> ArrayMesh:
	var st = SurfaceTool.new()
	var mesh = ArrayMesh.new()

	# --- Surface 0: Blade (Metallic Steel) ---
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blade_mat = StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.88, 0.92, 0.98, 1.0)
	blade_mat.metallic = 0.95
	blade_mat.roughness = 0.20
	blade_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(blade_mat)

	_build_blade_geometry(st)
	st.generate_normals()
	st.commit(mesh)

	# --- Surface 1: Glowing Blade Fuller / Runes ---
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rune_mat = StandardMaterial3D.new()
	rune_mat.albedo_color = Color(0.2, 0.85, 1.0, 1.0)
	rune_mat.emission_enabled = true
	rune_mat.emission = Color(0.15, 0.85, 1.2, 1.0)
	rune_mat.emission_energy_multiplier = 3.5
	rune_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(rune_mat)

	_build_fuller_runes(st)
	st.generate_normals()
	st.commit(mesh)

	# --- Surface 2: Crossguard and Pommel (Dark Metal / Gold Accents) ---
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var guard_mat = StandardMaterial3D.new()
	guard_mat.albedo_color = Color(0.16, 0.18, 0.22, 1.0)
	guard_mat.metallic = 0.88
	guard_mat.roughness = 0.28
	guard_mat.cull_mode = BaseMaterial3D.CULL_BACK
	st.set_material(guard_mat)

	_build_crossguard(st)
	_build_pommel(st)
	st.generate_normals()
	st.commit(mesh)

	# --- Surface 3: Grip (Leather Wrap) ---
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grip_mat = StandardMaterial3D.new()
	grip_mat.albedo_color = Color(0.14, 0.10, 0.08, 1.0)
	grip_mat.roughness = 0.82
	grip_mat.metallic = 0.05
	st.set_material(grip_mat)

	_build_grip(st)
	st.generate_normals()
	st.commit(mesh)

	return mesh

static func _build_blade_geometry(st: SurfaceTool) -> void:
	# Blade sections along Y from hilt (0.0) to tip (1.18)
	var sections: Array[Dictionary] = [
		{"y": 0.00, "w": 0.075, "t": 0.018},
		{"y": 0.35, "w": 0.070, "t": 0.016},
		{"y": 0.75, "w": 0.060, "t": 0.013},
		{"y": 1.05, "w": 0.040, "t": 0.009},
		{"y": 1.18, "w": 0.002, "t": 0.002}
	]

	for i in range(sections.size() - 1):
		var s0 = sections[i]
		var s1 = sections[i + 1]

		# Diamond profile vertices: 
		# Left edge (-X), Center front (+Z), Right edge (+X), Center back (-Z)
		var v0_l = Vector3(-s0["w"], s0["y"], 0.0)
		var v0_f = Vector3(0.0, s0["y"], s0["t"])
		var v0_r = Vector3(s0["w"], s0["y"], 0.0)
		var v0_b = Vector3(0.0, s0["y"], -s0["t"])

		var v1_l = Vector3(-s1["w"], s1["y"], 0.0)
		var v1_f = Vector3(0.0, s1["y"], s1["t"])
		var v1_r = Vector3(s1["w"], s1["y"], 0.0)
		var v1_b = Vector3(0.0, s1["y"], -s1["t"])

		# Front Left facet
		_add_quad(st, v0_l, v1_l, v1_f, v0_f)
		# Front Right facet
		_add_quad(st, v0_f, v1_f, v1_r, v0_r)
		# Back Right facet
		_add_quad(st, v0_r, v1_r, v1_b, v0_b)
		# Back Left facet
		_add_quad(st, v0_b, v1_b, v1_l, v0_l)

static func _build_fuller_runes(st: SurfaceTool) -> void:
	# Subtle thin glowing fuller running down the center of the blade
	var y_start = 0.06
	var y_end = 0.88
	var w = 0.009
	var z_front = 0.017
	var z_back = -0.017

	# Front rune strip
	st.set_uv(Vector2(0.0, 0.0))
	var f0 = Vector3(-w, y_start, z_front)
	var f1 = Vector3(-w, y_end, z_front * 0.7)
	var f2 = Vector3(w, y_end, z_front * 0.7)
	var f3 = Vector3(w, y_start, z_front)
	_add_quad(st, f0, f1, f2, f3)

	# Back rune strip
	var b0 = Vector3(w, y_start, z_back)
	var b1 = Vector3(w, y_end, z_back * 0.7)
	var b2 = Vector3(-w, y_end, z_back * 0.7)
	var b3 = Vector3(-w, y_start, z_back)
	_add_quad(st, b0, b1, b2, b3)

static func _build_crossguard(st: SurfaceTool) -> void:
	# Stylized winged crossguard
	var hw = 0.16 # half width along X
	var h = 0.035 # height along Y
	var d = 0.026 # depth along Z

	# Central block
	_add_box(st, Vector3(0.0, -0.015, 0.0), Vector3(0.09, h, d))

	# Left wing (sweeps slightly upward)
	var lw_center = Vector3(-hw * 0.65, 0.005, 0.0)
	_add_box(st, lw_center, Vector3(hw * 0.7, h * 0.75, d * 0.75))

	# Right wing (sweeps slightly upward)
	var rw_center = Vector3(hw * 0.65, 0.005, 0.0)
	_add_box(st, rw_center, Vector3(hw * 0.7, h * 0.75, d * 0.75))

static func _build_grip(st: SurfaceTool) -> void:
	var y_top = -0.035
	var y_bot = -0.26
	var r = 0.016
	var segments = 8

	for i in range(segments):
		var a0 = float(i) / float(segments) * TAU
		var a1 = float(i + 1) / float(segments) * TAU

		var x0 = cos(a0) * r
		var z0 = sin(a0) * r
		var x1 = cos(a1) * r
		var z1 = sin(a1) * r

		var v0 = Vector3(x0, y_bot, z0)
		var v1 = Vector3(x0, y_top, z0)
		var v2 = Vector3(x1, y_top, z1)
		var v3 = Vector3(x1, y_bot, z1)

		_add_quad(st, v0, v1, v2, v3)

static func _build_pommel(st: SurfaceTool) -> void:
	var center = Vector3(0.0, -0.285, 0.0)
	_add_box(st, center, Vector3(0.045, 0.045, 0.032))

static func _add_quad(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3) -> void:
	st.add_vertex(v0)
	st.add_vertex(v1)
	st.add_vertex(v2)

	st.add_vertex(v0)
	st.add_vertex(v2)
	st.add_vertex(v3)

static func _add_box(st: SurfaceTool, center: Vector3, size: Vector3) -> void:
	var hx = size.x * 0.5
	var hy = size.y * 0.5
	var hz = size.z * 0.5

	var p0 = center + Vector3(-hx, -hy, hz)
	var p1 = center + Vector3(hx, -hy, hz)
	var p2 = center + Vector3(hx, hy, hz)
	var p3 = center + Vector3(-hx, hy, hz)
	var p4 = center + Vector3(-hx, -hy, -hz)
	var p5 = center + Vector3(hx, -hy, -hz)
	var p6 = center + Vector3(hx, hy, -hz)
	var p7 = center + Vector3(-hx, hy, -hz)

	# Front
	_add_quad(st, p0, p1, p2, p3)
	# Back
	_add_quad(st, p5, p4, p7, p6)
	# Left
	_add_quad(st, p4, p0, p3, p7)
	# Right
	_add_quad(st, p1, p5, p6, p2)
	# Top
	_add_quad(st, p3, p2, p6, p7)
	# Bottom
	_add_quad(st, p4, p5, p1, p0)

static func _create_blade_aura_particles() -> CPUParticles3D:
	var parts = CPUParticles3D.new()
	parts.amount = 18
	parts.lifetime = 1.2
	parts.preprocess = 0.5
	parts.speed_scale = 0.8
	parts.explosiveness = 0.0
	parts.randomness = 0.5
	parts.local_coords = false

	# Emission volume along the sword blade
	parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	parts.emission_box_extents = Vector3(0.04, 0.45, 0.03)
	parts.position = Vector3(0.0, 0.55, 0.0)

	parts.direction = Vector3(0.0, 1.0, 0.0)
	parts.spread = 25.0
	parts.gravity = Vector3(0.0, 0.25, 0.0)
	parts.initial_velocity_min = 0.05
	parts.initial_velocity_max = 0.18

	# Color and scale
	parts.color = Color(0.2, 0.85, 1.0, 0.8)
	parts.scale_amount_min = 0.015
	parts.scale_amount_max = 0.035

	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.3, 0.9, 1.0, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.9, 1.2, 1.0)
	mat.emission_energy_multiplier = 3.0
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	parts.material_override = mat

	var quad = QuadMesh.new()
	quad.size = Vector2(0.04, 0.04)
	parts.mesh = quad

	return parts
