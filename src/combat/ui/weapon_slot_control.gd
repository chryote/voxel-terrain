class_name WeaponSlotControl
extends PanelContainer

## Custom slot control metadata holder for weapon icons and technique card slots.
## Dragging and fly-back animations are coordinated by WeaponDeckUI.

var deck_ui: Control
var slot_type: String = ""
var weapon_idx: int = -1
var slot_idx: int = -1
var card: Resource = null
var weapon: Resource = null

func _get_drag_data(_at_position: Vector2) -> Variant:
	# Custom hold-left-click drag and fly-back animation is handled directly by WeaponDeckUI
	return null


