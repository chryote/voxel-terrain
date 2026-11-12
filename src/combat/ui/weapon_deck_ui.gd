class_name WeaponDeckUI
extends Control

## Authentic Weapon & Technique Deck Interface.
## Normal HUD: Top-left compact quickbar displaying weapon icons in small boxes beside item boxes.
## Inventory Mode ("I" Key): Opens full-screen backdrop, reveals bright white text labels
## (WEAPON, ITEM, INVENTORY), places weapon accordion directly under the top-left weapon quick access,
## breaks weapon accordion sockets per 10 slots (rows of 10), and ensures ITEM slots NEVER move away from WEAPON slots.

const FloatingWeaponController = preload("res://src/combat/visuals/floating_weapon_controller.gd")
const MeleeWeaponDef = preload("res://src/combat/core/melee_weapon_def.gd")
const TechniqueCard = preload("res://src/combat/core/technique_card.gd")
const MotionCard = preload("res://src/combat/techniques/motions/motion_card.gd")
const ModifierCard = preload("res://src/combat/techniques/modifiers/modifier_card.gd")
const MulticastCard = preload("res://src/combat/techniques/multicast/multicast_card.gd")
const TriggerCard = preload("res://src/combat/techniques/triggers/trigger_card.gd")
const MeleeDeckEvaluator = preload("res://src/combat/core/melee_deck_evaluator.gd")
const WeaponIconFactory = preload("res://src/combat/ui/weapon_icon_factory.gd")

@export var floating_weapon: FloatingWeaponController:
	set(val):
		if floating_weapon != null:
			if floating_weapon.inventory_updated.is_connected(_on_inventory_data_changed):
				floating_weapon.inventory_updated.disconnect(_on_inventory_data_changed)
			if floating_weapon.weapon_equipped.is_connected(_on_weapon_equipped):
				floating_weapon.weapon_equipped.disconnect(_on_weapon_equipped)
		floating_weapon = val
		if floating_weapon != null:
			if not floating_weapon.inventory_updated.is_connected(_on_inventory_data_changed):
				floating_weapon.inventory_updated.connect(_on_inventory_data_changed)
			if not floating_weapon.weapon_equipped.is_connected(_on_weapon_equipped):
				floating_weapon.weapon_equipped.connect(_on_weapon_equipped)
			_update_ui_state()

## Compatibility alias for code checking floating_sword
var floating_sword: FloatingWeaponController:
	get:
		return floating_weapon
	set(val):
		floating_weapon = val

@export var player_motor: PlayerMotor

# UI Modes
var _is_inventory_open: bool = false
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _initial_ui_synced: bool = false

# Selected card for click-to-swap
var _selected_source: String = "" # "weapon" or "inventory"
var _selected_weapon_idx: int = -1
var _selected_slot_idx: int = -1
var _selected_card: TechniqueCard = null

# Fullscreen Backdrop Overlay
var _inventory_overlay: Control
var _backdrop: ColorRect

# Top Bar Containers (Separated so WEAPON and ITEM never shift)
var _hud_container: HBoxContainer
var _top_bar_container: HBoxContainer
var _weapon_col: VBoxContainer
var _item_col: VBoxContainer
var _item_spacer: Control
var _inv_spacer: Control
var _inventory_column: VBoxContainer

# Component Labels (White text shown in Inventory Mode)
var _weapon_label: Label
var _item_label: Label
var _inventory_label: Label
var _inventory_hint_label: Label

# Slots & Indicators
var _top_indicator_hbox: HBoxContainer
var _top_slots_hbox: HBoxContainer
var _quickbar_hbox: HBoxContainer
var _hud_weapon_boxes: Array[PanelContainer] = []
var _hud_item_boxes: Array[PanelContainer] = []
var _active_marker_labels: Array[Label] = []

# Accordions & Inventory Grid
var _accordion_scroll: ScrollContainer
var _accordion_container: VBoxContainer
var _grid_container: GridContainer
var _inventory_boxes: Array[PanelContainer] = []
var _accordion_weapon_boxes: Array[PanelContainer] = []
var _accordion_socket_boxes: Array[PanelContainer] = []

# Drag-and-Drop & Fly-Back State
const FLY_BACK_DURATION: float = 0.20
var _drag_proxy: PanelContainer
var _drag_proxy_style: StyleBoxFlat
var _drag_proxy_icon: TextureRect
var _is_dragging: bool = false
var _drag_from_mouse_input: bool = false
var _drag_data: Dictionary = {}
var _hovered_drop_box: Control = null
var _hovered_drop_prev_border: Color = COLOR_SLOT_BORDER
var _is_flying_back: bool = false
var _fly_back_elapsed: float = 0.0
var _fly_back_start_pos: Vector2 = Vector2.ZERO
var _fly_back_target_pos: Vector2 = Vector2.ZERO
var _fly_back_origin_box: Control = null

# Constants
const INVENTORY_GRID_COLS: int = 8
const INVENTORY_GRID_ROWS: int = 4 # 32 slots total
const ACCORDION_SLOTS_PER_ROW: int = 10 # Break weapon accordion slots per 10 slots

# Visual Color Palette
const COLOR_BG_BACKDROP: Color = Color(0.04, 0.03, 0.02, 0.85)
const COLOR_ACCORDION_BORDER: Color = Color(0.55, 0.40, 0.22, 0.95)
const COLOR_ACCORDION_ACTIVE_BORDER: Color = Color(0.92, 0.72, 0.28, 1.0)
const COLOR_SLOT_BG: Color = Color(0.11, 0.08, 0.06, 0.95)
const COLOR_SLOT_BORDER: Color = Color(0.32, 0.23, 0.17, 0.95)
const COLOR_SLOT_HOVER: Color = Color(0.98, 0.82, 0.35, 1.0)
const COLOR_SLOT_SELECTED: Color = Color(1.0, 0.85, 0.25, 1.0)
const COLOR_ITEM_BORDER: Color = Color(0.26, 0.19, 0.14, 0.85)

# Rich Tooltip
var _tooltip_panel: PanelContainer
var _tooltip_title: Label
var _tooltip_type: Label
var _tooltip_stats: Label
var _tooltip_desc: Label
var _hovered_card: TechniqueCard = null

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)

	if has_node("TopBarContainer") and has_node("InventoryOverlay") and has_node("AccordionScroll"):
		_bind_scene_nodes()
	else:
		_setup_inventory_overlay()
		_setup_top_bar()
		_setup_accordion_section()
		_setup_tooltip()

	_setup_drag_proxy()

	if player_motor != null and floating_weapon == null and player_motor.floating_weapon != null:
		floating_weapon = player_motor.floating_weapon

	if floating_weapon != null:
		if not floating_weapon.inventory_updated.is_connected(_on_inventory_data_changed):
			floating_weapon.inventory_updated.connect(_on_inventory_data_changed)
		if not floating_weapon.weapon_equipped.is_connected(_on_weapon_equipped):
			floating_weapon.weapon_equipped.connect(_on_weapon_equipped)

	_update_ui_state()

