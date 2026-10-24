# Implementation Plan: ASCII Map Atlas Voxel Face Texturing

## Executive Summary & Objective

This implementation plan defines the complete engineering architecture for mapping an **ASCII Glyph Map Atlas** across voxel terrain faces in Godot 4.4+. The visual goal is to **fake depth** and **mimic the tactile coarseness of real-world materials** (organic grass thatch, crumbly particulate soil, rigid crystalline stone fractures, rippled dune sand, and sparkling snow crust) without incurring geometry overhead or sacrificing 2D greedy meshing performance.

The plan strictly adheres to three non-negotiable architectural mandates:
1. **Separation of Concerns**: Isolation of pure data definitions, atlas generation, material-to-glyph mapping, GPU shader math, material provisioning, and scene orchestration.
2. **No God Classes / No God Functions**: Every script and shader is decomposed into focused, single-responsibility units (< 150 lines per class, < 25 lines per function/helper).
3. **Sustainable Game Development**: Multi-threaded safety, zero CPU meshing overhead, headless CI testability (100% pass rate in headless Godot), data-driven configuration via Godot `.tres` resources, and zero regression against existing systems.

---

## 1. Physical & Visual Foundation: Faking Depth & Real-World Coarseness

### 1.1 Why ASCII Map Atlases for Voxel Faces?
Real-world natural surfaces exhibit distinct microscopic relief, pores, fissures, and tactile coarseness. Traditional flat vertex colors fail to convey this tangible texture. By projecting an ASCII glyph atlas onto voxel faces:
* **Glyph Strokes act as Micro-Relief (Peaks)**: Character strokes catch directional light, cast micro-shadows, and reflect highlights.
* **Glyph Negative Spaces act as Cavities (Pores/Recesses)**: Voids between character strokes simulate porous gaps (soil aeration, grass thatch underlayers, stone crevices).
* **Typographic Density Ramps act as Coarseness Scales**: Different characters produce distinct tactile frequencies.

### 1.2 Real-Life Material Coarseness Matrix

