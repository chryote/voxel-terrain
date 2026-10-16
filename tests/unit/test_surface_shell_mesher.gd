class_name TestSurfaceShellMesher
extends "res://tests/framework/test_case.gd"

func test_flat_chunk_greedy_merging() -> void:
	var c_size = 16
	var data = SurfaceChunkData.new(c_size)
	# Fill entire chunk and apron with uniform height and grass material
	data.fill(10, 1, 2)

	var reg = MaterialRegistry.create_default_registry()
	var mesher = SurfaceShellMesher.new()
	var mesh = mesher.build_mesh(data, reg)

	assert_false(mesh.is_empty(), "Mesh should not be empty")
	# A uniform flat 16x16 chunk has no internal or apron height steps.
	# Greedy meshing must merge the entire top surface into exactly 1 quad (4 vertices, 2 triangles, 6 indices)!
	assert_eq(mesh.get_vertex_count(), 4, "Flat chunk top should be merged into exactly 4 vertices")
	assert_eq(mesh.get_triangle_count(), 2, "Flat chunk top should be merged into exactly 2 triangles")

	# Check normals
	for norm in mesh.normals:
		assert_vec_almost_eq(norm, Vector3(0.0, 1.0, 0.0), 0.001, "Top normal must point straight up")

func test_single_pillar_walls() -> void:
	var c_size = 8
	var data = SurfaceChunkData.new(c_size)
	data.fill(5, 1, 2) # Base height 5

	# Add a single pillar at (3, 3) with height 7
	data.set_height(3, 3, 7)

	var reg = MaterialRegistry.create_default_registry()
	var mesher = SurfaceShellMesher.new()
	var mesh = mesher.build_mesh(data, reg)

	# Pillar has 1 top quad + 4 vertical walls (West, East, South, North)
	# In addition, the base area is merged around the pillar
	assert_true(mesh.get_triangle_count() > 2, "Pillar must generate top and side walls")

	# Check all indices are valid
	var v_count = mesh.get_vertex_count()
	for idx in mesh.indices:
		assert_true(idx >= 0 and idx < v_count, "Index %d must be in [0, %d)" % [idx, v_count])

func test_array_mesh_creation() -> void:
	var c_size = 8
	var data = SurfaceChunkData.new(c_size)
	data.fill(10, 1, 2)
	var reg = MaterialRegistry.create_default_registry()
	var mesher = SurfaceShellMesher.new()
	var mesh_data = mesher.build_mesh(data, reg)

	var array_mesh = mesh_data.create_array_mesh()
	assert_not_null(array_mesh, "ArrayMesh creation should succeed")
	assert_eq(array_mesh.get_surface_count(), 1, "ArrayMesh should have 1 surface")