func _bind_scene_nodes() -> void:
	_inventory_overlay = get_node("InventoryOverlay") as Control
	_backdrop = get_node("InventoryOverlay/Backdrop") as ColorRect

	_top_bar_container = get_node("TopBarContainer") as HBoxContainer
	_hud_container = _top_bar_container

	_weapon_col = get_node("TopBarContainer/WeaponColumn") as VBoxContainer
	_top_indicator_hbox = get_node("TopBarContainer/WeaponColumn/TopIndicatorHBox") as HBoxContainer
	_active_marker_labels.clear()
	for child in _top_indicator_hbox.get_children():
		if child is Label:
			child.text = ""
			_active_marker_labels.append(child)

	_weapon_label = get_node("TopBarContainer/WeaponColumn/WeaponLabel") as Label
	_top_slots_hbox = get_node("TopBarContainer/WeaponColumn/TopSlotsHBox") as HBoxContainer
	_quickbar_hbox = _top_slots_hbox
	_hud_weapon_boxes.clear()
	var w_idx = 0
	for child in _top_slots_hbox.get_children():
		if child is PanelContainer:
			_ensure_slot_children_mouse_ignore(child)
			child.set_meta("slot_type", "quickbar")
			child.set_meta("weapon_idx", w_idx)
			child.set_meta("slot_idx", w_idx)
			_setup_drag_and_drop(child, "quickbar", w_idx, w_idx)
			if not child.gui_input.is_connected(_on_hud_box_clicked):
				child.gui_input.connect(_on_hud_box_clicked.bind(w_idx))
			_hud_weapon_boxes.append(child)
			w_idx += 1

	_item_spacer = get_node("TopBarContainer/ItemSpacer") as Control
	_item_col = get_node("TopBarContainer/ItemColumn") as VBoxContainer
	_item_label = get_node("TopBarContainer/ItemColumn/ItemLabel") as Label

	var item_slots_hbox = get_node("TopBarContainer/ItemColumn/ItemSlotsHBox") as HBoxContainer
	_hud_item_boxes.clear()
	var item_idx = 0
	for center_c in item_slots_hbox.get_children():
		for child in center_c.get_children():
			if child is PanelContainer:
				_ensure_slot_children_mouse_ignore(child)
				child.set_meta("slot_type", "item")
				child.set_meta("weapon_idx", -1)
				child.set_meta("slot_idx", item_idx)
				_hud_item_boxes.append(child)
				item_idx += 1

	_inv_spacer = get_node("TopBarContainer/InvSpacer") as Control
	_inventory_column = get_node("TopBarContainer/InventoryColumn") as VBoxContainer
	_inventory_label = get_node("TopBarContainer/InventoryColumn/HeaderHBox/InventoryLabel") as Label
	_inventory_hint_label = get_node("TopBarContainer/InventoryColumn/HeaderHBox/InventoryHint") as Label

	_grid_container = get_node("TopBarContainer/InventoryColumn/GridContainer") as GridContainer
	_inventory_boxes.clear()
	var slot_i = 0
	for child in _grid_container.get_children():
		if child is PanelContainer:
			_ensure_slot_children_mouse_ignore(child)
			if not child.gui_input.is_connected(_on_inventory_slot_clicked):
				child.gui_input.connect(_on_inventory_slot_clicked.bind(slot_i))
			_setup_drag_and_drop(child, "inventory", -1, slot_i)
			_inventory_boxes.append(child)
			slot_i += 1

	_accordion_scroll = get_node("AccordionScroll") as ScrollContainer
	_accordion_container = get_node("AccordionScroll/AccordionContainer") as VBoxContainer

	if has_node("TooltipPanel"):
		_tooltip_panel = get_node("TooltipPanel") as PanelContainer
		_tooltip_title = _tooltip_panel.find_child("TitleLabel", true, false) as Label
		_tooltip_type = _tooltip_panel.find_child("TypeLabel", true, false) as Label
		_tooltip_stats = _tooltip_panel.find_child("StatsLabel", true, false) as Label
		_tooltip_desc = _tooltip_panel.find_child("DescLabel", true, false) as Label
	else:
		_setup_tooltip()

func _ensure_slot_children_mouse_ignore(box: Control) -> void:
	for child in box.get_children():
		if child is Control:
			child.mouse_filter = MOUSE_FILTER_IGNORE
			_ensure_slot_children_mouse_ignore(child)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_backdrop_size()

func _sync_backdrop_size() -> void:
	if _backdrop != null and is_inside_tree():
		var vp_size = get_viewport_rect().size
		_backdrop.size = vp_size
		_backdrop.custom_minimum_size = vp_size

## -----------------------------------------------------------------------------
## 1. FULLSCREEN BACKDROP OVERLAY
## -----------------------------------------------------------------------------
func _setup_inventory_overlay() -> void:
	_inventory_overlay = Control.new()
	_inventory_overlay.name = "InventoryOverlay"
	_inventory_overlay.mouse_filter = MOUSE_FILTER_IGNORE
	_inventory_overlay.visible = false
	add_child(_inventory_overlay)

	_inventory_overlay.anchor_left = 0.0
	_inventory_overlay.anchor_top = 0.0
	_inventory_overlay.anchor_right = 1.0
	_inventory_overlay.anchor_bottom = 1.0
	_inventory_overlay.offset_left = 0.0
	_inventory_overlay.offset_top = 0.0
	_inventory_overlay.offset_right = 0.0
	_inventory_overlay.offset_bottom = 0.0
	_inventory_overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_inventory_overlay.grow_vertical = Control.GROW_DIRECTION_BOTH

	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.color = COLOR_BG_BACKDROP
	_backdrop.mouse_filter = MOUSE_FILTER_IGNORE
	_inventory_overlay.add_child(_backdrop)

	_backdrop.anchor_left = 0.0
	_backdrop.anchor_top = 0.0
	_backdrop.anchor_right = 1.0
	_backdrop.anchor_bottom = 1.0
	_backdrop.offset_left = 0.0
	_backdrop.offset_top = 0.0
	_backdrop.offset_right = 0.0
	_backdrop.offset_bottom = 0.0
	_backdrop.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_backdrop.grow_vertical = Control.GROW_DIRECTION_BOTH

