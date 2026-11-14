class_name ModifierCard
extends "res://src/combat/core/technique_card.gd"

## Blade infusion modifier card.
## Alters slotted motion timing (speed & frequency), VFX appearance, damage, and kinematics.

@export_group("Timing Multipliers")
## Multiplier on execution_duration (< 1.0 makes attack execute faster, > 1.0 makes it a heavy slow swing)
@export var execution_duration_multiplier: float = 1.0

## Multiplier on recovery_delay (< 1.0 increases attack frequency, > 1.0 reduces attack frequency)
@export var recovery_delay_multiplier: float = 1.0

## Multiplier on weapon deck recharge time (e.g. 0.0 for instant reset in Kinetic Heat Sink)
@export var deck_recharge_multiplier: float = 1.0

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

@export_group("Visual & VFX Infusion (Explicit)")
## Override motion shader mode: 0 = PLASMA, 1 = VOID_INVERSION
@export var override_shader_mode: bool = false
@export var visual_shader_mode: int = 0

## Infuse a supersonic conical Mach vapor ring into the strike
@export var infuse_mach_ring: bool = false

## Infuse a 1-frame full-screen incandescent/invert flash on hit
@export var infuse_screen_flash: bool = false

## Infuse a 24m ground arena shockwave ring on hit
@export var infuse_arena_shockwave: bool = false

## Infuse a lingering gravitational black hole implosion on hit
@export var infuse_gravitational_implosion: bool = false

## Infuse the full 1-Billion Cataclysm Event on hit
@export var infuse_cataclysm: bool = false

## Infuse Singularity Apex Event
@export var infuse_singularity: bool = false

@export_group("Impact & Juice Infusion")
## Additional hitstop freeze duration in seconds added to the strike
@export var add_hitstop_duration: float = 0.0

## Multiplier on screen shake intensity
@export var screen_shake_multiplier: float = 1.0

## Additional camera impact snap (FOV punch degrees)
@export var add_camera_impact_snap: float = 0.0

## Infuse voxel afterimage ghost trail during motion execution
@export var infuse_afterimages: bool = false

## Override camera velocity pull-back
@export var override_camera_pullback: bool = false
@export var camera_velocity_pullback: bool = true

@export_group("Scale & Reach")
@export var radius_multiplier: float = 1.0
@export var arc_sweep_multiplier: float = 1.0
@export var thickness_multiplier: float = 1.0

@export_group("Kinematics & Decoupled Locomotion")
@export var player_lunge_distance: float = 0.0
@export var is_blink: bool = false
@export var blink_distance: float = 0.0
@export var override_locomotion_mode: bool = false
@export var locomotion_mode: int = MeleeAttackContext.LocomotionVectorMode.FORWARD
@export var locomotion_vertical_impulse: float = 0.0
@export var allows_free_movement: bool = false
@export var move_speed_multiplier: float = 1.0
@export var is_implosion: bool = false

@export_group("Resource Cost / Inertia Mitigation")
## Multiplier on stamina cost (e.g. 0.3 for Inertia Compensator or 0.0 for Zero-Point Flywheel)
@export var stamina_multiplier: float = 1.0

func get_card_kind() -> CardKind:
	return CardKind.MODIFIER

func apply_to_context(ctx: MeleeAttackContext) -> void:
	ctx.execution_duration *= execution_duration_multiplier
	ctx.recovery_delay *= recovery_delay_multiplier
	ctx.deck_recharge_multiplier *= deck_recharge_multiplier
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
	ctx.stamina_cost = (ctx.stamina_cost + stamina_cost) * stamina_multiplier

	if is_blink:
		ctx.is_blink = true
		ctx.blink_distance = maxf(ctx.blink_distance, blink_distance)

	if override_locomotion_mode:
		ctx.locomotion_mode = locomotion_mode as MeleeAttackContext.LocomotionVectorMode
	ctx.locomotion_vertical_impulse += locomotion_vertical_impulse
	if allows_free_movement:
		ctx.allows_free_movement = true
	ctx.move_speed_multiplier *= move_speed_multiplier
	if is_implosion:
		ctx.is_implosion = true

	if color_tint != Color.WHITE:
		ctx.core_color = ctx.core_color.lerp(color_tint, 0.65)
		ctx.edge_color = ctx.edge_color.lerp(color_tint, 0.85)
		ctx.deep_color = ctx.deep_color.lerp(color_tint, 0.90)

	ctx.emission_intensity *= emission_multiplier
	ctx.player_lunge_distance += player_lunge_distance

	# Explicit visual & VFX infusion
	if override_shader_mode:
		ctx.visual_shader_mode = visual_shader_mode as MeleeAttackContext.VisualShaderMode
		ctx.is_negative_space = (visual_shader_mode == 1)

	if infuse_mach_ring:
		ctx.has_mach_ring = true
	if infuse_screen_flash:
		ctx.triggers_screen_flash = true
	if infuse_arena_shockwave:
		ctx.triggers_arena_shockwave = true
	if infuse_gravitational_implosion:
		ctx.triggers_gravitational_implosion = true
	if infuse_cataclysm:
		ctx.is_cataclysm = true
		ctx.triggers_screen_flash = true
		ctx.triggers_arena_shockwave = true
		ctx.triggers_gravitational_implosion = true
	if infuse_singularity:
		ctx.is_singularity = true
		ctx.is_cataclysm = true
		ctx.has_mach_ring = true
		ctx.visual_shader_mode = MeleeAttackContext.VisualShaderMode.VOID_INVERSION
		ctx.is_negative_space = true
		ctx.triggers_screen_flash = true
		ctx.triggers_arena_shockwave = true
		ctx.triggers_gravitational_implosion = true

	# Explicit impact & juice infusion
	ctx.hitstop_duration += add_hitstop_duration
	ctx.screen_shake_intensity *= screen_shake_multiplier
	ctx.camera_impact_snap += add_camera_impact_snap

	if infuse_afterimages:
		ctx.has_afterimages = true

	if override_camera_pullback:
		ctx.camera_velocity_pullback = camera_velocity_pullback