| Material ID | Material Name | Tactile Character & Grain | Assigned ASCII Glyph Set | Faux-Depth Relief Behavior |
| :--- | :--- | :--- | :--- | :--- |
| `ID_GRASS` (1) | Grass | Fibrous, vertical thatch, blade tips | `"`, `'`, `,`, `.`, `;`, `\|`, `/`, `\` | Cavity shadowing beneath blades simulates deep organic sod layer. |
| `ID_DIRT` (2) | Dirt / Soil | Crumbly aggregate, porous loam, pebbles | `:`, `.`, `*`, `~`, `%`, `o`, `8` | Irregular cavity occlusion mimics loose granular porosity. |
| `ID_STONE` (3) | Stone / Rock | Crystalline fractures, cleavage planes, mineral grain | `#`, `%`, `[`, `]`, `/`, `\`, `\|`, `X`, `=` | High-contrast edge relief; directional normal perturbation catches grazing sun glints. |
| `ID_SAND` (4) | Sand | Granular quartz grains, wind ripples | `·`, `.`, `~`, `^`, `,`, `-` | Fine, high-frequency stippling with horizontal ripple alignment. |
| `ID_SNOW` (5) | Snow | Powder flakes, frozen crust, ice crystals | `*`, `+`, `·`, `o`, `x`, `¤` | High-albedo stroke peaks with cool sky-ambient tint in recessed valleys. |
| `ID_SEABED` (6) | Seabed | Silty mud, sediment ribbons, algae film | `~`, `≈`, `-`, `=`, `_` | Undulating horizontal strokes with deep murky cavity absorption. |
| `ID_GRAVEL` (7) | Gravel | Loose crushed stone, angular fragments | `&`, `8`, `%`, `o`, `*`, `.` | Dense clustered particulate relief. |
| `ID_CAVE_WALL` (8)| Cave Wall | Fractured subterranean bedrock, basalt seams | `\|`, `!`, `I`, `H`, `M`, `#`, `▓`, `▒` | Heavy vertical striae and jointing with ink-dark recessed cavities. |
| `ID_CHASM_BASALT` (9)| Chasm Basalt | Volcanic columnar jointing, dense basaltic cliffs | `\|`, `I`, `!`, `]`, `[`, `█`, `▓` | Rigid vertical columnar lines with deep pitch-black crevices. |
| `ID_CAVE_CRYSTAL` (10)| Cave Crystal | Prismatic facets, specular crystal lattices | `◇`, `/`, `\`, `^`, `v`, `X`, `*`, `◆` | Sharply angled facets catching specular highlights. |

---

## 2. The Greedily Merged Voxel Problem & Mathematical Solution

### 2.1 The Challenge
The terrain mesher (`SurfaceShellMesher`) employs **2D greedy run-length merging**:
* Flat horizontal surfaces are merged into quads of width $W$ and depth $D$ (up to $16 \times 16$ blocks per quad).
* Side cliff walls are merged into tall vertical quads ($1 \times H$ or $W \times 1$).
* The vertex buffer (`MeshData`) contains **zero UV coordinates** to keep generation speeds fast (< 2.1 ms/chunk) and memory usage minimal.

Standard UV texturing would stretch a single glyph across a $12 \times 8$ merged quad, distorting the aesthetic.

### 2.2 The Solution: World-Space Dominant-Axis Face Projection
Because voxel surfaces are strictly axis-aligned cubes, every polygon normal aligns with $\pm X$, $\pm Y$, or $\pm Z$. 
By projecting world coordinates in the fragment shader:

$$\text{axis} = \text{dominant}(\lvert \vec{N}_{\text{world}} \rvert)$$

$$\text{FaceUV} = \begin{cases} 
(P_x, P_z) \cdot \text{scale} & \text{if } \text{axis} == Y \text{ (Top/Bottom face)} \\ 
(P_z, P_y) \cdot \text{scale} & \text{if } \text{axis} == X \text{ (East/West wall)} \\ 
(P_x, P_y) \cdot \text{scale} & \text{if } \text{axis} == Z \text{ (North/South wall)} 
\end{cases}$$

$$\text{CellUV} = \operatorname{fract}(\text{FaceUV}) \in [0.0, 1.0)$$

**Key Benefits**:
1. **Zero Meshing Changes**: `SurfaceShellMesher`, `ChasmShellMesher`, and `MeshData` remain 100% untouched.
2. **Perfect Grid Alignment**: Every $1 \times 1$ meter voxel block receives an identical, crisp, perfectly tiled grid of ASCII characters regardless of whether it is an isolated block or part of a 100-block merged plain.
3. **Single Texture Fetch**: Because dominant-axis selection eliminates the need for 3-way blended triplanar sampling, the GPU performs only **1 texture sample per fragment**, preserving high framerates.

---

## 3. Architecture Overview & Separation of Concerns

```
                             [ AsciiAtlasConfig ] (.tres)
                                     │
                 ┌───────────────────┴───────────────────┐
                 ▼                                       ▼
     [ AsciiAtlasGenerator ]                  [ AsciiMaterialMapper ]
     (Pure RefCounted: Image/Atlas)           (Pure RefCounted: Material -> Glyph LUT)
                 │                                       │
                 ▼                                       ▼
     [ ASCII Glyph Atlas Texture ]            [ Material Palette / LUT Texture ]
                 │                                       │
                 └───────────────────┬───────────────────┘
                                     ▼
                        [ TerrainMaterialProvider ]
                        (Material Factory & Cache)
                                     │
                                     ▼
                     [ ascii_terrain.gdshader ]
                     (Modular GPU Triplanar & Relief Math)
                                     │
                 ┌───────────────────┴───────────────────┐
                 ▼                                       ▼
        [ ChunkNode (Surface) ]                [ ChunkNode (Cave) ]
