# Procedural Weapon Generator

This directory contains the procedural synthesis engine for modular melee weapons.

- **Primary Script**: [`procedural_weapon_engine.gd`](file:///d:/GODOT/terrain/src/combat/generator/procedural_weapon_engine.gd)
- **Full Architecture & Technical Documentation**: [`docs/procedural_weapon_engine.md`](file:///d:/GODOT/terrain/docs/procedural_weapon_engine.md)

## Quick Overview

[`ProceduralWeaponEngine`](file:///d:/GODOT/terrain/src/combat/generator/procedural_weapon_engine.gd) programmatically synthesizes:
1. **3D Voxel Meshes (`ArrayMesh`)**: 24-voxel high (~1.08m) models with face culling and dual opaque/emissive materials.
2. **2D Pixel-Art HUD Icons (`ImageTexture`)**: $28 \times 28$ directional pixel-shaded icons for UI and quickbars.
3. **Deckbuilding Combat Definitions (`MeleeWeaponDef`)**: Configures slot capacity, recharge times, shuffle behavior, and damage multipliers. Attack motions and combos are driven separately by slotted `TechniqueCard`s.

