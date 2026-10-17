# Terrain Generation & Meshing Optimization Roadmap (Surface & Subterranean)

A prioritized architectural blueprint and actionable TODO for optimizing procedural generation, greedy meshing, streaming, and collision performance in the Godot 4.4 Voxel Terrain framework.

---

## Phase 5: GDExtension (C++ / Rust) Acceleration Strategy

When GDScript algorithmic optimizations reach their maximum theoretical ceiling, isolate the computational hotspots into a lightweight GDExtension module.

### Target Candidates for C++ Migration:
1. **`VoxelMesher::build_mesh`:** Raw pointer array access, bitwise greedy merging, and SIMD mask operations (`PackedVector3Array` construction in C++ is 30x faster than GDScript).
2. **`Noise Batching / Domain Warping`:** Calling `FastNoiseLite` from C++ eliminates the Godot variant dispatch overhead on every coordinate query.

### What Stays in GDScript:
- Streaming coordination, world boundaries, player motor, camera, UI, and scene composition remain in GDScript for rapid game design and iteration.

---
