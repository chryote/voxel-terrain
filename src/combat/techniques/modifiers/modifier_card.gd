class_name ModifierCard
extends "res://src/combat/core/technique_card.gd"

## Blade infusion modifier card.
## Alters slotted motion timing (speed & frequency), VFX appearance, damage, and kinematics.

@export_group("Timing Multipliers")
## Multiplier on execution_duration (< 1.0 makes attack execute faster, > 1.0 makes it a heavy slow swing)
@export var execution_duration_multiplier: float = 1.0

## Multiplier on recovery_delay (< 1.0 increases attack frequency, > 1.0 reduces attack frequency)
@export var recovery_delay_multiplier: float = 1.0

@export_group("Kinetic Mass & Momentum Multipliers")
## Multiplies the effective mass of the strike (e.g. Densifier mods, weighted edge).
## Directly scales kinetic energy: E = 0.5 * (mass * mass_multiplier) * v^2.
@export var mass_multiplier: float = 1.0

## Percentage of exit velocity retained from the previous strike in a combo (0.0 to 1.0+).
## Enabling momentum retention allows chained swings to accelerate exponentially!
@export var momentum_retention: float = 0.0

@export_group("Damage & Appearance Infusion")
@export var damage_multiplier: float = 1.0
@export var poise_multiplier: float = 1.0
@export var color_tint: Color = Color.WHITE
@export var emission_multiplier: float = 1.0

@export_group("Scale & Reach")
@export var radius_multiplier: float = 1.0
@export var arc_sweep_multiplier: float = 1.0
@export var thickness_multiplier: float = 1.0

@export_group("Kinematics")
@export var player_lunge_distance: float = 0.0

func get_card_kind() -> CardKind:
	return CardKind.MODIFIER

func apply_to_context(ctx: MeleeAttackContext) -> void:
	ctx.execution_duration *= execution_duration_multiplier
	ctx.recovery_delay *= recovery_delay_multiplier
	ctx.mass_multiplier *= mass_multiplier
	ctx.momentum_retention += momentum_retention
	ctx.damage_multiplier *= damage_multiplier
	ctx.poise_multiplier *= poise_multiplier
	# Also scale ctx.damage directly in case legacy base_damage was preset
	ctx.damage *= damage_multiplier
	ctx.poise_damage *= poise_multiplier
	ctx.outer_radius *= radius_multiplier
	ctx.arc_sweep_degrees *= arc_sweep_multiplier
	ctx.volume_thickness *= thickness_multiplier
	ctx.stamina_cost += stamina_cost

	if color_tint != Color.WHITE:
		ctx.core_color = ctx.core_color.lerp(color_tint, 0.65)
		ctx.edge_color = ctx.edge_color.lerp(color_tint, 0.85)
		ctx.deep_color = ctx.deep_color.lerp(color_tint, 0.90)

	ctx.emission_intensity *= emission_multiplier
	ctx.player_lunge_distance += player_lunge_distance
