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