## -----------------------------------------------------------------------------
## 2. TOP BAR SETUP (WEAPON + Fixed Gap + ITEM + Inventory Grid)
## -----------------------------------------------------------------------------
func _setup_top_bar() -> void:
	_top_bar_container = HBoxContainer.new()
	_top_bar_container.name = "TopBarContainer"
	_top_bar_container.position = Vector2(16, 10)
	_top_bar_container.mouse_filter = MOUSE_FILTER_IGNORE
	_top_bar_container.add_theme_constant_override("separation", 0)
	add_child(_top_bar_container)

	_hud_container = _top_bar_container # Compatibility alias

	# -------------------------------------------------------------------------
	# 2A. WEAPON Quick Access Column (Fixed width: 4 * 34 + 3 * 4 = 148px)
	# -------------------------------------------------------------------------
	_weapon_col = VBoxContainer.new()
	_weapon_col.name = "WeaponColumn"
	_weapon_col.mouse_filter = MOUSE_FILTER_IGNORE
	_weapon_col.add_theme_constant_override("separation", 3)
	_top_bar_container.add_child(_weapon_col)

	# White Label: "WEAPON" (displayed directly above quick access slots when inventory is open)
	_weapon_label = Label.new()
	_weapon_label.name = "WeaponLabel"
	_weapon_label.text = "WEAPON"
	_weapon_label.add_theme_font_size_override("font_size", 11)
	_weapon_label.add_theme_color_override("font_color", Color.WHITE)
	_weapon_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_weapon_label.add_theme_constant_override("shadow_offset_x", 1)
	_weapon_label.add_theme_constant_override("shadow_offset_y", 1)
	_weapon_label.visible = false
	_weapon_col.add_child(_weapon_label)

	# Top indicator spacer/container (no numbers shown)
	_top_indicator_hbox = HBoxContainer.new()
	_top_indicator_hbox.name = "TopIndicatorHBox"
	_top_indicator_hbox.mouse_filter = MOUSE_FILTER_IGNORE
	_top_indicator_hbox.add_theme_constant_override("separation", 4)
	_weapon_col.add_child(_top_indicator_hbox)

	for i in range(4):
		var num_lbl = Label.new()
		num_lbl.custom_minimum_size = Vector2(34, 13)
		num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num_lbl.add_theme_font_size_override("font_size", 10)
		num_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65, 0.95))
		num_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		num_lbl.add_theme_constant_override("shadow_offset_x", 1)
		num_lbl.add_theme_constant_override("shadow_offset_y", 1)
		num_lbl.text = ""
		_top_indicator_hbox.add_child(num_lbl)
		_active_marker_labels.append(num_lbl)

	# 4 Weapon Slots Row (34x34)
	_top_slots_hbox = HBoxContainer.new()
	_top_slots_hbox.name = "TopSlotsHBox"
	_top_slots_hbox.mouse_filter = MOUSE_FILTER_IGNORE
	_top_slots_hbox.add_theme_constant_override("separation", 4)
	_weapon_col.add_child(_top_slots_hbox)

	_quickbar_hbox = _top_slots_hbox

	for i in range(4):
		var box = _create_slot_box(Vector2(34, 34), "quickbar", i, i)
		box.name = "WeaponSlot_%d" % i
		_setup_drag_and_drop(box, "quickbar", i, i)
		box.gui_input.connect(_on_hud_box_clicked.bind(i))
		_top_slots_hbox.add_child(box)
		_hud_weapon_boxes.append(box)

	# -------------------------------------------------------------------------
	# 2B. Fixed Spacer between WEAPON and ITEM (10px - NEVER CHANGES!)
	# -------------------------------------------------------------------------
	_item_spacer = Control.new()
	_item_spacer.name = "ItemSpacer"
	_item_spacer.custom_minimum_size = Vector2(10, 0)
	_item_spacer.mouse_filter = MOUSE_FILTER_IGNORE
	_top_bar_container.add_child(_item_spacer)

	# -------------------------------------------------------------------------
	# 2C. ITEM Quick Access Column (Fixed width: 4 * 28 = 112px, NEVER SHIFTS!)
	# -------------------------------------------------------------------------
	_item_col = VBoxContainer.new()
	_item_col.name = "ItemColumn"
	_item_col.mouse_filter = MOUSE_FILTER_IGNORE
	_item_col.add_theme_constant_override("separation", 3)
	_top_bar_container.add_child(_item_col)

	# White Label: "ITEM" (aligned with WEAPON label)
	_item_label = Label.new()
	_item_label.name = "ItemLabel"
	_item_label.text = "ITEM"
	_item_label.add_theme_font_size_override("font_size", 11)
	_item_label.add_theme_color_override("font_color", Color.WHITE)
	_item_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_item_label.add_theme_constant_override("shadow_offset_x", 1)
	_item_label.add_theme_constant_override("shadow_offset_y", 1)
	_item_label.visible = false
	_item_col.add_child(_item_label)

	var ind_spacer = Control.new()
	ind_spacer.name = "IndSpacer"
	ind_spacer.custom_minimum_size = Vector2(0, 13)
	ind_spacer.mouse_filter = MOUSE_FILTER_IGNORE
	_item_col.add_child(ind_spacer)

	# 4 Small Item Boxes (26x26)
	var item_slots_hbox = HBoxContainer.new()
	item_slots_hbox.name = "ItemSlotsHBox"
	item_slots_hbox.mouse_filter = MOUSE_FILTER_IGNORE
	item_slots_hbox.add_theme_constant_override("separation", 4)
	_item_col.add_child(item_slots_hbox)

	for i in range(4):
		var item_center = CenterContainer.new()
		item_center.name = "ItemCenter_%d" % i
		item_center.custom_minimum_size = Vector2(28, 34)
		item_center.mouse_filter = MOUSE_FILTER_IGNORE

		var item_box = _create_slot_box(Vector2(26, 26), "item", -1, i)
		item_box.name = "ItemSlot_%d" % i
		var style = item_box.get_theme_stylebox("panel") as StyleBoxFlat
		if style != null:
			style.border_color = COLOR_ITEM_BORDER
			style.bg_color = Color(0.09, 0.07, 0.05, 0.85)

		item_center.add_child(item_box)
		item_slots_hbox.add_child(item_center)
		_hud_item_boxes.append(item_box)

	# -------------------------------------------------------------------------
	# 2D. Spacer between ITEM and INVENTORY Grid (Leaves room for 10-slot accordion)
	# -------------------------------------------------------------------------
	_inv_spacer = Control.new()
	_inv_spacer.name = "InvSpacer"
	_inv_spacer.custom_minimum_size = Vector2(94, 0)
	_inv_spacer.mouse_filter = MOUSE_FILTER_IGNORE
	_inv_spacer.visible = false
	_top_bar_container.add_child(_inv_spacer)

	# -------------------------------------------------------------------------
	# 2E. INVENTORY Grid Column (Aligned on top row beside ITEM)
	# -------------------------------------------------------------------------
	_inventory_column = VBoxContainer.new()
	_inventory_column.name = "InventoryColumn"
	_inventory_column.mouse_filter = MOUSE_FILTER_IGNORE
	_inventory_column.add_theme_constant_override("separation", 3)
	_inventory_column.visible = false
	_top_bar_container.add_child(_inventory_column)

	# White Label: "INVENTORY" + Sub-hint (aligned with WEAPON and ITEM labels)
	var header_hbox = HBoxContainer.new()
	header_hbox.name = "HeaderHBox"
	header_hbox.mouse_filter = MOUSE_FILTER_IGNORE
	header_hbox.add_theme_constant_override("separation", 6)
	_inventory_column.add_child(header_hbox)

	_inventory_label = Label.new()
	_inventory_label.name = "InventoryLabel"
	_inventory_label.text = "INVENTORY"
	_inventory_label.add_theme_font_size_override("font_size", 11)
	_inventory_label.add_theme_color_override("font_color", Color.WHITE)
	_inventory_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_inventory_label.add_theme_constant_override("shadow_offset_x", 1)
	_inventory_label.add_theme_constant_override("shadow_offset_y", 1)
	header_hbox.add_child(_inventory_label)

	_inventory_hint_label = Label.new()
	_inventory_hint_label.name = "InventoryHint"
	_inventory_hint_label.text = "(32 SLOTS)  • Click/Drag to Swap • Right-Click Quick Slot"
	_inventory_hint_label.add_theme_font_size_override("font_size", 9)
	_inventory_hint_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.8))
	header_hbox.add_child(_inventory_hint_label)

	var inv_ind_spacer = Control.new()
	inv_ind_spacer.name = "InvIndSpacer"
	inv_ind_spacer.custom_minimum_size = Vector2(0, 13)
	inv_ind_spacer.mouse_filter = MOUSE_FILTER_IGNORE
	_inventory_column.add_child(inv_ind_spacer)

	# 32-Slot Grid (8 columns x 4 rows)
	_grid_container = GridContainer.new()
	_grid_container.name = "GridContainer"
	_grid_container.columns = INVENTORY_GRID_COLS
	_grid_container.add_theme_constant_override("h_separation", 4)
	_grid_container.add_theme_constant_override("v_separation", 4)
	_grid_container.mouse_filter = MOUSE_FILTER_IGNORE
	_inventory_column.add_child(_grid_container)

	var total_slots = INVENTORY_GRID_COLS * INVENTORY_GRID_ROWS
	for i in range(total_slots):
		var slot_box = _create_slot_box(Vector2(34, 34), "inventory", -1, i)
		slot_box.name = "InvSlot_%d" % i
		slot_box.gui_input.connect(_on_inventory_slot_clicked.bind(i))
		_setup_drag_and_drop(slot_box, "inventory", -1, i)
		_grid_container.add_child(slot_box)
		_inventory_boxes.append(slot_box)

## -----------------------------------------------------------------------------
## 3. WEAPON ACCORDION SECTION (Directly below weapon slots with clean margin-top)
## -----------------------------------------------------------------------------
func _setup_accordion_section() -> void:
	_accordion_scroll = ScrollContainer.new()
	_accordion_scroll.name = "AccordionScroll"
	_accordion_scroll.position = Vector2(16, 94)
	_accordion_scroll.custom_minimum_size = Vector2(360, 420)
	_accordion_scroll.mouse_filter = MOUSE_FILTER_PASS
	_accordion_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_accordion_scroll.visible = false
	add_child(_accordion_scroll)

	_accordion_container = VBoxContainer.new()
	_accordion_container.name = "AccordionContainer"
	_accordion_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_accordion_container.add_theme_constant_override("separation", 8)
	_accordion_container.mouse_filter = MOUSE_FILTER_IGNORE
	_accordion_scroll.add_child(_accordion_container)

## -----------------------------------------------------------------------------
## 4. TOOLTIP SETUP
## -----------------------------------------------------------------------------
func _setup_tooltip() -> void:
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.mouse_filter = MOUSE_FILTER_IGNORE
	_tooltip_panel.visible = false
	_tooltip_panel.top_level = true

	_tooltip_panel.name = "TooltipPanel"

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.05, 0.96)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.85, 0.65, 0.25, 0.95)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	_tooltip_panel.add_theme_stylebox_override("panel", style)

	var m = MarginContainer.new()
	m.name = "MarginContainer"
	m.add_theme_constant_override("margin_left", 10)
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_right", 10)
	m.add_theme_constant_override("margin_bottom", 8)
	m.mouse_filter = MOUSE_FILTER_IGNORE
	_tooltip_panel.add_child(m)

	var vb = VBoxContainer.new()
	vb.name = "VBoxContainer"
	vb.mouse_filter = MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 3)
	m.add_child(vb)

	_tooltip_title = Label.new()
	_tooltip_title.name = "TitleLabel"
	_tooltip_title.add_theme_font_size_override("font_size", 12)
	vb.add_child(_tooltip_title)

	_tooltip_type = Label.new()
	_tooltip_type.name = "TypeLabel"
	_tooltip_type.add_theme_font_size_override("font_size", 10)
	vb.add_child(_tooltip_type)

	_tooltip_stats = Label.new()
	_tooltip_stats.name = "StatsLabel"
	_tooltip_stats.add_theme_font_size_override("font_size", 11)
	_tooltip_stats.add_theme_color_override("font_color", Color(0.88, 0.92, 0.95))
	vb.add_child(_tooltip_stats)

	_tooltip_desc = Label.new()
	_tooltip_desc.name = "DescLabel"
	_tooltip_desc.add_theme_font_size_override("font_size", 10)
	_tooltip_desc.add_theme_color_override("font_color", Color(0.72, 0.68, 0.62))
	_tooltip_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_desc.custom_minimum_size = Vector2(230, 0)
	vb.add_child(_tooltip_desc)

	add_child(_tooltip_panel)

