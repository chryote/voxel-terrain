# Voxel Terrain Framework (Godot 4.4)

An industry-standard, clean-architecture procedural voxel terrain framework built in GDScript for Godot 4.4+.

Designed with strict separation of concerns, zero tight coupling, asynchronous multi-threaded generation and meshing, a decoupled player module with third-person shooter mechanics, and a complete headless test suite (unit, benchmark, and regression).

---

## Architecture Overview

The codebase is split into two cleanly separated layers:

### 1. Pure Data & Logic Layer (`RefCounted`)
Contains zero `Node` dependencies, runs completely thread-safe on `WorkerThreadPool`, and runs in headless CI test runners without scene tree dependencies:
- **`src/core/`**:
  - `ChunkCoord`: (cx, cz) coordinates, 64-bit key packing, Chebyshev/Manhattan/Euclidean distance metrics.
  - `WorldBounds`: Fixed continent maximum bounds, coordinate space conversions, border clamping.
  - `SurfaceChunkData`: Compact column heights & material IDs with a **1-column apron** eliminating cross-chunk boundary seam queries during meshing.
  - `MaterialDef` & `MaterialRegistry`: Typed palette definitions (Grass, Dirt, Stone, Sand, Snow, Seabed).
  - `WorldConfig`: Typed resource managing world seed, map limits, sea level, view distance, and apply budgets.
- **`src/generation/`**:
  - `TerrainGenerator`: Abstract strategy interface.
  - `ContinentMask`: Smooth distance falloff to borders with simplex noise warping for organic coastlines that naturally fade into ocean before map borders.
  - `ContinentGenerator`: Deterministic multi-octave FBM fractal elevation + ridged mountain peaks + slope/altitude material classifier.
  - `ContinentGeneratorConfig`: Procedural noise tuning parameters.
- **`src/meshing/`**:
  - `Mesher`: Abstract meshing interface.
  - `MeshData`: Pure vertex, normal, color, UV, UV2, and index buffers generated safely on worker threads.
  - `SurfaceShellMesher`: Surface-shell voxel mesher with **2D greedy top-face merging** (merging uniform flat areas down to 1 single quad) and outward-facing vertical step/cliff walls.
- **`src/painting/`**:
  - `TerrainPaintLayer`: Typed resource defining splat channels (R: Dirt Path, G: Sand, B: Cobblestone, A: Snow) with foliage suppression flags.
  - `TerrainPaintData`: Per-chunk 4-channel (RGBA8) splatmap buffer with smooth Hermite brush falloff and direct Godot `Image` and `ImageTexture` generation.
  - `ChunkPaintManager`: Multi-chunk brush coordination, boundary clipping, splatmap texture cache, and discrete voxel material painting directly into `SurfaceChunkData`.
  - `TerrainPainter`: High-level painter with continuous stroke interpolation (no gaps during rapid mouse dragging) and a full undo/redo stack.
  - `PaintStroke`: Serializable brush stroke records supporting `PAINT`, `ERASE`, `SMOOTH`, and `REPLACE` modes.
- **`src/biomes/`**:
  - `BiomeDef`: Biome configuration with temperature/humidity targets, elevation envelopes, surface materials, foliage density, and visual tints.
  - `BiomeRegistry`: Catalog of biomes with 8 built-in presets (*Plains, Forest, Desert, Tundra, Mountain Peaks, Beach, Ocean, Swamp*).
  - `BiomeSampler`: Procedural multi-octave simplex climate noise generator with climate-space nearest-neighbor classification and smooth multi-point blend weights.
- **`src/foliage/`**:
  - `FoliageDef` & `FoliageRegistry`: Typed resource catalog of instanced foliage types (grass tufts, wildflowers, ferns, shrubs, pine trees, pebbles) with slope, material, and elevation rules.
  - `FoliageChunkData`: Pure data container holding instanced transforms and colors per chunk.
  - `FoliageSpawner`: Thread-safe procedural generator with slope checking, surface material matching, biome density scaling, and **paint exclusions** (e.g. painted dirt paths suppress foliage).
- **`src/streaming/`**:
  - `ChunkStreamer`: Pure set algebra determining `to_load` (sorted closest-first) and `to_unload` (with distance hysteresis).
  - `ChunkScheduler`: Background multi-threaded pipeline using Godot 4's `WorkerThreadPool`, thread-safe mutex synchronization, and task reclamation.

### 2. Scene Layer (`Node3D` / SceneTree)
- **`src/graphics/`**:
  - Shaders (`terrain.gdshader`, `terrain_water.gdshader`, `terrain_cave.gdshader`):
    - **Triplanar Mapping**: Prevents texture stretching on vertical voxel cliffs and steps without requiring per-quad UV unwrapping.
    - **Slope-Based Blending**: Automatically transitions steep angles (> 45°) to cliff rock, leaving horizontal planes with topsoil, grass, sand, or snow.
    - **Elevation Blending**: Procedurally transitions low elevations to coastal beaches and high peaks to snowlines.
    - **Terrain Splat Painting (RGBA)**: Multi-layer splatmap overlay blending up to 4 custom painted layers.
    - **Macro-Variation Anti-Tiling**: Subtly modulates color and roughness over large world coordinates to prevent repetitive tiling artifacts.
    - **PBR Lighting & Biome Tinting**: Full albedo, roughness, metallic, and specular response with vegetation biome tinting.
  - `TerrainMaterialConfig`: Typed resource exposing triplanar scale/sharpness, slope thresholds, PBR layer colors/roughness, and optional textures.
  - `TerrainMaterialManager`: Material factory managing uniform synchronization and chunk-specific material instances with world origin and splatmaps bound.
