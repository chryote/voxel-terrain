class_name TestWormTunnelCarverIntegration
extends "res://tests/framework/test_case.gd"

## Unit test suite validating Phase 4: Carver & Sampler Integration.
## Verifies that CaveCarver automatically generates and registers worm corridors when allowed mouths
## are set, SubterraneanTunnelSampler carves via segment distance fields, and culling guarantees 0% false positives.

const CaveCarverClass = preload("res://src/generation/caves/cave_carver.gd")
const CaveGeneratorConfigClass = preload("res://src/generation/caves/cave_generator_config.gd")
const CaveMouthDataClass = preload("res://src/map/cave_mouth_data.gd")
const WorldBoundsClass = preload("res://src/core/world_bounds.gd")

func test_carver_initialization_with_registry() -> void:
	var config = CaveGeneratorConfigClass.new()
	var carver = CaveCarverClass.new(1337, config)

	assert_not_null(carver.worm_generator, "CaveCarver must initialize worm_generator")
	assert_not_null(carver.worm_registry, "CaveCarver must initialize worm_registry")
	assert_eq(carver.tunnel_sampler.worm_registry, carver.worm_registry, "tunnel_sampler must share carver's worm_registry")
	assert_eq(carver.worm_registry.get_registered_chunk_count(), 0, "Initial registry must be empty before mouths are set")

func test_set_allowed_mouths_generates_and_registers_corridors() -> void:
	var config = CaveGeneratorConfigClass.new()
	var carver = CaveCarverClass.new(1337, config)

	# Surface cave mouth at (96.0, 50.0, 96.0) inside Chunk (6, 6) [96..112m]
	var mouth = CaveMouthDataClass.new(
		Vector3(96.0, 50.0, 96.0),
		Vector2(96.0, 96.0),
		CaveMouthDataClass.Type.TUNNEL,
		10.0,
		7.0,
		50.0
	)

	carver.set_allowed_mouths([mouth])

	var reg = carver.worm_registry
	assert_true(reg.get_registered_chunk_count() > 0, "Setting allowed mouths must populate worm registry")

	# Entrance chunk (6, 6) must be registered
	var start_c = ChunkCoord.new(6, 6)
	assert_true(reg.has_chunk(start_c), "Entrance chunk (6, 6) must be registered in worm registry")

	# Route must be populated
	var route = reg.get_corridor_route(0)
	assert_true(route.size() >= 2, "Corridor route for mouth 0 must contain descent chunks")
	assert_eq(route[0].x, 6, "Route start chunk X must be 6")
	assert_eq(route[0].z, 6, "Route start chunk Z must be 6")

func test_subterranean_tunnel_sampler_carves_along_registered_corridor() -> void:
	var config = CaveGeneratorConfigClass.new()
	var carver = CaveCarverClass.new(1337, config)

	var mouth_pos = Vector3(80.0, 48.0, 80.0)
	var mouth = CaveMouthDataClass.new(
		mouth_pos,
		Vector2(80.0, 80.0),
		CaveMouthDataClass.Type.TUNNEL,
		10.0,
		7.0,
		48.0
	)
	carver.set_allowed_mouths([mouth])

	# Retrieve the generated trajectory
	var traj = carver.worm_registry._trajectories.get(0, null)
	assert_not_null(traj, "Trajectory must be stored in registry")

	# Test carving density along the centerline of the trajectory
	for i in range(1, traj.waypoints.size() - 1, 2):
		var pt = traj.waypoints[i]
		if carver.tunnel_sampler.get_arena_suppression(pt.x, pt.z) <= 0.0:
			continue
		var carve = carver.tunnel_sampler.get_tunnel_carve(pt.x, pt.y, pt.z)
		assert_true(carve > 0.5, "Centerline point at %v must be carved (density: %f)" % [pt, carve])

	# Distant point far away from any corridor must have strictly 0 carve density
	var distant_carve = carver.tunnel_sampler.get_tunnel_carve(500.0, 25.0, 500.0)
	assert_almost_eq(distant_carve, 0.0, 0.0001, "Distant point must have 0.0 tunnel carve")

