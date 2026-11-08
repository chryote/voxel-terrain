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

func test_cliff_face_greedy_merging() -> void:
	var c_size = 8
	var data = SurfaceChunkData.new(c_size)
	data.fill(5, 1, 2) # Base height 5

	# Add a continuous 4-block horizontal ridge at lz = 3, lx in [2, 5] with height 8
	for lx in range(2, 6):
		data.set_height(lx, 3, 8)

	var reg = MaterialRegistry.create_default_registry()
	var mesher = SurfaceShellMesher.new()
	var mesh = mesher.build_mesh(data, reg)

	# The top of the ridge merges into 1 quad (width 4, depth 1)
	# The south wall of the ridge (length 4 along X) merges into 1 quad
	# The north wall of the ridge (length 4 along X) merges into 1 quad
	# The west wall (lx=2, lz=3) is 1 quad
	# The east wall (lx=5, lz=3) is 1 quad
	# Therefore, exactly 5 quads = 20 vertices, 10 triangles for the entire ridge structure!
	# Verify that all vertical cliff walls with identical elevations merge into single quads
	var south_wall_found = false
	for i in range(0, mesh.vertices.size(), 4):
		var v0 = mesh.vertices[i]
		var v1 = mesh.vertices[i + 1]
		var norm = mesh.normals[i]
		# Check for merged south wall (normal 0, 0, -1) spanning 4 units from x=2 to x=6
		if norm.is_equal_approx(Vector3(0.0, 0.0, -1.0)):
			var width = absf(v0.x - v1.x)
			if absf(width - 4.0) < 0.001:
				south_wall_found = true
				break

	assert_true(south_wall_found, "4-block cliff south wall must be greedily merged into a single quad of width 4.0")

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

func test_water_mesher_null_when_dry_or_at_sea_level() -> void:
	var c_size = 8
	var data = SurfaceChunkData.new(c_size)
	data.fill(10, 1, 2)
	var reg = MaterialRegistry.create_default_registry()
	var mesher = SurfaceShellMesher.new()
	mesher.sea_level = 24

	var mesh_data = mesher.build_mesh(data, reg)
	assert_null(mesh_data.water_mesh_data, "Water mesh must be null when chunk has no water")

	# Even if water height is at or below sea level, elevated water mesher should return null
	data.fill(10, 1, 2, 24)
	var sea_mesh_data = mesher.build_mesh(data, reg)
	assert_null(sea_mesh_data.water_mesh_data, "Water mesh must be null when water is at sea level (covered by ocean plane)")

func test_elevated_water_greedy_meshing() -> void:
	var c_size = 16
	var data = SurfaceChunkData.new(c_size)
	# Terrain base height 40, water height 48 (elevated lake 8m deep)
	data.fill(40, 1, 2, 48)

	var reg = MaterialRegistry.create_default_registry()
	var mesher = SurfaceShellMesher.new()
	mesher.sea_level = 24

	var mesh_data = mesher.build_mesh(data, reg)
	assert_not_null(mesh_data.water_mesh_data, "Water mesh must not be null when elevated water is present")
	assert_false(mesh_data.water_mesh_data.is_empty(), "Water mesh should not be empty")

	# Entire 16x16 chunk with uniform water height should be greedy merged into 1 quad
	assert_eq(mesh_data.water_mesh_data.get_vertex_count(), 4, "Uniform elevated water should merge into 4 vertices")
	assert_eq(mesh_data.water_mesh_data.get_triangle_count(), 2, "Uniform elevated water should merge into 2 triangles")

	# Check water vertex elevation
	for v in mesh_data.water_mesh_data.vertices:
		assert_almost_eq(v.y, 48.0, 0.001, "Water vertex Y must equal water height 48")

	# Check normals point up
	for norm in mesh_data.water_mesh_data.normals:
		assert_vec_almost_eq(norm, Vector3(0.0, 1.0, 0.0), 0.001, "Water normal must point straight up")

	# Check array mesh creation
	var water_array_mesh = mesh_data.water_mesh_data.create_array_mesh()
	assert_not_null(water_array_mesh, "Water ArrayMesh creation must succeed")
	assert_eq(water_array_mesh.get_surface_count(), 1, "Water ArrayMesh should have 1 surface")

func test_elevated_water_vertical_side_faces_and_waterfalls() -> void:
	var c_size = 8
	var data = SurfaceChunkData.new(c_size)
	# Base terrain at height 20 across chunk
	data.fill(20, 1, 2, 20)

	# Create a 4-wide river step at lz = 2..3, lx = 2..5 with elevated water at height 35
	# and downstream pool at lz = 4..5, lx = 2..5 with lower water at height 30
	for lz in range(2, 4):
		for lx in range(2, 6):
			data.set_water_height(lx, lz, 35)

	for lz in range(4, 6):
		for lx in range(2, 6):
			data.set_water_height(lx, lz, 30)

	var mesher = SurfaceShellMesher.new()
	mesher.sea_level = 24

	var mesh_data = mesher.build_mesh(data, MaterialRegistry.create_default_registry())
	assert_not_null(mesh_data.water_mesh_data, "Water mesh must exist")

	var water_mesh = mesh_data.water_mesh_data
	var north_fall_found = false

	for i in range(0, water_mesh.vertices.size(), 4):
		var norm = water_mesh.normals[i]
		# Check for vertical side normal (abs(norm.y) < 0.5)
		if absf(norm.y) < 0.5:
			# Waterfall cascading North (+Z) from Y=30 to Y=35 across width 4 (lx=2 to lx=6) at lz=4 (flz=3 + 1)
			if norm.is_equal_approx(Vector3(0.0, 0.0, 1.0)):
				var v0 = water_mesh.vertices[i]
				var v1 = water_mesh.vertices[i + 1]
				var v2 = water_mesh.vertices[i + 2]
				var width = absf(v1.x - v0.x)
				if absf(width - 4.0) < 0.001 and absf(v0.y - 30.0) < 0.001 and absf(v2.y - 35.0) < 0.001:
					north_fall_found = true

	assert_true(north_fall_found, "4-wide river step must emit greedily-merged North waterfall quad spanning Y=30 to Y=35")