- **`src/world/`**:
  - `TerrainQuery`: Decoupled query interface (`get_height_at`, `get_spawn_point`, `get_world_bounds`).
  - `VoxelWorld`: Composition root managing streaming, collision budgets, graphics overrides, runtime painting API (`paint_terrain`), biome/climate queries, water plane, and boundary barriers.
  - `ChunkNode`: Scene instance with `MeshInstance3D`, dynamic material overrides, splatmap texture updates, foliage node pooling, and optional `StaticBody3D` (`ConcavePolygonShape3D`).
  - `FoliageChunkNode`: Scene node batching instances per chunk via `MultiMeshInstance3D` with automatic procedural cross-mesh fallbacks.
  - `WorldBoundary`: 4 perimeter barrier walls stopping entities at map limits.
  - `WaterPlane`: Continent-wide ocean surface at configured sea level.
- **`src/player/`**:
  - `PlayerIntent`: Plain data container of player actions.
  - `PlayerInput`: Single source of truth for mouse capture and `InputMap` reading.
  - `ThirdPersonCamera`: Yaw/pitch pivots, `SpringArm3D` anti-clipping, aim zoom, shoulder swapping, and center-screen hitscan raycasting.
  - `CameraMath`: Pure helper functions for pitch clamping and smoothing.
  - `PlayerMotor`: `CharacterBody3D` with camera-relative movement, sprinting, jumping, standard gravity, and 1-block voxel step-assist.
  - `PlayerHUD`: Dynamic crosshair, hit markers, and debug overlay (FPS, chunk coord, player pos, loaded chunk count).

---

## Directory Structure

```
res://
├── config/
│   ├── default_world.tres           # World configuration resource
│   ├── default_generator.tres       # Continent noise & elevation parameters
│   ├── default_terrain_shader.tres  # PBR terrain shader & palette parameters
│   └── materials.tres               # Voxel palette (colors & properties)
├── src/
│   ├── core/                        # Pure RefCounted data structures
│   ├── generation/                  # Procedural continent noise & masking
│   ├── meshing/                     # Greedy meshing & buffer generation
│   ├── painting/                    # Terrain splatmap buffers, brush logic & undo/redo
│   ├── biomes/                      # Biome definitions, registry & climate sampler
│   ├── foliage/                     # Foliage definitions, chunk data & procedural spawner
│   ├── graphics/                    # Triplanar PBR shaders & material manager
│   ├── streaming/                   # Chunk streamer & WorkerThreadPool scheduler
│   ├── world/                       # Composition root, chunk nodes, foliage nodes, boundary, water
│   └── player/                      # Motor, TPS camera, HUD, input & intent
├── scenes/
│   ├── main.tscn                    # Main runnable scene
│   └── player.tscn                  # Player character prefab
└── tests/
    ├── run_tests.gd                 # Headless test runner entry point
    ├── framework/                   # TestCase, BenchmarkCase, RegressionCase, TestRunner
    ├── unit/                        # 32 Unit tests (including architecture, shader, painting, biome, foliage)
    ├── regression/                  # Golden snapshot regression tests
    └── benchmark/                   # Automated performance benchmarks
```

---

## Controls

| Action | Key / Input |
|---|---|
| **Move** | W, A, S, D |
| **Sprint** | Left Shift |
| **Jump** | Space |
| **Aim Zoom** | Right Mouse Button (Hold) |
| **Shoot (Hitscan)** | Left Mouse Button |
| **Swap Shoulder** | V |
| **Toggle Mouse Capture** | Tab or Escape |
| **Toggle Debug Overlay** | F3 |
| **Toggle Spawn Location** | F4 (Surface ↔ Underground Arena) |
| **Toggle Map** | M |

---

## Running the Automated Test Suite

The framework includes a zero-dependency headless test runner with unit tests, performance benchmarks, and golden-file regression tests.

### Run All Tests:
```bash
godot --headless --path . -s res://tests/run_tests.gd -- --suite=all
```

### Run Only Unit Tests:
```bash
godot --headless --path . -s res://tests/run_tests.gd -- --suite=unit
```

### Run Only Benchmarks:
```bash
godot --headless --path . -s res://tests/run_tests.gd -- --suite=benchmark
```

### Run Regression Tests:
```bash
godot --headless --path . -s res://tests/run_tests.gd -- --suite=regression
```

### CLI Flags:
- `--suite=unit|benchmark|regression|all`: Filter test category.
- `--filter=<name>`: Run matching test names or files.
- `--update-golden`: Recalculate and update regression golden snapshots.
- `--update-baseline`: Update benchmark performance baselines.
- `--strict`: Fail the test run if benchmark performance regresses by > 20%.
- `--json=<path>`: Export machine-readable test execution report.
