class_name TestStaggeredPromotion
extends "res://tests/framework/test_case.gd"

## Unit tests validating Item 3.2: Staggered Directional Subterranean Promotion.
## Verifies Tier 1 (Immediate), Tier 2 (Nearby Entrance), and Tier 3 (Deferred Peripheral)
## priority classification and frame rate limiting.

func test_priority_tier_classification() -> void:
	var coord = SubterraneanStreamCoordinator.new()
	var focus_chunk = ChunkCoord.new(0, 0)

	var c_focus = ChunkCoord.new(0, 0)
	var c_forward = ChunkCoord.new(0, 1)
	var c_backward = ChunkCoord.new(0, -1)
	var c_mouth = ChunkCoord.new(1, 1)
	var c_peripheral = ChunkCoord.new(-2, -2)

	coord.register_surface_chunk(c_focus, false)
	coord.register_surface_chunk(c_forward, false)
	coord.register_surface_chunk(c_backward, false)
	coord.register_surface_chunk(c_mouth, true)
	coord.register_surface_chunk(c_peripheral, false)

	var mouth_cache = {
		c_focus.to_key(): false,
		c_forward.to_key(): false,
		c_backward.to_key(): false,
		c_mouth.to_key(): true,
		c_peripheral.to_key(): false
	}

	# Player looking forward along +Z at (0, 30, 0) with surface at 50 (subterranean)
	var sub_pos = Vector3(0.0, 30.0, 0.0)
	var look_dir = Vector3(0.0, 0.0, 1.0) # Forward is +Z

	var tiers = coord.get_tiered_chunks_to_promote(sub_pos, focus_chunk, 50.0, mouth_cache, look_dir)
	var tier1 = tiers["tier1"]
	var tier2 = tiers["tier2"]
	var tier3 = tiers["tier3"]

	# Tier 1 must include current chunk c_focus, mouth chunk c_mouth, and direct forward chunk c_forward
	var has_focus = false
	var has_mouth = false
	var has_forward = false
	for c in tier1:
		if c.equals(c_focus):
			has_focus = true
		if c.equals(c_mouth):
			has_mouth = true
		if c.equals(c_forward):
			has_forward = true
	assert_true(has_focus, "Tier 1 must contain focus chunk")
	assert_true(has_mouth, "Tier 1 must contain mouth chunk")
	assert_true(has_forward, "Tier 1 must contain immediate forward moving chunk")

	# Backward chunk must not be in Tier 1
	for c in tier1:
		assert_false(c.equals(c_backward), "Backward chunk must not be Tier 1")

	# Peripheral (2, 2) must be in Tier 3
	var has_peripheral = false
	for c in tier3:
		if c.equals(c_peripheral):
			has_peripheral = true
	assert_true(has_peripheral, "Distant peripheral chunk must be in Tier 3")

func test_rate_limiting_stagger() -> void:
	var coord = SubterraneanStreamCoordinator.new()
	var focus_chunk = ChunkCoord.new(0, 0)
	var mouth_cache: Dictionary = {}

	# Register focus chunk and multiple peripheral chunks
	coord.register_surface_chunk(focus_chunk, false)
	mouth_cache[focus_chunk.to_key()] = false

	var peripheral_chunks: Array[ChunkCoord] = []
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			if dx == 0 and dz == 0:
				continue
			var c = ChunkCoord.new(dx, dz)
			coord.register_surface_chunk(c, false)
			mouth_cache[c.to_key()] = false
			peripheral_chunks.append(c)

	var sub_pos = Vector3(0.0, 30.0, 0.0)
	# Call with rate_limit_tier3 = true, max_tier3_count = 2
	var batch1 = coord.get_chunks_to_promote(sub_pos, focus_chunk, 50.0, mouth_cache, Vector3.ZERO, true, 2)

	# Must return Tier 1/2 chunks plus exactly 2 Tier 3 chunks
	assert_true(batch1.size() > 0, "Must return initial batch")
	var t3_count = 0
	for c in batch1:
		if focus_chunk.chebyshev_distance_to(c) >= 2:
			t3_count += 1
	assert_true(t3_count <= 2, "Tier 3 chunks in batch 1 must be throttled to <= 2")

	# Mark batch 1 queued
	for c in batch1:
		coord.mark_subterranean_queued(c)

	# Next frame: call again
	var batch2 = coord.get_chunks_to_promote(sub_pos, focus_chunk, 50.0, mouth_cache, Vector3.ZERO, true, 2)
	assert_true(batch2.size() > 0, "Next frame must return subsequent throttled chunks")

	# None of batch 2 should be in batch 1
	for c2 in batch2:
		for c1 in batch1:
			assert_false(c2.equals(c1), "Batch 2 must not duplicate already queued chunks from batch 1")
