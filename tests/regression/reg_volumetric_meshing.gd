class_name RegVolumetricMeshing
extends "res://tests/framework/regression_case.gd"

## Golden regression snapshot for 3D volumetric greedy meshing.

var update_golden: bool = false

func test_volumetric_meshing_golden_snapshot() -> void:
	var bounds = WorldBounds.new(Vector2i(32, 32), 16, 1.0)
	var config = VolumetricGeneratorConfig.new()
	config.chunk_height = 64
	var gen = VolumetricContinentGenerator.new(4242, config)
	var mesher = VoxelMesher3D.new()
	var reg = MaterialRegistry.create_default_registry()

	var data = gen.generate(ChunkCoord.new(0, 0), bounds)
	var mesh = mesher.build_mesh(data, reg)

	var v_bytes = mesh.vertices.to_byte_array()
	var i_bytes = mesh.indices.to_byte_array()

	var snapshot = {
		"vertex_count": mesh.get_vertex_count(),
		"triangle_count": mesh.get_triangle_count(),
		"vertices_hash": hash_bytes(v_bytes),
		"indices_hash": hash_bytes(i_bytes)
	}

	assert_golden("volumetric_meshing", snapshot, update_golden)