func _setup_drag_proxy() -> void:
	if _drag_proxy != null:
		return

	_drag_proxy = PanelContainer.new()
	_drag_proxy.name = "DragProxy"
	_drag_proxy.mouse_filter = MOUSE_FILTER_IGNORE
	_drag_proxy.visible = false
	_drag_proxy.top_level = true
	_drag_proxy.z_index = 120
	_drag_proxy.custom_minimum_size = Vector2(34, 34)
	_drag_proxy.size = Vector2(34, 34)

	_drag_proxy_style = StyleBoxFlat.new()
	_drag_proxy_style.bg_color = COLOR_SLOT_BG
	_drag_proxy_style.border_width_left = 2
	_drag_proxy_style.border_width_top = 2
	_drag_proxy_style.border_width_right = 2
	_drag_proxy_style.border_width_bottom = 2
	_drag_proxy_style.border_color = COLOR_SLOT_SELECTED
	_drag_proxy_style.corner_radius_top_left = 2
	_drag_proxy_style.corner_radius_top_right = 2
	_drag_proxy_style.corner_radius_bottom_left = 2
	_drag_proxy_style.corner_radius_bottom_right = 2
	_drag_proxy.add_theme_stylebox_override("panel", _drag_proxy_style)

	var center = CenterContainer.new()
	center.name = "CenterContainer"
	center.mouse_filter = MOUSE_FILTER_IGNORE
	center.set_anchors_preset(PRESET_FULL_RECT)
	_drag_proxy.add_child(center)

	_drag_proxy_icon = TextureRect.new()
	_drag_proxy_icon.name = "IconRect"
	_drag_proxy_icon.mouse_filter = MOUSE_FILTER_IGNORE
	_drag_proxy_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_drag_proxy_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_drag_proxy_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_drag_proxy_icon.custom_minimum_size = Vector2(30, 30)
	center.add_child(_drag_proxy_icon)

	add_child(_drag_proxy)

## -----------------------------------------------------------------------------
## HELPER: CREATE SLOT BOX
## -----------------------------------------------------------------------------
func _create_slot_box(box_size: Vector2, slot_type: String, weapon_idx: int, slot_idx: int) -> PanelContainer:
	var box = PanelContainer.new()
	box.custom_minimum_size = box_size
	box.size = box_size
	box.mouse_filter = MOUSE_FILTER_STOP

	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_SLOT_BG
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = COLOR_SLOT_BORDER
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	box.add_theme_stylebox_override("panel", style)

	var center = CenterContainer.new()
	center.name = "CenterContainer"
	center.mouse_filter = MOUSE_FILTER_IGNORE
	center.set_anchors_preset(PRESET_FULL_RECT)
	box.add_child(center)

	var icon_rect = TextureRect.new()
	icon_rect.name = "IconRect"
	icon_rect.mouse_filter = MOUSE_FILTER_IGNORE
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = box_size - Vector2(4, 4)
	center.add_child(icon_rect)

	var label = Label.new()
	label.name = "SlotLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.mouse_filter = MOUSE_FILTER_IGNORE
	center.add_child(label)

	var cd_rect = ColorRect.new()
	cd_rect.name = "CooldownOverlay"
	cd_rect.color = Color(0.85, 0.2, 0.1, 0.0)
	cd_rect.mouse_filter = MOUSE_FILTER_IGNORE
	cd_rect.set_anchors_preset(PRESET_FULL_RECT)
	box.add_child(cd_rect)

	box.set_meta("slot_type", slot_type)
	box.set_meta("weapon_idx", weapon_idx)
	box.set_meta("slot_idx", slot_idx)

	return box

## -----------------------------------------------------------------------------
## DRAG AND DROP & FLY-BACK SYSTEM
## -----------------------------------------------------------------------------
func _setup_drag_and_drop(box: PanelContainer, slot_type: String, weapon_idx: int, slot_idx: int) -> void:
	box.set_script(load("res://src/combat/ui/weapon_slot_control.gd"))
	box.set("deck_ui", self)
	box.set("slot_type", slot_type)
	box.set("weapon_idx", weapon_idx)
	box.set("slot_idx", slot_idx)
	box.set_meta("slot_type", slot_type)
	box.set_meta("weapon_idx", weapon_idx)
	box.set_meta("slot_idx", slot_idx)

func _get_box_slot_type(box: Control) -> String:
	if box == null or not is_instance_valid(box):
		return ""
	if "slot_type" in box and str(box.get("slot_type")) != "":
		return str(box.get("slot_type"))
	if box.has_meta("slot_type"):
		return str(box.get_meta("slot_type"))
	return ""

func _get_box_weapon_idx(box: Control) -> int:
	if box == null or not is_instance_valid(box):
		return -1
	if "weapon_idx" in box and int(box.get("weapon_idx")) >= 0:
		return int(box.get("weapon_idx"))
	if box.has_meta("weapon_idx") and int(box.get_meta("weapon_idx")) >= 0:
		return int(box.get_meta("weapon_idx"))
	return -1

func _get_box_slot_idx(box: Control) -> int:
	if box == null or not is_instance_valid(box):
		return -1
	if "slot_idx" in box and int(box.get("slot_idx")) >= 0:
		return int(box.get("slot_idx"))
	if box.has_meta("slot_idx") and int(box.get_meta("slot_idx")) >= 0:
		return int(box.get_meta("slot_idx"))
	return -1

func _can_drag_from_box(box: Control) -> bool:
	if floating_weapon == null or box == null or not is_instance_valid(box):
		return false
	var stype = _get_box_slot_type(box)
	if stype == "quickbar" or stype == "accordion_weapon":
		var w_idx = _get_box_weapon_idx(box)
		if w_idx < 0:
			w_idx = _get_box_slot_idx(box)
		return w_idx >= 0 and w_idx < floating_weapon.weapons.size() and floating_weapon.weapons[w_idx] != null
	elif stype == "inventory":
		var s_idx = _get_box_slot_idx(box)
		return s_idx >= 0 and s_idx < floating_weapon.inventory_cards.size() and floating_weapon.inventory_cards[s_idx] != null
	elif stype == "weapon_socket" or stype == "weapon":
		var w_idx = _get_box_weapon_idx(box)
		var s_idx = _get_box_slot_idx(box)
		if w_idx >= 0 and w_idx < floating_weapon.weapons.size() and floating_weapon.weapons[w_idx] != null:
			var w = floating_weapon.weapons[w_idx]
			return s_idx >= 0 and s_idx < w.slotted_techniques.size() and w.slotted_techniques[s_idx] != null
	return false

func is_valid_drop_target(data: Dictionary, target_box: Control) -> bool:
	if target_box == null or not is_instance_valid(target_box) or data.is_empty():
		return false

	var tgt_type = _get_box_slot_type(target_box)
	var item_type = str(data.get("item_type", ""))
	if item_type == "":
		if data.has("weapon") and data.get("weapon") != null:
			item_type = "weapon"
		elif data.has("card") and data.get("card") != null:
			item_type = "card"

	if item_type == "weapon":
		return tgt_type == "quickbar" or tgt_type == "accordion_weapon"
	elif item_type == "card":
		return tgt_type == "inventory" or tgt_type == "weapon_socket" or tgt_type == "weapon"

	return false

func start_slot_drag(box: Control, cursor_pos: Vector2 = Vector2.ZERO) -> bool:
	if not _is_inventory_open or floating_weapon == null or box == null or not is_instance_valid(box):
		return false
	if _is_flying_back:
		_complete_fly_back()
	if _is_dragging:
		return false
	if not _can_drag_from_box(box):
		return false

	var stype = _get_box_slot_type(box)
	var w_idx = _get_box_weapon_idx(box)
	var s_idx = _get_box_slot_idx(box)

	var box_rect = box.get_global_rect()
	var box_size = box_rect.size if box_rect.size.x > 0 else box.custom_minimum_size
	if box_size.x <= 0:
		box_size = Vector2(34, 34)
	var origin_center = box_rect.position + box_size * 0.5
	var start_cursor = cursor_pos if cursor_pos != Vector2.ZERO else origin_center

	if stype == "quickbar" or stype == "accordion_weapon":
		var resolved_w_idx = w_idx if w_idx >= 0 else s_idx
		var w = floating_weapon.weapons[resolved_w_idx]
		var icon_tex = w.icon if (w != null and "icon" in w and w.icon != null) else WeaponIconFactory.get_weapon_icon(w.weapon_id)

		_drag_data = {
			"item_type": "weapon",
			"source": stype,
			"weapon_idx": resolved_w_idx,
			"slot_idx": resolved_w_idx,
			"weapon": w,
			"origin_box": box,
			"origin_global_pos": box_rect.position,
			"origin_size": box_size,
			"start_mouse_pos": start_cursor,
			"has_moved": false
		}

		if _drag_proxy != null:
			_drag_proxy.custom_minimum_size = box_size
			_drag_proxy.size = box_size
			_drag_proxy_icon.texture = icon_tex
			_drag_proxy_style.bg_color = Color(0.18, 0.14, 0.08, 0.96)
			_drag_proxy_style.border_color = COLOR_ACCORDION_ACTIVE_BORDER
	else:
		var card: TechniqueCard = null
		if stype == "inventory":
			card = floating_weapon.inventory_cards[s_idx] as TechniqueCard
		else:
			card = floating_weapon.weapons[w_idx].slotted_techniques[s_idx] as TechniqueCard

		var card_tex = WeaponIconFactory.get_card_icon(card.card_id, card.get_class())
		_drag_data = {
			"item_type": "card",
			"source": stype,
			"weapon_idx": w_idx,
			"slot_idx": s_idx,
			"card": card,
			"origin_box": box,
			"origin_global_pos": box_rect.position,
			"origin_size": box_size,
			"start_mouse_pos": start_cursor,
			"has_moved": false
		}

		if _drag_proxy != null:
			_drag_proxy.custom_minimum_size = box_size
			_drag_proxy.size = box_size
			_drag_proxy_icon.texture = card_tex
			_apply_card_slot_style(_drag_proxy_style, card)

	_is_dragging = true
	_hide_tooltip()

	var origin_icon = box.get_node_or_null("CenterContainer/IconRect") as TextureRect
	if origin_icon != null:
		origin_icon.visible = false

	if _drag_proxy != null:
		_drag_proxy.global_position = start_cursor - _drag_proxy.size * 0.5
		_drag_proxy.visible = true

	return true

