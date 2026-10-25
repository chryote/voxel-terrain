# Implementation Plan: Stylized Non-Photorealistic (NPR) Toon Water Shader

## 1. Executive Summary & Problem Motivation

In the current terrain rendering pipeline, inland elevated lakes, river basins, subterranean cave pools, and the continental ocean plane (`WaterPlane`) rely on default Godot `StandardMaterial3D` instances with generic PBR roughness, metallic highlights, and linear alpha blending (`Color(0.12, 0.38, 0.65, 0.75)`).

This creates an aesthetic dissonance against the rest of the visual stack:
- The voxel terrain uses **Moebius-style cel-shading, ink outlines, and ASCII cross-hatching**.
- The sky uses **discrete stepped color bands** (`banded_sky.gdshader`).
- In contrast, the current water exhibits realistic specular reflections and muddy, smooth gradients, breaking visual cohesion.

To establish complete visual harmony with the graphic novel / retro-flat aesthetic, we will implement a dedicated **Stylized NPR Toon Water Shader** (`res://shaders/water/toon_water.gdshader`) and an accompanying architectural pipeline.

---

## 2. The Four Pillars of NPR Graphic Novel Water

```
                       [ Camera View Ray ]
                               │
                               ▼
        Water Surface (Unshaded / Flat Emission, No Specular)
 ┌─────────────────────────────────────────────────────────────┐
 │  Foam Line (Crisp Solid White Step, depth_diff < foam_th)   │ ◄── Terrain Intersection
 ├─────────────────────────────────────────────────────────────┤
 │  Shallow Band (Flat Cyan-Azure, depth_diff < shallow_th)    │
 ├─────────────────────────────────────────────────────────────┤
 │  Mid-Depth Band (Flat Cobalt Blue, depth_diff < deep_th)    │
 ├─────────────────────────────────────────────────────────────┤
 │  Abyss / Deep Band (Flat Dark Navy, depth_diff >= deep_th)  │
 ├─────────────────────────────────────────────────────────────┤
 │  Graphic Surface Ripples: Stepped Cellular / Voronoi Lines   │
 └─────────────────────────────────────────────────────────────┘
```

The shader is built around four specific non-photorealistic characteristics:

### 1. Hard-Edge Intersection Foam
- **Mechanism**: Samples the scene depth buffer (`hint_depth_texture`) behind the transparent water surface in screen space.
- **Linearization**: Converts raw non-linear logarithmic depth into metric view-space distance via `INV_PROJECTION_MATRIX`.
- **Crisp Step Threshold**: Calculates the distance difference $\Delta z = z_{\text{scene}} - z_{\text{water}}$. Where $\Delta z < \text{foam\_thickness}$ (e.g. $0.35\,\text{m}$), it outputs a **100% solid, opaque white band** (`#ffffff`).
- **No Soft Gradients**: Replaces standard `smoothstep()` or linear fades with a hard binary step (`step()` or discrete conditional), matching the crisp hand-inked line aesthetic.

### 2. Stepped Depth Color (Discrete Comic Bands)
- **Mechanism**: Instead of exponential Beer-Lambert absorption or smooth gradient blending, water color is quantized into **2 or 3 distinct, flat color horizons** based on depth behind the surface:
  - **Shallow Horizon** ($\Delta z < 1.5\,\text{m}$): Vibrant, high-key cyan/azure (`#3ba3db`).
  - **Mid-Depth Horizon** ($1.5\,\text{m} \le \Delta z < 5.0\,\text{m}$): Saturated comic cobalt (`#1f619e`).
  - **Deep Abyss Horizon** ($\Delta z \ge 5.0\,\text{m}$): Deep navy ink (`#112942`).
- **Zero In-Between Blending**: Pure flat polygon fills for each band.

### 3. Stylized Surface Noise (Graphic Ripple Lines)
- **Mechanism**: To make the surface feel alive without looking like continuous liquid waves, dual scrolling procedural cellular/Voronoi coordinates (`TIME * speed_1` and `TIME * speed_2`) generate sharp interference patterns.
- **Binary Line Extraction**: Evaluated with a strict threshold (`step(threshold, cellular_val)`) to generate crisp $1$-pixel or single-block contour lines resembling ink-drawn ripple rings.
- **Color Accent**: Active ripple lines render as crisp foam-white or shallow-tinted accents over the flat water base.

### 4. No Normal Maps or Specular Highlights (Flat / Unlit Shading)
- **Mechanism**: Uses `render_mode unshaded, cull_back` (or emission-based flat shading).
- **Aesthetic Alignment**: Completely omits microfacet roughness, Fresnel reflections, and Blinn-Phong specular glints.
- **Lighting Cohesion**: Matches the flat-colored faces of voxel grass, dirt, and rock blocks, avoiding realistic water reflections that clash with cel-shaded terrain.

---

## 3. Core Architectural Principles & Clean Code Standards

Following the repository's strict architectural constraints (enforced by `test_ascii_architecture.gd` and `test_graphic_novel_architecture.gd`):

