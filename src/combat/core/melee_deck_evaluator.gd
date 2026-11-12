class_name MeleeDeckEvaluator
extends RefCounted

## Evaluator for style melee technique decks.
## Parses slotted cards from MeleeWeaponDef, resolves modifiers, multicasts,
## and triggers, and compiles MeleeAttackContext packets.
## Strictly enforces card-driven execution speed (duration) and frequency (recovery).

const MeleeWeaponDef = preload("res://src/combat/core/melee_weapon_def.gd")
const TechniqueCard = preload("res://src/combat/core/technique_card.gd")
const MotionCard = preload("res://src/combat/techniques/motions/motion_card.gd")
const ModifierCard = preload("res://src/combat/techniques/modifiers/modifier_card.gd")
const MulticastCard = preload("res://src/combat/techniques/multicast/multicast_card.gd")
const TriggerCard = preload("res://src/combat/techniques/triggers/trigger_card.gd")
const MeleeAttackContext = preload("res://src/combat/core/melee_attack_context.gd")

enum State {
	READY,
	RECOVERING,
	RECHARGING
}

signal state_changed(new_state: State)
signal deck_recharged()
signal card_executed(card_index: int, context: MeleeAttackContext)
signal sequence_reset()

var weapon: MeleeWeaponDef:
	set(value):
		weapon = value
		rebuild_deck()

var _active_deck: Array[TechniqueCard] = []
var _current_index: int = 0
var _state: State = State.READY
var _timer: float = 0.0
var _accumulated_modifiers: Array[ModifierCard] = []
var _pending_triggers: Array[TriggerCard] = []
var _previous_tip_velocity: float = 0.0

func _init(initial_weapon: MeleeWeaponDef = null) -> void:
	if initial_weapon != null:
		weapon = initial_weapon

func rebuild_deck() -> void:
	_current_index = 0
	_state = State.READY
	_timer = 0.0
	_accumulated_modifiers.clear()
	_pending_triggers.clear()
	_previous_tip_velocity = 0.0
	_active_deck.clear()

	if weapon != null:
		for card in weapon.slotted_techniques:
			if card != null:
				_active_deck.append(card)

		if weapon.is_shuffle and _active_deck.size() > 1:
			_active_deck.shuffle()

func update(delta: float) -> void:
	if _state != State.READY:
		_timer -= delta
		if _timer <= 0.0:
			var prev = _state
			_state = State.READY
			_timer = 0.0
			state_changed.emit(_state)
			if prev == State.RECHARGING:
				deck_recharged.emit()

func is_ready() -> bool:
	return _state == State.READY

func get_state() -> State:
	return _state

func get_current_index() -> int:
	return _current_index

func get_total_cards() -> int:
	return _active_deck.size()

func get_cooldown_remaining() -> float:
	return maxf(_timer, 0.0)

## Resets the cast pointer back to the first card in the deck sequence.
## Clears any queued modifiers and pending triggers.
## Preserves recovery/recharge cooldown timers so delays cannot be bypassed.
func reset_sequence() -> void:
	if _current_index != 0 or not _accumulated_modifiers.is_empty() or not _pending_triggers.is_empty():
		_current_index = 0
		_accumulated_modifiers.clear()
		_pending_triggers.clear()
		_previous_tip_velocity = 0.0
		sequence_reset.emit()

