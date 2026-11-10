class_name TechniqueCard
extends Resource

## Base Resource class for all melee technique cards (Motions, Modifiers, Multicasts, Triggers).
## Slotted into MeleeWeaponDef to compose dynamic, procedural melee combat.

const MeleeAttackContext = preload("res://src/combat/core/melee_attack_context.gd")

enum CardKind {
	MOTION,
	MODIFIER,
	MULTICAST,
	TRIGGER
}

@export var card_id: String = ""
@export var card_name: String = ""
@export_multiline var description: String = ""
@export var stamina_cost: float = 10.0

func get_card_kind() -> CardKind:
	return CardKind.MOTION

func apply_to_context(_ctx: MeleeAttackContext) -> void:
	pass

