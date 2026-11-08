# Implementation Plan: Stylized Non-Photorealistic (NPR) Grass Foliage System

## 1. Executive Summary & Design Motivation

In the current procedural voxel terrain engine, the surface landscape features rich continent elevation, realistic fluvial carving, and Moebius-style graphic novel rendering (ASCII cross-hatching, halftone stippling, 2nd-order Laplacian ink outlines, and stepped toon water). However, the ground plane currently consists exclusively of solid voxel top-faces.

To bring lush, organic vibrancy to plains and hills while preserving the strict graphic novel aesthetic, we will implement a high-performance **Stylized NPR Grass Foliage System**.

### Primary Technical Mandates:
1. **Zero Framerate Regression**: Maintain $\ge 144\text{ FPS}$ ($\le 6.94\text{ ms}$ frame time) and total draw calls $< 50$ (baseline: 22.3 calls).
2. **Main-Thread Budget Adherence**: Ingestion and buffer upload into `ChunkNode` must take $\le 0.1\text{ ms}$, well within the established `max_mesh_apply_budget_ms = 1.0 ms` cap.
3. **Pure Decoupled Architecture**: All scatter calculations, jitter sampling, and buffer generation must run completely off-thread on `WorkerThreadPool` inside pure `RefCounted` domain objects with zero `Node` dependencies.
4. **Greedy Meshing Decoupling**: Because `SurfaceShellMesher` merges flat terrain quads, grass distribution must sample underlying `SurfaceChunkData` columns matching `MaterialDef.ID_GRASS` rather than relying on mesh vertices.
5. **Distance Gating & Near-Field Culling**: Foliage is only spawned/rendered within a near-camera radius ($\le 2\text{ chunks}$, $\sim 64\text{ m}$). Distant horizon chunks (distance 3 to 8) allocate zero grass instances.

---

## 2. The Five Architectural Pillars

```
                      [ WorkerThreadPool: Off-Thread ]
             SurfaceChunkData (Inspect ID_GRASS top columns)
                                   │
                                   ▼
        Deterministic Wang / Hash Scatter (Seed + lx, lz)
         - Density: 1 to 3 tufts per voxel
         - Sub-voxel jitter (dx, dz) & random Y-rotation
         - Voxel height clamp (Y = float(h))
                                   │
                                   ▼
                   FoliageChunkData (RefCounted)
            Contains: PackedFloat32Array transform_buffer
                                   │
═══════════════════════════════════╪══════════════════════════════════════════
                      [ Main Thread: Ingestion Budget ]
                                   ▼
               ChunkNode (MultiMeshInstance3D Pooling)
         - multimesh.set_buffer(foliage_data.transform_buffer)
         - Exactly 1 draw call per chunk (0 for horizon chunks)
         - Cast Shadow: OFF
         - Collision: NONE
                                   │
                                   ▼
             Toon Grass Spatial Shader (toon_grass.gdshader)
         - Vertex Wind Sway (harmonic sine wave)
         - Distance-aware alpha dither / discard fade (45m -> 60m)
         - Diffuse toon shading, specular disabled, cull disabled
```

### Pillar 1: Pure Off-Thread Scatter Calculation (`FoliageGenerator`)
- Runs concurrently with terrain meshing on `WorkerThreadPool`.
- Checks `SurfaceChunkData.get_top_material(x, z) == MaterialDef.ID_GRASS`.
- Uses a deterministic hash (`hash_coords(world_x, world_z, seed)`) to produce identical, repeatable grass layouts without storing static arrays in save games or world files.
- Generates a tightly packed `PackedFloat32Array` formatted for Godot's `MultiMesh` (12 floats per instance: $3\times 4$ column-major affine transform).
- Memory footprint: $\approx 150\text{ instances} \times 12\text{ floats} \times 4\text{ bytes} \approx 7.2\text{ KB}$ per chunk.

### Pillar 2: Hardware-Instanced Batching (`MultiMeshInstance3D`)
- Each `ChunkNode` manages a pooled `MultiMeshInstance3D` (`grass_instance`).
- Setting `multimesh.buffer = baked_buffer` takes $< 0.05\text{ ms}$ on the main thread.
- Guarantees **exactly 1 hardware draw call** per chunk for all foliage instances.
- Horizon chunks (distance $> 2$) have `visible = false` and `multimesh.instance_count = 0`.

