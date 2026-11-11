class_name TestWeaponDeckUI
extends "res://tests/framework/test_case.gd"

## Unit tests for WeaponDeckUI, weapon quickbar, accordion, and extensive inventory grid.

const WeaponDeckUI = preload("res://src/combat/ui/weapon_deck_ui.gd")
const FloatingSwordController = preload("res://src/combat/visuals/floating_sword_controller.gd")
const MeleeWeaponDef = preload("res://src/combat/core/melee_weapon_def.gd")
const MotionCard = preload("res://src/combat/techniques/motions/motion_card.gd")
const ModifierCard = preload("res://src/combat/techniques/modifiers/modifier_card.gd")

func test_ui_initialization() -> void:
	var sword_ctrl = FloatingSwordController.new()
	sword_ctrl._ready()

	var ui = WeaponDeckUI.new()
	ui.floating_sword = sword_ctrl
	ui._ready()

	# Normal HUD should be created at top-left
	assert_not_null(ui._hud_container)
	assert_eq(ui._hud_weapon_boxes.size(), 4)
	assert_false(ui._is_inventory_open)
	assert_false(ui._inventory_overlay.visible)

	ui.free()
	sword_ctrl.free()

func test_inventory_open_and_close() -> void:
	var sword_ctrl = FloatingSwordController.new()
	sword_ctrl._ready()

	var ui = WeaponDeckUI.new()
	ui.floating_sword = sword_ctrl
	ui._ready()

	# Open inventory
	ui.open_inventory()
	assert_true(ui._is_inventory_open)
	assert_true(ui._inventory_overlay.visible)
	assert_true(ui._weapon_label.visible)
	assert_true(ui._item_label.visible)
	assert_true(ui._inventory_column.visible)
	assert_true(ui._accordion_scroll.visible)
	assert_eq(ui._weapon_label.get_theme_color("font_color"), Color.WHITE)
	assert_eq(ui._item_label.get_theme_color("font_color"), Color.WHITE)
	assert_eq(ui._inventory_label.get_theme_color("font_color"), Color.WHITE)

	# Close inventory
	ui.close_inventory()
	assert_false(ui._is_inventory_open)
	assert_false(ui._inventory_overlay.visible)
	assert_false(ui._weapon_label.visible)
	assert_false(ui._item_label.visible)
	assert_false(ui._inventory_column.visible)
	assert_false(ui._accordion_scroll.visible)

	ui.free()
	sword_ctrl.free()

func test_grid_and_accordion_slots() -> void:
	var sword_ctrl = FloatingSwordController.new()
	sword_ctrl._ready()

	var ui = WeaponDeckUI.new()
	ui.floating_sword = sword_ctrl
	ui._ready()

	ui.open_inventory()

	# Verify extensive inventory grid slots (4 rows of 8 = 32 slots)
	assert_eq(ui._inventory_boxes.size(), 32)

	# Verify accordion has entries for player weapons
	assert_true(ui._accordion_container.get_child_count() > 0)

	ui.close_inventory()
	ui.free()
	sword_ctrl.free()

func test_card_slotting_and_unslotting_via_controller() -> void:
	var sword_ctrl = FloatingSwordController.new()
	sword_ctrl._ready()

	var initial_inv_count = sword_ctrl.inventory_cards.size()
	var initial_socket_count = sword_ctrl.weapon_def.slotted_techniques.size()

	# Slot a card from inventory into active weapon
	var success = sword_ctrl.slot_inventory_card(0)
	assert_true(success)
	assert_eq(sword_ctrl.weapon_def.slotted_techniques.size(), initial_socket_count + 1)
	assert_eq(sword_ctrl.inventory_cards.size(), initial_inv_count - 1)

	# Unslot the newly added card back into inventory
	var last_idx = sword_ctrl.weapon_def.slotted_techniques.size() - 1
	var unslot_success = sword_ctrl.unslot_card(last_idx)
	assert_true(unslot_success)
	assert_eq(sword_ctrl.weapon_def.slotted_techniques.size(), initial_socket_count)
	assert_eq(sword_ctrl.inventory_cards.size(), initial_inv_count)

	sword_ctrl.free()