func update_slot_drag(cursor_pos: Vector2) -> void:
	if not _is_dragging:
		return

	var start_pos: Vector2 = _drag_data.get("start_mouse_pos", cursor_pos)
	if cursor_pos.distance_to(start_pos) > 3.0:
		_drag_data["has_moved"] = true

	if _drag_proxy != null:
		_drag_proxy.global_position = cursor_pos - _drag_proxy.size * 0.5

	var hovered = _get_slot_at_position(cursor_pos)
	if hovered != null and is_valid_drop_target(_drag_data, hovered):
		_set_hovered_drop_box(hovered)
	else:
		_set_hovered_drop_box(null)

func end_slot_drag(cursor_pos: Vector2) -> bool:
	if not _is_dragging:
		return false

	var target_box = _get_slot_at_position(cursor_pos)
	return end_slot_drag_on_target(target_box, cursor_pos)

func end_slot_drag_on_target(target_box: Control, cursor_pos: Vector2 = Vector2.ZERO) -> bool:
	if not _is_dragging:
		return false

	if cursor_pos != Vector2.ZERO and _drag_proxy != null:
		var start_pos: Vector2 = _drag_data.get("start_mouse_pos", cursor_pos)
		if cursor_pos.distance_to(start_pos) > 3.0:
			_drag_data["has_moved"] = true
		_drag_proxy.global_position = cursor_pos - _drag_proxy.size * 0.5

	_set_hovered_drop_box(null)
	_drag_from_mouse_input = false

	var origin_box: Control = _drag_data.get("origin_box", null)
	var has_moved: bool = _drag_data.get("has_moved", false)

	if target_box != null and is_valid_drop_target(_drag_data, target_box):
		_is_dragging = false
		if _drag_proxy != null:
			_drag_proxy.visible = false
		_restore_box_icon_visibility(origin_box)

		# Quick click without dragging onto the same origin slot
		if target_box == origin_box and not has_moved:
			var item_type = str(_drag_data.get("item_type", ""))
			if item_type == "weapon":
				var w_idx = int(_drag_data.get("weapon_idx", -1))
				if floating_weapon != null and w_idx >= 0:
					floating_weapon.equip_weapon_index(w_idx)
					_update_ui_state()
			else:
				_handle_card_slot_click(origin_box)
			_drag_data.clear()
			return true

		var drop_payload = _drag_data.duplicate()
		_drag_data.clear()
		handle_slot_drop(drop_payload, target_box)
		return true

	# Invalid drop target (or dropped outside any valid slot) -> fly back toward origin slot!
	_fly_back_to_origin()
	return false

func _fly_back_to_origin() -> void:
	_is_dragging = false
	_is_flying_back = true
	_fly_back_elapsed = 0.0
	_fly_back_origin_box = _drag_data.get("origin_box", null)
	_fly_back_start_pos = _drag_proxy.global_position if _drag_proxy != null else _drag_data.get("origin_global_pos", Vector2.ZERO)
	_fly_back_target_pos = _get_origin_target_pos()

	if _drag_proxy != null:
		_drag_proxy.visible = true

func _get_origin_target_pos() -> Vector2:
	if _fly_back_origin_box != null and is_instance_valid(_fly_back_origin_box):
		var rect = _fly_back_origin_box.get_global_rect()
		var proxy_size = _drag_proxy.size if _drag_proxy != null else rect.size
		return rect.position + (rect.size - proxy_size) * 0.5
	return _drag_data.get("origin_global_pos", Vector2.ZERO)

func _complete_fly_back() -> void:
	_is_flying_back = false
	_fly_back_elapsed = 0.0
	if _drag_proxy != null:
		_drag_proxy.global_position = _fly_back_target_pos
		_drag_proxy.visible = false
	_restore_box_icon_visibility(_fly_back_origin_box)
	_fly_back_origin_box = null
	_drag_data.clear()
	_update_ui_state()

func _cancel_drag_and_restore() -> void:
	_set_hovered_drop_box(null)
	_is_dragging = false
	_drag_from_mouse_input = false
	_is_flying_back = false
	_fly_back_elapsed = 0.0
	if _drag_proxy != null:
		_drag_proxy.visible = false
	var origin_box: Control = _drag_data.get("origin_box", _fly_back_origin_box)
	_restore_box_icon_visibility(origin_box)
	_fly_back_origin_box = null
	_drag_data.clear()

func _restore_box_icon_visibility(box: Control) -> void:
	if box != null and is_instance_valid(box):
		var icon_rect = box.get_node_or_null("CenterContainer/IconRect") as TextureRect
		if icon_rect != null and icon_rect.texture != null:
			icon_rect.visible = true

func _set_hovered_drop_box(box: Control) -> void:
	if _hovered_drop_box == box:
		return
	if _hovered_drop_box != null and is_instance_valid(_hovered_drop_box):
		var prev_style = _hovered_drop_box.get_theme_stylebox("panel") as StyleBoxFlat
		if prev_style != null:
			prev_style.border_color = _hovered_drop_prev_border
	_hovered_drop_box = box
	if _hovered_drop_box != null and is_instance_valid(_hovered_drop_box):
		var new_style = _hovered_drop_box.get_theme_stylebox("panel") as StyleBoxFlat
		if new_style != null:
			_hovered_drop_prev_border = new_style.border_color
			new_style.border_color = COLOR_SLOT_HOVER

func _get_slot_at_position(global_pos: Vector2) -> Control:
	for box in _hud_weapon_boxes:
		if box != null and is_instance_valid(box) and box.visible and box.get_global_rect().has_point(global_pos):
			return box

	for box in _hud_item_boxes:
		if box != null and is_instance_valid(box) and box.visible and box.get_global_rect().has_point(global_pos):
			return box

	if _inventory_column != null and _inventory_column.visible:
		for box in _inventory_boxes:
			if box != null and is_instance_valid(box) and box.visible and box.get_global_rect().has_point(global_pos):
				return box

	if _accordion_scroll != null and _accordion_scroll.visible:
		var scroll_rect = _accordion_scroll.get_global_rect()
		var check_inside_scroll = scroll_rect.size.x <= 0 or scroll_rect.has_point(global_pos)
		if check_inside_scroll:
			for box in _accordion_weapon_boxes:
				if box != null and is_instance_valid(box) and box.visible and box.get_global_rect().has_point(global_pos):
					return box
			for box in _accordion_socket_boxes:
				if box != null and is_instance_valid(box) and box.visible and box.get_global_rect().has_point(global_pos):
					return box

	return null

func is_dragging() -> bool:
	return _is_dragging

func is_flying_back() -> bool:
	return _is_flying_back

func get_drag_proxy() -> Control:
	return _drag_proxy

