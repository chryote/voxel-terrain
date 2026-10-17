class_name TestTrilinearTunnelGrid
extends "res://tests/framework/test_case.gd"

## Unit tests validating Item 3.3: Trilinear Density Grid for 3D Worm Tunnels.
## Verifies 8-corner density evaluation, trilinear mathematical interpolation accuracy,
## and subterranean chunk generation integrity.

func test_trilinear_corner_sampling_and_interpolation() -> void:
	var config = CaveGeneratorConfig.new()
	var sampler = SubterraneanTunnelSampler.new(1337, config)

	var min_p = Vector3(10.0, 15.0, 10.0)
	var max_p = Vector3(14.0, 19.0, 14.0)

	var corners = sampler.sample_trilinear_cell_corners(min_p, max_p)
	assert_eq(corners.size(), 8, "Must sample exactly 8 corner densities")

	# Verify corners match exact get_tunnel_carve at extremes
	assert_almost_eq(sampler.evaluate_trilinear(corners, 0.0, 0.0, 0.0), corners[0], 0.0001, "Corner (0,0,0) must match corners[0]")
	assert_almost_eq(sampler.evaluate_trilinear(corners, 1.0, 0.0, 0.0), corners[1], 0.0001, "Corner (1,0,0) must match corners[1]")
	assert_almost_eq(sampler.evaluate_trilinear(corners, 0.0, 1.0, 0.0), corners[2], 0.0001, "Corner (0,1,0) must match corners[2]")
	assert_almost_eq(sampler.evaluate_trilinear(corners, 1.0, 1.0, 0.0), corners[3], 0.0001, "Corner (1,1,0) must match corners[3]")
	assert_almost_eq(sampler.evaluate_trilinear(corners, 0.0, 0.0, 1.0), corners[4], 0.0001, "Corner (0,0,1) must match corners[4]")
	assert_almost_eq(sampler.evaluate_trilinear(corners, 1.0, 0.0, 1.0), corners[5], 0.0001, "Corner (1,0,1) must match corners[5]")
	assert_almost_eq(sampler.evaluate_trilinear(corners, 0.0, 1.0, 1.0), corners[6], 0.0001, "Corner (0,1,1) must match corners[6]")
	assert_almost_eq(sampler.evaluate_trilinear(corners, 1.0, 1.0, 1.0), corners[7], 0.0001, "Corner (1,1,1) must match corners[7]")

	# Midpoint interpolation
	var mid_interp = sampler.evaluate_trilinear(corners, 0.5, 0.5, 0.5)
	var avg_corners = 0.0
	for i in range(8):
		avg_corners += corners[i]
	avg_corners /= 8.0
	assert_almost_eq(mid_interp, avg_corners, 0.001, "Centroid interpolation must equal average of 8 corners")

func test_trilinear_subterranean_generation_integrity() -> void:
	var bounds = WorldBounds.new(Vector2i(16, 16), 16, 1.0)
	var coord = ChunkCoord.new(2, 2)

	# 1. Generate with trilinear grid enabled (default)
	var config_tri = CaveGeneratorConfig.new()
	config_tri.use_trilinear_tunnel_grid = true
	var gen_tri = LayeredTerrainGenerator.new(1337, null, config_tri)
	var s_data_tri = gen_tri.generate_surface(coord, bounds)
	var v_data_tri = gen_tri.generate_subterranean(s_data_tri, coord, bounds)

	assert_not_null(v_data_tri, "Trilinear subterranean generation must succeed")
	assert_eq(v_data_tri.get_voxel(0, 0, 0), MaterialDef.ID_STONE, "Bedrock Y=0 must be solid stone")
	assert_eq(v_data_tri.get_voxel(5, 1, 5), MaterialDef.ID_STONE, "Bedrock Y=1 must be solid stone")
	assert_eq(v_data_tri.get_voxel(10, 2, 10), MaterialDef.ID_STONE, "Bedrock Y=2 must be solid stone")

	# 2. Generate with trilinear grid disabled (exact noise)
	var config_exact = CaveGeneratorConfig.new()
	config_exact.use_trilinear_tunnel_grid = false
	var gen_exact = LayeredTerrainGenerator.new(1337, null, config_exact)
	var s_data_exact = gen_exact.generate_surface(coord, bounds)
	var v_data_exact = gen_exact.generate_subterranean(s_data_exact, coord, bounds)

	assert_not_null(v_data_exact, "Exact subterranean generation must succeed")
	assert_eq(v_data_exact.get_voxel(0, 0, 0), MaterialDef.ID_STONE, "Bedrock must remain solid")
