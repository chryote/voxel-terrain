class_name MeleeWeaponDef
extends Resource

## Modular Weapon Stance and Data Container (Noita-style Wand equivalent).
## Contains NO hardcoded attacks or frame timings.
## All combat execution (VFX, speed, frequency) is dictated by slotted TechniqueCards.

const TechniqueCard = preload("res://src/combat/core/technique_card.gd")
const SwordMeshBuilder = preload("res://src/combat/visuals/sword_mesh_builder.gd")

@export_group("Identity & Visual Profile")
@export var weapon_id: String = "novice_longsword"
@export var display_name: String = "Novice Longsword"
@export_multiline var description: String = "A balanced steel blade that serves as a modular technique frame."
@export var mesh_builder: Script = SwordMeshBuilder

@export_group("Floating Mount Transform")
@export var float_offset_right: float = 0.68
@export var float_offset_height: float = 0.95
@export var float_offset_forward: float = -0.12
@export var float_tilt_degrees: Vector3 = Vector3(18.0, -12.0, 10.0)

@export_group("Technique Card Sockets")
## Maximum number of technique cards this weapon can hold.
@export var slot_capacity: int = 5

## Cards currently slotted into the weapon sockets.
@export var slotted_techniques: Array = []

## If true, cards in sockets are shuffled randomly on each full cycle rather than sequential.
@export var is_shuffle: bool = false

@export_group("Deck Timing & Multipliers")
## Cooldown after all slotted cards have been cast before resetting to slot 0.
@export var deck_recharge_time: float = 0.55

## Global scaling applied to damage and stamina for this frame.
@export var base_damage_multiplier: float = 1.0
@export var stamina_cost_multiplier: float = 1.0

func get_slotted_card(index: int) -> TechniqueCard:
	if index >= 0 and index < slotted_techniques.size():
		return slotted_techniques[index]
	return null

func get_active_card_count() -> int:
	return slotted_techniques.size()
