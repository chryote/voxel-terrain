class_name TestChasmSampler
extends "res://tests/framework/test_case.gd"

## Comprehensive unit test suite for Dual-2D Heightmap UndergroundChasmSampler.
## Validates geometric invariants: clearance, vertical wall continuity,
## bedrock preservation, deterministic generation, and coarse culling correctness.

func test_clearance_invariant() -> void:
	var config = CaveGeneratorConfig.new()
	config.min_chasm_height = 5.0
	config.chasm_min_y = 4
	config.chasm_max_y = 24
	config.chasm_floor_variation = 3.0
	config.chasm_ceil_variation = 4.0
	var sampler = UndergroundChasmSampler.new(1337, config)

	var col = ChasmColumnResult.new()
	var sample_count = 0
	var chasm_count = 0

	# Sample a 100x100 grid (10,000 samples)
	for x_idx in range(-50, 50):
		var wx = float(x_idx) * 6.0
		for z_idx in range(-50, 50):
			var wz = float(z_idx) * 6.0
			sample_count += 1
			sampler.sample_column(wx, wz, col)

			if col.is_chasm:
				chasm_count += 1
				var clearance = col.ceil_y - col.floor_y
				assert_true(
					clearance >= int(config.min_chasm_height),
					"Clearance must be >= min_chasm_height at (%f, %f): got %d" % [wx, wz, clearance]
				)

	assert_eq(sample_count, 10000, "Should evaluate 10,000 column samples")
	assert_true(chasm_count > 500, "Should find at least hundreds of active chasm columns (found %d)" % chasm_count)

func test_bedrock_protection() -> void:
	var config = CaveGeneratorConfig.new()
	config.chasm_min_y = 4
	config.chasm_floor_variation = 5.0 # High amplitude downward variation
	var sampler = UndergroundChasmSampler.new(4242, config)

	var col = ChasmColumnResult.new()
	var chasm_count = 0

	# Scan 4,000 samples across varied terrain
	for x_idx in range(-40, 40):
		var wx = float(x_idx) * 7.5
		for z_idx in range(-25, 25):
			var wz = float(z_idx) * 7.5
			sampler.sample_column(wx, wz, col)

			if col.is_chasm:
				chasm_count += 1
				assert_true(col.floor_y >= 3, "Chasm floor (%d) must never penetrate bedrock (Y <= 2)" % col.floor_y)

				# Check point query carve density in bedrock
				assert_eq(sampler.get_chasm_carve(wx, 0.0, wz), 0.0, "Bedrock Y=0 must be solid")
				assert_eq(sampler.get_chasm_carve(wx, 1.0, wz), 0.0, "Bedrock Y=1 must be solid")
				assert_eq(sampler.get_chasm_carve(wx, 2.0, wz), 0.0, "Bedrock Y=2 must be solid")

	assert_true(chasm_count > 100, "Should evaluate active chasm columns for bedrock test")

func test_vertical_wall_boundary() -> void:
	var config = CaveGeneratorConfig.new()
	var sampler = UndergroundChasmSampler.new(1337, config)

	# Find a horizontal boundary crossing between solid rock and chasm void
	var boundary_found = false
	var col_solid = ChasmColumnResult.new()
	var col_chasm = ChasmColumnResult.new()

	for step in range(0, 1000):
		var wx1 = float(step) * 1.0
		var wz = 50.0
		sampler.sample_column(wx1, wz, col_solid)

		var wx2 = wx1 + 1.0
		sampler.sample_column(wx2, wz, col_chasm)

		if not col_solid.is_chasm and col_chasm.is_chasm and not col_chasm.is_pillar:
			boundary_found = true

			# Inside the chasm column:
			# Every vertical voxel strictly between floor_y and ceil_y must be hollow void
			for y in range(col_chasm.floor_y + 1, col_chasm.ceil_y):
				var carve = sampler.get_chasm_carve(wx2, float(y), wz)
				assert_eq(carve, 1.0, "Chasm void at Y=%d must be carved" % y)

			# At or below floor_y and at or above ceil_y must be solid rock
			assert_eq(sampler.get_chasm_carve(wx2, float(col_chasm.floor_y), wz), 0.0, "Floor voxel must be solid")
			assert_eq(sampler.get_chasm_carve(wx2, float(col_chasm.ceil_y), wz), 0.0, "Ceiling voxel must be solid")

			# Across the vertical wall in the solid column:
			# All points in that same vertical span must be 100% solid rock (no diagonal holes)
			for y in range(col_chasm.floor_y + 1, col_chasm.ceil_y):
				var carve_wall = sampler.get_chasm_carve(wx1, float(y), wz)
				assert_eq(carve_wall, 0.0, "Adjacent wall voxel at Y=%d must be solid rock" % y)
			break

	assert_true(boundary_found, "Must locate a chasm wall boundary for vertical wall continuity test")