func test_culling_efficiency_and_zero_false_positives() -> void:
	var config = CaveGeneratorConfigClass.new()
	var carver = CaveCarverClass.new(1337, config)

	var mouth = CaveMouthDataClass.new(
		Vector3(32.0, 45.0, 32.0),
		Vector2(32.0, 32.0),
		CaveMouthDataClass.Type.TUNNEL,
		10.0,
		7.0,
		45.0
	)
	carver.set_allowed_mouths([mouth])

	# Registered chunk (2, 2) [32..48m] must return true
	var start_c = ChunkCoord.new(2, 2)
	assert_true(carver.tunnel_sampler.can_tunnel_intersect_chunk(start_c), "Chunk (2, 2) must intersect tunnel")

	# Distant chunks must return false in O(1)
	for dx in [10, 20, -15]:
		for dz in [10, 20, -15]:
			var c = ChunkCoord.new(dx, dz)
			assert_false(carver.tunnel_sampler.can_tunnel_intersect_chunk(c), "Distant chunk (%d, %d) must return false" % [dx, dz])

	# AABB cell culling on distant cell
	var distant_box_min = Vector3(300.0, 10.0, 300.0)
	var distant_box_max = Vector3(316.0, 26.0, 316.0)
	assert_false(carver.tunnel_sampler.can_tunnel_intersect_cell(distant_box_min, distant_box_max), "Distant cell must cull to false")

func test_watertight_mouth_funnel_to_tunnel_connection() -> void:
	var config = CaveGeneratorConfigClass.new()
	config.mouth_threshold = -1.0 # Guarantee test position is evaluated as mouth epicenter
	var carver = CaveCarverClass.new(1337, config)

	var surf_h = 45.0
	var mouth_pos = Vector3(64.0, surf_h, 64.0)
	var mouth = CaveMouthDataClass.new(
		mouth_pos,
		Vector2(64.0, 64.0),
		CaveMouthDataClass.Type.TUNNEL,
		12.0,
		7.0,
		surf_h
	)
	carver.set_allowed_mouths([mouth])

	# Step vertically down from mouth bottom into the worm corridor
	var mouth_info = carver.mouth_sampler.sample_mouth(mouth_pos.x, mouth_pos.z, surf_h, 24)
	assert_true(mouth_info.is_mouth, "Must be valid mouth")

	# Check carve density from surface down through entrance shaft into tunnel
	var y = surf_h
	while y >= (surf_h - 14.0):
		var density = carver.sample_carve_density(mouth_pos.x, y, mouth_pos.z, surf_h, 24)
		assert_true(density > 0.05, "Descent at Y=%f must be hollow air (density: %f)" % [y, density])
		y -= 1.0

func test_clear_allowed_mouths_cleans_registry() -> void:
	var config = CaveGeneratorConfigClass.new()
	var carver = CaveCarverClass.new(1337, config)

	var mouth = CaveMouthDataClass.new(
		Vector3(0.0, 50.0, 0.0),
		Vector2(0.0, 0.0),
		CaveMouthDataClass.Type.TUNNEL,
		8.0,
		6.0,
		50.0
	)
	carver.set_allowed_mouths([mouth])
	assert_true(carver.worm_registry.get_registered_chunk_count() > 0, "Must be populated")

	carver.clear_allowed_mouths()
	assert_eq(carver.worm_registry.get_registered_chunk_count(), 0, "Registry must be cleared")
	assert_false(carver.worm_registry.has_chunk(ChunkCoord.new(0, 0)), "Chunk must no longer be registered")

func test_use_directed_worm_corridors_toggle() -> void:
	var config = CaveGeneratorConfigClass.new()
	config.use_directed_worm_corridors = false
	var carver = CaveCarverClass.new(1337, config)

	var mouth = CaveMouthDataClass.new(
		Vector3(0.0, 50.0, 0.0),
		Vector2(0.0, 0.0),
		CaveMouthDataClass.Type.TUNNEL,
		8.0,
		6.0,
		50.0
	)
	carver.set_allowed_mouths([mouth])
	assert_eq(carver.worm_registry.get_registered_chunk_count(), 0, "Registry must remain empty when use_directed_worm_corridors = false")

	# Sampler can_tunnel_intersect_chunk should fall back to cell culling when registry is not used
	var min_p = Vector3(-544.0, 3.0, -736.0)
	var max_p = Vector3(-512.0, 43.0, -704.0)
	assert_true(carver.tunnel_sampler.can_tunnel_intersect_chunk(ChunkCoord.new(-17, -23), min_p, max_p), "Fallback simplex path must evaluate chunk cell")
