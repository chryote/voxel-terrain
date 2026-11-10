class_name MeleeAttackContext
extends RefCounted

## Runtime attack packet compiled by MeleeDeckEvaluator from slotted technique cards.
## Dictates all visual, temporal, physical, and hitbox properties of an attack execution.

enum ElementalType {
	PHYSICAL = 0,
	FIRE = 1,
	ICE = 2,
	LIGHTNING = 3,
	ACID = 4
}

# --- Attack Execution Timing (Card-Driven) ---
## How fast the slash sweeps through space (seconds).
## Governs ProceduralSlashEffect tween and the duration the floating sword remains hidden.
var execution_duration: float = 0.24

## How frequent attacks can occur (seconds).
## Governs the cooldown before the next slotted technique in sequence can be cast.
var recovery_delay: float = 0.18

# --- Hitbox & Damage ---
var damage: float = 25.0
var poise_damage: float = 15.0
var knockback_force: float = 5.0
var elemental_type: int = ElementalType.PHYSICAL
var stamina_cost: float = 10.0

# --- 3D Volumetric Slash VFX Mesh Parameters ---
var inner_radius: float = 0.75
var outer_radius: float = 2.45
var arc_sweep_degrees: float = 135.0
var volume_thickness: float = 0.22
var outer_height: float = 0.025
var tilt_degrees: float = -10.0
var is_reversed_sweep: bool = false

# --- Slash Energy Shader & Particle Colors ---
var core_color: Color = Color(0.9, 0.96, 1.0, 1.0)
var edge_color: Color = Color(0.15, 0.75, 1.0, 1.0)
var deep_color: Color = Color(0.02, 0.18, 0.75, 1.0)
var emission_intensity: float = 4.5
var trail_dissolve_rate: float = 0.65

# --- Kinematic Impulses ---
var player_lunge_distance: float = 0.0

# --- Trigger Payloads ---
var nested_triggers: Array = []

# --- Metadata ---
var source_card_id: String = ""

func duplicate_context() -> RefCounted:
	var c = (load("res://src/combat/core/melee_attack_context.gd") as GDScript).new()
	c.execution_duration = execution_duration
	c.recovery_delay = recovery_delay
	c.damage = damage
	c.poise_damage = poise_damage
	c.knockback_force = knockback_force
	c.elemental_type = elemental_type
	c.stamina_cost = stamina_cost
	c.inner_radius = inner_radius
	c.outer_radius = outer_radius
	c.arc_sweep_degrees = arc_sweep_degrees
	c.volume_thickness = volume_thickness
	c.outer_height = outer_height
	c.tilt_degrees = tilt_degrees
	c.is_reversed_sweep = is_reversed_sweep
	c.core_color = core_color
	c.edge_color = edge_color
	c.deep_color = deep_color
	c.emission_intensity = emission_intensity
	c.trail_dissolve_rate = trail_dissolve_rate
	c.player_lunge_distance = player_lunge_distance
	c.nested_triggers = nested_triggers.duplicate()
	c.source_card_id = source_card_id
	return c