1. **Separation of Concerns**:
   - **`ToonWaterConfig`** (`res://src/rendering/toon_water_config.gd`): Pure `Resource` exporting customizable thresholds (foam thickness, depth steps, ripple speed, color palette).
   - **`ToonWaterMaterialProvider`** (`res://src/rendering/toon_water_material_provider.gd`): Pure `RefCounted` material cache and uniform binder.
   - **`TerrainMaterialProvider`** (`res://src/rendering/terrain_material_provider.gd`): Material lifecycle facade. Calls `ToonWaterMaterialProvider.get_water_material()` in 1 line, maintaining its $\le 170$ lines file size limit.
   - **`toon_water.gdshader`** (`res://shaders/water/toon_water.gdshader`): Pure GPU spatial shader handling linear depth reconstruction, foam stepping, and cellular ripples.
2. **File and Function Length Bounds**:
   - `toon_water.gdshader`: $\le 140$ lines total.
   - `toon_water_material_provider.gd`: $\le 120$ lines total.
   - `toon_water_config.gd`: $\le 70$ lines total.
   - All helper functions: $< 35$ lines.
3. **Zero Coupling**:
   - Pure rendering domain classes contain zero `Node` or `Node3D` inheritance.
   - Zero dependencies on `src/world` or `src/player`.
4. **Greedy Meshing & Performance Preservation**:
   - Shader runs entirely on existing greedy-meshed quads from `SurfaceShellMesher` (`ElevatedWaterMesher`), `ChasmShellMesher`, and `WaterPlane` (PlaneMesh).
   - Zero CPU vertex generation overhead.

---

## 4. Technical Implementation Steps

### Phase 1: Spatial Shader Construction (`res://shaders/water/toon_water.gdshader`)

Create the dedicated spatial shader with Godot 4 depth texture sampling:

```glsl
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_always;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

group_uniforms Foam_Settings;
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float foam_thickness : hint_range(0.05, 1.5) = 0.35;

group_uniforms Stepped_Depth_Colors;
uniform vec4 shallow_color : source_color = vec4(0.23, 0.64, 0.86, 0.85);
uniform vec4 mid_color : source_color = vec4(0.12, 0.38, 0.62, 0.90);
uniform vec4 deep_color : source_color = vec4(0.07, 0.16, 0.26, 0.95);
uniform float shallow_threshold : hint_range(0.2, 5.0) = 1.5;
uniform float deep_threshold : hint_range(1.0, 20.0) = 5.0;

group_uniforms Graphic_Ripples;
uniform bool ripples_enabled = true;
uniform float ripple_scale : hint_range(0.05, 1.0) = 0.25;
uniform float ripple_speed : hint_range(0.01, 1.0) = 0.08;
uniform float ripple_threshold : hint_range(0.5, 0.99) = 0.88;
uniform vec4 ripple_color : source_color = vec4(1.0, 1.0, 1.0, 0.9);
```

#### Key Shader Functions:
1. `get_linear_depth(vec2 screen_uv, mat4 inv_proj)`:
   - Samples `depth_texture` at `screen_uv`.
   - Reconstructs view space $Z$: `view_pos = inv_proj * vec4(screen_uv * 2.0 - 1.0, raw_depth, 1.0); return -view_pos.z / view_pos.w;`
2. `evaluate_procedural_ripples(vec2 world_xz, float time)`:
   - Computes dual-layer scrolling cellular/Voronoi hash.
   - Evaluates `step(ripple_threshold, pattern_value)` for crisp line rings.
3. `fragment()`:
   - Computes `depth_diff = scene_depth - (-VERTEX.z)`.
   - Evaluates stepped depth color (shallow vs mid vs deep).
   - If `depth_diff < foam_thickness`, overrides with solid `foam_color`.
   - If ripples are enabled and active, layers crisp `ripple_color`.
   - Sets `ALBEDO = col.rgb; ALPHA = col.a;`.

---

### Phase 2: Configuration Resource (`res://src/rendering/toon_water_config.gd`)

Create a dedicated pure configuration resource exposing all designer-tunable parameters:

```gdscript
class_name ToonWaterConfig
extends Resource

@export_group("Foam Line")
@export var foam_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export_range(0.05, 1.5, 0.05) var foam_thickness: float = 0.35

@export_group("Stepped Depth Colors")
@export var shallow_color: Color = Color(0.23, 0.64, 0.86, 0.85)
@export var mid_color: Color = Color(0.12, 0.38, 0.62, 0.90)
@export var deep_color: Color = Color(0.07, 0.16, 0.26, 0.95)
@export_range(0.2, 5.0, 0.1) var shallow_threshold: float = 1.5
@export_range(1.0, 20.0, 0.5) var deep_threshold: float = 5.0

@export_group("Stylized Ripples")
@export var ripples_enabled: bool = true
@export_range(0.05, 1.0, 0.01) var ripple_scale: float = 0.25
@export_range(0.01, 1.0, 0.01) var ripple_speed: float = 0.08
@export_range(0.5, 0.99, 0.01) var ripple_threshold: float = 0.88
@export var ripple_color: Color = Color(1.0, 1.0, 1.0, 0.9)
```

Also add presets (e.g. `ocean_day`, `alpine_lake`, `toxic_subterranean`, `night_chasm`).

