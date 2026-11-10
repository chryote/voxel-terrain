class_name SlashArcMeshBuilder
extends RefCounted

## Generates a parametric 3D volumetric crescent slash arc mesh.
## Creates a true 3D wedge prism with top, bottom, outer cutting edge, and inner rim,
## providing real volumetric presence rather than a flat 2D billboard ribbon.

static func build_volumetric_slash_mesh(
	inner_radius: float = 0.75,
	outer_radius: float = 2.45,
	arc_sweep_rad: float = deg_to_rad(135.0),
	inner_height: float = 0.22,
	outer_height: float = 0.025,
	segments: int = 36
) -> ArrayMesh:
	var st = SurfaceTool.new()
	var mesh = ArrayMesh.new()

	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var start_angle = -arc_sweep_rad * 0.5

	# Build vertices per slice
	for i in range(segments):
		var t0 = float(i) / float(segments)
		var t1 = float(i + 1) / float(segments)

		var a0 = start_angle + t0 * arc_sweep_rad
		var a1 = start_angle + t1 * arc_sweep_rad

		# Crescent taper envelope: swells in center, sharp at tips
		var env0 = sin(t0 * PI)
		var env1 = sin(t1 * PI)

		# Outer radius with crescent expansion
		var r_out_0 = inner_radius + (outer_radius - inner_radius) * (0.35 + 0.65 * env0)
		var r_out_1 = inner_radius + (outer_radius - inner_radius) * (0.35 + 0.65 * env1)

		# Height taper
		var h_in_0 = inner_height * (0.4 + 0.6 * env0)
		var h_in_1 = inner_height * (0.4 + 0.6 * env1)
		var h_out_0 = outer_height * (0.4 + 0.6 * env0)
		var h_out_1 = outer_height * (0.4 + 0.6 * env1)

		# 3D Coordinates (X = right/tangent, Y = vertical thickness, Z = forward)
		# Arc is oriented sweeping in the XZ plane forward (-Z)
		var dir0 = Vector3(sin(a0), 0.0, -cos(a0))
		var dir1 = Vector3(sin(a1), 0.0, -cos(a1))

		# Slice 0 points
		var in_top_0 = dir0 * inner_radius + Vector3(0.0, h_in_0 * 0.5, 0.0)
		var in_bot_0 = dir0 * inner_radius - Vector3(0.0, h_in_0 * 0.5, 0.0)
		var out_top_0 = dir0 * r_out_0 + Vector3(0.0, h_out_0 * 0.5, 0.0)
		var out_bot_0 = dir0 * r_out_0 - Vector3(0.0, h_out_0 * 0.5, 0.0)

		# Slice 1 points
		var in_top_1 = dir1 * inner_radius + Vector3(0.0, h_in_1 * 0.5, 0.0)
		var in_bot_1 = dir1 * inner_radius - Vector3(0.0, h_in_1 * 0.5, 0.0)
		var out_top_1 = dir1 * r_out_1 + Vector3(0.0, h_out_1 * 0.5, 0.0)
		var out_bot_1 = dir1 * r_out_1 - Vector3(0.0, h_out_1 * 0.5, 0.0)

		# 1. Top Surface (winding: in_top_0 -> out_top_0 -> out_top_1 -> in_top_1)
		_add_quad_uv(st,
			in_top_0, Vector2(t0, 0.0),
			out_top_0, Vector2(t0, 1.0),
			out_top_1, Vector2(t1, 1.0),
			in_top_1, Vector2(t1, 0.0)
		)

		# 2. Bottom Surface (winding facing down)
		_add_quad_uv(st,
			in_bot_0, Vector2(t0, 0.0),
			in_bot_1, Vector2(t1, 0.0),
			out_bot_1, Vector2(t1, 1.0),
			out_bot_0, Vector2(t0, 1.0)
		)

		# 3. Outer Edge (the razor sharp cutting rim)
		_add_quad_uv(st,
			out_top_0, Vector2(t0, 1.0),
			out_bot_0, Vector2(t0, 1.0),
			out_bot_1, Vector2(t1, 1.0),
			out_top_1, Vector2(t1, 1.0)
		)

		# 4. Inner Wall
		_add_quad_uv(st,
			in_top_0, Vector2(t0, 0.0),
			in_top_1, Vector2(t1, 0.0),
			in_bot_1, Vector2(t1, 0.0),
			in_bot_0, Vector2(t0, 0.0)
		)

		# Start cap on first segment
		if i == 0:
			_add_quad_uv(st,
				in_top_0, Vector2(0.0, 0.0),
				in_bot_0, Vector2(0.0, 0.0),
				out_bot_0, Vector2(0.0, 1.0),
				out_top_0, Vector2(0.0, 1.0)
			)

		# End cap on last segment
		if i == segments - 1:
			_add_quad_uv(st,
				in_top_1, Vector2(1.0, 0.0),
				out_top_1, Vector2(1.0, 1.0),
				out_bot_1, Vector2(1.0, 1.0),
				in_bot_1, Vector2(1.0, 0.0)
			)

	st.generate_normals()
	st.commit(mesh)

	return mesh

static func _add_quad_uv(
	st: SurfaceTool,
	v0: Vector3, uv0: Vector2,
	v1: Vector3, uv1: Vector2,
	v2: Vector3, uv2: Vector2,
	v3: Vector3, uv3: Vector2
) -> void:
	st.set_uv(uv0)
	st.add_vertex(v0)
	st.set_uv(uv1)
	st.add_vertex(v1)
	st.set_uv(uv2)
	st.add_vertex(v2)

	st.set_uv(uv0)
	st.add_vertex(v0)
	st.set_uv(uv2)
	st.add_vertex(v2)
	st.set_uv(uv3)
	st.add_vertex(v3)