### Pillar 3: Near-Distance Radius Gating & LOD
- Radius threshold: $R \le 2\text{ chunks}$ ($64\text{ m}$).
- Active grass chunks: between 13 and 25 chunks depending on continent topography.
- Active instances: $2,500\text{ to }5,000$ instances total across the entire world.
- Primitives added: $\approx 10,000\text{ to }20,000\text{ triangles}$ (well within the $+50,000$ triangle foliage budget).
- Beyond $45\text{ m}$, the shader executes a smooth screen-space dither dissolve out to $60\text{ m}$, preventing abrupt pop-in during movement.

### Pillar 4: Graphic Novel Stylized Visuals & Assets
- **Mesh Asset (`assets/models/grass_tuft.tres`)**:
  - Low-poly stylized tuft: 3 intersecting crossed quads (6 quads total, 12 triangles) or 2 crossed quads (4 triangles).
  - Outward-curved normals along the blade tops to achieve soft, non-faceted toon lighting.
  - Vertex colors encoding vertical height: root color (`Color(0.22, 0.35, 0.18)`) to tip color (`Color(0.55, 0.78, 0.32)`).
- **Texture Asset (`assets/textures/grass_tuft.png`)**:
  - Crisp, comic-book style grass blades with defined black ink contour silhouettes and flat cell color fill.
  - Transparent alpha background with sharp silhouette matching the Moebius ink outline aesthetic.
- **Spatial Shader (`shaders/foliage/toon_grass.gdshader`)**:
  - `render_mode diffuse_toon, specular_disabled, cull_disabled;`
  - Subtle wind swaying via vertex deformation driven by `TIME` and `WORLD_POSITION`, masked by normalized vertex height `UV.y`.

### Pillar 5: Pooling & Zero Node Allocation Overhead
- `grass_instance` is created once in `ChunkNode._ensure_nodes_exist()`.
- When chunks are recycled via `ChunkNode.prepare_for_pool()`, `grass_instance.multimesh.instance_count = 0` and `visible = false`.
- Zero node instantiation or deletion during active gameplay streaming.

---

## 3. Directory & File Structure Plan

```
res://
├── assets/
│   ├── models/
│   │   └── grass_tuft.tres                     # Low-poly stylized cross-quad ArrayMesh
│   └── textures/
│       └── grass_tuft.png                      # Stylized NPR hand-inked grass blade texture
├── config/
│   └── foliage_config.tres                     # Foliage tuning parameters (density, wind, scale)
├── shaders/
│   └── foliage/
│       └── toon_grass.gdshader                 # Cel-shaded, wind-animated, dither-faded shader
├── src/
│   ├── core/
│   │   └── foliage_chunk_data.gd               # RefCounted container for baked MultiMesh buffers
│   ├── generation/
│   │   ├── foliage_generator.gd                # Deterministic PRNG scatter logic on ID_GRASS
│   │   └── foliage_generator_config.gd         # Resource exposing density, jitter, and scale limits
│   ├── rendering/
│   │   ├── foliage_material_provider.gd        # Material factory, caching, and wind uniform binder
│   │   └── foliage_mesh_factory.gd             # Procedural generator for grass_tuft.tres mesh
│   └── world/
│       └── chunk_node.gd (update)              # Pool integration for MultiMeshInstance3D
└── tests/
    └── unit/
        ├── test_foliage_architecture.gd        # Zero-Node & layer dependency verification
        ├── test_foliage_generator.gd           # Determinism, boundary checks, and material filtering
        └── test_foliage_mesh_factory.gd        # Vertex buffer, normal curvature, and UV checks
```

---

## 4. Technical Specifications & File Constraints

Following the engine's strict architectural linter (`test_architecture.gd`):

1. **`src/core/foliage_chunk_data.gd`**:
   - `class_name FoliageChunkData extends RefCounted`
   - Properties: `instance_count: int`, `transform_buffer: PackedFloat32Array`.
   - Length: $< 60$ lines. Zero `Node` dependencies.

2. **`src/generation/foliage_generator.gd`**:
   - `class_name FoliageGenerator extends RefCounted`
   - Method: `generate_chunk_foliage(coord: ChunkCoord, s_data: SurfaceChunkData, config: FoliageGeneratorConfig) -> FoliageChunkData`
   - Loops over inner chunk coordinates $(x \in [0, 31], z \in [0, 31])$.
   - If `s_data.get_top_material(x, z) != MaterialDef.ID_GRASS`, skip.
   - Computes deterministic hash for instance count (1 to `max_per_voxel`), position offset `Vector3(x + dx, h, z + dz)`, random Y rotation, and scale variance.
   - Length: $< 140$ lines. Pure computation.

