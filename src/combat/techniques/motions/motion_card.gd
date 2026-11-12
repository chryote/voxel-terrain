class_name MotionCard
extends "res://src/combat/core/technique_card.gd"

## Core strike action technique card.
## Dictates the 3D volume slash VFX, execution duration (speed), and recovery delay (frequency).

@export_group("Attack Execution Timing")
## How fast the slash sweeps through space (seconds).
## Directly controls ProceduralSlashEffect duration and sword hide time.
@export var execution_duration: float = 0.24

## How frequent attacks can occur (seconds).
## The cooldown before the next slotted technique in sequence can be executed.
@export var recovery_delay: float = 0.18

@export_group("3D Volumetric Slash VFX Mesh")
@export var inner_radius: float = 0.75
@export var outer_radius: float = 2.45
@export var arc_sweep_degrees: float = 135.0
@export var volume_thickness: float = 0.22
@export var outer_height: float = 0.025
@export var tilt_degrees: float = -10.0
@export var is_reversed_sweep: bool = false

@export_group("VFX Shader & Appearance")
@export var core_color: Color = Color(0.9, 0.96, 1.0, 1.0)
@export var edge_color: Color = Color(0.15, 0.75, 1.0, 1.0)
@export var deep_color: Color = Color(0.02, 0.18, 0.75, 1.0)
@export var emission_intensity: float = 4.5
@export var trail_dissolve_rate: float = 0.65

@export_group("Kinetic Motion Dynamics")
## Forward kinetic lunge distance (meters) covered during execution duration.
@export var player_lunge_distance: float = 0.0

## Kinetic energy transfer efficiency (1.0 = 100% conversion of 0.5*m*v^2 into damage).
## Thrusts and piercing motions can have higher efficiency (>1.0), wide sweeping cleaves ~1.0.
@export var kinetic_efficiency: float = 1.0

## Multiplier on effective mass participating in this specific motion (default 1.0).
@export var mass_multiplier: float = 1.0

@export_group("Legacy / Manual Override (Optional)")
## Optional fixed base damage override. If <= 0.0 (default), damage is derived
## purely from physical kinetic energy: E = 0.5 * m * v^2.
@export var base_damage: float = 0.0
@export var poise_damage: float = 0.0
@export var knockback_force: float = 0.0

func get_card_kind() -> CardKind:
	return CardKind.MOTION

func apply_to_context(ctx: MeleeAttackContext) -> void:
	ctx.source_card_id = card_id
	ctx.execution_duration = execution_duration
	ctx.recovery_delay = recovery_delay
	ctx.kinetic_efficiency = kinetic_efficiency
	ctx.mass_multiplier = mass_multiplier
	ctx.player_lunge_distance = player_lunge_distance
	ctx.stamina_cost += stamina_cost

	# If explicit base_damage is set (> 0.0), preserve for legacy test compatibility
	if base_damage > 0.0:
		ctx.damage = base_damage
	if poise_damage > 0.0:
		ctx.poise_damage = poise_damage
	if knockback_force > 0.0:
		ctx.knockback_force = knockback_force

	ctx.inner_radius = inner_radius
	ctx.outer_radius = outer_radius
	ctx.arc_sweep_degrees = arc_sweep_degrees
	ctx.volume_thickness = volume_thickness
	ctx.outer_height = outer_height
	ctx.tilt_degrees = tilt_degrees
	ctx.is_reversed_sweep = is_reversed_sweep

	ctx.core_color = core_color
	ctx.edge_color = edge_color
	ctx.deep_color = deep_color
	ctx.emission_intensity = emission_intensity
	ctx.trail_dissolve_rate = trail_dissolve_rate