func test_deterministic_reproducibility() -> void:
	var config = CaveGeneratorConfig.new()
	var sampler1 = UndergroundChasmSampler.new(7777, config)
	var sampler2 = UndergroundChasmSampler.new(7777, config)
	var sampler_diff = UndergroundChasmSampler.new(8888, config)

	var col1 = ChasmColumnResult.new()
	var col2 = ChasmColumnResult.new()
	var col_diff = ChasmColumnResult.new()

	var found_difference = false

	for i in range(100):
		var wx = float(i) * 13.7
		var wz = float(i) * 9.3

		sampler1.sample_column(wx, wz, col1)
		sampler2.sample_column(wx, wz, col2)
		sampler_diff.sample_column(wx, wz, col_diff)

		assert_eq(col1.is_chasm, col2.is_chasm, "Deterministic is_chasm check at %d" % i)
		assert_eq(col1.floor_y, col2.floor_y, "Deterministic floor_y check at %d" % i)
		assert_eq(col1.ceil_y, col2.ceil_y, "Deterministic ceil_y check at %d" % i)
		assert_eq(col1.is_pillar, col2.is_pillar, "Deterministic is_pillar check at %d" % i)

		if col1.is_chasm != col_diff.is_chasm or col1.floor_y != col_diff.floor_y:
			found_difference = true

	assert_true(found_difference, "Different seeds must produce different chasm geometry")

func test_domain_wall_warping() -> void:
	var config = CaveGeneratorConfig.new()
	config.chasm_wall_warp_amplitude = 4.0
	var sampler = UndergroundChasmSampler.new(1337, config)

	var wx = 25.0
	var wz = 40.0
	var warped = sampler.get_warped_coordinates(wx, wz)

	# Perturbation must not be zero
	var dist = (warped - Vector2(wx, wz)).length()
	assert_true(dist > 0.01, "Warping must perturb coordinates: dist was %f" % dist)
	assert_true(dist <= config.chasm_wall_warp_amplitude * 1.5, "Warp displacement within bounds")

	# If amplitude is 0, warped coords must match input exactly
	config.chasm_wall_warp_amplitude = 0.0
	var unwarped = sampler.get_warped_coordinates(wx, wz)
	assert_almost_eq(unwarped.x, wx, 0.0001, "Zero amplitude warp must leave X unchanged")
	assert_almost_eq(unwarped.y, wz, 0.0001, "Zero amplitude warp must leave Z unchanged")

func test_support_pillar_exclusion() -> void:
	var config = CaveGeneratorConfig.new()
	config.pillar_threshold = 0.35 # Low threshold to guarantee pillars
	var sampler = UndergroundChasmSampler.new(1337, config)

	var col = ChasmColumnResult.new()
	var pillar_found = false

	for x in range(-50, 50, 2):
		for z in range(-50, 50, 2):
			sampler.sample_column(float(x), float(z), col)
			if col.is_pillar:
				pillar_found = true
				assert_false(col.is_chasm, "Pillars must not be marked as carved chasm")
				# All elevations must be solid rock
				for y in range(config.chasm_min_y, config.chasm_max_y):
					assert_eq(sampler.get_chasm_carve(float(x), float(y), float(z)), 0.0, "Pillar at Y=%d must be solid" % y)
				break
		if pillar_found:
			break

	assert_true(pillar_found, "Must locate at least one support pillar")

func test_column_result_zero_alloc_reuse() -> void:
	var config = CaveGeneratorConfig.new()
	var sampler = UndergroundChasmSampler.new(1337, config)

	# Single reusable result object
	var reusable_col = ChasmColumnResult.new()

	for step in range(200):
		var wx = float(step) * 5.0
		var wz = float(step) * 3.0
		var returned = sampler.sample_column(wx, wz, reusable_col)

		# Must return the identical object passed in
		assert_true(returned == reusable_col, "sample_column must populate and return the passed object")

func test_coarse_cell_culling_soundness() -> void:
	var config = CaveGeneratorConfig.new()
	var sampler = UndergroundChasmSampler.new(1337, config)

	# 1. Vertical envelope culling checks
	var below_bedrock_cell = sampler.can_chasm_intersect_cell(Vector3(0, 0, 0), Vector3(4, 2, 4))
	assert_false(below_bedrock_cell, "Bedrock cells must be culled")

	var above_ceiling_cell = sampler.can_chasm_intersect_cell(Vector3(0, 25, 0), Vector3(4, 29, 4))
	assert_false(above_ceiling_cell, "Cells above chasm_max_y must be culled")

	# 2. Horizontal rift mask culling checks over wide macro region (wavelength ~333m)
	var culled_horizontal_cells = 0

	for cx in range(-400, 400, 40):
		for cz in range(-400, 400, 40):
			var min_p = Vector3(float(cx), 8.0, float(cz))
			var max_p = min_p + Vector3(4.0, 4.0, 4.0)

			if not sampler.can_chasm_intersect_cell(min_p, max_p):
				culled_horizontal_cells += 1
				# Verify that points in this culled cell are indeed 100% solid rock
				for px in [min_p.x, (min_p.x + max_p.x) * 0.5, max_p.x]:
					for pz in [min_p.z, (min_p.z + max_p.z) * 0.5, max_p.z]:
						for py in [min_p.y + 0.5, (min_p.y + max_p.y) * 0.5, max_p.y - 0.5]:
							var carve = sampler.get_chasm_carve(px, py, pz)
							assert_eq(carve, 0.0, "Culled cell must not have carved void at (%f, %f, %f)" % [px, py, pz])

	assert_true(culled_horizontal_cells > 20, "Must verify multiple horizontally culled cells (found %d)" % culled_horizontal_cells)

