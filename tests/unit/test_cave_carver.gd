class_name TestCaveCarver
extends "res://tests/framework/test_case.gd"

func test_boundary_conditions() -> void:
	var config = CaveGeneratorConfig.new()
	var carver = CaveCarver.new(1337, config)
	var surface_h = 50.0
	var sea_level = 24

	# Above surface is 1.0 (air)
	var above_h = carver.sample_carve_density(0.0, 55.0, 0.0, surface_h, sea_level)
	assert_almost_eq(above_h, 1.0, 0.0001, "Above surface elevation must be air (1.0)")

	# Bedrock floor (Y <= 2) is 0.0 (solid)
	var bedrock = carver.sample_carve_density(0.0, 1.0, 0.0, surface_h, sea_level)
	assert_almost_eq(bedrock, 0.0, 0.0001, "Bedrock floor must be solid (0.0)")

func test_coarse_cell_status_culling() -> void:
	var config = CaveGeneratorConfig.new()
	var carver = CaveCarver.new(1337, config)
	var sea_level = 24

	# Cell completely above surface
	var status_air = carver.sample_coarse_cell_status(
		Vector3(0.0, 60.0, 0.0),
		Vector3(4.0, 64.0, 4.0),
		40.0, 50.0, sea_level
	)
	assert_eq(status_air, CaveCarver.STATUS_AIR, "Cell entirely above surface must be STATUS_AIR")

	# Cell completely in bedrock
	var status_bedrock = carver.sample_coarse_cell_status(
		Vector3(0.0, 0.0, 0.0),
		Vector3(4.0, 2.0, 4.0),
		40.0, 50.0, sea_level
	)
	assert_eq(status_bedrock, CaveCarver.STATUS_SOLID, "Cell entirely in bedrock must be STATUS_SOLID")

func test_material_classification() -> void:
	var config = CaveGeneratorConfig.new()
	config.chasm_max_y = 22
	config.chasm_water_level = 10
	var carver = CaveCarver.new(1337, config)

	# Deep chasm basin floor (Y <= 11)
	var mat_basin = carver.classify_subterranean_voxel(0.0, 8.0, 0.0)
	assert_eq(mat_basin, MaterialDef.ID_CHASM_BASALT, "Basin floor must be classified as basalt")

	# Upper cave wall (Y > 22)
	var mat_upper = carver.classify_subterranean_voxel(0.0, 35.0, 0.0)
	assert_eq(mat_upper, MaterialDef.ID_CAVE_WALL, "Upper cave wall must be classified as cave_wall")

func test_strata_envelope_culling() -> void:
	var config = CaveGeneratorConfig.new()
	var carver = CaveCarver.new(1337, config)

	# 1. Chasm cannot intersect above chasm_max_y (Y >= 22)
	var chasm_above = carver.chasm_sampler.can_chasm_intersect_cell(Vector3(0, 24, 0), Vector3(4, 28, 4))
	assert_false(chasm_above, "Cells above chasm_max_y must be culled by chasm envelope")

	# 2. Chasm cannot intersect below chasm_min_y (Y <= 4)
	var chasm_below = carver.chasm_sampler.can_chasm_intersect_cell(Vector3(0, 0, 0), Vector3(4, 3, 4))
	assert_false(chasm_below, "Cells below chasm_min_y must be culled by chasm envelope")

	# 3. Mouth cannot intersect deep subterranean cells (> 14m below surface)
	var mouth_deep = carver.mouth_sampler.can_mouth_intersect_cell(
		Vector3(0, 10, 0), Vector3(4, 14, 4), 60.0, 24
	)
	assert_false(mouth_deep, "Cells deeper than max_entrance_depth must be culled by mouth envelope")

