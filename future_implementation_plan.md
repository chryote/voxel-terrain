# Procedural Melee Attack System (Noita-Style) — Implementation Plan

> **Status:** **Active & In Progress**  
> **Current Codebase State:** Foundation Implemented (Procedural Floating Sword, Parametric 3D Volumetric Slash VFX, Shader Pipeline, and Player Integration operational).  
> **Core Architectural Paradigm:** The **Weapon is purely a Data Container / Modular Stance Frame**. All attack execution behavior—including the **3D volume VFX slash**, **how fast it executes an attack** (execution duration), and **how frequent it attacks** (recovery/tempo delay)—is strictly dictated by the **Technique Cards slotted into the weapon's technique slots**.

---

## 1. Executive Summary & Core Concept

This plan outlines the architecture, visual pipeline, and step-by-step implementation of a **Card-Driven Procedural Melee Attack System** inspired by *Noita's* wand and spellcrafting mechanics, adapted for 3D third-person melee combat in Godot 4.

### 1.1 The Weapon as a Pure Data Container
In this architecture:
- **The Weapon does NOT hardcode attack behaviors, combos, swing speeds, or cooldowns.**
- The **Weapon (`MeleeWeaponDef`)** is strictly a **Data Container**:
  - Defines the weapon's visual identity (procedural mesh builder, material profile, floating aura motes).
  - Defines the weapon's floating mount transform (right offset, height offset, forward offset, idle bobbing curves).
  - Holds the **Technique Sockets (`Array[TechniqueCard]`)** with a defined `slot_capacity` (e.g. 3 to 8 slots).
  - Configures deck traversal mode (`is_shuffle: bool`).
  - Sets global base multipliers (e.g. global damage scaling, stamina capacity multiplier).

### 1.2 Slotted Technique Cards Drive All Attack Kinematics
Every physical and visual parameter of an attack is determined by the **Technique Cards** slotted inside the weapon:
1. **3D Volume VFX Slash:** The slotted `MotionCard` dictates the parametric arc mesh geometry (inner/outer radius, arc sweep angle, 3D thickness, crescent profile), the slash plane orientation (horizontal, upswing, overhead cleave, diagonal, thrust), and visual energy shader uniforms (core color, edge glow, noise sizzle, trail dissipation rate).
2. **Attack Execution Speed ("How fast it executes an attack"):** Dictated by the card's `execution_duration`. A lightweight *Quick Slash* card executes in 0.14s; a heavy *Colossal Cleave* card executes in 0.42s. Slotted modifier cards can scale this duration (e.g. *Swift Edge* reduces duration by 30%).
3. **Attack Frequency ("How frequent it attacks"):** Dictated by the card's `recovery_delay` / `tempo_delay`. High-frequency flurry cards allow immediate follow-up strikes within 0.08s; heavy finisher cards impose a 0.55s recovery delay before the next slotted technique can be cast. When all slots are exhausted, the weapon-level or card-weighted recharge delay governs cycle reset.
4. **Kinetic Weapon Behavior:** The weapon floats telekinetically beside the player's right side during idle. When left-click attack is triggered, the floating sword **instantly hides**, the slotted card's **3D volume slash VFX sweeps through space** at the card's designated execution speed, and upon completion the sword **restores with a dynamic spring pop** back to its floating rest position.