func handle_slot_drop(data: Dictionary, target_box: Control) -> void:
	if floating_weapon == null or target_box == null or not (data is Dictionary):
		return

	var src_type = str(data.get("source", ""))
	var src_w = int(data.get("weapon_idx", -1))
	var src_s = int(data.get("slot_idx", -1))

	var tgt_type = _get_box_slot_type(target_box)
	var tgt_w = _get_box_weapon_idx(target_box)
	var tgt_s = _get_box_slot_idx(target_box)

	var item_type = str(data.get("item_type", ""))
	if item_type == "":
		if data.has("weapon") and data.get("weapon") != null:
			item_type = "weapon"
		elif data.has("card") and data.get("card") != null:
			item_type = "card"

	if item_type == "weapon" or src_type in ["quickbar", "accordion_weapon"]:
		if tgt_type in ["quickbar", "accordion_weapon"]:
			var resolved_src_w = src_w if src_w >= 0 else src_s
			var resolved_tgt_w = tgt_w if tgt_w >= 0 else tgt_s
			floating_weapon.swap_weapons(resolved_src_w, resolved_tgt_w)
			_clear_selection()
			_update_ui_state()
		return

	if not data.has("card"):
		return

	var src_is_weapon_socket = src_type in ["weapon", "weapon_socket"]
	var tgt_is_weapon_socket = tgt_type in ["weapon", "weapon_socket"]

	if src_type == "inventory" and tgt_type == "inventory":
		floating_weapon.swap_inventory_slots(src_s, tgt_s)
	elif src_is_weapon_socket and tgt_type == "inventory":
		floating_weapon.swap_weapon_and_inventory(src_w, src_s, tgt_s)
	elif src_type == "inventory" and tgt_is_weapon_socket:
		floating_weapon.swap_weapon_and_inventory(tgt_w, tgt_s, src_s)
	elif src_is_weapon_socket and tgt_is_weapon_socket:
		if src_w == tgt_w and src_w == floating_weapon.active_weapon_index:
			floating_weapon.swap_weapon_sockets(src_s, tgt_s)
		else:
			floating_weapon.swap_between_weapons(src_w, src_s, tgt_w, tgt_s)

	_clear_selection()
	_rebuild_inventory_ui()

## -----------------------------------------------------------------------------
## INPUT & INVENTORY TOGGLING
## -----------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if not _is_inventory_open:
		return

	if event is InputEventMouseMotion and _is_dragging:
		update_slot_drag(get_global_mouse_position())
		_mark_handled()
		return

	if event is InputEventMouseButton:
		var mouse_pos = get_global_mouse_position()
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _is_flying_back:
					_complete_fly_back()
				var box = _get_slot_at_position(mouse_pos)
				if box != null:
					if _can_drag_from_box(box):
						if start_slot_drag(box, mouse_pos):
							_drag_from_mouse_input = true
							_mark_handled()
							return
					else:
						_handle_empty_slot_click(box)
						_mark_handled()
						return
				else:
					if _selected_source != "":
						_clear_selection()
						_rebuild_inventory_ui()
			else:
				if _is_dragging:
					end_slot_drag(mouse_pos)
					_mark_handled()
					return
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if _is_dragging:
				_set_hovered_drop_box(null)
				_fly_back_to_origin()
				_mark_handled()
				return
			var box = _get_slot_at_position(mouse_pos)
			if box != null:
				var stype = _get_box_slot_type(box)
				if stype == "inventory":
					floating_weapon.quick_slot_card(_get_box_slot_idx(box))
					_clear_selection()
					_rebuild_inventory_ui()
					_mark_handled()
					return
				elif stype == "weapon_socket" or stype == "weapon":
					floating_weapon.quick_unslot_card(_get_box_weapon_idx(box), _get_box_slot_idx(box))
					_clear_selection()
					_rebuild_inventory_ui()
					_mark_handled()
					return

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_I or event.keycode == KEY_I:
			toggle_inventory()
			_mark_handled()
			return

		if not _is_inventory_open and event.physical_keycode in [KEY_1, KEY_2, KEY_3, KEY_4]:
			var idx = event.physical_keycode - KEY_1
			if floating_weapon != null:
				floating_weapon.equip_weapon_index(idx)
			_mark_handled()
			return

		if _is_inventory_open and (event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE):
			close_inventory()
			_mark_handled()
			return

func _mark_handled() -> void:
	var vp = get_viewport()
	if vp != null:
		vp.set_input_as_handled()

func toggle_inventory() -> void:
	if _is_inventory_open:
		close_inventory()
	else:
		open_inventory()

func open_inventory() -> void:
	_is_inventory_open = true
	_sync_backdrop_size()

	_inventory_overlay.visible = true
	_weapon_label.visible = true
	_item_label.visible = true
	_inv_spacer.visible = true
	_inventory_column.visible = true
	_accordion_scroll.visible = true

	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if player_motor != null and player_motor.player_input != null:
		player_motor.player_input.input_enabled = false

	_rebuild_inventory_ui()

func close_inventory() -> void:
	_cancel_drag_and_restore()
	_is_inventory_open = false
	_inventory_overlay.visible = false
	_weapon_label.visible = false
	_item_label.visible = false
	_inv_spacer.visible = false
	_inventory_column.visible = false
	_accordion_scroll.visible = false

	_clear_selection()
	_hide_tooltip()

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if player_motor != null and player_motor.player_input != null:
		player_motor.player_input.input_enabled = true
		player_motor.player_input.capture_mouse()

	_update_ui_state()

## -----------------------------------------------------------------------------
## PROCESS & COOLDOWN RENDERING
## -----------------------------------------------------------------------------
func _process(delta: float) -> void:
	if not _initial_ui_synced:
		if floating_weapon == null and player_motor != null and player_motor.floating_weapon != null:
			floating_weapon = player_motor.floating_weapon
		if floating_weapon != null and not floating_weapon.weapons.is_empty():
			_update_ui_state()
			_initial_ui_synced = true

	if _is_dragging and _drag_from_mouse_input and is_inside_tree():
		var mouse_pos = get_global_mouse_position()
		update_slot_drag(mouse_pos)
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			end_slot_drag(mouse_pos)

	if _is_flying_back:
		_fly_back_elapsed += delta
		var t = clampf(_fly_back_elapsed / FLY_BACK_DURATION, 0.0, 1.0)
		var eased_t = 1.0 - pow(1.0 - t, 3.0)
		_fly_back_target_pos = _get_origin_target_pos()
		if _drag_proxy != null:
			_drag_proxy.global_position = _fly_back_start_pos.lerp(_fly_back_target_pos, eased_t)
		if t >= 1.0:
			_complete_fly_back()

	_update_quickbar_cooldowns()

	if _tooltip_panel != null and _tooltip_panel.visible:
		if _is_dragging or _is_flying_back:
			_hide_tooltip()
		else:
			var mouse_pos = get_viewport().get_mouse_position()
			_tooltip_panel.position = mouse_pos + Vector2(16, 16)

func _update_quickbar_cooldowns() -> void:
	if floating_weapon == null:
		return

	var active_idx = floating_weapon.active_weapon_index
	var evaluator = floating_weapon.get_evaluator()

	for i in range(_hud_weapon_boxes.size()):
		var box = _hud_weapon_boxes[i]
		var cd_rect = box.get_node_or_null("CooldownOverlay") as ColorRect
		var style = box.get_theme_stylebox("panel") as StyleBoxFlat

		if i == active_idx:
			if evaluator != null and not evaluator.is_ready():
				if cd_rect != null:
					cd_rect.color = Color(0.9, 0.25, 0.15, 0.45)
				if style != null:
					style.border_color = Color(0.9, 0.3, 0.2, 1.0)
			else:
				if cd_rect != null:
					cd_rect.color = Color(0, 0, 0, 0)
				if style != null:
					style.border_color = COLOR_ACCORDION_ACTIVE_BORDER
		else:
			if cd_rect != null:
				cd_rect.color = Color(0, 0, 0, 0)
			if style != null:
				style.border_color = COLOR_SLOT_BORDER

		if box == _hovered_drop_box and style != null:
			style.border_color = COLOR_SLOT_HOVER

## -----------------------------------------------------------------------------
## STATE SYNCHRONIZATION
## -----------------------------------------------------------------------------
func update_ui_state() -> void:
	_update_ui_state()

