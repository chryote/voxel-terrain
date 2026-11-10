class_name TriggerCard
extends "res://src/combat/core/technique_card.gd"

## Trigger technique card.
## Carries payload cards that execute conditionally upon collision or timer expiry.

enum TriggerType {
	ON_HIT = 0,
	ON_TIMER = 1
}

@export var trigger_type: int = TriggerType.ON_HIT
@export var timer_delay: float = 0.12
@export var payload_cards: Array = []

func get_card_kind() -> CardKind:
	return CardKind.TRIGGER

func apply_to_context(ctx: MeleeAttackContext) -> void:
	ctx.nested_triggers.append(self)