func test_weapon_switching_from_quickbar() -> void:
	var sword_ctrl = FloatingSwordController.new()
	sword_ctrl._ready()

	assert_eq(sword_ctrl.active_weapon_index, 0)

	# Switch to weapon 2
	var ok = sword_ctrl.equip_weapon_index(1)
	assert_true(ok)
	assert_eq(sword_ctrl.active_weapon_index, 1)

	# Switch back to weapon 1
	var ok2 = sword_ctrl.equip_weapon_index(0)
	assert_true(ok2)
	assert_eq(sword_ctrl.active_weapon_index, 0)

	sword_ctrl.free()

func test_procedural_icons() -> void:
	var IconFactory = preload("res://src/combat/ui/weapon_icon_factory.gd")
	var w_icon = IconFactory.get_weapon_icon("apprentice_blade")
	assert_not_null(w_icon)
	assert_true(w_icon.get_width() > 0)

	var rapier_icon = IconFactory.get_weapon_icon("flurry_rapier")
	assert_not_null(rapier_icon)

	var c_icon = IconFactory.get_card_icon("motion_horizontal_sweep")
	assert_not_null(c_icon)
	assert_true(c_icon.get_width() > 0)

func test_top_bar_hud_and_item_boxes() -> void:
	var sword_ctrl = FloatingSwordController.new()
	sword_ctrl._ready()

	var ui = WeaponDeckUI.new()
	ui.floating_sword = sword_ctrl
	ui._ready()

	assert_eq(ui._hud_weapon_boxes.size(), 4)
	assert_eq(ui._hud_item_boxes.size(), 4)
	assert_eq(ui._active_marker_labels.size(), 4)
	assert_eq(ui._active_marker_labels[0].text, "")
	assert_eq(ui._active_marker_labels[1].text, "")

	# Switching weapon keeps indicator numbers clear
	sword_ctrl.equip_weapon_index(1)
	assert_eq(ui._active_marker_labels[1].text, "")
	assert_eq(ui._active_marker_labels[0].text, "")

	ui.free()
	sword_ctrl.free()

func test_weapon_icons_auto_loaded_on_start() -> void:
	var sword_ctrl = FloatingSwordController.new()
	sword_ctrl._ready()

	var ui = WeaponDeckUI.new()
	ui.floating_sword = sword_ctrl
	ui._ready()

	# Without opening inventory, weapon icons must be populated immediately on start
	var box0 = ui._hud_weapon_boxes[0]
	var icon_rect0 = box0.get_node_or_null("CenterContainer/IconRect") as TextureRect
	assert_not_null(icon_rect0)
	assert_not_null(icon_rect0.texture)
	assert_true(icon_rect0.visible)

	var box1 = ui._hud_weapon_boxes[1]
	var icon_rect1 = box1.get_node_or_null("CenterContainer/IconRect") as TextureRect
	assert_not_null(icon_rect1)
	assert_not_null(icon_rect1.texture)
	assert_true(icon_rect1.visible)

	# Verify no numbers are displayed on weapon or item slots
	for lbl in ui._active_marker_labels:
		assert_eq(lbl.text, "")
	for w_box in ui._hud_weapon_boxes:
		var slot_lbl = w_box.get_node_or_null("CenterContainer/SlotLabel") as Label
		if slot_lbl != null:
			assert_eq(slot_lbl.text, "")
	for i_box in ui._hud_item_boxes:
		var slot_lbl = i_box.get_node_or_null("CenterContainer/SlotLabel") as Label
		if slot_lbl != null:
			assert_eq(slot_lbl.text, "")

	ui.free()

	# Also verify assigning floating_weapon after _ready() auto updates without pressing I
	var ui2 = WeaponDeckUI.new()
	ui2._ready()
	var box_unloaded = ui2._hud_weapon_boxes[0].get_node_or_null("CenterContainer/IconRect") as TextureRect
	assert_null(box_unloaded.texture)
	ui2.floating_weapon = sword_ctrl
	assert_not_null(box_unloaded.texture)
	assert_true(box_unloaded.visible)

	ui2.free()
	sword_ctrl.free()

