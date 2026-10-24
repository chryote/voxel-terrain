# Implementation Plan: Sedimentary Strata Height-Based Color Banding for Dirt Side Faces

## 1. Problem Statement & Motivation
On the mainland surface level, player perspective is dominated by vertical cliff faces, step drops, and embankment cuts. In procedural voxel generation, these vertical side faces are classified as `MaterialDef.ID_DIRT` (or dirt side faces for grass top voxels). Currently, these side faces render as a flat, uniform brown color (`#593e2b`) with only subtle ($< 4\%$) noise variation, resulting in a visually repetitive ("boring") appearance.

By introducing **height-based sedimentary strata color banding** exclusively for dirt side faces (`mat_id == 2 && abs(v_world_normal.y) < 0.5`), cliffs gain the visual richness of real-world geological formations (such as the Grand Canyon, Painted Desert, or soil horizons).

---

## 2. Core Architectural Principles & Sustainable Design
Following clean software engineering practices and the repository's strict architecture guidelines:
1. **Separation of Concerns**:
   - **`StrataPaletteRegistry`** (`res://src/rendering/strata_palette_registry.gd`): Single-responsibility pure `RefCounted` domain model managing theme groups, presets, color definitions, and material parameter binding.
   - **`AsciiAtlasConfig`** (`res://src/rendering/ascii_atlas_config.gd`): Configuration resource exposing user-tunable parameters (theme group, preset, frequency, warp strength).
   - **`TerrainMaterialProvider`** (`res://src/rendering/terrain_material_provider.gd`): Material caching and polymorphic lifecycle dispatcher, delegating strata parameter application to `StrataPaletteRegistry` (1 line of code, preventing God-Class bloat).
   - **`ascii_terrain.gdshader`** (`res://shaders/terrain/ascii_terrain.gdshader`): GPU-side evaluation within `evaluate_subtle_color()`, strictly gated to dirt side faces.
2. **Strict File & Function Length Bounds**:
   - `ascii_terrain.gdshader`: Must remain $\le 160$ lines total (monitored by `test_ascii_architecture.gd`).
   - `terrain_material_provider.gd`: Must remain $\le 170$ lines total.
   - Pure components: Must remain $\le 160$ lines with functions $< 35$ lines.
3. **Preservation of Greedy Meshing**:
   - Doing color banding on the GPU fragment shader leaves CPU `SurfaceShellMesher` run-length quad merging 100% intact. Zero extra vertices or triangles are generated.
4. **Zero Coupling**:
   - Zero scene `Node` dependencies in pure rendering classes. Zero coupling to `src/world` or `src/player`.

---

## 3. Matplotlib-Style Theme Groups & Color Palettes

Strata palettes are categorized into 4 scientific/aesthetic theme groups inspired by geological horizons and Matplotlib's colormap families:

```
Strata Palette Taxonomy
├── 1. Soil & Humus (Pedological Horizons)
│   ├── loam_temperate    [Default: O-Humus, A-Topsoil, B-Subsoil, C-Substratum]
│   ├── podzol_boreal     [Boreal: Acid raw humus, Eluvial silica, Spodic Fe-layer, Till]
│   └── peat_wetland      [Wetland: Fibrous peat, Sapric umber, Organic root, Saturated silt]
│
├── 2. Arid & Badlands (Ferruginous Canyon - Matplotlib OrRd / Copper Style)
│   ├── canyon_terracotta [Zion: Iron shale, Vivid redstone, Baked terracotta, Pale silt]
│   ├── painted_desert   [Chinle: Dusty rose clay, Banded sienna, Ochre silt, Purple shale]
│   └── desert_sandstone  [Navajo: Desert varnish, Raw sienna, Desert buff, Golden apricot]
│
├── 3. Mineral & Evaporite (Banded Formations - Matplotlib BrBG / PuOr Style)
│   ├── banded_ironstone  [BIF: Magnetite black, Hematite rust, Jasperite tan, Weathered silica]
│   ├── copper_oxide      [Secondary: Gossan umber, Malachite wash, Cuprite red, Carbonate]
│   └── sulfur_alkali     [Playa: Bituminous shale, Sulfurous ochre, Alkali clay, Salt crust]
│
└── 4. Volcanic & Tephra (Pyroclastic Fallout - Matplotlib Cividis / Bone Style)
    ├── basaltic_tephra   [Volcanic: Ash charcoal, Olivine lapilli, Weathered sienna, Dark cinder]
    └── calcite_shale     [Fault Crag: Carbonaceous shale, Slate gray, Fault gouge, Limestone]
```

### Detailed Color Horizon Definitions (4-Band Strata)

