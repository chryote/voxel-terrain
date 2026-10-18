class_name TestDirectionalSubterraneanPromotion
extends "res://tests/framework/test_case.gd"

## Unit test suite validating:
## 1. Watertight boundary seams between chasm chunks and adjacent voxel chunks.
## 2. Dynamic camera forward vector extraction in VoxelWorld.
## 3. Directional forward-cone priority promotion of subterranean chunks facing the player.

const ChasmChunkDataClass = preload("res://src/core/chasm_chunk_data.gd")
const ChasmShellMesherClass = preload("res://src/meshing/chasm_shell_mesher.gd")
const VoxelChunkDataClass = preload("res://src/core/voxel_chunk_data.gd")
const VoxelMesherClass = preload("res://src/meshing/voxel_mesher.gd")
const VoxelWorldClass = preload("res://src/world/voxel_world.gd")

func test_chasm_shell_seam_step_walls_watertight() -> void:
	## Validates that ChasmShellMesher produces fully sealed, watertight step walls
	## along all four chunk boundary planes (lx=0, lx=n, lz=0, lz=n) when floor/ceiling steps occur.
	var mesher = ChasmShellMesherClass.new()
	var reg = MaterialRegistry.create_default_registry()
	var c_size = 16

	# Case 1: West boundary step at lx = 0
	# Current chunk (lx=0..15) has floor=4, ceiling=26.
	# Apron neighbor at lx = -1 has higher floor=8, lower ceiling=22.
	var s_data = SurfaceChunkData.new(c_size)
	var chasm_data = ChasmChunkDataClass.new(c_size, 40, s_data)
	chasm_data.has_chasm = true

	for lz in range(c_size):
		for lx in range(c_size):
			chasm_data.set_floor(lx, lz, 4)
			chasm_data.set_ceil(lx, lz, 26)
			chasm_data.set_flags(lx, lz, ChasmChunkDataClass.FLAG_CHASM)
			chasm_data.set_column_material(lx, lz, MaterialDef.ID_CHASM_BASALT)
		# Apron at lx = -1
		chasm_data.set_floor(-1, lz, 8)
		chasm_data.set_ceil(-1, lz, 22)
		chasm_data.set_flags(-1, lz, ChasmChunkDataClass.FLAG_CHASM)
		chasm_data.set_column_material(-1, lz, MaterialDef.ID_CHASM_BASALT)

	var bundle = mesher.build_mesh(chasm_data, reg) as DualMeshBundle
	assert_not_null(bundle, "Must produce DualMeshBundle")
	assert_true(bundle.has_cave_geometry(), "Must produce cave geometry")

	var cave = bundle.cave_mesh_data
	var found_west_floor_step = false
	var found_west_ceil_step = false

	for i in range(cave.vertices.size()):
		var v = cave.vertices[i]
		var norm = cave.normals[i]
		# Face at lx=0 facing +X into room
		if is_equal_approx(v.x, 0.0) and norm.is_equal_approx(Vector3.RIGHT):
			if v.y >= 4.0 and v.y <= 9.0:
				found_west_floor_step = true
			if v.y >= 21.0 and v.y <= 27.0:
				found_west_ceil_step = true

	assert_true(found_west_floor_step, "Must emit vertical floor step wall at West seam (lx=0) facing +X")
	assert_true(found_west_ceil_step, "Must emit vertical ceiling step wall at West seam (lx=0) facing +X")