## Main evaluation function: casts the next technique(s) in sequence.
## Returns an array of compiled MeleeAttackContexts to be dispatched visually and physically.
func evaluate_attack() -> Array[MeleeAttackContext]:
	if not is_ready():
		return []

	var results: Array[MeleeAttackContext] = []

	# Fallback if weapon has no slotted cards
	if _active_deck.is_empty():
		var fallback_ctx = _create_fallback_context()
		_state = State.RECOVERING
		_timer = fallback_ctx.recovery_delay
		state_changed.emit(_state)
		results.append(fallback_ctx)
		return results

	var multicast_remaining: int = 1
	var multicast_tilt_offset: float = 32.0
	var multicast_reverse: bool = false
	var motion_count: int = 0

	var max_iterations = _active_deck.size() * 2
	var iter_count = 0

	while iter_count < max_iterations:
		iter_count += 1

		# Check if end of deck is reached
		if _current_index >= _active_deck.size():
			_on_deck_cycle_completed()
			break

		var card = _active_deck[_current_index]
		var card_idx = _current_index
		_current_index += 1

		if card is ModifierCard:
			_accumulated_modifiers.append(card)
		elif card is MulticastCard:
			multicast_remaining += (card.simultaneous_count - 1)
			multicast_tilt_offset = card.formation_tilt_offset
			multicast_reverse = card.reverse_second_sweep
		elif card is TriggerCard:
			_pending_triggers.append(card)
		elif card is MotionCard:
			motion_count += 1
			var ctx = MeleeAttackContext.new()

			# 1. Motion Card sets base execution parameters
			card.apply_to_context(ctx)

			# 2. Modifiers alter speed, frequency, scale, mass, momentum
			for mod in _accumulated_modifiers:
				mod.apply_to_context(ctx)

			# 3. Attach pending triggers
			for trig in _pending_triggers:
				trig.apply_to_context(ctx)

			# 4. Resolve inherited momentum from previous attack
			if ctx.momentum_retention > 0.0 and _previous_tip_velocity > 0.0:
				ctx.inherited_velocity = _previous_tip_velocity * ctx.momentum_retention

			# 5. Compute physical kinetic energy (E = 0.5 * m * v^2) and momentum
			var base_mass = weapon.mass if weapon != null else 14.0
			ctx.compute_kinetic_metrics(base_mass)

			# 6. Apply weapon base multipliers and resolve emergent vs legacy damage
			var weapon_dmg_mult = weapon.base_damage_multiplier if weapon != null else 1.0
			var weapon_stam_mult = weapon.stamina_cost_multiplier if weapon != null else 1.0

			if card.base_damage <= 0.0:
				# Pure emergent kinetic energy damage
				ctx.damage = ctx.kinetic_energy * ctx.kinetic_efficiency * ctx.damage_multiplier * weapon_dmg_mult
				ctx.poise_damage = ctx.momentum * 0.15 * ctx.poise_multiplier
				ctx.knockback_force = clampf(ctx.momentum * 0.05 * ctx.poise_multiplier, 2.0, 150.0)
			else:
				# Legacy manual override if test/card explicitly set base_damage
				ctx.damage *= weapon_dmg_mult

			ctx.stamina_cost *= weapon_stam_mult

			# Record exit velocity for combo chaining
			_previous_tip_velocity = ctx.tip_velocity

			# 7. Multicast formation adjustments (e.g. twin slash / cross cut)
			if motion_count > 1:
				ctx.tilt_degrees += multicast_tilt_offset * (1.0 if motion_count % 2 == 0 else -1.0)
				if multicast_reverse and motion_count % 2 == 0:
					ctx.is_reversed_sweep = not ctx.is_reversed_sweep

			results.append(ctx)
			card_executed.emit(card_idx, ctx)

			multicast_remaining -= 1
			if multicast_remaining <= 0:
				_accumulated_modifiers.clear()
				_pending_triggers.clear()
				break

	# Timing state transition governed by card-driven recovery
	if not results.is_empty():
		var max_recovery = 0.0
		for c in results:
			if c.recovery_delay > max_recovery:
				max_recovery = c.recovery_delay

		if _current_index >= _active_deck.size():
			var recharge = weapon.deck_recharge_time if weapon != null else 0.5
			_state = State.RECHARGING
			_timer = maxf(max_recovery, recharge)
			_on_deck_cycle_completed()
		else:
			_state = State.RECOVERING
			_timer = max_recovery

		state_changed.emit(_state)

	return results

func _on_deck_cycle_completed() -> void:
	_current_index = 0
	_accumulated_modifiers.clear()
	_pending_triggers.clear()
	_previous_tip_velocity = 0.0
	if weapon != null and weapon.is_shuffle and _active_deck.size() > 1:
		_active_deck.shuffle()

func _create_fallback_context() -> MeleeAttackContext:
	var ctx = MeleeAttackContext.new()
	ctx.source_card_id = "fallback_swing"
	ctx.execution_duration = 0.24
	ctx.recovery_delay = 0.20
	ctx.outer_radius = 2.45
	ctx.inner_radius = 0.75
	ctx.arc_sweep_degrees = 135.0
	ctx.tilt_degrees = -10.0
	var w_mass = weapon.mass if weapon != null else 14.0
	ctx.compute_kinetic_metrics(w_mass)
	ctx.damage = ctx.kinetic_energy
	ctx.poise_damage = ctx.momentum * 0.15
	return ctx

