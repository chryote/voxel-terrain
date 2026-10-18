# Underground & Arena Chunking Optimization Guide

## 1. Executive Summary

Procedural generation benchmarks (`baseline.json` and `bench_chasm_carving.gd`) highlight a significant performance disparity between surface terrain streaming and subterranean chasm/arena generation:

| Pipeline Stage | Surface Chunk (16×16 / 32×32) | Subterranean Chasm / Arena Chunk | Disparity |
| :--- | :--- | :--- | :--- |
| **Generation Time** | ~4.0 ms (16×16) / ~13.4 ms (32×32) | ~42.6 ms (16×16) / ~90–120 ms (32×32) | **~8× to 10× slower** |
| **Meshing Time** | ~1.5 ms (16×16) / ~5.6 ms (32×32) | ~8.0 ms (16×16) / ~22–35 ms (32×32) | **~4× to 6× slower** |
| **Collision Baking** | 1 Trimesh shape (surface) | 2 Trimesh shapes (surface + cave) | **2× baking cost** |
| **Perceived Streaming Latency** | Instantaneous (< 22 ms total) | Noticeable hitch / queue delay (> 60–150 ms) | High queue pressure |

While the surface layer achieves ~14 ms streaming via **stride-4 coarse grid interpolation** and **single-heightfield greedy meshing**, underground chasm and combat arena chunks incur heavy mathematical, algorithmic, and meshing penalties.

This document details the root bottlenecks and provides an actionable, prioritized roadmap to hasten underground chasm and arena chunk loading.

---

## 2. Root Cause Analysis

### Bottleneck A: Hidden Noise Multiplicity in `UndergroundChasmSampler`
Contrary to intuition, the dual-2D heightmap noise maps (`floor_noise` and `ceil_noise`) are **not** the bottleneck. The real bottleneck is the surrounding noise stack evaluated per column in `sample_column()`:
1. **Per-Column Domain Warping:** `wall_warp_noise` (2-octave FBM) is sampled twice per column for $(X, Z)$ coordinate displacement.
2. **Continental Ocean Falloff Clamping:** `sample_rift_mask()` calls `continent_mask.get_land_raw()`. This internally samples **6 domain-warp fractal noises + 1 4-octave shape fractal noise** on *every single column* ($34 \times 34 = 1,156$ times per chunk).
3. **Pillar & Mineral Noise:** Support column noise (`pillar_noise`) and 3D crystal noise (`crystal_noise.get_noise_3d`) are sampled per column.
4. **No Grid Stride:** Surface generation evaluates noise on a sparse $9 \times 9$ grid (stride 4) and interpolates. The chasm sampler evaluates all $1,156$ columns at full resolution with zero downsampling.

### Bottleneck B: False-Positive Fallbacks to 3D Voxel Carving (185k Voxels)
In `LayeredTerrainGenerator.generate_subterranean()`:
- The fast 2.5D bypass (`generate_chasm_data()`) is disabled whenever `can_tunnel_intersect_cell()` or `can_mouth_intersect_cell()` returns `true`.
- In practice, broad AABB checks for worm tunnels trigger frequent false positives across entire vertical chunk columns ($Y = 0 \dots 160$).
- When triggered, the generator drops out of 2.5D mode and allocates/iterates a full **$34 \times 160 \times 34 = 184,960$ voxel array in GDScript**, traversing 3D worm tunnels and mouth funnels per voxel.

### Bottleneck C: Meshing Multiplicity in `ChasmShellMesher`
`SurfaceShellMesher` processes 1 heightfield. By comparison, `ChasmShellMesher` generates a `DualMeshBundle` requiring:
1. Complete surface mesh pass (`_surface_mesher.build_mesh`).
2. Subterranean floor greedy meshing pass.
3. Subterranean ceiling greedy meshing pass.
4. Subterranean water greedy meshing pass.
5. Column-by-column **X-axis vertical curtain walls** (arena boundary steps, basalt pillars, and cavern bounding walls).
6. Column-by-column **Z-axis vertical curtain walls**.

Vertical curtain walls currently generate unmerged quad strips along jagged boundaries, inflating vertex counts, indices, and GDScript looping overhead.

### Bottleneck D: Dual Concave Trimesh Collision Baking
Worker threads must bake two separate complex `ConcavePolygonShape3D` instances per chunk via `OffThreadCollisionBaker`. Cave collision geometry has complex interior topology (overhangs, pillars, vertical drops), which takes 2–3× longer to compute in Godot's physics engine than a single continuous surface heightfield.

