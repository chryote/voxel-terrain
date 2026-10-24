# Graphic Novel Aesthetic Implementation Plan
## Clean-Architecture, Data-Driven & Modular Design for Voxel Terrain (Godot 4.4)

Based on [core_idea.md](file:///d:/GODOT/terrain/core_idea.md).

---

## 1. Architectural Principles & Sustainability Audit

To adhere strictly to **Separation of Concerns (SoC)**, prevent **God Classes / God Functions**, and guarantee **Sustainable Game Development**, this implementation plan enforces the following architectural guardrails:

```
+-------------------------------------------------------------------------------------------------+
|                                SUSTAINABLE ARCHITECTURE MAPPING                                 |
+-------------------------------------------------------------------------------------------------+
| 1. DATA LAYER (Decoupled, Pure Resources)                                                       |
|    `GraphicNovelConfig` (Resource)                                                              |
|    - Single Source of Truth for all aesthetic parameters (palettes, line widths, dot scales).   |
|    - Stored as .tres files (e.g., `default_graphic_novel.tres`). Zero hardcoded shader values. |
|    - Artists & designers tweak themes in Inspector without touching code or scene files.        |
+-------------------------------------------------------------------------------------------------+
| 2. SHADER LAYER (Modular, Single-Responsibility GLSL Functions - No God Functions)              |
|    - `banded_sky.gdshader`: Pure sky quantization. Modular zenith/horizon/sun functions.        |
|    - `outline_postprocess.gdshader`: Pure edge-detection. Distinct helper functions:            |
|       * linearize_depth(), sample_view_normal(), detect_depth_edge(), detect_normal_edge()     |
|    - `halftone_terrain.gdshader`: Pure spatial toon & pattern. Distinct helper functions:       |
|       * quantize_light(), evaluate_halftone_pattern(), compute_comic_shadow()                   |
+-------------------------------------------------------------------------------------------------+
| 3. PRESENTATION / CONTROLLER LAYER (Isolated Single-Responsibility Nodes)                       |
|    - `GraphicNovelPostProcess` (CanvasLayer): Controls post-process life cycle, viewport        |
|      resizing, hardware fallback, and runtime ON/OFF toggling.                                  |
|    - `TerrainMaterialProvider` (RefCounted/Resource): Factory providing shared ShaderMaterials  |
|      to `ChunkNode`. Keeps `ChunkNode` 100% agnostic to visual themes.                          |
+-------------------------------------------------------------------------------------------------+
| 4. CORE ENGINE & MESHING LAYER (Zero Contamination)                                             |
|    - `ChunkNode`, `SurfaceShellMesher`, `WorkerThreadPool`: Remain 100% unchanged in their logic|
|      and data structures. `MeshData` continues outputting pure vertex colors.                   |
+-------------------------------------------------------------------------------------------------+
```

---

## 2. Directory Structure & File Inventory

```
res://
├── assets/
│   └── textures/
│       └── halftone_pattern.png            # Reference 64x64 seamless comic dot pattern
├── config/
│   └── graphic_novel_theme.tres            # Typed Resource storing active visual profile
├── scenes/
│   ├── main.tscn                           # Instances GraphicNovelPostProcess & WorldEnvironment
│   └── player.tscn                         # HUD CanvasLayer configured at layer 10+
├── shaders/
│   ├── postprocess/
│   │   └── outline_postprocess.gdshader    # Modular screen-space edge detection
│   ├── sky/
│   │   └── banded_sky.gdshader             # Stepped atmospheric color bands
│   └── terrain/
│       └── halftone_terrain.gdshader       # Toon quantized lighting with screen-space halftones
├── src/
│   ├── rendering/
│   │   ├── graphic_novel_config.gd         # Typed Resource for aesthetic settings
│   │   ├── graphic_novel_post_process.gd   # Post-process lifecycle & toggle controller
│   │   └── terrain_material_provider.gd    # Decoupled material factory for ChunkNodes
│   └── world/
│       └── chunk_node.gd                   # Consumes materials via provider; no hardcoded shaders
└── tests/
    └── unit/
        └── test_graphic_novel_architecture.gd # Headless validation of resources, shaders & materials
```

---

## 3. Detailed Component Specifications

### Component A: Data-Driven Configuration (`GraphicNovelConfig`)
* **Path**: `res://src/rendering/graphic_novel_config.gd`
* **Base Class**: `Resource`
* **Responsibility**: Single Source of Truth for visual parameters. Enables creating multiple theme presets (`graphic_novel_day.tres`, `graphic_novel_noir.tres`, `graphic_novel_sunset.tres`).

```gdscript
class_name GraphicNovelConfig
extends Resource

@export_group("Banded Sky Palette")
@export var sky_top_color: Color = Color(0.24, 0.44, 0.72, 1.0)
@export var sky_mid_color: Color = Color(0.48, 0.72, 0.88, 1.0)
@export var sky_horizon_color: Color = Color(0.96, 0.86, 0.70, 1.0)
@export var ground_horizon_color: Color = Color(0.68, 0.60, 0.52, 1.0)
@export var ground_bottom_color: Color = Color(0.20, 0.18, 0.16, 1.0)
@export_range(0.0, 1.0) var mid_band_threshold: float = 0.25
@export_range(-0.2, 0.2) var horizon_band_threshold: float = 0.02
@export var sun_enabled: bool = true
@export var sun_color: Color = Color(1.0, 0.98, 0.88, 1.0)
@export_range(0.001, 0.1) var sun_disk_size: float = 0.025

@export_group("Post-Process Outlines")
@export var outlines_enabled: bool = true
@export var outline_color: Color = Color(0.05, 0.05, 0.07, 1.0)
@export_range(0.5, 3.0) var outline_thickness: float = 1.0
@export_range(0.001, 0.2) var depth_threshold: float = 0.04
@export_range(0.05, 1.0) var normal_threshold: float = 0.35

@export_group("Cel-Shading & Halftone Terrain")
@export var halftone_texture: Texture2D
@export_range(0.01, 1.0) var halftone_scale: float = 0.15
@export_range(0.0, 1.0) var lit_threshold: float = 0.30
@export var shadow_tint: Color = Color(0.22, 0.24, 0.32, 1.0)
@export_range(0.0, 1.0) var halftone_intensity: float = 0.75
@export var use_procedural_pattern: bool = false
```

---

### Component B: Material Decoupling (`TerrainMaterialProvider`)
* **Path**: `res://src/rendering/terrain_material_provider.gd`
* **Base Class**: `RefCounted`
* **Responsibility**: Factory that creates and caches shared `ShaderMaterial` instances configured from a `GraphicNovelConfig`.
* **Benefits**:
  - `ChunkNode` does **not** hardcode shader paths or static shader creation.
  - Materials can be dynamically swapped (e.g. Graphic Novel mode vs. Standard PBR vs. Wireframe debug) without recreating chunks.
  - Guarantees 1 single shared material across all chunk instances for optimal GPU batching and zero state-change overhead.

```gdscript
class_name TerrainMaterialProvider
extends RefCounted

static var _cached_surface_material: ShaderMaterial
static var _cached_cave_material: ShaderMaterial

static func get_surface_material(config: GraphicNovelConfig) -> ShaderMaterial:
    if _cached_surface_material == null:
        _cached_surface_material = _create_material(config, false)
    else:
        _update_uniforms(_cached_surface_material, config, false)
    return _cached_surface_material

static func get_cave_material(config: GraphicNovelConfig) -> ShaderMaterial:
    if _cached_cave_material == null:
        _cached_cave_material = _create_material(config, true)
    else:
        _update_uniforms(_cached_cave_material, config, true)
    return _cached_cave_material
```

---

### Component C: Modular Shaders (No God Functions)

#### 1. Banded Sky Shader (`banded_sky.gdshader`)
* **Single Responsibility**: Render quantized atmospheric color bands and a flat graphic sun disk based on view direction vector.
* **Decomposed Functions**:
  - `vec3 calculate_sky_band(float eye_y, ...)`: Stepped color evaluation.
  - `vec3 calculate_sun_disk(vec3 eye_dir, vec3 light_dir, ...)`: Flat sun circle rendering.
  - `void sky()`: Orchestrator invoking helper functions (10 lines).

#### 2. Screen-Space Outline Shader (`outline_postprocess.gdshader`)
* **Single Responsibility**: Edge detection on depth and normal buffers.
* **Decomposed Functions (Eliminating the God-Function Smell)**:
  - `float linearize_depth(vec2 uv, mat4 inv_proj)`: Converts NDC z into metric distance.
  - `vec3 sample_normal(vec2 uv)`: Unpacks normal buffer from `[0,1]` to `[-1,1]`.
  - `bool is_background(float raw_depth)`: Identifies skybox pixels to prevent false horizon outlines.
  - `float evaluate_depth_edge(vec2 uv, vec2 texel_size, mat4 inv_proj)`: Cross-sample depth delta normalized by distance.
  - `float evaluate_normal_edge(vec2 uv, vec2 texel_size)`: Cross-sample normal angle divergence.
  - `void fragment()`: Clean 12-line compositor:
    ```glsl
    void fragment() {
        vec2 texel = SCREEN_PIXEL_SIZE * outline_thickness;
        float d_edge = evaluate_depth_edge(SCREEN_UV, texel, INV_PROJECTION_MATRIX);
        float n_edge = evaluate_normal_edge(SCREEN_UV, texel);
        float edge = clamp(d_edge + n_edge, 0.0, 1.0);
        
        vec4 scene_col = texture(screen_texture, SCREEN_UV);
        COLOR = mix(scene_col, outline_color, edge);
    }
    ```

#### 3. Cel-Shaded Halftone Terrain Shader (`halftone_terrain.gdshader`)
* **Single Responsibility**: Toon lighting quantization with screen-space halftone pattern in shadow bands while preserving vertex colors.
* **Decomposed Functions**:
  - `float sample_halftone(vec2 screen_coord, float scale)`: Computes texture or procedural dot matrix.
  - `float quantize_diffuse(float n_dot_l, float attenuation)`: Stepped toon terminator.
  - `void fragment()`: Sets vertex color albedo (`COLOR.rgb`), maximum roughness, zero specular.
  - `void light()`: Clean 14-line light evaluator:
    ```glsl
    void light() {
        float lit = quantize_diffuse(dot(NORMAL, LIGHT), ATTENUATION);
        float pattern = sample_halftone(FRAGCOORD.xy, halftone_scale);
        
        vec3 lit_color = ALBEDO * LIGHT_COLOR;
        vec3 shadow_color = ALBEDO * shadow_tint.rgb * mix(1.0, 1.0 - halftone_intensity, pattern);
        
        DIFFUSE_LIGHT += mix(shadow_color, lit_color, lit);
    }
    ```

---

### Component D: Post-Processing Controller Node (`GraphicNovelPostProcess`)
* **Path**: `res://src/rendering/graphic_novel_post_process.gd`
* **Base Class**: `CanvasLayer`
* **Responsibility**: Manages the post-process quad lifecycle, uniform updates, and hardware scalability.
* **Features**:
  - Encapsulates `ColorRect` child and material setup programmatically.
  - Exposes `@export var config: GraphicNovelConfig`.
  - Supports runtime toggling: `config.outlines_enabled` toggles visibility instantly.
  - Enforces `layer = 1` so UI elements on higher layers (e.g. `PlayerHUD` on `layer = 10`) are never outlined.
  - Graceful fallback: If run in headless mode or on devices without normal-roughness buffer support, automatically bypasses edge detection.

---

## 4. Separation of Concerns & Clean Architecture Audit

| Architectural Dimension | Existing System | Graphic Novel Plan Implementation | Verdict |
| :--- | :--- | :--- | :--- |
| **Data vs Presentation** | Hardcoded parameters in scenes | Dedicated `GraphicNovelConfig` resource (`.tres`). Clean separation. | **PASS** |
| **Chunk Meshing vs Visual Style** | `ChunkNode` hardcoding `StandardMaterial3D` | `TerrainMaterialProvider` injects shared materials. `ChunkNode` remains style-agnostic. | **PASS** |
| **Worker Threads vs Shaders** | Meshing occurs off-thread | `MeshData` vertex color pipeline untouched. Shaders execute strictly on GPU. | **PASS** |
| **Post-Process Isolation** | Loose nodes in scene | Self-contained `GraphicNovelPostProcess` node. Single responsibility. | **PASS** |
| **UI vs Post-Process** | Single canvas layer risk | Strict `CanvasLayer` separation (Layer 1 PostProcess, Layer 10 HUD). | **PASS** |
| **Shader Modularity** | Monolithic shader danger | Modular helper functions for depth, normals, and halftones. Zero god functions. | **PASS** |
| **Hardware Scalability** | Fixed rendering pipeline | Outlines and halftones toggleable at runtime for low-end devices. | **PASS** |
| **Headless CI Compatibility** | Headless unit test runner | Shaders compile without error; providers testable headlessly without GPU crashes. | **PASS** |

---

## 5. Step-by-Step Implementation Sequence

1. **Phase 1: Architecture Foundation**
   - Create `src/rendering/graphic_novel_config.gd` (Typed Resource).
   - Create `config/graphic_novel_theme.tres` with default palette and thresholds.
   - Create reference halftone texture `assets/textures/halftone_pattern.png`.
2. **Phase 2: Shaders Implementation**
   - Write `shaders/sky/banded_sky.gdshader` (Modular sky functions).
   - Write `shaders/postprocess/outline_postprocess.gdshader` (Modular edge-detection functions).
   - Write `shaders/terrain/halftone_terrain.gdshader` (Modular cel-shading & halftone functions).
3. **Phase 3: Controller & Material Provider**
   - Implement `src/rendering/terrain_material_provider.gd`.
   - Implement `src/rendering/graphic_novel_post_process.gd`.
   - Update `ChunkNode` to query `TerrainMaterialProvider` for its shared materials.
4. **Phase 4: Scene Tree Setup**
   - Update `scenes/main.tscn`: Add `GraphicNovelPostProcess` instance and apply sky material to `WorldEnvironment`.
   - Update `scenes/player.tscn`: Confirm `CanvasLayer` for `PlayerHUD` is set to `layer = 10`.
5. **Phase 5: Automated Testing & Verification**
   - Write and execute `tests/unit/test_graphic_novel_architecture.gd`.
   - Verify zero regressions across existing test suite via `tests/run_tests.gd`.
   - Run render benchmark to verify draw calls and frame times remain within budget.