func test_coarse_culling_preserves_cave_cavities() -> void:
	var config = CaveGeneratorConfig.new()
	var carver = CaveCarver.new(1337, config)
	var sea_level = 24
	var surface_h = 50.0

	# Scan for a known carved voxel
	var carved_pos = Vector3.ZERO
	var found = false
	for rx in range(-20, 20):
		for rz in range(-20, 20):
			for ry in range(8, 20):
				var p = Vector3(float(rx), float(ry), float(rz))
				if carver.is_carved(p.x, p.y, p.z, surface_h, sea_level):
					carved_pos = p
					found = true
					break
			if found:
				break
		if found:
			break

	assert_true(found, "A carved voxel must exist within the subterranean test region")

	# Construct a coarse cell around this carved voxel
	var cell_min = Vector3(floorf(carved_pos.x / 4.0) * 4.0, floorf(carved_pos.y / 4.0) * 4.0, floorf(carved_pos.z / 4.0) * 4.0)
	var cell_max = cell_min + Vector3(4.0, 4.0, 4.0)

	var status = carver.sample_coarse_cell_status(cell_min, cell_max, surface_h, surface_h, sea_level)
	assert_ne(status, CaveCarver.STATUS_SOLID, "A cell containing a hollow cave cavity must NEVER be culled as STATUS_SOLID")
	assert_eq(status, CaveCarver.STATUS_MIXED, "A cell containing hollow voids must be classified as STATUS_MIXED")

func test_column_span_adapter() -> void:
	var config = CaveGeneratorConfig.new()
	var carver = CaveCarver.new(1337, config)
	var col = ChasmColumnResult.new()

	# Scan for an active chasm column
	var chasm_found = false
	for x in range(0, 100, 5):
		for z in range(0, 100, 5):
			carver.sample_chasm_column(float(x), float(z), col)
			if col.is_chasm and not col.is_pillar:
				chasm_found = true
				# Below floor: not void
				assert_false(carver.is_chasm_void(float(col.floor_y), col), "Floor elevation must not be void")
				assert_false(carver.is_chasm_void(float(col.floor_y - 1), col), "Below floor elevation must not be void")

				# Above ceiling: not void
				assert_false(carver.is_chasm_void(float(col.ceil_y), col), "Ceiling elevation must not be void")
				assert_false(carver.is_chasm_void(float(col.ceil_y + 1), col), "Above ceiling elevation must not be void")

				# Middle of span: void
				var mid_y = float(col.floor_y + col.ceil_y) * 0.5
				assert_true(carver.is_chasm_void(mid_y, col), "Mid-span elevation must be void")
				break
		if chasm_found:
			break

	assert_true(chasm_found, "Must locate an active chasm column to test column span adapter")

func test_span_point_query_equivalence() -> void:
	var config = CaveGeneratorConfig.new()
	var carver = CaveCarver.new(1337, config)
	var col = ChasmColumnResult.new()

	var tested_columns = 0
	for x in range(-30, 30, 6):
		for z in range(-30, 30, 6):
			tested_columns += 1
			carver.sample_chasm_column(float(x), float(z), col)

			# Compare point query against span query across vertical elevations
			for y in range(config.chasm_min_y - 1, config.chasm_max_y + 2):
				var wy = float(y)
				var is_void_span = carver.is_chasm_void(wy, col)
				var is_void_point = carver.chasm_sampler.get_chasm_carve(float(x), wy, float(z)) > 0.05
				assert_eq(is_void_span, is_void_point, "Span and point queries must agree at (%f, %f, %f)" % [float(x), wy, float(z)])

				# Subterranean water consistency
				var is_water_with_col = carver.is_subterranean_water(float(x), wy, float(z), 50.0, 24, col)
				var is_water_standalone = carver.is_subterranean_water(float(x), wy, float(z), 50.0, 24)
				# If it's a chasm void, both must agree
				if is_void_span:
					assert_eq(is_water_with_col, is_water_standalone, "Subterranean water query must agree at (%f, %f, %f)" % [float(x), wy, float(z)])

	assert_true(tested_columns > 50, "Must test multiple columns for span/point equivalence")

