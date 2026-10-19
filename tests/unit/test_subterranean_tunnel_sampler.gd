class_name TestSubterraneanTunnelSampler
extends "res://tests/framework/test_case.gd"

func test_determinism() -> void:
	var config = CaveGeneratorConfig.new()
	var sampler1 = SubterraneanTunnelSampler.new(1337, config)
	var sampler2 = SubterraneanTunnelSampler.new(1337, config)
	var sampler_diff = SubterraneanTunnelSampler.new(7777, config)

	for x in [0.0, 50.0, 100.0]:
		for y in [15.0, 30.0, 45.0]:
			for z in [0.0, 50.0, 100.0]:
				var res1 = sampler1.sample_tunnel(x, y, z)
				var res2 = sampler2.sample_tunnel(x, y, z)
				assert_eq(res1.is_tunnel, res2.is_tunnel, "Determinism failed at (%f, %f, %f)" % [x, y, z])
				assert_almost_eq(res1.density, res2.density, 0.0001)
				assert_almost_eq(res1.effective_radius, res2.effective_radius, 0.0001)

	# Verify different seed produces different values
	var found_diff = false
	for x in range(0, 500, 20):
		var c1 = sampler1.get_tunnel_carve(float(x), 20.0, 0.0)
		var cd = sampler_diff.get_tunnel_carve(float(x), 20.0, 0.0)
		if absf(c1 - cd) > 0.01:
			found_diff = true
			break
	assert_true(found_diff, "Different seeds must produce different tunnel values")

func test_traversable_corridor_clearance() -> void:
	var config = CaveGeneratorConfig.new()
	config.min_clearance = 2.2
	var sampler = SubterraneanTunnelSampler.new(1337, config)

	# Find traversable corridors and assert clearance
	var tested_count = 0
	for x in range(0, 300, 15):
		for y in range(15, 60, 10):
			for z in range(0, 300, 15):
				var res = sampler.sample_tunnel(float(x), float(y), float(z))
				if res.is_tunnel and not res.is_dead_end:
					assert_true(res.effective_radius >= config.min_clearance,
						"Traversable tunnel radius %f must be >= min_clearance %f" % [res.effective_radius, config.min_clearance])
					tested_count += 1
					if tested_count > 10:
						break
			if tested_count > 10:
				break
		if tested_count > 10:
			break

	assert_true(tested_count > 0, "Must find and test traversable tunnel points")

func test_dead_end_pinch_off() -> void:
	var config = CaveGeneratorConfig.new()
	config.dead_end_threshold = 0.2 # Raise threshold to easily detect dead-end zones
	config.pinch_rate = 6.0
	var sampler = SubterraneanTunnelSampler.new(1337, config)

	var found_dead_end = false
	for x in range(0, 400, 20):
		for y in range(15, 45, 10):
			for z in range(0, 400, 20):
				var res = sampler.sample_tunnel(float(x), float(y), float(z))
				if res.is_dead_end:
					found_dead_end = true
					# Either pinched to 0 radius or radius significantly reduced
					assert_true(res.effective_radius < config.tunnel_radius_base,
						"Dead-end effective radius must be pinched below base radius")
					break
			if found_dead_end:
				break
		if found_dead_end:
			break

	assert_true(found_dead_end, "Must find at least one dead-end point with dead_end_threshold=0.2")

func test_can_tunnel_intersect_cell_bounding_box() -> void:
	var config = CaveGeneratorConfig.new()
	var sampler = SubterraneanTunnelSampler.new(1337, config)

	# 1. Invalid degenerate boxes must return false
	assert_false(sampler.can_tunnel_intersect_cell(Vector3(10, 10, 10), Vector3(10, 10, 10)), "Degenerate box must return false")
	assert_false(sampler.can_tunnel_intersect_cell(Vector3(20, 20, 20), Vector3(10, 10, 10)), "Inverted box must return false")

	# 2. Large chunk volume (-17, -23) known to contain tunnels must return true
	var min_p = Vector3(-544.0, 3.0, -736.0)
	var max_p = Vector3(-512.0, 43.0, -704.0)
	assert_true(sampler.can_tunnel_intersect_cell(min_p, max_p), "Chunk (-17, -23) volume containing 3D worm tunnels must return true")

	# 3. Solid rock block away from tunnel zero-crossings must cull to false
	var void_cell_found = false
	for x in range(0, 500, 20):
		var b_min = Vector3(float(x), 20.0, 0.0)
		var b_max = Vector3(float(x) + 4.0, 24.0, 4.0)
		if not sampler.can_tunnel_intersect_cell(b_min, b_max):
			void_cell_found = true
			break
	assert_true(void_cell_found, "Solid rock cell far from tunnel zero-crossings must cull to false")

func test_arena_tunnel_suppression() -> void:
	var config = CaveGeneratorConfig.new()
	config.arena_enabled = true
	config.arena_rift_threshold = 0.80
	var chasm_sampler = UndergroundChasmSampler.new(1337, config)
	var tunnel_sampler = SubterraneanTunnelSampler.new(1337, config, chasm_sampler)

	# 1. Without chasm_sampler, suppression is always 1.0 (no reduction)
	var isolated_sampler = SubterraneanTunnelSampler.new(1337, config)
	assert_eq(isolated_sampler.get_arena_suppression(0.0, 0.0), 1.0, "Isolated sampler must return 1.0")

	# 2. Locate an arena center and check suppression
	var col = ChasmColumnResult.new()
	var found_arena = false
	var arena_pos = Vector2.ZERO
	for ix in range(-200, 200, 4):
		for iz in range(-200, 200, 4):
			var wx = float(ix) * 5.0
			var wz = float(iz) * 5.0
			chasm_sampler.sample_column(wx, wz, col)
			if col.is_arena and col.raw_rift >= 0.82:
				found_arena = true
				arena_pos = Vector2(wx, wz)
				break
		if found_arena:
			break

	assert_true(found_arena, "Must locate core arena")

	# 3. Inside the core arena, suppression must be 0.0 and tunnel carve must be 0.0
	assert_eq(tunnel_sampler.get_arena_suppression(arena_pos.x, arena_pos.y), 0.0, "Suppression inside core arena must be 0.0")
	for y in range(5, 30, 2):
		assert_eq(tunnel_sampler.get_tunnel_carve(arena_pos.x, float(y), arena_pos.y), 0.0, "Worm tunnels must be strictly 0 inside core arena")

	# 4. Far from any arena, suppression must be 1.0
	var supp_outside = tunnel_sampler.get_arena_suppression(0.0, 0.0)
	assert_eq(supp_outside, 1.0, "Suppression outside arena must be 1.0")