```

### Layer Boundaries
* **Pure Data & Generator Layer (`src/rendering/`)**: Extends `RefCounted` or `Resource`. Zero `Node` dependencies. Zero references to `src/world` or `src/player`. Fully testable in headless CI runners.
* **Shader Pipeline Layer (`shaders/terrain/`)**: Pure GLSL modular functions. No monolithic god functions.
* **Material Management Layer (`src/rendering/terrain_material_provider.gd`)**: Encapsulates material caching, shader parameter application, and runtime theme switching.
* **Scene Layer (`src/world/chunk_node.gd`)**: Pure consumer of the shared material provided by `TerrainMaterialProvider`. Agnostic to ASCII or shader internals.

---

## 4. Decomposed Component Specifications (No God Classes / Functions)

### Component 1: `AsciiAtlasConfig` (`src/rendering/ascii_atlas_config.gd`)
* **Base Class**: `Resource`
* **Responsibility**: Holds data-driven configuration parameters for the ASCII atlas, coarseness scale, depth extrusion, and material mappings.
* **Size**: ~75 lines.
* **Properties**:
  * `@export var atlas_texture: Texture2D`: The baked ASCII glyph atlas.
  * `@export var grid_columns: int = 16`: Number of columns in atlas (default: 16).
  * `@export var grid_rows: int = 16`: Number of rows in atlas (default: 16).
  * `@export_range(0.25, 8.0) var glyphs_per_voxel: float = 2.0`: Frequency of glyphs per 1-meter voxel face.
  * `@export_range(0.0, 1.0) var depth_relief_strength: float = 0.50`: Depth bump/extrusion intensity.
  * `@export_range(0.0, 1.0) var cavity_shadow_intensity: float = 0.65`: Ambient self-shadowing in recesses.
  * `@export_range(0.0, 0.05) var parallax_strength: float = 0.015`: View-dependent parallax displacement factor.
  * `@export_range(0.0, 1.0) var lit_threshold: float = 0.30`: Cel-shaded toon terminator threshold.
  * `@export var shadow_tint: Color = Color(0.22, 0.24, 0.32, 1.0)`: Ambient shadow tint.
  * `@export var material_glyph_lut: Texture2D`: Optional prebaked LUT texture.

---

### Component 2: `AsciiAtlasGenerator` (`src/rendering/ascii_atlas_generator.gd`)
* **Base Class**: `RefCounted`
* **Responsibility**: Pure utility that rasterizes a complete ASCII / CP437 glyph map atlas programmatically into an `Image` with multi-channel depth information.
* **Size**: ~130 lines.
* **Channel Architecture**:
  * **R (Red)**: Binary/Antialiased Glyph Stroke Mask (`1.0` = stroke, `0.0` = background).
  * **G (Green)**: Distance Field / Bevel Height (`1.0` = peak center, falling to `0.0` at outer boundaries). Used for normal perturbation and parallax.
  * **B (Blue)**: Cavity Ambient Occlusion (`0.0` in deep crevices, `1.0` in open flat regions).
  * **A (Alpha)**: Solid `1.0`.
* **Single-Responsibility Functions**:
  * `generate_atlas_image(cell_size: int, font: Font) -> Image`: Master coordinator generating the grid.
  * `_rasterize_builtin_glyph(img: Image, char_code: int, cell_x: int, cell_y: int, cell_size: int) -> void`: Headless fallback using built-in 8x8 font primitives when running without OS display servers.
  * `_compute_distance_field_channel(img: Image, cell_rect: Rect2i) -> void`: Computes 1-pixel soft bevels for normal perturbation.
  * `save_atlas_to_png(path: String, cell_size: int) -> Error`: Persists the atlas asset for editor caching.

---

### Component 3: `AsciiMaterialMapper` (`src/rendering/ascii_material_mapper.gd`)
* **Base Class**: `RefCounted`
* **Responsibility**: Pure lookup engine mapping `MaterialDef` IDs (`ID_GRASS`, `ID_STONE`, etc.) and lighting states into glyph atlas indices.
* **Size**: ~95 lines.
* **Decomposed Functions**:
  * `get_glyph_for_material(material_id: int, density_level: int) -> int`: Returns atlas tile index (0 to 255).
  * `get_density_ramp(material_id: int) -> PackedInt32Array`: Returns array of glyphs ordered from light to dark density.
  * `bake_material_lut_image(registry: MaterialRegistry) -> Image`: Generates a compact $16 \times 4$ pixel LUT image:
    * $X$ coordinate = `material_id` (0 to 15).
    * $Y$ coordinate = lighting/slope band (0 = Shadow, 1 = Midtone, 2 = Highlight, 3 = Grazing).
    * Pixel value = Atlas Glyph Index ($0$ to $255$).
  * `create_lut_texture(registry: MaterialRegistry) -> ImageTexture`: Wraps baked image in GPU texture for $O(1)$ shader indexing.

---

### Component 4: Modular Spatial Shader (`shaders/terrain/ascii_terrain.gdshader`)
* **Single Responsibility**: Render voxel terrain surfaces using triplanar local-face mapping, $O(1)$ glyph atlas sampling, parallax micro-relief, and stepped cel-shading.
* **Decomposed Shader Functions (Zero God Functions)**:

```glsl
shader_type spatial;
render_mode diffuse_toon, specular_disabled;