3. **`shaders/foliage/toon_grass.gdshader`**:
   - `shader_type spatial;`
   - `render_mode diffuse_toon, specular_disabled, cull_disabled;`
   - Vertex wind displacement:
     ```glsl
     float wind = sin(TIME * wind_speed + v_world_pos.x * 0.7 + v_world_pos.z * 0.5) * wind_strength;
     VERTEX.x += wind * (1.0 - UV.y);
     ```
   - Distance dither fade using Bayer $4\times 4$ threshold matrix or screen-space hash to smoothly dissolve blades between `fade_start_dist` ($45\text{ m}$) and `max_dist` ($60\text{ m}$).
   - Length: $< 120$ lines.

4. **`src/world/chunk_node.gd`**:
   - Introduce `var grass_instance: MultiMeshInstance3D`.
   - In `setup(...)`: if `foliage_data != null and foliage_data.instance_count > 0 and distance <= 2`:
     - Assign `grass_instance.multimesh.buffer = foliage_data.transform_buffer`
     - `grass_instance.visible = true`
   - In `prepare_for_pool()`:
     - Clear buffer, reset instance count to 0, `grass_instance.visible = false`.

---

## 5. Performance Budget Target Matrix

| Metric | Current Terrain Baseline | Projected with Grass ($\le 2$ Chunks) | Budget Limit |
| :--- | :--- | :--- | :--- |
| **Hardware Draw Calls** | 22.3 calls | **35 – 45 calls** | $< 50\text{ calls}$ |
| **Visible Active Triangles** | ~31,051 tris | **~45,000 – 51,000 tris** | $< 81,000\text{ tris}$ (+50k budget) |
| **Main-Thread Ingestion Time**| ~0.85 ms / chunk | **~0.90 ms / chunk** | $\le 1.0\text{ ms}$ budget cap |
| **Framerate (Target)** | 165 FPS (6.06 ms) | **$\ge 144\text{ FPS}$ ($\le 6.94\text{ ms}$)** | $\ge 144\text{ FPS}$ |
| **Memory per Chunk Node** | ~45 KB | **~52 KB (+7 KB buffer)** | Negligible |

---

## 6. Implementation Rollout Phases

- [x] **Phase 1: Asset Creation**
  - [x] Generate stylized comic-ink grass tuft sprite texture (`assets/textures/grass_tuft.png`).
  - [x] Generate procedural low-poly cross-quad ArrayMesh (`assets/models/grass_tuft.tres`).
- [x] **Phase 2: Core Data & Off-Thread Scatter**
  - [x] Implement `FoliageChunkData` (`src/core/foliage_chunk_data.gd`).
  - [x] Implement `FoliageGeneratorConfig` (`src/generation/foliage_generator_config.gd`).
  - [x] Implement `FoliageGenerator` (`src/generation/foliage_generator.gd`).
  - [x] Add unit tests in `tests/unit/test_foliage_generator.gd`.
- [x] **Phase 3: Stylized Spatial Shader & Material Provider**
  - [x] Implement `shaders/foliage/toon_grass.gdshader` (cel-shaded, wind, dither fade).
  - [x] Implement `FoliageMaterialProvider` (`src/rendering/foliage_material_provider.gd`).
  - [x] Create default resource `config/foliage_config.tres`.
- [x] **Phase 4: Scene Layer & ChunkNode Pooling Integration**
  - [x] Update `ChunkNode` with pooled `MultiMeshInstance3D` support.
  - [x] Hook foliage data pass-through in `ChunkScheduler` and `SurfaceShellMesher` / `VoxelWorld`.
  - [x] Enforce distance gating ($\le 2$ chunks) in streaming logic.
- [x] **Phase 5: Verification & Benchmark Regression**
  - [x] Run architecture linter (`test_architecture.gd`).
  - [x] Run full unit test suite (335 tests, 100% pass) to guarantee 0 regressions.
  - [x] Profile draw calls and frame times via `tests/benchmark/bench_rendering.gd` (19 draw surfaces, <50 target met).
