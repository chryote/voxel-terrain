class_name TestVoxelMesher3D
extends "res://tests/framework/test_case.gd"

func test_flat_plane_greedy_merging() -> void:
	var c_size = 16
	var data = VoxelChunkData.new(c_size, 32)
	# Fill single layer y=5 across chunk and apron
	data.fill_layer(5, 1) # grass

	var reg = MaterialRegistry.create_default_registry()
	var mesher = VoxelMesher3D.new()
	var mesh = mesher.build_mesh(data, reg)

	assert_false(mesh.is_empty(), "Mesh should not be empty")

	# Top face (+Y) and Bottom face (-Y) must both be merged into exactly 1 quad each (2 quads total = 4 triangles)
	# Since apron is also filled at y=5, X and Z faces against apron neighbors are culled!
	assert_eq(mesh.get_triangle_count(), 4, "Flat plane should have exactly 4 triangles (1 top quad + 1 bottom quad)")
	assert_eq(mesh.get_vertex_count(), 8, "Flat plane should have exactly 8 vertices")

	# Check normals: 4 top normals (+Y) and 4 bottom normals (-Y)
	var up_count = 0
	var down_count = 0
	for norm in mesh.normals:
		if norm.is_equal_approx(Vector3(0.0, 1.0, 0.0)):
			up_count += 1
		elif norm.is_equal_approx(Vector3(0.0, -1.0, 0.0)):
			down_count += 1

	assert_eq(up_count, 4, "Top quad must have 4 +Y normals")
	assert_eq(down_count, 4, "Bottom quad must have 4 -Y normals")

func test_overhang_underside_facing_down() -> void:
	var c_size = 8
	var data = VoxelChunkData.new(c_size, 16)

	# Elevated overhang slab at y=10, from x=2..5, z=2..5
	for lz in range(2, 6):
		for lx in range(2, 6):
			data.set_voxel(lx, 10, lz, 3) # stone

	var reg = MaterialRegistry.create_default_registry()
	var mesher = VoxelMesher3D.new()
	var mesh = mesher.build_mesh(data, reg)

	# Must have bottom face pointing down (-Y)
	var has_down_normal = false
	for norm in mesh.normals:
		if norm.is_equal_approx(Vector3(0.0, -1.0, 0.0)):
			has_down_normal = true
			break
	assert_true(has_down_normal, "Overhang underside must have downward-facing (-Y) geometry")

func test_hollow_cave_interior_faces() -> void:
	var c_size = 10
	var data = VoxelChunkData.new(c_size, 16)

	# Create a solid box from x=1..8, y=1..8, z=1..8
	for ly in range(1, 9):
		for lz in range(1, 9):
			for lx in range(1, 9):
				data.set_voxel(lx, ly, lz, 3) # stone

	# Hollow out a 4x4x4 cave void inside from x=3..6, y=3..6, z=3..6
	for ly in range(3, 7):
		for lz in range(3, 7):
			for lx in range(3, 7):
				data.set_voxel(lx, ly, lz, 0) # air void

	var reg = MaterialRegistry.create_default_registry()
	var mesher = VoxelMesher3D.new()
	var mesh = mesher.build_mesh(data, reg)

	# Verify indices integrity
	var v_count = mesh.get_vertex_count()
	for idx in mesh.indices:
		assert_true(idx >= 0 and idx < v_count, "Index %d must be in [0, %d)" % [idx, v_count])

	# Interior cave must produce internal faces:
	# Ceiling of cave at y=7 pointing DOWN (-Y)
	# Floor of cave at y=2 pointing UP (+Y)
	var found_cave_ceiling = false
	var found_cave_floor = false
	for i in range(mesh.vertices.size()):
		var v = mesh.vertices[i]
		var n = mesh.normals[i]
		if is_equal_approx(v.y, 7.0) and n.is_equal_approx(Vector3(0.0, -1.0, 0.0)):
			# Inside the cave bounds x in [3, 7], z in [3, 7]
			if v.x >= 3.0 and v.x <= 7.0 and v.z >= 3.0 and v.z <= 7.0:
				found_cave_ceiling = true
		elif is_equal_approx(v.y, 3.0) and n.is_equal_approx(Vector3(0.0, 1.0, 0.0)):
			if v.x >= 3.0 and v.x <= 7.0 and v.z >= 3.0 and v.z <= 7.0:
				found_cave_floor = true

	assert_true(found_cave_ceiling, "Cave interior must produce a downward-facing ceiling")
	assert_true(found_cave_floor, "Cave interior must produce an upward-facing floor")

func test_array_mesh_creation_from_3d_voxel_mesh() -> void:
	var c_size = 8
	var data = VoxelChunkData.new(c_size, 16)
	data.fill_layer(4, 1)

	var reg = MaterialRegistry.create_default_registry()
	var mesher = VoxelMesher3D.new()
	var mesh_data = mesher.build_mesh(data, reg)

	var array_mesh = mesh_data.create_array_mesh()
	assert_not_null(array_mesh, "ArrayMesh creation must succeed")
	assert_eq(array_mesh.get_surface_count(), 1, "ArrayMesh should have exactly 1 surface")
