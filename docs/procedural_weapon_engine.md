# ProceduralWeaponEngine Architecture & Technical Guide

The [`ProceduralWeaponEngine`](file:///d:/GODOT/terrain/src/combat/generator/procedural_weapon_engine.gd) is a dedicated procedural synthesis engine written in GDScript for Godot 4. It deterministically generates complete, modular voxel-based melee weapon frames paired with 3D optimized meshes, 2D pixel-art HUD icons, and deck-building combat statistics.

---

## 1. High-Level Design Philosophy

In traditional action-RPGs, weapons are static 3D meshes bound to fixed animation data and hardcoded swing timings. In this codebase's combat architecture (inspired by modular wand-crafting mechanics such as *Noita*), a weapon is conceptualized as an **arcane floating frame or stance** rather than a static animation rig:

```mermaid
flowchart TD
    subgraph Generation ["ProceduralWeaponEngine"]
        A[Seed & Profile Parameters] --> B[generate_voxel_matrix]
        B --> C[build_weapon_mesh]
        B --> D[generate_weapon_icon]
        B --> E[_generate_deck_stats]
        C & D & E --> F[MeleeWeaponDef Resource]
    end

    subgraph Runtime ["Combat & Presentation Runtime"]
        F --> G[FloatingWeaponController]
        F --> H[MeleeDeckEvaluator]
        F --> I[WeaponDeckUI & Quickbar]
        G --> J[3D Voxel Mesh + Aura VFX]
        H --> K[TechniqueCard Execution Queue]
        I --> L[2D Pixel-Art Icon Cache]
    end
```

### Key Principles:
1. **Decoupled Combat Mechanics**: The weapon definition ([`MeleeWeaponDef`](file:///d:/GODOT/terrain/src/combat/core/melee_weapon_def.gd)) does **not** contain hardcoded attack animations or damage values. All combat behaviors (slashes, thrusts, lunges, projectile casts) are driven dynamically by slotted [`TechniqueCard`](file:///d:/GODOT/terrain/src/combat/core/technique_card.gd)s.
2. **Unified Triple Output**: A single call to `ProceduralWeaponEngine.generate_weapon()` creates:
   - A **3D voxel ArrayMesh** with dual-material shading and face culling.
   - A **2D pixel-art ImageTexture** with directional shading for UI/HUDs.
   - A **Deck profile** with slot capacity, shuffle behavior, recharge times, and stat multipliers.
3. **Deterministic Seeding**: Any integer seed produces the identical 3D structure, color theme, icon, and deck attributes.

---

## 2. Core Data Structures & Types

### 2.1 Voxel Types (`VoxelType`)
Every discrete point in the 3D grid is assigned a semantic voxel role:

| Value | Identifier | Semantic Function | Material / Shading |
|:---:|:---|:---|:---|
| `0` | `EMPTY` | Air or negative space | Skipped during meshing |
| `1` | `HANDLE` | Grip wraps and hilt core | Dark, low-roughness structural tone |
| `2` | `JUNCTION` | Collars, crossguards, socket brackets | Mid-tone alloy bracket |
| `3` | `BODY` | Main blade spine, hammer bulk, structural alloy | High-metallic frame material |
| `4` | `EDGE` | Polished perimeter, cutting bevels, spikes | Bright, reflective surface |
| `5` | `ENERGY` | Mana conduits, glowing power cores, plasma tips | **Emissive Material** (`multiplier = 3.5`) |
| `6` | `ACCENT` | Gold trim, pommel rings, magnetic stabilization coils | Highlighting specular tone |

### 2.2 Weapon Profiles (`WeaponProfile`)
Profiles dictate the silhouette, 3D volume, emitter head geometry, and deck archetype:

| Profile | ID | Silhouette / Archetype | Deck Capacity | Recharge Time | Damage Mult | Stamina Mult | Special Features |
|:---|:---:|:---|:---:|:---:|:---:|:---:|:---|
| **BALANCED** | `0` | Standard longsword / saber | 5 – 7 | 0.45 – 0.55s | 1.00 – 1.10x | 1.00x | Alternating central energy core |
| **SLENDER** | `1` | Rapier / needle / stiletto | 6 – 9 | 0.28 – 0.40s | 0.88 – 1.00x | 0.82 – 0.92x | High capacity, rapid recharge, needle tip |
| **HEAVY** | `2` | Greatsword / warhammer | 4 – 6 | 0.62 – 0.78s | 1.25 – 1.45x | 1.15 – 1.30x | True 3D volume (`depth = 3`), devastating hits |
| **SEGMENTED** | `3` | Floating modular sci-fi frame | 5 – 8 | 0.42 – 0.55s | 1.02 – 1.15x | 1.00x | 3 floating segments separated by energy gaps, 45% shuffle chance |
| **FLANGED** | `4` | Spiked mace / kinetic war-pick | 5 – 7 | 0.45 – 0.58s | 1.10 – 1.22x | 0.95 – 1.05x | Stepped lateral teeth and heavy pommel |

### 2.3 Curated Color Palettes (`PALETTES`)
The engine defines 6 distinct aesthetic themes that map colors to all voxel roles:
1. **Aether Steel**: Polished steel body with cyan energy conduits and brass accent.
2. **Molten Basalt**: Volcanic dark rock frame with fiery orange emission and copper edges.
3. **Verdant Jade**: Deep jade and forest green alloy with emerald energy conduits.
4. **Void Amethyst**: Shadowy purple alloy with vivid magenta energy and silver trim.
5. **Frost Cobalt**: Glacial blue steel with electric ice-blue emission.
6. **Brass Mechanum**: Steampunk brass and blackened iron with golden amber energy.

---

## 3. Spatial Grid & Voxel Dimensions

The weapon is forged inside a 3-dimensional discrete matrix:

```
                  +Y (Top: Height = 24 voxels, ~1.08m)
                   ^
                   |    [Tip / Emitter Layer: y = 19..23]
                   |    [Blade / Shaft Layer: y = 6..18]
                   |    [Crossguard / Junction: y = 5] <-- Pivot Origin (0,0,0)
                   |    [Handle / Grip Layer: y = 1..4]
                   |    [Pommel Cap: y = 0]
                   +----------------------------------> +X (Width = 7 voxels)
                  /
                 /
                v
               +Z (Depth = 3 voxels)
```

- **Voxel Size**: `DEFAULT_VOXEL_SIZE = 0.045m` (4.5 cm).
- **Total Height**: $24 \text{ voxels} \times 0.045\text{m} = 1.08\text{m}$ (matches Godot world block height).
- **Grid Dimensions**: `X = 7` (width), `Y = 24` (height), `Z = 3` (depth).
- **Centers**: `cx = 3` (horizontal center), `cz = 1` (depth center).
- **Pivot Origin (`JUNCTION_Y = 5`)**: The crossguard at $y=5$ is translated to local $(0,0,0)$ in 3D mesh space. This ensures the weapon pivots naturally around the player's hand or floating orbit point rather than its base.

---

## 4. Procedural Generation Pipeline

### Step 1: Matrix Construction & Symmetry
`generate_voxel_matrix()` initializes a 3D matrix (`grid_3d[x][y][z]`) and a 2D projection buffer (`grid_2d[y][x]`).

It utilizes an axial bilateral symmetry function:
```gdscript
var set_symmetric = func(dx: int, y: int, z: int, v_type: int) -> void:
    set_voxel.call(cx + dx, y, z, v_type)
    if dx != 0:
        set_voxel.call(cx - dx, y, z, v_type)
```
This guarantees perfect bilateral balance across the weapon's central spine while allowing $dx$ displacement for crossguards, flanges, and blades.

### Step 2: Layered Structural Assembly
The weapon is assembled from base to tip across 5 vertical strata:

1. **Pommel & Counterweight ($y = 0$)**:
   - Central accent voxel at $(cx, 0, cz)$.
   - Expanded with flanking junction voxels for `HEAVY` and `FLANGED` profiles to visually counterbalance larger heads.
2. **Grip / Hilt ($y = 1 \dots 4$)**:
   - Central handle column at $(cx, y, cz)$.
   - Alternates between `VoxelType.HANDLE` and `VoxelType.ACCENT` every even step to simulate hilt wrapping or wire grip coils.
3. **Collar & Crossguard ($y = 5$)**:
   - Generates a protective crossguard with width scaled to profile:
     - `SLENDER`: Guard width = 1 voxel ($\pm 1$ from center).
     - `BALANCED` / `FLANGED` / `SEGMENTED`: Guard width = 2 voxels ($\pm 2$).
     - `HEAVY`: Guard width = 3 voxels ($\pm 3$), with 3D depth reinforcement at $z = cz \pm 1$.
4. **Shaft / Blade Spine ($y = 6 \dots 18$)**:
   - `SLENDER`: Needle-thin spine with high-taper edge and periodic energy nodes.
   - `HEAVY`: Solid multi-voxel thick blade with reinforced front and back depth ($z = 0, 1, 2$) and periodic energy cores.
   - `SEGMENTED`: Three physically separated modules with pure energy gaps at $y = 9$ and $y = 14$ to mimic suspended floating levitation.
   - `FLANGED`: Spiked lateral ribs with accent tips at $y \in \{8, 11, 14, 17\}$.
   - `BALANCED`: Central alloy core flanked by cutting edges with internal glowing mana conduits.
5. **Head / Emitter Point ($y = 19 \dots 23$)**:
   - `SLENDER`: Tapers to a single energy needle emitter at $y = 23$.
   - `HEAVY`: Expands into a massive hammer/axe block strike head with edge perimeter.
   - `SEGMENTED`: Splits into a forked tuning-fork dual emitter with a suspended central plasma core.
   - `FLANGED` / `BALANCED`: Crowned cutting head capped with an accent apex gem.

---

## 5. 3D Mesh Generation & Mesh Optimization

The 3D mesh is created inside `build_weapon_mesh()` using Godot's `SurfaceTool`.

### 5.1 Greedy Face Culling
Rather than generating 6 quad faces (12 triangles) for every voxel (which would generate thousands of hidden polygons inside solid structures), the engine checks all 6 neighbor directions:
- $+Z$ (Front)
- $-Z$ (Back)
- $+X$ (Right)
- $-X$ (Left)
- $+Y$ (Top)
- $-Y$ (Bottom)

A quad is emitted **only if the adjacent cell is `VoxelType.EMPTY` or falls outside the grid bounds**:
```gdscript
# Example: +X (Right Face) Culling
if x + 1 >= w or grid_3d[x + 1][y][z] == VoxelType.EMPTY:
    _emit_quad(st, col, Vector3(1, 0, 0), ...)
```
> [!TIP]
> This reduces the polygon count of heavy and solid weapons by over **60%**, dramatically improving batch rendering efficiency for floating weapons and inventory inspect screens.

### 5.2 Dual Surface Materials
Voxels are segregated into two distinct draw passes:
1. **Opaque Geometry (`st_opaque`)**:
   - Material: `StandardMaterial3D`
   - Properties: `vertex_color_use_as_albedo = true`, `metallic = 0.78`, `roughness = 0.32`, `cull_mode = CULL_BACK`.
2. **Energy Geometry (`st_energy`)**:
   - Material: `StandardMaterial3D`
   - Properties: `emission_enabled = true`, `emission = palette["energy"]`, `emission_energy_multiplier = 3.5`.
   - Results in natural bloom and glow when WorldEnvironment / Post-processing HDR is active.

---

## 6. 2D Pixel-Art Icon Projection

For UI inventory slots, quickbars, and card HUDs, [`ProceduralWeaponEngine.generate_weapon_icon()`](file:///d:/GODOT/terrain/src/combat/generator/procedural_weapon_engine.gd#L512) renders a dedicated $28 \times 28$ pixel-art texture directly from the 2D projection matrix (`grid_2d`):

```mermaid
flowchart LR
    A["grid_2d [24 x 7]"] --> B["Diagonal Ray Cast: (5, 23) to (23, 5)"]
    B --> C["Perpendicular Offset Vector (0.7071, 0.7071)"]
    C --> D["Directional Pseudo-Lighting (dx < 0: +18%, dx > 0: -22%)"]
    D --> E["Energy Core Brightness Boost (+35% White Lerp)"]
    E --> F["ImageTexture (28x28 RGBA8)"]
```

### Features:
- **Diagonal Display ($45^\circ$)**: Fits naturally into RPG weapon slots and quickbars.
- **Directional Lighting**: Pixels offset to the left ($dx < 0$) receive an 18% tint brightening, while pixels to the right ($dx > 0$) receive a 22% shadow darkening.
- **Icon Registration**: Icons are automatically registered in [`WeaponIconFactory`](file:///d:/GODOT/terrain/src/combat/ui/weapon_icon_factory.gd) using the weapon's unique ID for instantaneous retrieval across all UI panels.

---

## 7. Visual Node Assembly & Particle VFX

Calling `create_weapon_node(weapon_def)` instantiates a complete `Node3D` hierarchy ready to attach to the player or weapon socket:

```
WeaponVisualRoot (Node3D)
├── WeaponMeshInstance (MeshInstance3D) [ArrayMesh with Opaque & Energy surfaces]
└── WeaponAuraParticles (CPUParticles3D)
```

### Particle System Specification (`WeaponAuraParticles`):
- **Count**: 14 ambient motes
- **Emission Box**: Extents `(0.045, 0.45, 0.035)` spanning the blade length
- **Position**: Offset `Vector3(0.0, 0.50, 0.0)` above the guard
- **Material**: Unshaded billboard particles matching the palette's energy color with an emission boost of `3.0`
- **Behavior**: Gentle upward draft with low velocity ($0.04 \dots 0.15 \text{ m/s}$) to give floating frames a living, resonant aura.

---

## 8. Integration with the Combat System

The following sequence illustrates how `ProceduralWeaponEngine` interacts with the rest of the game:

```mermaid
sequenceDiagram
    autonumber
    participant Caller as Game / Loot Spawner
    participant Engine as ProceduralWeaponEngine
    participant Def as MeleeWeaponDef
    participant IconFactory as WeaponIconFactory
    participant Controller as FloatingWeaponController
    participant DeckUI as WeaponDeckUI

    Caller->>Engine: generate_weapon(seed, params)
    Engine->>Engine: generate_voxel_matrix()
    Engine->>Engine: generate_weapon_icon()
    Engine->>IconFactory: register_weapon_icon(id, icon)
    Engine->>Def: new() populated with stats & voxel_data
    Engine-->>Caller: return weapon_def

    Caller->>Controller: equip_weapon(weapon_def)
    Controller->>Engine: create_weapon_node(weapon_def)
    Engine-->>Controller: WeaponVisualRoot (Mesh + Aura)
    Controller->>Controller: Apply float_offset and float_tilt_degrees

    Caller->>DeckUI: set_weapon(weapon_def)
    DeckUI->>Def: Read slot_capacity, slotted_techniques, icon
    DeckUI->>DeckUI: Draw quickbar slot & technique sockets
```

### Key Consumer Classes:
- [`MeleeWeaponDef`](file:///d:/GODOT/terrain/src/combat/core/melee_weapon_def.gd): Data container holding deck capacity, recharge timings, damage/stamina multipliers, and floating mount coordinates.
- [`FloatingWeaponController`](file:///d:/GODOT/terrain/src/combat/visuals/floating_weapon_controller.gd): Controls the weapon in 3D space, handles floating idle bobbing, sway, attack arcs, and calls `builder.create_weapon_node(weapon_def)`.
- [`MeleeDeckEvaluator`](file:///d:/GODOT/terrain/src/combat/core/melee_deck_evaluator.gd): Consumes the weapon's card slots to execute attack combos without coupling to geometry.
- [`WeaponIconFactory`](file:///d:/GODOT/terrain/src/combat/ui/weapon_icon_factory.gd): Stores and provides cached pixel textures for UI buttons, loot tooltips, and HUD readouts.

---

## 9. Usage Examples

### 9.1 Generating a Random Weapon
```gdscript
# Generates a completely randomized weapon from current system time
var weapon: MeleeWeaponDef = ProceduralWeaponEngine.generate_weapon()

print("Generated:", weapon.display_name)
print("Capacity:", weapon.slot_capacity, "Recharge:", weapon.deck_recharge_time)
```

### 9.2 Generating a Deterministic Archetype with Overrides
```gdscript
var custom_params = {
    "profile": ProceduralWeaponEngine.WeaponProfile.HEAVY,
    "name": "Oblivion Sunderer",
    "slot_capacity": 6,
    "deck_recharge_time": 0.70,
    "base_damage_multiplier": 1.40,
    "stamina_cost_multiplier": 1.20
}

# Fixed seed (42001) guarantees identical visuals every run
var heavy_blade: MeleeWeaponDef = ProceduralWeaponEngine.generate_weapon(42001, custom_params)
```

### 9.3 Spawning 3D Visuals in Scene
```gdscript
# Instantiate visual node hierarchy
var weapon_node: Node3D = ProceduralWeaponEngine.create_weapon_node(heavy_blade)
add_child(weapon_node)

# Position and tilt according to weapon definition defaults
weapon_node.position = Vector3(heavy_blade.float_offset_right, heavy_blade.float_offset_height, heavy_blade.float_offset_forward)
weapon_node.rotation_degrees = heavy_blade.float_tilt_degrees
```

---

## 10. Summary of Constants & Tuning Parameters

| Parameter | Type | Default Value | Description |
|:---|:---|:---|:---|
| `DEFAULT_VOXEL_SIZE` | `float` | `0.045` | Real-world meters per voxel side (~1.08m total height). |
| `TARGET_WEAPON_HEIGHT_VOXELS` | `int` | `24` | Total vertical voxel resolution along the Y-axis. |
| `DEFAULT_GRID_WIDTH` | `int` | `7` | Maximum voxel spread along the lateral X-axis. |
| `DEFAULT_GRID_DEPTH` | `int` | `3` | Maximum voxel thickness along the Z-axis. |
| `JUNCTION_Y` | `int` | `5` | Height index of collar/crossguard; aligns with mesh local origin. |
| `float_offset_right` | `float` | `0.68` | Resting horizontal hover distance from player center. |
| `float_offset_height` | `float` | `0.95` | Resting vertical hover height relative to player origin. |
| `float_offset_forward` | `float` | `-0.12` | Resting forward/backward position relative to player facing. |
| `float_tilt_degrees` | `Vector3` | `(18.0, -12.0, 10.0)` | Natural aesthetic 3-axis idle tilt angles. |