func _update_ui_state() -> void:
	if floating_weapon == null:
		return
	if _hud_weapon_boxes.is_empty():
		return

	var weapons = floating_weapon.weapons
	var active_idx = floating_weapon.active_weapon_index

	for i in range(_hud_weapon_boxes.size()):
		var box = _hud_weapon_boxes[i]
		var icon_rect = box.get_node_or_null("CenterContainer/IconRect") as TextureRect
		var lbl = box.get_node_or_null("CenterContainer/SlotLabel") as Label
		var style = box.get_theme_stylebox("panel") as StyleBoxFlat

		box.set_meta("weapon_idx", i)
		box.set("weapon_idx", i)
		box.set_meta("slot_idx", i)
		box.set("slot_idx", i)

		if i < _active_marker_labels.size():
			_active_marker_labels[i].text = ""

		if i < weapons.size() and weapons[i] != null:
			var w = weapons[i]
			var icon_tex = w.icon if (w != null and "icon" in w and w.icon != null) else WeaponIconFactory.get_weapon_icon(w.weapon_id)
			if icon_rect != null:
				icon_rect.texture = icon_tex
				icon_rect.visible = not ((_is_dragging or _is_flying_back) and (_drag_data.get("origin_box") == box or _fly_back_origin_box == box))
			if lbl != null:
				lbl.text = ""

			box.set_meta("weapon", w)
			box.set("weapon", w)

			if style != null:
				if i == active_idx:
					style.border_color = COLOR_ACCORDION_ACTIVE_BORDER
					style.bg_color = Color(0.18, 0.14, 0.08, 0.95)
				else:
					style.border_color = COLOR_SLOT_BORDER
					style.bg_color = COLOR_SLOT_BG
		else:
			if icon_rect != null:
				icon_rect.texture = null
				icon_rect.visible = false
			if lbl != null:
				lbl.text = ""
			box.set_meta("weapon", null)
			box.set("weapon", null)
			if style != null:
				style.border_color = Color(0.22, 0.17, 0.13, 0.6)
				style.bg_color = Color(0.06, 0.05, 0.04, 0.8)

	for box in _hud_item_boxes:
		var lbl = box.get_node_or_null("CenterContainer/SlotLabel") as Label
		if lbl != null:
			lbl.text = ""

	if _is_inventory_open and not _is_dragging and not _is_flying_back:
		_rebuild_inventory_ui()

## -----------------------------------------------------------------------------
## ACCORDIONS & 32-GRID REBUILD
## -----------------------------------------------------------------------------
func _rebuild_inventory_ui() -> void:
	if floating_weapon == null:
		return

	# 1. Rebuild Weapon Accordions
	_accordion_weapon_boxes.clear()
	_accordion_socket_boxes.clear()
	for c in _accordion_container.get_children():
		c.queue_free()

	var weapons = floating_weapon.weapons
	var active_idx = floating_weapon.active_weapon_index

	for w_idx in range(weapons.size()):
		var w = weapons[w_idx]
		if w == null:
			continue

		var acc_panel = _create_weapon_accordion_card(w, w_idx, w_idx == active_idx)
		_accordion_container.add_child(acc_panel)

	# 2. Rebuild Extensive 32 Inventory Grid
	var inv_cards = floating_weapon.inventory_cards
	for i in range(_inventory_boxes.size()):
		var box = _inventory_boxes[i]
		var icon_rect = box.get_node_or_null("CenterContainer/IconRect") as TextureRect
		var lbl = box.get_node_or_null("CenterContainer/SlotLabel") as Label
		var style = box.get_theme_stylebox("panel") as StyleBoxFlat

		_disconnect_mouse_signals(box)

		if i < inv_cards.size() and inv_cards[i] != null:
			var card = inv_cards[i] as TechniqueCard
			var card_tex = WeaponIconFactory.get_card_icon(card.card_id, card.get_class())
			if icon_rect != null:
				icon_rect.texture = card_tex
				icon_rect.visible = true
			if lbl != null:
				lbl.text = ""

			_apply_card_slot_style(style, card)
			box.set_meta("card", card)
			box.set("card", card)

			box.mouse_entered.connect(_show_card_tooltip.bind(card))
			box.mouse_exited.connect(_hide_tooltip)
		else:
			if icon_rect != null:
				icon_rect.texture = null
				icon_rect.visible = false
			if lbl != null:
				lbl.text = ""
			if style != null:
				style.bg_color = Color(0.09, 0.07, 0.05, 0.85)
				style.border_color = COLOR_SLOT_BORDER
			box.set_meta("card", null)
			box.set("card", null)

		if _selected_source == "inventory" and _selected_slot_idx == i and style != null:
			style.border_color = COLOR_SLOT_SELECTED
			style.bg_color = Color(0.28, 0.22, 0.12, 0.95)

func _create_weapon_accordion_card(w: MeleeWeaponDef, w_idx: int, is_active: bool) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(356, 0)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.09, 0.07, 0.94) if is_active else Color(0.08, 0.06, 0.05, 0.88)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = COLOR_ACCORDION_ACTIVE_BORDER if is_active else COLOR_ACCORDION_BORDER
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	vbox.mouse_filter = MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	# Top Row: Weapon Icon on Left + White Text Stats Table on Right
	var top_hbox = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 8)
	top_hbox.mouse_filter = MOUSE_FILTER_IGNORE
	vbox.add_child(top_hbox)

	var w_icon_box = _create_slot_box(Vector2(36, 36), "accordion_weapon", w_idx, w_idx)
	w_icon_box.name = "AccordionWeaponIcon_%d" % w_idx
	var w_style = w_icon_box.get_theme_stylebox("panel") as StyleBoxFlat
	if w_style != null:
		w_style.bg_color = Color(0.14, 0.10, 0.07, 0.9)
		w_style.border_color = COLOR_ACCORDION_ACTIVE_BORDER if is_active else COLOR_SLOT_BORDER

	var w_icon_rect = w_icon_box.get_node_or_null("CenterContainer/IconRect") as TextureRect
	if w_icon_rect != null:
		w_icon_rect.custom_minimum_size = Vector2(30, 30)
		w_icon_rect.texture = w.icon if (w != null and "icon" in w and w.icon != null) else WeaponIconFactory.get_weapon_icon(w.weapon_id)
		w_icon_rect.visible = true

	_setup_drag_and_drop(w_icon_box, "accordion_weapon", w_idx, w_idx)
	w_icon_box.set_meta("weapon", w)
	w_icon_box.set("weapon", w)
	top_hbox.add_child(w_icon_box)
	_accordion_weapon_boxes.append(w_icon_box)

	# Stats Table (Clear white text with Capacity)
	var stats_vbox = VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 1)
	stats_vbox.mouse_filter = MOUSE_FILTER_IGNORE
	top_hbox.add_child(stats_vbox)

	var s_shuffle = "Yes" if w.is_shuffle else "No"
	var row1 = Label.new()
	row1.text = "%-12s %s" % ["Shuffle", s_shuffle]
	row1.add_theme_font_size_override("font_size", 9)
	row1.add_theme_color_override("font_color", Color.WHITE)
	row1.mouse_filter = MOUSE_FILTER_IGNORE
	stats_vbox.add_child(row1)

	var row2 = Label.new()
	row2.text = "%-12s %d" % ["Spells/Cast", 1]
	row2.add_theme_font_size_override("font_size", 9)
	row2.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
	row2.mouse_filter = MOUSE_FILTER_IGNORE
	stats_vbox.add_child(row2)

	var row3 = Label.new()
	row3.text = "%-12s %.2fs" % ["Rechg. Time", w.deck_recharge_time]
	row3.add_theme_font_size_override("font_size", 9)
	row3.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	row3.mouse_filter = MOUSE_FILTER_IGNORE
	stats_vbox.add_child(row3)

	# Bottom Row: Weapon Technique Sockets (GridContainer: breaks every 10 slots!)
	var sockets_grid = GridContainer.new()
	sockets_grid.name = "SocketsGrid"
	sockets_grid.columns = ACCORDION_SLOTS_PER_ROW # 10 slots per row
	sockets_grid.add_theme_constant_override("h_separation", 3)
	sockets_grid.add_theme_constant_override("v_separation", 3)
	sockets_grid.mouse_filter = MOUSE_FILTER_IGNORE
	vbox.add_child(sockets_grid)

	for s_idx in range(w.slot_capacity):
		var socket_box = _create_slot_box(Vector2(32, 32), "weapon_socket", w_idx, s_idx)
		var icon_rect = socket_box.get_node_or_null("CenterContainer/IconRect") as TextureRect
		var lbl = socket_box.get_node_or_null("CenterContainer/SlotLabel") as Label
		var style_s = socket_box.get_theme_stylebox("panel") as StyleBoxFlat

		if s_idx < w.slotted_techniques.size() and w.slotted_techniques[s_idx] != null:
			var card = w.slotted_techniques[s_idx] as TechniqueCard
			var card_tex = WeaponIconFactory.get_card_icon(card.card_id, card.get_class())
			if icon_rect != null:
				icon_rect.texture = card_tex
				icon_rect.visible = true
			if lbl != null:
				lbl.text = ""

			_apply_card_slot_style(style_s, card)
			socket_box.set_meta("card", card)
			socket_box.set("card", card)

			socket_box.mouse_entered.connect(_show_card_tooltip.bind(card))
			socket_box.mouse_exited.connect(_hide_tooltip)
		else:
			if icon_rect != null:
				icon_rect.texture = null
				icon_rect.visible = false
			if lbl != null:
				lbl.text = ""
			if style_s != null:
				style_s.bg_color = Color(0.08, 0.06, 0.05, 0.85)
				style_s.border_color = COLOR_SLOT_BORDER
			socket_box.set_meta("card", null)
			socket_box.set("card", null)

		if _selected_source == "weapon" and _selected_weapon_idx == w_idx and _selected_slot_idx == s_idx and style_s != null:
			style_s.border_color = COLOR_SLOT_SELECTED
			style_s.bg_color = Color(0.28, 0.22, 0.12, 0.95)

		socket_box.gui_input.connect(_on_weapon_socket_clicked.bind(w_idx, s_idx))
		_setup_drag_and_drop(socket_box, "weapon_socket", w_idx, s_idx)
		sockets_grid.add_child(socket_box)
		_accordion_socket_boxes.append(socket_box)

	return panel