func test_chasm_shell_seam_east_and_z_boundaries() -> void:
	## Validates East boundary (lx = n) and Z boundaries (lz = 0, lz = n) step walls.
	var mesher = ChasmShellMesherClass.new()
	var reg = MaterialRegistry.create_default_registry()
	var c_size = 16

	var s_data = SurfaceChunkData.new(c_size)
	var chasm_data = ChasmChunkDataClass.new(c_size, 40, s_data)
	chasm_data.has_chasm = true

	for lz in range(c_size):
		for lx in range(c_size):
			chasm_data.set_floor(lx, lz, 4)
			chasm_data.set_ceil(lx, lz, 26)
			chasm_data.set_flags(lx, lz, ChasmChunkDataClass.FLAG_CHASM)
			chasm_data.set_column_material(lx, lz, MaterialDef.ID_CHASM_BASALT)

	# In apron at lx = c_size (East neighbor): higher floor=8, lower ceiling=22
	for lz in range(c_size):
		chasm_data.set_floor(c_size, lz, 8)
		chasm_data.set_ceil(c_size, lz, 22)
		chasm_data.set_flags(c_size, lz, ChasmChunkDataClass.FLAG_CHASM)

	# In apron at lz = -1 (South neighbor): higher floor=8, lower ceiling=22
	for lx in range(c_size):
		chasm_data.set_floor(lx, -1, 8)
		chasm_data.set_ceil(lx, -1, 22)
		chasm_data.set_flags(lx, -1, ChasmChunkDataClass.FLAG_CHASM)

	var bundle = mesher.build_mesh(chasm_data, reg) as DualMeshBundle
	var cave = bundle.cave_mesh_data

	var found_east_floor_step = false
	var found_east_ceil_step = false
	var found_south_floor_step = false
	var found_south_ceil_step = false

	for i in range(cave.vertices.size()):
		var v = cave.vertices[i]
		var norm = cave.normals[i]
		# East boundary lx = c_size: step wall faces -X into room
		if is_equal_approx(v.x, float(c_size)) and norm.is_equal_approx(Vector3.LEFT):
			if v.y >= 4.0 and v.y <= 9.0:
				found_east_floor_step = true
			if v.y >= 21.0 and v.y <= 27.0:
				found_east_ceil_step = true
		# South boundary lz = 0: step wall faces +Z into room
		if is_equal_approx(v.z, 0.0) and norm.is_equal_approx(Vector3.BACK):
			if v.y >= 4.0 and v.y <= 9.0:
				found_south_floor_step = true
			if v.y >= 21.0 and v.y <= 27.0:
				found_south_ceil_step = true

	assert_true(found_east_floor_step, "Must emit vertical floor step wall at East seam (lx=n) facing -X")
	assert_true(found_east_ceil_step, "Must emit vertical ceiling step wall at East seam (lx=n) facing -X")
	assert_true(found_south_floor_step, "Must emit vertical floor step wall at South seam (lz=0) facing +Z")
	assert_true(found_south_ceil_step, "Must emit vertical ceiling step wall at South seam (lz=0) facing +Z")