func test_drag_and_drop_slot_swap() -> void:
	var sword_ctrl = FloatingSwordController.new()
	sword_ctrl._ready()

	var ui = WeaponDeckUI.new()
	ui.floating_sword = sword_ctrl
	ui._ready()
	ui.open_inventory()

	var initial_card = sword_ctrl.inventory_cards[0]
	assert_not_null(initial_card)

	# Simulate dropping inventory slot 0 onto empty inventory slot 7
	var drop_data = {
		"source": "inventory",
		"weapon_idx": -1,
		"slot_idx": 0,
		"card": initial_card
	}
	var target_box = ui._inventory_boxes[7]
	ui.handle_slot_drop(drop_data, target_box)

	assert_eq(sword_ctrl.inventory_cards[7], initial_card)
	assert_null(sword_ctrl.inventory_cards[0])

	ui.close_inventory()
	ui.free()
	sword_ctrl.free()

func test_quick_slot_and_unslot() -> void:
	var sword_ctrl = FloatingSwordController.new()
	sword_ctrl._ready()

	var initial_inv_card = sword_ctrl.inventory_cards[0]
	assert_not_null(initial_inv_card)

	# Quick-slot card from inventory index 0 into active weapon
	var slot_ok = sword_ctrl.quick_slot_card(0)
	assert_true(slot_ok)
	assert_null(sword_ctrl.inventory_cards[0])

	var found = false
	var found_socket = -1
	for s in range(sword_ctrl.weapon_def.slotted_techniques.size()):
		if sword_ctrl.weapon_def.slotted_techniques[s] == initial_inv_card:
			found = true
			found_socket = s
			break
	assert_true(found)

	# Quick-unslot back to inventory
	var unslot_ok = sword_ctrl.quick_unslot_card(sword_ctrl.active_weapon_index, found_socket)
	assert_true(unslot_ok)
	assert_true(found_socket >= sword_ctrl.weapon_def.slotted_techniques.size() or sword_ctrl.weapon_def.slotted_techniques[found_socket] == null)

	sword_ctrl.free()

func test_long_weapon_slot_wrapping_and_item_col_stability() -> void:
	var sword_ctrl = FloatingSwordController.new()
	sword_ctrl._ready()

	# Create a weapon with 20 slots
	var long_w = MeleeWeaponDef.new()
	long_w.weapon_id = "colossal_blade"
	long_w.display_name = "Colossal Blade"
	long_w.slot_capacity = 20
	sword_ctrl.weapons.append(long_w)

	var ui = WeaponDeckUI.new()
	ui.floating_sword = sword_ctrl
	ui._ready()

	# Record ITEM column position when inventory is closed
	var item_pos_closed = ui._item_col.position.x

	# Open inventory
	ui.open_inventory()

	# ITEM column position must NOT shift when inventory opens
	var item_pos_open = ui._item_col.position.x
	assert_eq(item_pos_open, item_pos_closed)

	# Verify accordion wraps at 10 columns for long weapon
	var acc_panels = ui._accordion_container.get_children()
	assert_eq(acc_panels.size(), 3) # 2 starter weapons + 1 colossal blade

	var long_panel = acc_panels[2]
	var sockets_grid = long_panel.find_child("SocketsGrid", true, false) as GridContainer
	assert_not_null(sockets_grid)
	assert_eq(sockets_grid.columns, 10)
	assert_eq(sockets_grid.get_child_count(), 20)

	ui.close_inventory()
	ui.free()
	sword_ctrl.free()
