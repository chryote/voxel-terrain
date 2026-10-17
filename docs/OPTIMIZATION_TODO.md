# Terrain Generation & Meshing Optimization Roadmap (Surface & Subterranean)

A prioritized architectural blueprint and actionable TODO for optimizing procedural generation, greedy meshing, streaming, and collision performance in the Godot 4.4 Voxel Terrain framework.

---

## Executive Summary & Architecture Diagnostics

| Pipeline Stage | Current Characteristic | Primary Bottleneck | Optimization Target |
| :--- | :--- | :--- | :--- |
| **Surface Generation (Phase A)** | 2.5D Heightfield ($34 \times 34$) | Multi-octave fractal noise per column | Fast (~10–15 ms) $\rightarrow$ Target: **< 3 ms** |
| **Surface Meshing** | 2D Greedy Quad Merge | Non-merged vertical cliff quads | Low tri count $\rightarrow$ Target: **60% fewer cliff quads** |
| **Subterranean Generation (Phase B)** | 3D Voxel Array ($34 \times 34 \times 160$) | 185k voxel populator + 3D carve loops in GDScript | Heavy (~50–90 ms) $\rightarrow$ Target: **< 12 ms** |
| **Subterranean Meshing** | 3-Axis Greedy Merge over 185k cells | Monolithic vertical column traversal | High CPU latency $\rightarrow$ Target: **Sub-chunking / Direct heightfield** |
| **Streaming Promotion** | Sudden 25-chunk queue explosion | "Thundering Herd" on `WorkerThreadPool` | Queue stalls $\rightarrow$ Target: **Staggered directional priority** |
| **Physics Collision** | Off-thread `ConcavePolygonShape3D` | Baking cave BVH even when player is on surface | Wasted CPU cycles $\rightarrow$ Target: **Deferred cave collision baking** |

---

## Phase 1: Algorithmic Quick Wins (GDScript Optimization)

Quick optimizations requiring no breaking changes to data structures or engine APIs.

