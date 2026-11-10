class_name MulticastCard
extends "res://src/combat/core/technique_card.gd"

## Multicast formation card.
## Resolves 2 or more subsequent slotted motion cards simultaneously in a single attack action.

@export var simultaneous_count: int = 2
@export var formation_tilt_offset: float = 32.0
@export var reverse_second_sweep: bool = true

func get_card_kind() -> CardKind:
	return CardKind.MULTICAST