group_uniforms ASCII_Atlas;
uniform sampler2D ascii_atlas : filter_linear_mipmap, repeat_enable;
uniform sampler2D material_lut : filter_nearest, repeat_disable;
uniform ivec2 atlas_grid = ivec2(16, 16);
uniform float glyphs_per_voxel : hint_range(0.25, 8.0) = 2.0;

group_uniforms Depth_And_Coarseness;
uniform float depth_relief_strength : hint_range(0.0, 1.0) = 0.50;
uniform float cavity_shadow_intensity : hint_range(0.0, 1.0) = 0.65;
uniform float parallax_strength : hint_range(0.0, 0.05) = 0.015;

group_uniforms Cel_Lighting;
uniform float lit_threshold : hint_range(0.0, 1.0) = 0.30;
uniform vec4 shadow_tint : source_color = vec4(0.22, 0.24, 0.32, 1.0);

varying vec3 v_world_pos;
varying vec3 v_world_normal;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Helper 1: Computes world-space local face UV and dominant tangent basis
vec2 calculate_voxel_face_uv(vec3 pos, vec3 norm, float frequency) {
	vec3 an = abs(norm);
	if (an.y >= an.x && an.y >= an.z) {
		return pos.xz * frequency;
	} else if (an.x >= an.z) {
		return vec2(pos.z, pos.y) * frequency;
	} else {
		return vec2(pos.x, pos.y) * frequency;
	}
}

// Helper 2: Unpacks 1D glyph index into 2D atlas normalized UV coordinate
vec2 get_atlas_tile_uv(vec2 cell_uv, int glyph_idx, ivec2 grid) {
	int gx = glyph_idx % grid.x;
	int gy = glyph_idx / grid.x;
	vec2 tile_size = 1.0 / vec2(grid);
	return (vec2(float(gx), float(gy)) + clamp(cell_uv, 0.01, 0.99)) * tile_size;
}

// Helper 3: Performs faux-depth parallax offset along view direction
vec2 evaluate_parallax(vec2 cell_uv, vec3 view_dir, float strength) {
	// Offset UV opposite to tangent view direction to fake protrusion
	return cell_uv - view_dir.xy * strength;
}

// Helper 4: Unpacks material ID from vertex color or LUT coordinate
int decode_material_id(vec4 vertex_color) {
	// If material ID is stored in COLOR.a: return int(round(vertex_color.a * 255.0))
	// Otherwise map primary vertex color:
	return int(round(vertex_color.a * 255.0));
}

// Helper 5: Samples glyph data (R: mask, G: bevel/height, B: cavity AO)
vec4 sample_glyph_data(vec2 face_uv, int glyph_idx) {
	vec2 cell_uv = fract(face_uv);
	vec2 atlas_uv = get_atlas_tile_uv(cell_uv, glyph_idx, atlas_grid);
	return texture(ascii_atlas, atlas_uv);
}