- [ ] **1.1 Greedy Merge Vertical Cliff Faces (Surface Shell)**
  - **Problem:** [`SurfaceShellMesher.gd`](file:///d:/GODOT/terrain/src/meshing/surface_shell_mesher.gd) greedily merges top horizontal quads, but creates individual 1-block quads for West/East/North/South cliff steps.
  - **Solution:** Add horizontal run-length merging to vertical cliff quads where adjacent columns share identical top and bottom elevations.
  - **Expected Gain:** 40%–60% reduction in surface mesh index/vertex count in hilly/mountainous terrain.

- [ ] **1.2 Defer Subterranean Collision Baking**
  - **Problem:** [`OffThreadCollisionBaker.gd`](file:///d:/GODOT/terrain/src/streaming/off_thread_collision_baker.gd) bakes both `surface_shape` and `cave_shape` whenever a subterranean chunk finishes, even though [`ChunkNode.gd`](file:///d:/GODOT/terrain/src/world/chunk_node.gd) disables cave collision while on the surface.
  - **Solution:** Only bake `surface_shape` during Phase B if the player is above ground. Bake `cave_shape` only when the player drops within promotion threshold or approaches a cave mouth.
  - **Expected Gain:** 30%–45% reduction in worker thread time during chunk generation.

- [ ] **1.3 Coarse Macro Topography Grid Interpolation**
  - **Problem:** [`MacroTopography.gd`](file:///d:/GODOT/terrain/src/generation/macro_topography.gd) computes multi-octave fractal noise (continentalness, erosion, ridge mountains) for every single column in the apron ($34 \times 34 = 1,156$ samples).
  - **Solution:** Sample macro noise on an $8 \times 8$ or $4 \times 4$ coarse stride across the chunk and bilinearly interpolate intermediate columns. Keep high-frequency noise (e.g. slope detail) at full resolution.
  - **Expected Gain:** 3x–4x faster surface column generation (drops Phase A from ~14 ms to ~4 ms).

- [ ] **1.4 Unify Mesher Axis Passes**
  - **Problem:** [`voxel_mesher.gd`](file:///d:/GODOT/terrain/src/meshing/voxel_mesher.gd) repeats nearly identical scanning and greedy-masking logic 3 times for $Y$, $X$, and $Z$ axes.
  - **Solution:** Consolidate into a parameterized 2D slice merger `_greedy_merge_slice(u_axis, v_axis, normal_axis)` to reduce code duplication and simplify profiling.

---

## Phase 2: Direct-Geometry Chasm & Arena Bypass

The single largest performance opportunity for subterranean chasms and combat arenas.

- [ ] **2.1 The "Bypass 3D Voxelization" Pattern for Chasms**
  - **Current Bottleneck:**
    ```
    2D Floor/Ceil Noise ──> Allocate 185k Voxels in RAM ──> Fill Solid Columns ──> Carve Air Voids ──> Run 3D Greedy Mesher ──> Dual Mesh
    ```
  - **Optimized Pipeline:**
    ```
    2D Floor/Ceil Noise ──> Direct 2D Heightfield Mesher (Floor & Inverted Ceiling) + Rift Boundary Wall Curtains ──> Cave Mesh
    ```
  - **Implementation Strategy:**
    - Since deep chasms are defined by `floor_noise` and `ceil_noise` with vertical warped walls, they are mathematically two 2.5D surfaces facing each other.
    - Mesh the chasm floor using the existing high-speed [`SurfaceShellMesher`](file:///d:/GODOT/terrain/src/meshing/surface_shell_mesher.gd).
    - Mesh the chasm ceiling identically with inverted normals (`Vector3.DOWN`).
    - Generate vertical curtain quads along rift boundary edges and pillars.
  - **Expected Gain:** Eliminates 3D voxel iteration entirely for chasms. Converts $O(N^3)$ chasm generation into an $O(N^2)$ operation (~5 ms instead of ~60 ms).

- [ ] **2.2 Chasm Arena POI Anchor System**
  - **Goal:** Procedurally generate wide, flat subterranean battle arenas / chambers without awkward jagged pillars in the combat zone.
  - **Implementation:**
    - Define an `ArenaFeature` mask in [`UndergroundChasmSampler.gd`](file:///d:/GODOT/terrain/src/generation/caves/underground_chasm_sampler.gd) where `raw_rift > 0.85` or at seeded POI coordinates.
    - Inside arena bounds, suppress random support pillars (`is_pillar = false`) and flatten `floor_noise` to a smooth amphitheater floor.
    - Add perimeter basalt columns / stepped perimeter spectator ledges.

---

## Phase 3: Vertical Sub-Chunking & Streaming Flow Control

Solving the vertical chunk scale and "Thundering Herd" thread starvation.

- [ ] **3.1 Vertical Sub-Chunk Partitioning ($32 \times 32 \times 16$ or $16 \times 16 \times 16$)**
  - **Problem:** Monolithic $32 \times 32 \times 160$ chunk columns force empty sky and solid deep-earth stone to be checked and meshed.
  - **Solution:**
    - Divide chunk columns into vertical sections of height 16.
    - Introduce an `is_uniform` / `is_empty` bitmask for each section.
    - If a subterranean section is entirely solid stone (no cave intersection) or entirely air (above terrain), mark it skipped.
  - **Expected Gain:** 70%+ of subterranean vertical chunks bypass meshing entirely.

- [ ] **3.2 Staggered Directional Subterranean Promotion**
  - **Problem:** Approaching a cave mouth promotes up to 25 surface chunks to subterranean at the same millisecond, flooding `WorkerThreadPool`.
  - **Solution:**
    - In [`subterranean_stream_coordinator.gd`](file:///d:/GODOT/terrain/src/streaming/subterranean_stream_coordinator.gd), introduce priority tiers:
      - **Tier 1 (Immediate):** Chunk the player is standing on or moving toward ($1$ chunk).
      - **Tier 2 (Nearby Entrance):** Chunks within 1 chunk of the cave mouth facing the player camera ($2$–$4$ chunks).
      - **Tier 3 (Deferred Peripheral):** Remaining chunks queued with rate-limiting ($1$–$2$ tasks scheduled per frame).
  - **Expected Gain:** Smooth 120+ FPS transition without thread starvation or camera stutter when entering caverns.

- [ ] **3.3 Trilinear Density Grid for 3D Worm Tunnels**
  - **Problem:** Non-chasm worm tunnels evaluate 3D Simplex noise at every single voxel in mixed coarse blocks.
  - **Solution:** Evaluate 3D tunnel noise at cell corners (stride 4) and trilinearly interpolate density values down to voxels.
  - **Expected Gain:** 8x reduction in expensive 3D simplex noise evaluations.

---

## Phase 4: Physics & Collision Optimization

- [ ] **4.1 Player-Centric Collision Distance Ring**
  - Ensure collision bodies are strictly disabled/uninstantiated beyond `collision_distance_chunks = 2`.
  - Distant visual chunks should remain purely visual `MeshInstance3D` nodes with zero physics overhead.

- [ ] **4.2 Simplified Collision Mesh (LOD 1 Physics)**
  - Mesh physics collision from a half-resolution index buffer ($16 \times 16$ grid instead of $32 \times 32$).
  - A player character moving at 6–10 m/s cannot perceive sub-voxel collision deviations, but reducing vertex count by 4x cuts Jolt/Godot Physics BVH tree generation time by ~75%.

---

## Phase 5: GDExtension (C++ / Rust) Acceleration Strategy

When GDScript algorithmic optimizations reach their maximum theoretical ceiling, isolate the computational hotspots into a lightweight GDExtension module.

### Target Candidates for C++ Migration:
1. **`VoxelMesher::build_mesh`:** Raw pointer array access, bitwise greedy merging, and SIMD mask operations (`PackedVector3Array` construction in C++ is 30x faster than GDScript).
2. **`Noise Batching / Domain Warping`:** Calling `FastNoiseLite` from C++ eliminates the Godot variant dispatch overhead on every coordinate query.

### What Stays in GDScript:
- Streaming coordination, world boundaries, player motor, camera, UI, and scene composition remain in GDScript for rapid game design and iteration.

---

## Implementation Priority Matrix

```
High Impact │  [2.1 Direct Chasm Bypass]       [3.1 Vertical Sub-Chunks]
            │  [1.2 Defer Cave Collision]      [5.1 GDExtension Mesher]
            │  [3.2 Staggered Promotion]       
            │
            │  [1.1 Cliff Face Merging]        [3.3 Trilinear Worm Noise]
            │  [1.3 Macro Noise Stride]        [4.2 Simplified Physics Mesh]
Low Impact  │  [1.4 Unify Mesher Passes]
            └─────────────────────────────────────────────────────────────
               Low Effort / Quick Wins            High Effort / Structural
```

---

## Next Iteration Checklist

When starting the next optimization iteration:
1. [ ] Implement **1.1** (Cliff face merging in `SurfaceShellMesher`) to lock in minimal surface triangle counts.
2. [ ] Implement **1.2** (Defer subterranean cave collision baking in `OffThreadCollisionBaker`).
3. [ ] Implement **3.2** (Priority throttling in `SubterraneanStreamCoordinator` to prevent thread herd spikes).
4. [ ] Prototype **2.1** (Direct 2D heightfield meshing for deep chasms) to eliminate 3D voxel overhead.
