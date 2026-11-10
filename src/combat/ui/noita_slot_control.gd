class_name NoitaSlotControl
extends PanelContainer

## Custom slot control enabling native Godot 4 drag-and-drop for Noita technique cards.

var deck_ui: Control
var slot_type: String = ""
var weapon_idx: int = -1
var slot_idx: int = -1
var card: Resource = null

func _get_drag_data(_at_position: Vector2) -> Variant:
	if card == null:
		return null

	var icon_rect = get_node_or_null("CenterContainer/IconRect") as TextureRect
	var preview_root = Control.new()
	preview_root.mouse_filter = MOUSE_FILTER_IGNORE

	var preview = TextureRect.new()
	if icon_rect != null and icon_rect.texture != null:
		preview.texture = icon_rect.texture
	preview.custom_minimum_size = Vector2(34, 34)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.position = -preview.custom_minimum_size * 0.5
	preview_root.add_child(preview)

	set_drag_preview(preview_root)

	return {
		"source": slot_type,
		"weapon_idx": weapon_idx,
		"slot_idx": slot_idx,
		"card": card
	}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and data.has("card") and data["card"] != null):
		return false
	return slot_type == "weapon_socket" or slot_type == "inventory"

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if deck_ui != null and deck_ui.has_method("handle_slot_drop"):
		deck_ui.handle_slot_drop(data, self)