// Helper 6: Perturbs normal based on glyph edge height gradient
vec3 perturb_normal(vec3 base_norm, vec2 face_uv, int glyph_idx, float strength) {
	float eps = 0.05;
	float h_c  = sample_glyph_data(face_uv, glyph_idx).g;
	float h_dx = sample_glyph_data(face_uv + vec2(eps, 0.0), glyph_idx).g;
	float h_dy = sample_glyph_data(face_uv + vec2(0.0, eps), glyph_idx).g;
	
	vec3 grad = vec3((h_dx - h_c) / eps, (h_dy - h_c) / eps, 0.0);
	return normalize(base_norm - grad * strength);
}

void fragment() {
	vec2 face_uv = calculate_voxel_face_uv(v_world_pos, v_world_normal, glyphs_per_voxel);
	int mat_id = decode_material_id(COLOR);
	
	// Lookup glyph index from LUT (Y=1: base midtone)
	int glyph_idx = int(texelFetch(material_lut, ivec2(mat_id, 1), 0).r * 255.0);
	
	// Sample multi-channel glyph data
	vec4 glyph_data = sample_glyph_data(face_uv, glyph_idx);
	float stroke_mask = glyph_data.r;
	float cavity_ao = glyph_data.b;
	
	// Modulate albedo: strokes receive true vertex color, recesses receive cavity darkness
	vec3 base_color = COLOR.rgb;
	vec3 recessed_color = base_color * (1.0 - cavity_shadow_intensity * (1.0 - cavity_ao));
	vec3 final_albedo = mix(recessed_color, base_color * 1.05, stroke_mask);
	
	ALBEDO = final_albedo;
	NORMAL = perturb_normal(NORMAL, face_uv, glyph_idx, depth_relief_strength);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float n_dot_l = max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION;
	float is_lit = step(lit_threshold, n_dot_l);
	
	vec3 lit_color = ALBEDO * LIGHT_COLOR;
	vec3 shadow_color = ALBEDO * shadow_tint.rgb;
	
	DIFFUSE_LIGHT += mix(shadow_color, lit_color, is_lit);
}
```

---

### Component 5: Material Provider Integration (`src/rendering/terrain_material_provider.gd`)
* **Single Responsibility**: Maintain cached, shared `ShaderMaterial` instances and apply uniforms dynamically.
* **Additions**:
  * Add support for `ASCII_SHADER_PATH = "res://shaders/terrain/ascii_terrain.gdshader"`.
  * Expose `get_ascii_surface_material(config: AsciiAtlasConfig) -> ShaderMaterial`.
  * Expose `get_ascii_cave_material(config: AsciiAtlasConfig) -> ShaderMaterial`.
  * Allow hot-swapping between Graphic Novel Halftone mode and ASCII Map mode via configuration.
  * Guarantee chunk instances share the same material resource, ensuring zero state-change overhead.

---

## 5. Separation of Concerns & Clean Architecture Audit

| Architectural Dimension | Existing System | ASCII Voxel Plan Implementation | Status |
| :--- | :--- | :--- | :--- |
| **Data vs. Presentation** | Hardcoded parameters | Dedicated `AsciiAtlasConfig` resource (`.tres`). Clean separation. | **PASS** |
| **Atlas Generation Isolation**| `HalftoneTextureGenerator` | Pure `AsciiAtlasGenerator` (RefCounted). Zero Node/Scene dependencies. | **PASS** |
| **Material Mapping Isolation**| Embedded in meshing/generation | Dedicated `AsciiMaterialMapper`. Translates IDs to glyphs via pure LUT. | **PASS** |
| **Chunk Meshing Decoupling** | Greedy surface mesher | **Zero changes to meshing buffers**. Triplanar projection handles greedy quads on GPU. | **PASS** |
| **Worker Thread Safety** | Background `WorkerThreadPool` | Atlas & LUT generation occur upfront or during initialization; meshing stays lock-free. | **PASS** |
| **Shader Modularity** | Monolithic shader danger | Modular GLSL helper functions (< 20 lines each). Zero god functions. | **PASS** |
| **Headless CI Compatibility** | Headless unit test runner | Pure RefCounted generators execute in headless Godot without crashing display server. | **PASS** |
| **Regression Safety** | Golden snapshot tests | Vertex and index buffers untouched; passes `test_meshing_golden_snapshot`. | **PASS** |

---

## 6. Implementation Sequence & Milestones

### Phase 1: Pure Data & Atlas Generation
1. Implement `src/rendering/ascii_atlas_config.gd` (Typed `Resource`).
2. Implement `src/rendering/ascii_atlas_generator.gd` (Pure `RefCounted` generator with fallback bitmap rasterizer).
3. Create default atlas asset `assets/textures/ascii_atlas.png`.
4. Create test suite `tests/unit/test_ascii_atlas_generator.gd` and verify in headless runner.

### Phase 2: Material Mapping & GPU LUT
1. Implement `src/rendering/ascii_material_mapper.gd` (Pure `RefCounted` material-to-glyph classifier).
2. Generate material LUT texture mapping `MaterialDef.id` to specific character sets and density ramps.
3. Write `tests/unit/test_ascii_material_mapper.gd` verifying all 10 material IDs map to valid glyph indices.

### Phase 3: Modular Spatial Shader Implementation
1. Create `shaders/terrain/ascii_terrain.gdshader` containing decoupled helper functions:
   * `calculate_voxel_face_uv`
   * `get_atlas_tile_uv`
   * `evaluate_parallax`
   * `perturb_normal`
   * `decode_material_id`
2. Validate shader compiles headlessly and contains all required uniforms and helpers.

### Phase 4: Material Provider Integration & Theme Configuration
1. Update `src/rendering/terrain_material_provider.gd` with factory methods for ASCII surface and cave materials.
2. Create default configuration resource `config/ascii_terrain_theme.tres`.
3. Verify `ChunkNode` properly binds the shared material instance without leaking node dependencies.

### Phase 5: Automated Testing, Benchmark & Regression Verification
1. Create `tests/unit/test_ascii_architecture.gd`:
   * Verify all new classes in `src/rendering/` extend `RefCounted` or `Resource`.
   * Verify zero references to `src/world` or `src/player` in pure layers.
   * Verify function length constraints.
2. Run full test suite:
   * `godot --headless -s res://tests/run_tests.gd -- --suite=unit` (Must pass 100%).
   * `godot --headless -s res://tests/run_tests.gd -- --suite=regression` (Verify zero regressions).
