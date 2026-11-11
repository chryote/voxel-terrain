# Procedural Weapon Generator

This directory contains the procedural synthesis engine for modular melee weapons.

- **Primary Script**: [`procedural_weapon_engine.gd`](file:///d:/GODOT/terrain/src/combat/generator/procedural_weapon_engine.gd)
- **Full Architecture & Technical Documentation**: [`docs/procedural_weapon_engine.md`](file:///d:/GODOT/terrain/docs/procedural_weapon_engine.md)

## Quick Overview

[`ProceduralWeaponEngine`](file:///d:/GODOT/terrain/src/combat/generator/procedural_weapon_engine.gd) programmatically synthesizes:
1. **Colossal 3D Voxel Meshes (`ArrayMesh`)**: Monster Hunter scale (40 voxels tall, $\sim 2.00\text{m}$, 11-voxel width $\sim 0.55\text{m}$, 5-voxel depth $\sim 0.25\text{m}$, 2,200 grid volume) with greedy face culling and dual opaque/emissive materials.
2. **Exotic Generative Topologies (`TopologyType`)**:
   - **Volumetric Erosion**: 3D Cellular Automata 26-neighborhood starvation creating porous hive relics.
   - **Parametric Helices & Orbitals**: Double-helix sine/cosine strands wrapping central spine (Caduceus / tuning fork).
   - **L-System Branching**: Recursive fractal and crystalline growth outward from spine anchor nodes.
   - **Noise-Sliced Fracturing**: 3D Simplex noise slicing heavy frames into floating shards with telekinetic energy lines.
   - **Multi-Axis Mirroring**: Hyper-symmetrical biblically accurate kaleidoscopic mandalas and sacred geometry stars.
   - **Fungal Bracket & Mycelial Rot**: Asymmetrical unilateral shelf bracket fungi, decaying host spine, and creeping mycelium random walks.
   - **The Osteological Cage**: Vertebral column spine, curving rib-like arches, and an untouched floating massive energy core.
   - **Insectoid Hive**: Bulky teardrop chitinous mass with 3D modulo honeycomb cavities and glowing volatile nectar.
   - **Abyssal Marine**: Branching staghorn coral random walk capped by an apex umbrella jellyfish dome and venomous trailing tentacles.
   - **Carnivorous Botanical**: Stalk spine wrapped in a strangling thorny vine helix, flaring into a bulbous pitcher plant with inward predatory teeth.
   - **Core Locking**: Two-handed functional handle ($y=1\dots6$), collar ($y=7$), and central spine ($y=8\dots39$) are strictly locked for anatomical structural integrity.
3. **2D Pixel-Art HUD Icons (`ImageTexture`)**: $28 \times 28$ directional pixel-shaded icons for UI and quickbars, with width auto-scaling.
4. **Deckbuilding Combat Definitions (`MeleeWeaponDef`)**: Configures slot capacity, recharge times, shuffle behavior, and damage multipliers. Attack motions and combos are driven separately by slotted `TechniqueCard`s.