---

### Phase 3: Material Provider & Registry (`res://src/rendering/toon_water_material_provider.gd`)

Create a pure `RefCounted` singleton/factory managing shader instantiation and caching:
- `get_water_material(config: Resource = null) -> ShaderMaterial`:
  - Returns cached surface water material with updated uniforms.
- `get_subterranean_water_material(config: Resource = null) -> ShaderMaterial`:
  - Returns material tuned for cave basins (deeper/darker mid & deep colors, muted ripples).
- `apply_to_material(mat: ShaderMaterial, config: ToonWaterConfig) -> void`:
  - Binds shader parameters safely with fallbacks.
- Line length: $< 120$ lines. Zero scene node dependencies.

---

### Phase 4: Integration with Terrain Material Provider & World Components

1. **`TerrainMaterialProvider`** (`res://src/rendering/terrain_material_provider.gd`):
   - Add delegator methods:
     ```gdscript
     static func get_water_material(config: Resource = null) -> ShaderMaterial:
         return ToonWaterMaterialProvider.get_water_material(config)

     static func get_subterranean_water_material(config: Resource = null) -> ShaderMaterial:
         return ToonWaterMaterialProvider.get_subterranean_water_material(config)
     ```
   - Maintains strict line length $\le 170$ lines.
2. **`WaterPlane`** (`res://src/world/water_plane.gd`):
   - Replace the legacy `StandardMaterial3D` assignment with `TerrainMaterialProvider.get_water_material()`.
3. **`ChunkNode`** (`res://src/world/chunk_node.gd`):
   - Update `_shared_water_material` and `_shared_subterranean_water_material` initialization to use `TerrainMaterialProvider`.
4. **Theme Configuration Resources**:
   - Add default `ToonWaterConfig` to `config/graphic_novel_theme.tres` and `config/ascii_terrain_theme.tres`.

---

### Phase 5: Verification & Unit Tests

Add targeted test suites to ensure 100% test pass rate and verify architectural constraints:

1. **`tests/unit/test_toon_water_shader.gd`**:
   - Test shader resource loading and syntax compilation in Godot 4.4.1.
   - Verify `render_mode unshaded` is active.
   - Verify absence of normal maps and specular calculations.
   - Verify depth texture sampling (`hint_depth_texture`).
   - Verify step-based foam and stepped depth color logic.
2. **`tests/unit/test_toon_water_architecture.gd`**:
   - Audit `toon_water_config.gd` and `toon_water_material_provider.gd`:
     - Assert zero `Node`, `Node3D`, or scene tree dependencies.
     - Assert zero references to `src/world` or `src/player`.
     - Assert line counts $\le 160$ lines and helper functions $< 35$ lines.
   - Verify `WaterPlane` and `ChunkNode` correctly receive `ShaderMaterial` instances.
   - Verify cache identity: repeated calls to `get_water_material()` return the same instance.
3. **Full Test Suite Execution**:
   - Run `tests/run_tests.gd` via Godot CLI to guarantee 0 regressions across all 309+ existing tests.

---

## 5. Visual Palette Specifications

To match the existing graphic novel color schemes:

| Parameter | Surface Ocean & Inland Lakes | Subterranean Cave Pools |
| :--- | :--- | :--- |
| **Foam Color** | `#ffffff` (Solid Chalk White) | `#d4e8f2` (Subtle Phosphor Tint) |
| **Foam Thickness** | `0.35 m` (~1/3 block width) | `0.25 m` (Tight edge line) |
| **Shallow Color** | `#3ca2dc` (Comic Azure Cyan, 85% alpha) | `#256a8a` (Deep Turquoise, 90% alpha) |
| **Mid-Depth Color** | `#1c578f` (Saturated Cobalt, 90% alpha) | `#143d54` (Abyssal Teal, 95% alpha) |
| **Deep Abyss Color**| `#0d1e30` (Dark Navy Ink, 98% alpha) | `#08141c` (Void Black, 100% alpha) |
| **Shallow Threshold**| `1.5 m` (1.5 blocks) | `1.0 m` (1 block) |
| **Deep Threshold** | `5.0 m` (5 blocks) | `3.5 m` (3.5 blocks) |
| **Ripple Style** | Active Crisp Rings (`speed=0.08`) | Minimal / Placid Lines (`speed=0.02`) |

---

## 6. Implementation Rollout Plan

- [x] **Step 1**: Create `res://shaders/water/toon_water.gdshader` implementing the 4 NPR pillars.
- [x] **Step 2**: Create `res://src/rendering/toon_water_config.gd` with clean parameters and presets.
- [x] **Step 3**: Create `res://src/rendering/toon_water_material_provider.gd` with caching and uniform binding.
- [ ] **Step 4**: Wire provider into `TerrainMaterialProvider.gd` without exceeding line length limits.
- [ ] **Step 5**: Update `WaterPlane.gd` and `ChunkNode.gd` to bind the new toon water materials.
- [ ] **Step 6**: Add unit tests in `tests/unit/test_toon_water_shader.gd` and architectural checks.
- [ ] **Step 7**: Execute test suite via headless Godot CLI and verify visual results in-engine.