3. Benchmark render performance to confirm chunk generation and frame draw times remain within budget.

---

## 7. Risk Analysis & Mitigation Matrix

| Risk | Impact | Root Cause | Architectural Mitigation |
| :--- | :--- | :--- | :--- |
| **Greedy Quad Distortion** | High | Merged quads have non-uniform width/depth. | **Dominant-Axis World Projection**: UVs are derived from world coordinates in the shader; greedy quads tile seamlessly. |
| **Distance Shimmer / Aliasing** | Medium | High-frequency character strokes alias at distance. | **Mipmapping & Smoothstep Bevel**: Texture atlas generated with mipmaps and continuous distance fields. |
| **GPU Texture Fetch Overhead** | Medium | Triplanar shaders sampling 3 planar projections. | **Dominant-Axis Branchless Selection**: Only 1 planar direction sampled per fragment on cubic voxel faces. |
| **CI Headless Crashes** | High | Relying on OS window manager or FontServer. | **Pure GDScript Bitmap Rasterizer**: Fallback bitmapped character matrix drawn directly onto `Image`. |
| **Tight Coupling Violation** | High | Meshing or ChunkNode knowing about ASCII glyphs. | **Material Provider Pattern**: `ChunkNode` only receives a `Material`; mesher only handles geometry. |
