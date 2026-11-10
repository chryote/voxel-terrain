class_name ComboReadoutHUD
extends Control

## On-screen HUD displaying the active melee weapon frame, slotted technique cards,
## active card highlight, and cooldown / recharge progress bar.

const FloatingWeaponController = preload("res://src/combat/visuals/floating_weapon_controller.gd")
const MeleeDeckEvaluator = preload("res://src/combat/core/melee_deck_evaluator.gd")
const MotionCard = preload("res://src/combat/techniques/motions/motion_card.gd")
const ModifierCard = preload("res://src/combat/techniques/modifiers/modifier_card.gd")

@export var floating_weapon: FloatingWeaponController

## Compatibility alias for code checking floating_sword
var floating_sword: FloatingWeaponController:
	get:
		return floating_weapon
	set(val):
		floating_weapon = val

var _weapon_name_label: Label
var _cards_container: HBoxContainer
var _cooldown_bar: ProgressBar

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_setup_ui()

func _setup_ui() -> void:
	# Position at bottom-center
	anchor_left = 0.5
	anchor_top = 1.0
	anchor_right = 0.5
	anchor_bottom = 1.0
	offset_left = -220.0
	offset_top = -90.0
	offset_right = 220.0
	offset_bottom = -20.0

	var panel = PanelContainer.new()
	panel.set_anchors_preset(PRESET_FULL_RECT)
	panel.mouse_filter = MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.10, 0.85)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.6, 0.85, 0.75)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_top = 6
	vbox.offset_right = -10
	vbox.offset_bottom = -6
	vbox.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	# Weapon Name Label
	_weapon_name_label = Label.new()
	_weapon_name_label.text = "Weapon: None"
	_weapon_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_weapon_name_label.add_theme_font_size_override("font_size", 13)
	_weapon_name_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	vbox.add_child(_weapon_name_label)

	# Cards HBox
	_cards_container = HBoxContainer.new()
	_cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_container.custom_minimum_size = Vector2(0, 24)
	_cards_container.mouse_filter = MOUSE_FILTER_IGNORE
	vbox.add_child(_cards_container)

	# Cooldown / Recharge Progress Bar
	_cooldown_bar = ProgressBar.new()
	_cooldown_bar.custom_minimum_size = Vector2(0, 5)
	_cooldown_bar.show_percentage = false
	_cooldown_bar.mouse_filter = MOUSE_FILTER_IGNORE
	vbox.add_child(_cooldown_bar)

func _process(_delta: float) -> void:
	if floating_sword == null:
		return

	var evaluator = floating_sword.get_evaluator()
	var weapon = floating_sword.weapon_def

	if weapon != null:
		_weapon_name_label.text = "Stance Frame: %s" % weapon.display_name

	if evaluator == null:
		return

	# Update card pills if count changed
	var total_cards = evaluator.get_total_cards()
	if _cards_container.get_child_count() != total_cards:
		_rebuild_card_pills(weapon)

	# Update active highlight and colors
	var current_idx = evaluator.get_current_index()
	var is_ready = evaluator.is_ready()

	for i in range(_cards_container.get_child_count()):
		var pill = _cards_container.get_child(i) as PanelContainer
		if pill == null:
			continue

		var p_style = pill.get_theme_stylebox("panel") as StyleBoxFlat
		if p_style != null:
			if i == current_idx and is_ready:
				p_style.border_color = Color(1.0, 0.85, 0.25, 1.0)
				p_style.bg_color = Color(0.18, 0.25, 0.35, 0.95)
			elif i < current_idx:
				p_style.border_color = Color(0.3, 0.4, 0.45, 0.4)
				p_style.bg_color = Color(0.08, 0.10, 0.12, 0.6)
			else:
				p_style.border_color = Color(0.2, 0.55, 0.75, 0.6)
				p_style.bg_color = Color(0.10, 0.14, 0.18, 0.8)

	# Cooldown bar update
	var state = evaluator.get_state()
	var cooldown_left = evaluator.get_cooldown_remaining()

	if state == MeleeDeckEvaluator.State.READY:
		_cooldown_bar.value = 100.0
	elif state == MeleeDeckEvaluator.State.RECHARGING:
		var max_r = weapon.deck_recharge_time if weapon != null else 0.5
		_cooldown_bar.value = clampf((1.0 - (cooldown_left / maxf(max_r, 0.01))) * 100.0, 0.0, 100.0)
	elif state == MeleeDeckEvaluator.State.RECOVERING:
		_cooldown_bar.value = clampf((1.0 - cooldown_left) * 100.0, 0.0, 100.0)

func _rebuild_card_pills(weapon) -> void:
	for c in _cards_container.get_children():
		c.queue_free()

	if weapon == null:
		return

	for card in weapon.slotted_techniques:
		if card == null:
			continue

		var pill = PanelContainer.new()
		pill.mouse_filter = MOUSE_FILTER_IGNORE

		var p_style = StyleBoxFlat.new()
		p_style.border_width_left = 1
		p_style.border_width_top = 1
		p_style.border_width_right = 1
		p_style.border_width_bottom = 1
		p_style.border_color = Color(0.2, 0.55, 0.75, 0.6)
		p_style.corner_radius_top_left = 4
		p_style.corner_radius_top_right = 4
		p_style.corner_radius_bottom_left = 4
		p_style.corner_radius_bottom_right = 4
		p_style.bg_color = Color(0.10, 0.14, 0.18, 0.8)
		pill.add_theme_stylebox_override("panel", p_style)

		var lbl = Label.new()
		lbl.text = " %s " % card.card_name
		lbl.add_theme_font_size_override("font_size", 11)

		if card is ModifierCard:
			lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.6))
		elif card is MotionCard:
			lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
		else:
			lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))

		pill.add_child(lbl)
		_cards_container.add_child(pill)