---

## 3. Actionable Optimization Tasks

### Priority 1: Instant Wins (Low Effort, High Impact)

#### Task 1.1: Fast Early-Exit Corridor Masking (Skip Unwarped Void Columns) [COMPLETED]
- **File:** `res://src/generation/caves/underground_chasm_sampler.gd`
- **Problem:** `get_warped_coordinates()` calculates two 2-octave FBM noise samples *before* checking if the column is anywhere near a chasm or arena.
- **Solution:** Sample `rift_noise.get_noise_2d(wx, wz)` first without domain warping.
  - Compute a conservative margin based on `config.chasm_wall_warp_amplitude` (e.g., `margin = wall_warp_amplitude * rift_frequency * 2.0`).
  - If `raw_unwarped_rift < (chasm_rift_threshold - margin)`, return early immediately (`is_chasm = false`).
- **Impact:** Skips domain warping, continent mask, floor, ceiling, and pillar noise for ~70–80% of columns in non-chasm regions of boundary chunks.

#### Task 1.2: Cache or Coarse-Sample the Continent Land Mask [COMPLETED]
- **File:** `res://src/generation/caves/underground_chasm_sampler.gd`
- **Problem:** `continent_mask.get_land_raw()` runs 7 multi-octave noises on every column just to check if the cave is near ocean water.
- **Solution:**
  1. **Chunk AABB Culling:** In `can_chasm_intersect_cell()`, sample `continent_mask.get_land_raw()` at the 4 chunk corners. If all corners have `land_raw > 0.20`, the entire chunk is deep inland. Set a chunk-level flag `is_deep_inland = true`.
  2. Inside `sample_rift_mask()`, if `is_deep_inland == true`, skip calling `get_land_raw()` entirely!
- **Impact:** Eliminates ~8,000 noise samples per inland subterranean chunk ($>90\%$ of landmass).

#### Task 1.3: Suppress 3D Worm Tunnels in Core Combat Arenas [COMPLETED]
- **File:** `res://src/generation/layered_terrain_generator.gd`, `res://src/generation/caves/subterranean_tunnel_sampler.gd`
- **Problem:** Combat arenas already suppress support pillars (`is_pillar = false`) to keep the battle floor clear. However, if a 3D worm tunnel intersects the arena AABB, the entire chunk drops into 185k voxel generation.
- **Solution:** 
  1. In `SubterraneanTunnelSampler`, mathematically taper worm tunnel radius to 0 using a smooth Hermite curve over a 0.04 rift margin before reaching the arena threshold (`arena_supp <= 0.0`), naturally terminating tunnels into solid stone walls without open boundary seams.
  2. In `generate_subterranean()`, check if the chunk is in an arena (`cave_carver.chasm_sampler.is_arena(mid_wx, mid_wz)`), allowing core arena chunks to bypass `can_tunnel` and generate directly via the fast 2.5D heightfield path (`generate_chasm_data()`).
- **Impact:** Forces core arena chunks to bypass 3D voxelization, dropping generation time from ~45 ms down to < 10 ms with 0 seam mismatches.

---

### Priority 2: Algorithmic & Meshing Improvements (Medium Effort, High Impact)

#### Task 2.1: Tighten Vertical Carving Extents for 3D Fallback [COMPLETED]
- **File:** `res://src/generation/layered_terrain_generator.gd`
- **Problem:** When 3D carving does run, it iterates up to `max_h = 160` (or `bounds.chunk_size * 4`), iterating tens of thousands of air voxels above the surface or subterranean ceiling.
- **Solution:**
  - Restrict the carving loop $Y$ boundaries to `[chasm_min_y - 2, mini(max_surface_h, chasm_max_y + 4)]`.
  - Skip voxel allocation and loops for strata known to be pure solid rock or open sky.
- **Impact:** Reduces voxel iteration count from ~185,000 to ~50,000 per carved chunk (~60% reduction in loop time).

#### Task 2.2: Greedy Merging for Vertical Curtain Walls in `ChasmShellMesher`
- **File:** `res://src/meshing/chasm_shell_mesher.gd`
- **Problem:** Vertical curtain walls along $X$ and $Z$ are generated per column. Adjacent columns with the same `floor_y` and `ceil_y` create separate quads instead of merged quads.
- **Solution:**
  - Implement 1D run-length greedy merging along $X$ and $Z$ curtain walls: if adjacent columns share identical boundary status, floor elevation, ceiling elevation, and material, merge them into a single wide quad.