func test_directional_subterranean_forward_prioritization() -> void:
	## Validates that chunks directly in the player's forward view cone
	## are prioritized into Tier 1 and Tier 2, and that forward radius reach is extended.
	var coord = SubterraneanStreamCoordinator.new()
	var focus_chunk = ChunkCoord.new(0, 0)
	var mouth_cache: Dictionary = {}

	# Setup chunks along +X axis (Player looking East along +X)
	var c_focus = ChunkCoord.new(0, 0)
	var c_forward1 = ChunkCoord.new(1, 0)
	var c_forward2 = ChunkCoord.new(2, 0)
	var c_forward3 = ChunkCoord.new(3, 0)
	var c_forward4 = ChunkCoord.new(4, 0)
	var c_backward1 = ChunkCoord.new(-1, 0)
	var c_backward2 = ChunkCoord.new(-2, 0)
	var c_backward3 = ChunkCoord.new(-3, 0)

	var all_chunks = [c_focus, c_forward1, c_forward2, c_forward3, c_forward4, c_backward1, c_backward2, c_backward3]
	for c in all_chunks:
		coord.register_surface_chunk(c, false)
		mouth_cache[c.to_key()] = false

	# Player is subterranean at Y=10.0 (surface at 50.0), looking East (+X)
	var sub_pos = Vector3(0.0, 10.0, 0.0)
	var look_dir = Vector3(1.0, 0.0, 0.0) # East (+X)

	var tiers = coord.get_tiered_chunks_to_promote(sub_pos, focus_chunk, 50.0, mouth_cache, look_dir)
	var tier1 = tiers["tier1"]
	var tier2 = tiers["tier2"]
	var tier3 = tiers["tier3"]

	# 1. Tier 1 must contain focus chunk, c_forward1 (dist 1, dot 1.0), and c_forward2 (dist 2, dot 1.0)
	var has_f1 = false
	var has_f2 = false
	for c in tier1:
		if c.equals(c_forward1): has_f1 = true
		if c.equals(c_forward2): has_f2 = true

	assert_true(has_f1, "Immediate forward chunk (1, 0) must be in Tier 1")
	assert_true(has_f2, "Direct forward gaze chunk (2, 0) must be prioritized in Tier 1")

	# 2. Tier 2 must contain forward chunk at distance 3 (3, 0)
	var has_f3 = false
	for c in tier2:
		if c.equals(c_forward3): has_f3 = true
	assert_true(has_f3, "Distance 3 forward chunk (3, 0) must be in Tier 2")

	# 3. Forward chunk at distance 4 (4, 0) must be eligible in Tier 3
	var has_f4 = false
	for c in tier3:
		if c.equals(c_forward4): has_f4 = true
	assert_true(has_f4, "Distance 4 forward chunk (4, 0) must be eligible under forward promotion radius")

	# 4. Backward chunk at distance 3 (-3, 0) must NOT be eligible (outside backward radius 2)
	var has_b3 = false
	for c in tier1 + tier2 + tier3:
		if c.equals(c_backward3): has_b3 = true
	assert_false(has_b3, "Distant backward chunk (-3, 0) must NOT be eligible for promotion")

	# 5. Backward chunks (-1, 0) and (-2, 0) must NOT be in Tier 1 or Tier 2
	for c in tier1 + tier2:
		assert_false(c.equals(c_backward1), "Backward chunk (-1, 0) must not be in Tier 1/2")
		assert_false(c.equals(c_backward2), "Backward chunk (-2, 0) must not be in Tier 1/2")

func test_tier3_sort_prioritizes_facing_chunks() -> void:
	## Validates that Tier 3 peripheral chunks are sorted with look_dir weighting,
	## ensuring chunks in front of player are scheduled before chunks behind player.
	var coord = SubterraneanStreamCoordinator.new()
	var focus_chunk = ChunkCoord.new(0, 0)
	var mouth_cache: Dictionary = {}

	# Create two diagonal chunks at distance 2: one facing (+2, +2) and one behind (-2, -2)
	var c_front_diag = ChunkCoord.new(2, 2)
	var c_back_diag = ChunkCoord.new(-2, -2)

	coord.register_surface_chunk(c_front_diag, false)
	coord.register_surface_chunk(c_back_diag, false)
	mouth_cache[c_front_diag.to_key()] = false
	mouth_cache[c_back_diag.to_key()] = false

	# Player looking towards (+1, 0, +1)
	var look_dir = Vector3(1.0, 0.0, 1.0).normalized()
	var sub_pos = Vector3(0.0, 10.0, 0.0)

	var chunks = coord.get_chunks_to_promote(sub_pos, focus_chunk, 50.0, mouth_cache, look_dir, false)
	assert_true(chunks.size() >= 2, "Must return both chunks")

	var front_idx = -1
	var back_idx = -1
	for i in range(chunks.size()):
		if chunks[i].equals(c_front_diag): front_idx = i
		if chunks[i].equals(c_back_diag): back_idx = i

	assert_true(front_idx >= 0 and back_idx >= 0, "Both chunks must be present")
	assert_true(front_idx < back_idx, "Forward-facing chunk (%d) must be scheduled before backward chunk (%d)" % [front_idx, back_idx])