```
                    [ PLAYER INPUT: Left Click (Fire Intent) ]
                                       │
                                       ▼
                     [ FLOATING SWORD CONTROLLER / EVALUATOR ]
               Reads active slotted Technique Card at current_index
               Weapon acts strictly as Data Container holding slots
                                       │
                    ┌──────────────────┴──────────────────┐
                    ▼                                     ▼
         [ SWORD VISUAL STATE ]               [ CARD-DRIVEN 3D SLASH VFX ]
       • Hide floating sword                • MotionCard defines arc geometry
       • Block re-entry until recovery        (inner/outer radius, 3D thickness)
         delay completes                    • Execution Speed: card.execution_duration
                    │                       • Attack Frequency: card.recovery_delay
                    │                       • Energy Shader & Particle Bursts
                    │                                     │
                    │                       ┌─────────────┴─────────────┐
                    │                       ▼                           ▼
                    │             [ 3D VOLUME HITBOX ]        [ ON-HIT TRIGGERS ]
                    │          • Sweep spatial query        • If card has Trigger,
                    │          • Impact spark spawner         evaluates sub-deck on
                    │          • Voxel carving / foliage      contact (Noita-style)
                    │                       │                           │
                    └───────────────────────┼───────────────────────────┘
                                            ▼
                           [ SWORD REAPPEARANCE & RECOVERY ]
                    • Card execution duration completes
                    • Sword unhides & springs back into floating idle
                    • Advances current_index (or reshuffles if enabled)
                    • Ready for next attack once recovery_delay elapses
```

---

## 2. Noita to Melee Translation Matrix

| Noita Wand / Spell Concept | Procedural Melee System Equivalent | Description |
| :--- | :--- | :--- |
| **Wand** | **Weapon Frame / Stance Container** (`MeleeWeaponDef`) | **Pure Data Container**. Holds technique slots, visual mesh profile, float offset, capacity, and shuffle flag. Has no hardcoded attacks. |
| **Projectile Spell** (e.g. *Spark Bolt*) | **Motion Card** (e.g. *HorizontalSweep*, *PiercingThrust*) | **The Core Strike Action**. Dictates the 3D volume slash VFX, **execution speed** (`execution_duration`), and **attack frequency** (`recovery_delay`). |
| **Cast Delay** | **Card Tempo / Recovery Delay** (`recovery_delay`) | **Set per Technique Card**. Governs how quickly the player can execute the *next* attack in the slot sequence. |
| **Spell Velocity & Lifetime** | **Attack Execution Speed** (`execution_duration`) | **Set per Technique Card**. Governs how fast the 3D volumetric slash sweeps through space (0.12s–0.45s). |
| **Recharge Time** | **Deck Cycle Reset Time** (`combo_reset_time`) | Cooldown after casting all slotted technique cards before resetting to slot 0 (or reshuffling). Influenced by card weight modifiers. |
| **Mana Cost / Max** | **Stamina Pool & Drain** (`stamina_cost`) | Stamina deducted per card execution. Prevents infinite attack spamming. |
| **Spell Modifier** (e.g. *Damage Plus, Fire Trail*) | **Blade Infusion Card** (e.g. *FlameEdge*, *SwiftEdge*) | Modifies damage, tints slash VFX shader, scales execution speed, adds player lunges, or attaches elemental trails. |
| **Multicast** (e.g. *Double Cast, Scatter*) | **Formation Card** (e.g. *TwinSlash*, *CrossCut*) | Resolves 2+ slotted motion cards in a single swing action with simultaneous 3D volume slashes. |
| **Spell with Trigger** (e.g. *Spark Bolt with Trigger*) | **Chain Trigger Card** (e.g. *Thrust with Hit-Trigger*) | On hitting an enemy or voxel surface, immediately executes the nested payload technique cards. |
| **Projectile Wave** (e.g. *Bouncing Burst*) | **Blade Beam Modifier** (`BladeBeamModifier`) | Ejects a flying crescent shockwave along the slash plane at the end of the swing. |

---

## 3. Current Codebase Implementation Baseline

The foundation for this system is already implemented and operating in the workspace:

### 3.1 Implemented Components in `src/combat/visuals/`
- **[`SwordMeshBuilder`](file:///d:/GODOT/terrain/src/combat/visuals/sword_mesh_builder.gd):**
  - Procedurally generates a stylized 3D longsword with double-edged blade, glowing runic fuller, winged crossguard, leather grip, and faceted pommel.
  - Spawns ambient floating magical aura particles (`CPUParticles3D`) drifting off the blade.
- **[`FloatingSwordController`](file:///d:/GODOT/terrain/src/combat/visuals/floating_sword_controller.gd):**
  - Mounts to the player character, floating on the right side (`right_offset = 0.68`, `height_offset = 0.95`).
  - Provides idle hover levitation with sine-wave bobbing, subtle pitch/roll tilts, camera yaw inertia tracking, and movement speed aerodynamic drag.
  - Controls attack hiding: On attack trigger, instantly sets `_sword_root.visible = false`, triggers the 3D slash VFX, and upon completion smoothly springs back into floating rest with a `Tween.TRANS_BACK` re-entry.
- **[`SlashArcMeshBuilder`](file:///d:/GODOT/terrain/src/combat/visuals/slash_arc_mesh_builder.gd):**
  - Generates a **true 3D volumetric crescent arc prism mesh** with real physical thickness (top curved surface, bottom curved surface, razor cutting edge, inner wall, and tapered end caps).
  - Eliminates flat 2D billboard artifacts across dynamic third-person camera angles.
- **[`slash_volume.gdshader`](file:///d:/GODOT/terrain/shaders/combat/slash_volume.gdshader):**
  - Spatial shader (`blend_add`, unshaded, `cull_disabled`) driven by uniform `progress`.
  - Implements dynamic head sweep reveal, exponential trailing tail dissolution, high-frequency plasma noise sizzle, white-hot core, and volumetric 3D Fresnel rim highlights.
- **[`ProceduralSlashEffect`](file:///d:/GODOT/terrain/src/combat/visuals/procedural_slash_effect.gd):**
  - World-space animated 3D slash instance with progress tweening, forward spark burst particles, and multi-point arc ray collision checking against environment and entities.
- **[`HitImpactSpawner`](file:///d:/GODOT/terrain/src/combat/visuals/hit_impact_spawner.gd):**
  - Spawns directional spark bursts oriented along collision surface normals upon solid strikes.
- **Integration & Tests:**
  - Integrated into [`PlayerMotor`](file:///d:/GODOT/terrain/src/player/player_motor.gd) and [`scenes/player.tscn`](file:///d:/GODOT/terrain/scenes/player.tscn).
  - Verified with 5 unit tests in [`tests/unit/test_floating_sword.gd`](file:///d:/GODOT/terrain/tests/unit/test_floating_sword.gd) (5/5 passed).

---

## 4. Architecture & Directory Layout

The combat module is located in `res://src/combat/`, maintaining strict decoupling from voxel terrain generation and pawn physics:

```
src/combat/
├── core/
│   ├── melee_attack_context.gd       # Runtime packet: compiled damage, reach, arc mesh params, execution duration, recovery delay
│   ├── melee_deck_evaluator.gd       # Interpreter: parses weapon slots, evaluates modifiers, multicasts & triggers
│   ├── melee_weapon_def.gd           # Resource: Pure Data Container (mesh profile, slot capacity, float offsets, shuffle flag)
│   └── technique_card.gd             # Base Resource for all technique cards
├── techniques/
│   ├── motions/                      # Motion Cards: Dictate VFX slash geometry, execution speed, recovery delay
│   │   ├── motion_card.gd            # Base class for all physical swing motions
│   │   ├── motion_horizontal_sweep.gd# 130° wide cleave (medium speed, wide crowd control)
│   │   ├── motion_upswing.gd         # Fast vertical upward cut (high speed, launch effect)
│   │   ├── motion_downcleave.gd      # Heavy overhead slam (slower speed, high recovery, ground crater)
│   │   ├── motion_piercing_thrust.gd # Ultra-fast narrow needle stab (low recovery, armor piercing)
│   │   └── motion_spin_whirl.gd      # 360° circular sweep (longer execution duration, all-around hit)
│   ├── modifiers/                    # Modifier Cards: Alter VFX, speed, frequency, element, physics
│   │   ├── modifier_card.gd          # Base class for blade infusions
│   │   ├── mod_swift_edge.gd         # -30% execution duration, -40% recovery delay (high frequency)
│   │   ├── mod_heavy_impact.gd       # +50% damage, +25% execution duration, +40% recovery delay, ground crater
│   │   ├── mod_flame_edge.gd         # Fire damage + burning trail VFX + voxel ignition
│   │   ├── mod_frost_edge.gd         # Ice slow + crystalline freeze VFX
│   │   ├── mod_shock_edge.gd         # Chain lightning to adjacent targets on hit
│   │   ├── mod_lunge.gd              # Forward player impulse during execution
│   │   └── mod_blade_beam.gd         # Fires flying crescent shockwave along the slash plane
│   ├── multicast/                    # Formations
│   │   ├── multicast_card.gd         # Base class for simultaneous / flurry casts
│   │   ├── multi_double_slash.gd     # Dispatches 2 motion cards in one attack action
│   │   └── multi_cross_cut.gd        # Intersecting diagonal "X" slashes
│   └── triggers/                     # Event-driven sub-deck evaluation
│       ├── trigger_card.gd           # Base class for conditional triggers
│       └── trigger_on_hit.gd         # Contact-triggered payload execution
├── visuals/                          # Visual and Procedural Kinematics
│   ├── floating_sword_controller.gd  # [Implemented] Idle hover, sword hide/restore, evaluator execution bridge
│   ├── sword_mesh_builder.gd         # [Implemented] Procedural 3D stylized sword mesh & aura particles
│   ├── slash_arc_mesh_builder.gd     # [Implemented] Parametric 3D volumetric arc prism generator
│   ├── procedural_slash_effect.gd    # [Implemented] Slash VFX instance manager (sweep animation, sparks, hit test)
│   └── hit_impact_spawner.gd         # [Implemented] Collision impact spark spawner
├── hitbox/
│   ├── slash_hitbox_query.gd         # ShapeCast3D / spatial volume intersection pipeline
│   └── damage_packet.gd              # Damage, knockback, damage type, poise break, instigator
├── ui/
│   ├── deck_editor_hud.gd            # Noita-style card inventory and weapon slot interface
│   └── combo_readout_hud.gd          # On-screen active combo indicator & stamina gauge
└── shaders/
    └── slash_volume.gdshader         # [Implemented] Volumetric arc energy shader with noise & dissolve
```

---

## 5. Detailed Component Specifications

### 5.1 The Weapon as a Pure Data Container (`MeleeWeaponDef`)

The weapon resource holds no attack animations, frame data, or hardcoded cooldowns:

```gdscript
class_name MeleeWeaponDef
extends Resource

@export_group("Visual Profile")
@export var weapon_id: String = "novice_longsword"
@export var display_name: String = "Novice Longsword"
@export var mesh_profile: Script = preload("res://src/combat/visuals/sword_mesh_builder.gd")
@export var float_offset_right: float = 0.68
@export var float_offset_height: float = 0.95
@export var float_offset_forward: float = -0.12
@export var float_tilt_degrees: Vector3 = Vector3(18.0, -12.0, 10.0)

@export_group("Technique Sockets")
@export var slot_capacity: int = 5
@export var slotted_techniques: Array[TechniqueCard] = []
@export var is_shuffle: bool = false

@export_group("Base Modifiers")
@export var base_damage_multiplier: float = 1.0
@export var base_stamina_capacity: float = 100.0
@export var deck_recharge_time: float = 0.65 # Fallback cycle cooldown when deck ends
```

### 5.2 Card-Driven Attack Kinematics (`MotionCard`)

Every physical and visual property of a strike is configured on the slotted `MotionCard`:

```gdscript
class_name MotionCard
extends TechniqueCard

@export_group("Attack Execution Timing")
## How fast the slash sweeps through space (in seconds).
## Dictates the animation speed of the 3D volume slash and the duration the sword remains hidden.
@export var execution_duration: float = 0.24

## How frequent attacks can occur (in seconds).
## The minimum cooldown before the next slotted technique can be executed.
@export var recovery_delay: float = 0.18

@export_group("3D Volumetric Slash VFX")
@export var inner_radius: float = 0.75
@export var outer_radius: float = 2.45
@export var arc_sweep_degrees: float = 135.0
@export var volume_thickness: float = 0.22
@export var tilt_degrees: float = -10.0
@export var is_reversed_sweep: bool = false

@export_group("VFX Shader & Elemental Appearance")
@export var core_color: Color = Color(0.9, 0.96, 1.0, 1.0)
@export var edge_color: Color = Color(0.15, 0.75, 1.0, 1.0)
@export var deep_color: Color = Color(0.02, 0.18, 0.75, 1.0)
@export var emission_intensity: float = 4.5
@export var trail_dissolve_rate: float = 0.65

@export_group("Damage & Hitbox")
@export var base_damage: float = 25.0
@export var poise_damage: float = 15.0
@export var knockback_force: float = 5.0
```

### 5.3 Modifiers Dictating Speed, Frequency, and Elements (`ModifierCard`)

Modifiers placed before a motion card alter both its timing and its visual footprint:

```gdscript
class_name ModifierCard
extends TechniqueCard

@export_group("Timing Multipliers")
## Multiplier applied to execution_duration (< 1.0 = faster execution, > 1.0 = slower heavy swing)
@export var execution_duration_multiplier: float = 1.0

## Multiplier applied to recovery_delay (< 1.0 = higher frequency, > 1.0 = lower frequency)
@export var recovery_delay_multiplier: float = 1.0

@export_group("VFX & Element Modifiers")
@export var color_tint: Color = Color.WHITE
@export var radius_scale: float = 1.0
@export var damage_multiplier: float = 1.0
@export var elemental_type: int = 0 # 0=Physical, 1=Fire, 2=Ice, 3=Lightning
@export var player_lunge_impulse: float = 0.0
```

### 5.4 Evaluator Loop (`MeleeDeckEvaluator`)

The evaluator processes cards sequentially from the weapon's sockets:

```
[ Attack Requested (Left Click) ]
       │
       ▼
Is Evaluator in Recovery Delay or Deck Recharge?
       ├── Yes ──> Ignore input (or buffer next stroke)
       └── No  ──> Fetch card at weapon.slotted_techniques[current_index]
                     │
                     ▼
             Card Type Check:
             ├── ModifierCard:
             │     Accumulate into active MeleeAttackContext:
             │     • execution_duration *= mod.execution_duration_multiplier
             │     • recovery_delay *= mod.recovery_delay_multiplier
             │     • radius_scale *= mod.radius_scale
             │     • color_tint = mod.color_tint
             │     Advance current_index -> loop next card
             │
             ├── MulticastCard:
             │     Set multicast_counter = N
             │     Advance current_index -> loop next card
             │
             └── MotionCard:
                   Compile MeleeAttackContext with card-dictated parameters:
                   • execution_duration = motion.execution_duration * accumulated_speed_mult
                   • recovery_delay = motion.recovery_delay * accumulated_recovery_mult
                   • arc_parameters = motion.get_arc_params(accumulated_scale)
                   • vfx_shader_params = motion.get_shader_params(accumulated_tint)
                   
                   Dispatch to FloatingSwordController:
                   1. Hide floating sword immediately.
                   2. Spawn 3D volume slash VFX with compiled arc parameters.
                   3. Play slash sweep over execution_duration.
                   4. Start recovery timer set to recovery_delay.
                   5. When execution_duration completes:
                      Restore floating sword with spring pop.
                   6. Advance current_index.
                   7. If end of deck reached:
                      Enter deck_recharge_time cooldown, reset index (or reshuffle).
```

---

## 6. Phased Implementation Roadmap

### Phase 1: Modular Card Core & Weapon Data Container (COMPLETED)
- [x] Create `src/combat/core/technique_card.gd` (Base Resource).
- [x] Create `src/combat/techniques/motions/motion_card.gd` with `execution_duration`, `recovery_delay`, 3D arc geometry, and shader parameters.
- [x] Create `src/combat/techniques/modifiers/modifier_card.gd` with timing multipliers and elemental overrides.
- [x] Create `src/combat/techniques/multicast/multicast_card.gd` for simultaneous / formation strikes.
- [x] Create `src/combat/techniques/triggers/trigger_card.gd` for on-hit / on-timer nested payloads.
- [x] Create `src/combat/core/melee_attack_context.gd` (Runtime compiled attack packet).
- [x] Create `src/combat/core/melee_weapon_def.gd` as pure data container holding sockets, capacity, mesh profile, and float offsets.
- [x] Implement `src/combat/core/melee_deck_evaluator.gd` handling card sequence parsing, modifier accumulation, execution duration, and recovery pacing.
- [x] Author comprehensive unit tests in `tests/unit/test_melee_deck_evaluator.gd` (6/6 passed, 41 assertions).

### Phase 2: Floating Sword Controller & Card Execution Bridge (COMPLETED)
- [x] Create `src/combat/visuals/sword_mesh_builder.gd` for stylized 3D weapon models.
- [x] Implement `src/combat/visuals/floating_sword_controller.gd`:
  - [x] Telekinetic idle hover levitation on the character's right side.
  - [x] Sine-wave bobbing, tilt swaying, camera yaw tracking, and running inertia.
  - [x] Left-click attack handling: instantly hides the sword on attack start.
  - [x] Dynamic sword restoration: springs back into floating idle with `Tween.TRANS_BACK`.
  - [x] Bridge `FloatingSwordController` to accept `MeleeAttackContext` from `MeleeDeckEvaluator`.

### Phase 3: 3D Volumetric Slash VFX Pipeline (COMPLETED)
- [x] Create `src/combat/visuals/slash_arc_mesh_builder.gd` generating parametric 3D volumetric arc prism meshes with thickness.
- [x] Author `shaders/combat/slash_volume.gdshader` with progress sweep, noise sizzle, white-hot core, and fresnel.
- [x] Create `src/combat/visuals/procedural_slash_effect.gd` combining mesh generation, shader animation, and spark particles.
- [x] Create `src/combat/visuals/hit_impact_spawner.gd` for surface collision sparks.
- [x] Wire into `PlayerMotor` and `scenes/player.tscn`.
- [x] Author unit tests in `tests/unit/test_floating_sword.gd` (5/5 passed).

### Phase 4: Starter Technique Cards & Weapon Presets (COMPLETED)
- [x] Implement Starter Motion Cards:
  - `motion_horizontal_sweep.tres`: 130° wide arc, duration 0.22s, recovery 0.16s.
  - `motion_upswing.tres`: Vertical upward cut, duration 0.18s, recovery 0.12s.
  - `motion_downcleave.tres`: Heavy slam, duration 0.36s, recovery 0.42s, poise break.
  - `motion_piercing_thrust.tres`: Forward linear stab, duration 0.14s, recovery 0.10s.
- [x] Implement Starter Modifier Cards:
  - `mod_swift_edge.tres`: -35% execution duration, -45% recovery delay.
  - `mod_heavy_impact.tres`: +60% damage, +35% execution duration, +45% recovery delay.
  - `mod_flame_edge.tres`: Fire damage, orange-red flame shader tint.
- [x] Create Starter Weapon Data Presets:
  - `preset_apprentice_blade.tres`: 5 slots, slotted with Sweep, Upswing, Downcleave.
  - `preset_flurry_rapier.tres`: 6 slots, slotted with Swift Edge + Thrust + Upswing.

### Phase 5: Environmental & Voxel Interaction
- [ ] Integrate slash volume with `VoxelWorld`:
  - Slashes mow down grass tufts and bushes (`FoliageChunkData`) within strike volume.
  - Slashes with `HeavyImpact` chip voxels on collision.
- [ ] Camera micro-shake and hitstop micro-freeze on contact.

### Phase 6: Noita-Style Weapon & Deck Interface (COMPLETED)
- [x] Create `src/combat/ui/noita_icon_factory.gd`:
  - [x] Generates authentic 24x24 and 28x28 pixel-art sprites for weapons (`apprentice_blade`, `flurry_rapier`) and technique cards (`Horizontal Sweep`, `Upswing`, `Downcleave`, `Piercing Thrust`, `Swift Edge`, `Flame Edge`, `Heavy Impact`, `Double Slash`, `Trigger On Hit`).
  - [x] Nearest-neighbor pixel filter caching.
- [x] Implement `src/combat/ui/noita_deck_ui.gd` (Faithful to Noita UI references):
  - [x] **Normal HUD Mode**:
    - [x] Top-left compact quickbar displaying equipped weapon icons in 34x34 slots.
    - [x] Active slot number marker ("1", "2", etc.) placed directly above the equipped weapon slot.
    - [x] 4 small item boxes (26x26) positioned beside the weapon slots.
    - [x] Cooldown overlay dimming the active weapon slot during attack execution and recharge.
    - [x] Clean and unobtrusive: no labels or debug text obscuring the screen during normal gameplay.
  - [x] **Inventory Mode ("I" Key)**:
    - [x] Full-screen dark semi-translucent backdrop overlay covering 100% of the viewport.
    - [x] Crisp white-colored component labels (`WEAPON`, `ITEM`, `INVENTORY`) revealed above each HUD component.
    - [x] **Top Bar Stability**:
      - [x] Fixed gap between `WEAPON` and `ITEM` slots (10px); `ITEM` slots NEVER shift or jump when toggling inventory.
      - [x] Separated top bar container from the accordion scroll hierarchy so accordion dimensions do not push adjacent components.
    - [x] **Left Column: Weapon Accordions**:
      - [x] Positioned directly underneath the top-left weapon quick access slots.
      - [x] Multi-slot wrapping: sockets break per 10 slots (`GridContainer` with `columns = 10`), supporting long weapons (e.g. 20+ slots) cleanly in rows of 10 without horizontal elongation.
      - [x] Vertical stack of weapon cards with 1px gold/amber border.
      - [x] Weapon icon, shuffle mode, spells/cast, and deck recharge time.
      - [x] Clicking weapon accordion equips that weapon.
    - [x] **Top-Row Aligned Inventory Grid**:
      - [x] Positioned on the top row alongside the weapon quick access and item slots (clearing the 10-slot accordion width).
      - [x] 32-slot grid (8 columns x 4 rows) of 34x34 dark brown Noita slot boxes.
      - [x] Populated slots show card pixel icons with category accent borders.
      - [x] Empty slots show classic dark brown beveled empty frames.
    - [x] **Interactions**:
      - [x] Click-to-swap: click a card to select (pulsing gold border), click another slot to move or swap.
      - [x] Native Godot 4 drag-and-drop: drag cards seamlessly between sockets and inventory grid boxes with floating drag preview (`NoitaSlotControl`).
      - [x] Right-click quick transfer: right-click weapon socket unslots to inventory; right-click inventory card slots into active weapon.
    - [x] **Rich Noita Tooltip**:
      - [x] Gold-bordered floating tooltip tracking mouse with card title, type tag, numerical stats, and description.
- [x] Unit test suite in `tests/unit/test_noita_deck_ui.gd` expanded and passing (10/10 passed, 58 assertions).

---

## 7. Verification & Acceptance Criteria

1. **Pure Data Container Weapon**:
   - Swapping weapon definition only changes visual mesh and socket capacity; all combat feel, timing, and VFX are dictated by the slotted cards.
2. **Card-Driven Attack Speeds & Frequencies**:
   - Slotted card with `execution_duration = 0.12s` visibly sweeps and restores the sword 3x faster than a card with `execution_duration = 0.36s`.
   - Slotted card with `recovery_delay = 0.08s` allows near-instant follow-up clicks; `recovery_delay = 0.50s` enforces deliberate pacing.
3. **Card-Driven 3D Slash VFX**:
   - Each card can produce distinct arc dimensions (e.g. 360° spin vs 130° cleave vs 20° thrust) and shader color ramps without altering weapon code.
4. **Visual Polish**:
   - The sword cleanly disappears during the attack sweep and smoothly springs back into floating idle on completion with zero popping.
   - 3D volumetric slash arc maintains physical thickness from all third-person camera angles.
