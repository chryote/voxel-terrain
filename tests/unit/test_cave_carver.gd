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