func test_voxel_world_camera_forward_direction() -> void:
	## Validates that VoxelWorld._get_focus_forward() correctly reads the camera orientation
	## when a camera_rig with yaw is attached to focus_target.
	var world = VoxelWorldClass.new()

	# Create a mock focus target with camera_rig
	var target = Node3D.new()
	var rig = Node3D.new()
	rig.name = "camera_rig"
	target.add_child(rig)

	# Mock camera with yaw rotated to East (-PI/2)
	var cam = Camera3D.new()
	cam.name = "camera"
	cam.rotation.y = -PI * 0.5
	rig.add_child(cam)

	world.focus_target = target
	var forward_vec = world._get_focus_forward()

	# -basis.z of a node rotated by -PI/2 around Y points towards (+1, 0, 0) (East)
	assert_true(forward_vec.x > 0.9, "Focus forward vector must reflect camera yaw towards East (+X) (got %s)" % forward_vec)
	assert_true(absf(forward_vec.z) < 0.1, "Focus forward Z must be near 0 when looking East (got %s)" % forward_vec)

	target.free()
	world.free()

func test_chunks_properly_load_voxels_facing_player() -> void:
	## Validates that chunks facing the player in the underground arena
	## are prioritized for promotion, generate valid subterranean voxel/chasm data,
	## and produce non-empty geometry facing into the chamber without X-ray gaps.
	var world_config = WorldConfig.new()
	var bounds = world_config.create_world_bounds()
	var gen = LayeredTerrainGenerator.new(world_config.world_seed)
	var mesher = VoxelMesherClass.new()
	var reg = MaterialRegistry.create_default_registry()

	# Scenario from screenshot: player at Pos: (-413.0, 3.0, -746.9) in Chunk (-13, -24)
	var player_pos = Vector3(-413.0, 3.0, -746.9)
	var focus_chunk = bounds.world_to_chunk(player_pos)
	assert_eq(focus_chunk.x, -13, "Focus chunk X must be -13")
	assert_eq(focus_chunk.z, -24, "Focus chunk Z must be -24")

	# Player facing West towards the arena complex (-X: look_dir = (-1.0, 0.0, 0.0))
	var look_dir = Vector3(-1.0, 0.0, 0.0)

	var coord = SubterraneanStreamCoordinator.new()
	var mouth_cache: Dictionary = {}

	# Register loaded chunks in view distance around (-13, -24)
	var chunks_in_view: Array[ChunkCoord] = []
	for dz in range(-3, 4):
		for dx in range(-4, 2):
			var c = ChunkCoord.new(focus_chunk.x + dx, focus_chunk.z + dz)
			coord.register_surface_chunk(c, false)
			mouth_cache[c.to_key()] = false
			chunks_in_view.append(c)

	var surf_h = float(gen.height_at(bounds.world_to_column(player_pos), bounds))
	var to_promote = coord.get_chunks_to_promote(player_pos, focus_chunk, surf_h, mouth_cache, look_dir, false)

	# Verify that chunks directly in front of the player are scheduled for promotion:
	# (-14, -24) at dist 1, (-15, -24) at dist 2, (-16, -24) at dist 3
	var promoted_facing: Array[ChunkCoord] = []
	for c in to_promote:
		if c.z == -24 and c.x < -13:
			promoted_facing.append(c)

	assert_true(promoted_facing.size() >= 3, "Chunks facing player along gaze line (-14, -15, -16) must be promoted (got %d)" % promoted_facing.size())

	# Now generate and mesh the promoted chunks facing the player
	for c in promoted_facing:
		var s_data = gen.generate_surface(c, bounds)
		var sub_data = gen.generate_subterranean(s_data, c, bounds)
		assert_not_null(sub_data, "Subterranean data must be generated for facing chunk %s" % c)

		var bundle = mesher.build_mesh(sub_data, reg) as DualMeshBundle
		assert_not_null(bundle, "DualMeshBundle must be produced for facing chunk %s" % c)

		# If chunk is an arena or chasm chunk, verify it possesses cave mesh geometry
		if ("has_chasm" in sub_data and sub_data.has_chasm) or (sub_data is VoxelChunkDataClass):
			assert_true(bundle.has_cave_geometry(), "Chunk %s facing player must contain cave geometry" % c)
			assert_true(bundle.cave_mesh_data.get_triangle_count() > 0, "Chunk %s facing player must have non-empty cave triangles" % c)