| Group | Preset | Band 0 (Base/Substratum) | Band 1 (Lower Strata) | Band 2 (Mid Horizon) | Band 3 (Upper Cap) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Soil & Humus** | `loam_temperate` | `#3b261a` (Deep till) | `#593e2b` (Standard loam) | `#6c4e38` (Weathered subsoil) | `#462f20` (Humus topsoil) |
| | `podzol_boreal` | `#4a3a30` (Dense till) | `#5c3722` (Spodic Fe-oxide) | `#7a6352` (Bleached eluvial) | `#36251b` (Acid raw humus) |
| | `peat_wetland` | `#3a332d` (Saturated gley) | `#4d3728` (Sapric peat) | `#5a4332` (Root layer) | `#2d211a` (Black peat moss) |
| **Arid & Badlands** | `canyon_terracotta` | `#532619` (Ferruginous shale)| `#783723` (Red claystone) | `#9c4928` (Baked terracotta) | `#88583c` (Pale cap silt) |
| | `painted_desert` | `#503239` (Purplish siltstone)| `#844837` (Banded sienna) | `#926a3a` (Golden ochre) | `#6c3a37` (Dusty rose clay) |
| | `desert_sandstone` | `#482d1c` (Varnish umber) | `#7a3f20` (Raw sienna) | `#93592b` (Warm buff sand) | `#a2743c` (Apricot silt) |
| **Mineral & Evaporite** | `banded_ironstone` | `#262327` (Magnetite black) | `#662923` (Hematite red) | `#7c4b37` (Jasperite tan) | `#8a4025` (Rust silica) |
| | `copper_oxide` | `#4a2822` (Gossan umber) | `#38483a` (Malachite wash) | `#6b362c` (Cuprite red-brown) | `#495642` (Verdigris clay) |
| | `sulfur_alkali` | `#3e352b` (Bituminous shale) | `#796939` (Sulfur ochre) | `#84755d` (Alkali tan clay) | `#968a73` (Bleached salt) |
| **Volcanic & Tephra** | `basaltic_tephra` | `#252427` (Ash charcoal) | `#473f35` (Olivine lapilli) | `#5a3d2e` (Weathered sienna) | `#3c3430` (Dark cinder) |
| | `calcite_shale` | `#28262a` (Carbonaceous shale)| `#524d4a` (Cool slate gray) | `#4b382d` (Fault gouge umber) | `#706a64` (Limestone strata) |

---

## 4. Technical Implementation Steps

### Phase 1: Pure Component Creation (`StrataPaletteRegistry`)
- Create `res://src/rendering/strata_palette_registry.gd`.
- Define dictionary of theme groups and presets.
- Implement lookup functions with safe fallbacks:
  - `get_palette(group: String, preset: String) -> PackedColorArray`
  - `get_groups() -> PackedStringArray`
  - `get_presets(group: String) -> PackedStringArray`
  - `apply_to_material(mat: ShaderMaterial, config: Resource) -> void`
- Keep line count $< 130$ lines, zero node dependencies.

### Phase 2: Configuration Integration (`AsciiAtlasConfig`)
- Update `res://src/rendering/ascii_atlas_config.gd` to export:
  - `strata_enabled: bool = true`
  - `strata_group: String = "soil"`
  - `strata_preset: String = "loam_temperate"`
  - `strata_frequency: float = 0.35`
  - `strata_warp_strength: float = 0.50`

### Phase 3: Provider Delegation (`TerrainMaterialProvider`)
- In `_apply_ascii_uniforms()`, call `StrataPaletteRegistry.apply_to_material(mat, config)` in one line.
- Update `config/ascii_terrain_theme.tres` with default strata parameters.

### Phase 4: Spatial Shader Integration (`ascii_terrain.gdshader`)
- Declare uniform group `group_uniforms Sedimentary_Strata;`:
  - `uniform bool strata_enabled = true;`
  - `uniform float strata_frequency : hint_range(0.05, 1.0) = 0.35;`
  - `uniform float strata_warp_strength : hint_range(0.0, 1.0) = 0.50;`
  - `uniform vec4 strata_color_0 : source_color = ...;`
  - `uniform vec4 strata_color_1 : source_color = ...;`
  - `uniform vec4 strata_color_2 : source_color = ...;`
  - `uniform vec4 strata_color_3 : source_color = ...;`
- Update `evaluate_subtle_color()`:
  - Condition: `mat_id == 2 && abs(v_world_normal.y) < 0.5 && strata_enabled`
  - Natural domain-warped strata: `float strata_y = v_world_pos.y + sin(v_world_pos.x * 0.15 + v_world_pos.z * 0.12) * (strata_warp_strength * 1.5);`
  - Layer index: `int layer = int(floor(mod(strata_y * strata_frequency, 4.0)));`
  - Horizon color selection and blending with `base_col`.
- Refactor/compact redundant lines in shader to ensure total length $\le 160$ lines.

### Phase 5: Verification & Unit Tests
- Add `tests/unit/test_strata_palette_registry.gd` covering:
  - Palette integrity (all groups exist, all presets have 4 valid colors).
  - Robust fallback on invalid group/preset.
  - Material parameter application.
  - Architectural cleanliness (zero node dependencies, line length limits).
- Update `tests/unit/test_ascii_architecture.gd` to audit `strata_palette_registry.gd`.
- Run full test suite with Godot CLI to verify 100% pass rate.
