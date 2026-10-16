class_name TestOffThreadCollisionBaker
extends "res://tests/framework/test_case.gd"

## Unit test suite validating Phase 2: Off-Thread Physics Baking.
## Verifies that ConcavePolygonShape3D collision shapes are compiled in background threads
## and assigned with zero main-thread stall.

func test_bake_shape_from_mesh_data() -> void:
	var baker = OffThreadCollisionBaker.new()
	assert_null(baker.bake_shape(null), "Null mesh data must return null shape")

	var empty_mesh = MeshData.new()
	assert_null(baker.bake_shape(empty_mesh), "Empty mesh data must return null shape")

	var mesh = MeshData.new()
	mesh.vertices.append(Vector3(0, 0, 0))
	mesh.vertices.append(Vector3(1, 0, 0))
	mesh.vertices.append(Vector3(0, 0, 1))
	mesh.indices.append(0)
	mesh.indices.append(1)
	mesh.indices.append(2)

	var shape = baker.bake_shape(mesh)
	assert_not_null(shape, "Baking valid mesh must produce ConcavePolygonShape3D")
	assert_true(shape.backface_collision, "Collision shape must have backface collision enabled")
	assert_eq(shape.get_faces().size(), 3, "1 triangle must generate 3 face vertices")
	assert_eq(shape.get_faces()[0], Vector3(0, 0, 0))
	assert_eq(shape.get_faces()[1], Vector3(1, 0, 0))
	assert_eq(shape.get_faces()[2], Vector3(0, 0, 1))

func test_bake_shapes_for_dual_bundle() -> void:
	var baker = OffThreadCollisionBaker.new()
	var bundle = DualMeshBundle.new()

	bundle.vertices.append(Vector3(0, 0, 0))
	bundle.vertices.append(Vector3(1, 0, 0))
	bundle.vertices.append(Vector3(0, 0, 1))
	bundle.indices.append(0)
	bundle.indices.append(1)
	bundle.indices.append(2)

	bundle.cave_mesh_data.vertices.append(Vector3(0, -10, 0))
	bundle.cave_mesh_data.vertices.append(Vector3(1, -10, 0))
	bundle.cave_mesh_data.vertices.append(Vector3(0, -10, 1))
	bundle.cave_mesh_data.indices.append(0)
	bundle.cave_mesh_data.indices.append(1)
	bundle.cave_mesh_data.indices.append(2)

	var shapes = baker.bake_shapes_for_bundle(bundle)
	assert_not_null(shapes.surface_shape, "Surface shape must be compiled")
	assert_not_null(shapes.cave_shape, "Cave shape must be compiled")
	assert_eq(shapes.surface_shape.get_faces().size(), 3)
	assert_eq(shapes.cave_shape.get_faces().size(), 3)

func test_worker_thread_pool_execution() -> void:
	var payload = {
		"baker": OffThreadCollisionBaker.new(),
		"mesh": MeshData.new(),
		"shape": null
	}
	payload.mesh.vertices.append(Vector3(0, 0, 0))
	payload.mesh.vertices.append(Vector3(2, 0, 0))
	payload.mesh.vertices.append(Vector3(0, 0, 2))
	payload.mesh.indices.append(0)
	payload.mesh.indices.append(1)
	payload.mesh.indices.append(2)

	var task_id = WorkerThreadPool.add_task(func():
		payload.shape = payload.baker.bake_shape(payload.mesh)
	)
	WorkerThreadPool.wait_for_task_completion(task_id)

	assert_not_null(payload.shape, "Shape must be generated asynchronously on worker thread")
	assert_eq(payload.shape.get_faces().size(), 3)

func test_chunk_node_prebaked_shape_injection() -> void:
	var chunk_node = ChunkNode.new()
	var mesh = MeshData.new()
	mesh.vertices.append(Vector3(0, 0, 0))
	mesh.vertices.append(Vector3(1, 0, 0))
	mesh.vertices.append(Vector3(0, 0, 1))
	mesh.indices.append(0)
	mesh.indices.append(1)
	mesh.indices.append(2)

	var prebaked_s = ConcavePolygonShape3D.new()
	var faces_s = PackedVector3Array([Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)])
	prebaked_s.set_faces(faces_s)

	var prebaked_c = ConcavePolygonShape3D.new()
	var faces_c = PackedVector3Array([Vector3(0, -5, 0), Vector3(1, -5, 0), Vector3(0, -5, 1)])
	prebaked_c.set_faces(faces_c)

	chunk_node.setup(ChunkCoord.new(1, 1), Vector3.ZERO, mesh, true, prebaked_s, prebaked_c)

	# Verify injected shapes are directly applied without runtime recalculation
	assert_eq(chunk_node.collision_shape.shape, prebaked_s, "Surface shape must match pre-baked instance")
	assert_null(chunk_node.cave_collision_shape.shape, "Cave shape must be deferred until subterranean layer is activated")
	assert_true(chunk_node.cave_collision_shape.disabled, "Cave collision must be initially disabled")
	assert_false(chunk_node.collision_shape.disabled, "Surface collision must be active")

	# Activating subterranean layer must bind pre-baked cave shape without stall
	chunk_node.set_subterranean_visible(true)
	assert_eq(chunk_node.cave_collision_shape.shape, prebaked_c, "Cave shape must match pre-baked instance once activated")
	assert_false(chunk_node.cave_collision_shape.disabled, "Cave collision must be enabled once subterranean layer is active")

	chunk_node.free()