func _apply_card_slot_style(style: StyleBoxFlat, card: TechniqueCard) -> void:
	if style == null or card == null:
		return

	if card is ModifierCard:
		style.border_color = Color(0.25, 0.85, 0.45, 0.95)
		style.bg_color = Color(0.08, 0.18, 0.11, 0.92)
	elif card is MotionCard:
		style.border_color = Color(0.28, 0.75, 0.98, 0.95)
		style.bg_color = Color(0.08, 0.14, 0.22, 0.92)
	elif card is MulticastCard:
		style.border_color = Color(0.95, 0.80, 0.25, 0.95)
		style.bg_color = Color(0.20, 0.16, 0.08, 0.92)
	elif card is TriggerCard:
		style.border_color = Color(0.85, 0.40, 0.90, 0.95)
		style.bg_color = Color(0.18, 0.08, 0.18, 0.92)

func _disconnect_mouse_signals(box: PanelContainer) -> void:
	if box.mouse_entered.is_connected(_show_card_tooltip):
		box.mouse_entered.disconnect(_show_card_tooltip)
	if box.mouse_exited.is_connected(_hide_tooltip):
		box.mouse_exited.disconnect(_hide_tooltip)

## -----------------------------------------------------------------------------
## 5. CLICK & SELECTION HANDLERS
## -----------------------------------------------------------------------------
func _handle_card_slot_click(box: Control) -> void:
	if floating_weapon == null or box == null or not is_instance_valid(box):
		return
	var stype = _get_box_slot_type(box)
	if stype == "inventory":
		var slot_idx = _get_box_slot_idx(box)
		if _selected_source == "":
			if slot_idx >= 0 and slot_idx < floating_weapon.inventory_cards.size() and floating_weapon.inventory_cards[slot_idx] != null:
				_selected_source = "inventory"
				_selected_slot_idx = slot_idx
				_selected_card = floating_weapon.inventory_cards[slot_idx]
				_rebuild_inventory_ui()
		elif _selected_source == "inventory":
			if _selected_slot_idx == slot_idx:
				_clear_selection()
				_rebuild_inventory_ui()
			else:
				floating_weapon.swap_inventory_slots(_selected_slot_idx, slot_idx)
				_clear_selection()
				_rebuild_inventory_ui()
		elif _selected_source == "weapon":
			floating_weapon.swap_weapon_and_inventory(_selected_weapon_idx, _selected_slot_idx, slot_idx)
			_clear_selection()
			_rebuild_inventory_ui()
	elif stype == "weapon_socket" or stype == "weapon":
		var w_idx = _get_box_weapon_idx(box)
		var s_idx = _get_box_slot_idx(box)
		var w = floating_weapon.weapons[w_idx] if (w_idx >= 0 and w_idx < floating_weapon.weapons.size()) else null
		if _selected_source == "":
			if w != null and s_idx >= 0 and s_idx < w.slotted_techniques.size() and w.slotted_techniques[s_idx] != null:
				_selected_source = "weapon"
				_selected_weapon_idx = w_idx
				_selected_slot_idx = s_idx
				_selected_card = w.slotted_techniques[s_idx]
				_rebuild_inventory_ui()
		elif _selected_source == "inventory":
			floating_weapon.swap_weapon_and_inventory(w_idx, s_idx, _selected_slot_idx)
			_clear_selection()
			_rebuild_inventory_ui()
		elif _selected_source == "weapon":
			if _selected_weapon_idx == w_idx and _selected_slot_idx == s_idx:
				_clear_selection()
				_rebuild_inventory_ui()
			elif _selected_weapon_idx == w_idx and w_idx == floating_weapon.active_weapon_index:
				floating_weapon.swap_weapon_sockets(_selected_slot_idx, s_idx)
				_clear_selection()
				_rebuild_inventory_ui()
			else:
				floating_weapon.swap_between_weapons(_selected_weapon_idx, _selected_slot_idx, w_idx, s_idx)
				_clear_selection()
				_rebuild_inventory_ui()

func _handle_empty_slot_click(box: Control) -> void:
	if _selected_source != "":
		_handle_card_slot_click(box)

func _on_hud_box_clicked(event: InputEvent, box_idx: int) -> void:
	if _is_inventory_open:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if floating_weapon != null:
			floating_weapon.equip_weapon_index(box_idx)
			_update_ui_state()

func _on_inventory_slot_clicked(event: InputEvent, slot_idx: int) -> void:
	if _is_inventory_open:
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	if floating_weapon == null:
		return

	if event.button_index == MOUSE_BUTTON_RIGHT:
		floating_weapon.quick_slot_card(slot_idx)
		_clear_selection()
		_rebuild_inventory_ui()
		return

func _on_weapon_socket_clicked(event: InputEvent, w_idx: int, s_idx: int) -> void:
	if _is_inventory_open:
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	if floating_weapon == null:
		return

	if event.button_index == MOUSE_BUTTON_RIGHT:
		floating_weapon.quick_unslot_card(w_idx, s_idx)
		_clear_selection()
		_rebuild_inventory_ui()
		return

func _clear_selection() -> void:
	_selected_source = ""
	_selected_weapon_idx = -1
	_selected_slot_idx = -1
	_selected_card = null

## -----------------------------------------------------------------------------
## 6. TOOLTIP DISPLAY
## -----------------------------------------------------------------------------
func _show_card_tooltip(card: TechniqueCard) -> void:
	if card == null:
		return

	_hovered_card = card
	_tooltip_title.text = card.card_name

	if card is ModifierCard:
		_tooltip_title.add_theme_color_override("font_color", Color(0.4, 0.95, 0.6))
		_tooltip_type.text = "[MODIFIER] Kinetic & Blade Infusion"
		_tooltip_type.add_theme_color_override("font_color", Color(0.5, 0.9, 0.6))
		var speed_pct = int((card.execution_duration_multiplier - 1.0) * 100.0)
		var freq_pct = int((card.recovery_delay_multiplier - 1.0) * 100.0)
		var stats_str = "Speed: %+d%%  |  Recovery: %+d%%" % [speed_pct, freq_pct]
		if card.mass_multiplier != 1.0:
			stats_str += "  |  Mass: %.2fx" % card.mass_multiplier
		if card.momentum_retention > 0.0:
			stats_str += "  |  Momentum: +%d%%" % int(card.momentum_retention * 100.0)
		if card.radius_multiplier != 1.0:
			stats_str += "  |  Reach: %.2fx" % card.radius_multiplier
		_tooltip_stats.text = stats_str
	elif card is MotionCard:
		_tooltip_title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
		_tooltip_type.text = "[MOTION] Kinetic Strike Action"
		_tooltip_type.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
		_tooltip_stats.text = "Duration: %.2fs  |  Sweep: %.0f°  |  Reach: %.1fm  |  Lunge: %.1fm" % [
			card.execution_duration, card.arc_sweep_degrees, card.outer_radius, card.player_lunge_distance
		]
	elif card is MulticastCard:
		_tooltip_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		_tooltip_type.text = "[MULTICAST] Formation Strike"
		_tooltip_type.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
		_tooltip_stats.text = "Simultaneous Swings: %d  |  Tilt Offset: %.0f°" % [
			card.simultaneous_count, card.formation_tilt_offset
		]
	elif card is TriggerCard:
		_tooltip_title.add_theme_color_override("font_color", Color(0.95, 0.5, 0.95))
		_tooltip_type.text = "[TRIGGER] On-Hit Payload Chain"
		_tooltip_type.add_theme_color_override("font_color", Color(0.9, 0.5, 0.9))
		_tooltip_stats.text = "Payload Cards: %d" % [card.payload_cards.size()]

	_tooltip_desc.text = card.description
	_tooltip_panel.visible = true

func _hide_tooltip() -> void:
	_tooltip_panel.visible = false
	_hovered_card = null

func _on_inventory_data_changed() -> void:
	_update_ui_state()

func _on_weapon_equipped(_weapon: MeleeWeaponDef) -> void:
	_update_ui_state()