- **Impact:** Reduces vertex count by 40–60% on vertical walls and cuts meshing time by ~3–5 ms.

#### Task 2.3: Skip Cave Geometry Passes for Chunks without Chasms
- **File:** `res://src/meshing/chasm_shell_mesher.gd`
- **Problem:** Chunks with `has_chasm == false` already early-exit, but chunks where chasm columns are completely walled off or outside the active rift still execute water and curtain scans.
- **Solution:**
  - Maintain a count `chasm_column_count` in `ChasmChunkData`. If 0, bypass ceiling, floor, water, and wall meshing completely.

---

### Priority 3: Streaming, Priority & Collision Tuning (Low-to-Medium Effort)

#### Task 3.1: Selective Arena Promotion in `SubterraneanStreamCoordinator`
- **File:** `res://src/streaming/subterranean_stream_coordinator.gd`
- **Problem:** When the player reaches descent depth, all chunks within `subterranean_radius_chunks` (radius 2 = 25 chunks) are promoted simultaneously, causing worker thread queue saturation.
- **Solution:**
  - Prioritize promotion by viewing cone: Chunks in front of the player camera receive `high_priority = true` in `ChunkScheduler`.
  - Chunks behind the player or at the peripheral radius (Tier 3) are throttled via `max_tier3_promotions_per_frame = 2`.
- **Impact:** Eliminates frame drops and stalls during subterranean descent.

#### Task 3.2: Decoupled / Simplified Cave Collision Shapes
- **File:** `res://src/streaming/off_thread_collision_baker.gd`
- **Problem:** Complex cave ceiling geometry is included in the collision mesh even though the player rarely or never touches the ceiling in high arenas ($Y = 28$).
- **Solution:**
  - For high subterranean arenas (`arena_ceiling_y >= 20`), omit ceiling quads from the collision shape mesh or use a simplified bounding plane.
  - Only bake collision for floor, stepped ledges, and vertical walls.
- **Impact:** Cuts collision baking time in half on arena chunks.

---

### Priority 4: GDExtension / C++ Acceleration (Future Roadmap)

#### Task 4.1: Port `UndergroundChasmSampler` Column Loop to C++
- Porting `sample_column()` into a C++ GDExtension module removes Godot Variant call overhead and allows SIMD batch evaluation of `FastNoiseLite`.
- **Target:** Subterranean column sampling for a $32 \times 32$ chunk drops from ~12 ms to < 0.8 ms.

#### Task 4.2: Port `ChasmShellMesher` Greedy Passes to C++
- Direct pointer manipulation for `floor_heights`, `ceil_heights`, and `chasm_flags` with fast `PackedVector3Array` pre-allocation.
- **Target:** Meshing drops from ~8 ms to < 0.5 ms.

---

## 4. Implementation Checklist & Target Milestones

| Step | Action Item | Target File | Expected Gain |
| :---: | :--- | :--- | :--- |
| [x] | **1. Unwarped Rift Early Exit** | `underground_chasm_sampler.gd` | ~30% faster sampling |
| [x] | **2. Inland Continent Mask Bypass** | `underground_chasm_sampler.gd` | ~50% faster inland sampling |
| [x] | **4. Clamped $Y$ Bounds on 3D Carving** | `layered_terrain_generator.gd` | ~60% faster fallback carving |
| [ ] | **5. Greedy Curtain Wall Meshing** | `chasm_shell_mesher.gd` | 40% fewer vertices, ~3–5 ms meshing |
| [ ] | **6. Ceiling Collision Exclusion** | `chasm_shell_mesher.gd` / baker | ~50% faster cave collision baking |
| [ ] | **7. Directional Tier-1 Promotion** | `subterranean_stream_coordinator.gd` | Zero frame hitching on arena entry |

---

## 5. Verification & Benchmark Strategy

To validate improvements after each task:
1. **Unit Tests:**
   ```bash
   # Verify arena shape, ledges, and suppression invariants hold true
   godot --headless --script tests/framework/test_runner.gd --case=TestChasmArena
   godot --headless --script tests/framework/test_runner.gd --case=TestSubterraneanStreaming
   ```
2. **Benchmark Execution:**
   ```bash
   # Run baseline benchmark comparison
   godot --headless --script tests/framework/test_runner.gd --benchmark
   ```
   *Target: `subterranean_chasm_dense_chunk_16` runtime drops from **42.6 ms** to **< 12.0 ms**.*
