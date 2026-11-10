extends SceneTree

const WeaponDeckUIClass = preload("res://src/combat/ui/weapon_deck_ui.gd")
const PlayerHUDClass = preload("res://src/player/player_hud.gd")
const ContinentMapUIClass = preload("res://src/map/continent_map_ui.gd")

func _init() -> void:
	print("--- Generating UI Scenes ---")
	_generate_weapon_deck_ui()
	_generate_player_hud()
	_generate_continent_map_ui()
	print("--- All UI Scenes Generated Successfully ---")
	quit(0)

func _set_owners(node: Node, root: Node) -> void:
	if node != root:
		node.owner = root
	for child in node.get_children():
		_set_owners(child, root)

func _generate_weapon_deck_ui() -> void:
	print("Generating res://scenes/ui/weapon_deck_ui.tscn...")
	var ui = WeaponDeckUIClass.new()
	ui.name = "WeaponDeckUI"
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)

	ui._setup_inventory_overlay()
	ui._setup_top_bar()
	ui._setup_accordion_section()
	ui._setup_tooltip()

	_set_owners(ui, ui)

	var packed = PackedScene.new()
	var err = packed.pack(ui)
	if err != OK:
		printerr("Failed to pack WeaponDeckUI: ", err)
		return

	var save_err = ResourceSaver.save(packed, "res://scenes/ui/weapon_deck_ui.tscn")
	if save_err != OK:
		printerr("Failed to save weapon_deck_ui.tscn: ", save_err)
		return
	print("Saved res://scenes/ui/weapon_deck_ui.tscn successfully.")

func _generate_player_hud() -> void:
	print("Generating res://scenes/ui/player_hud.tscn...")
	var hud = PlayerHUDClass.new()
	hud.name = "PlayerHUD"
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Debug Label
	var debug_lbl = Label.new()
	debug_lbl.name = "DebugLabel"
	debug_lbl.position = Vector2(16, 85)
	debug_lbl.add_theme_color_override("font_color", Color.WHITE)
	debug_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	debug_lbl.add_theme_constant_override("shadow_offset_x", 1)
	debug_lbl.add_theme_constant_override("shadow_offset_y", 1)
	debug_lbl.visible = false
	hud.add_child(debug_lbl)

	# Status Banner
	var status_banner = Label.new()
	status_banner.name = "StatusBanner"
	status_banner.anchor_left = 0.5
	status_banner.anchor_top = 0.0
	status_banner.anchor_right = 0.5
	status_banner.anchor_bottom = 0.0
	status_banner.offset_left = -250
	status_banner.offset_top = 32
	status_banner.offset_right = 250
	status_banner.offset_bottom = 64
	status_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_banner.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	status_banner.add_theme_color_override("font_shadow_color", Color.BLACK)
	status_banner.add_theme_constant_override("shadow_offset_x", 1)
	status_banner.add_theme_constant_override("shadow_offset_y", 1)
	status_banner.visible = false
	hud.add_child(status_banner)

	# Instance WeaponDeckUI from its scene
	var weapon_deck_packed = load("res://scenes/ui/weapon_deck_ui.tscn") as PackedScene
	if weapon_deck_packed != null:
		var weapon_deck_instance = weapon_deck_packed.instantiate()
		weapon_deck_instance.name = "WeaponDeckUI"
		hud.add_child(weapon_deck_instance)

	_set_owners(hud, hud)

	var packed = PackedScene.new()
	var err = packed.pack(hud)
	if err != OK:
		printerr("Failed to pack PlayerHUD: ", err)
		return

	var save_err = ResourceSaver.save(packed, "res://scenes/ui/player_hud.tscn")
	if save_err != OK:
		printerr("Failed to save player_hud.tscn: ", save_err)
		return
	print("Saved res://scenes/ui/player_hud.tscn successfully.")

func _generate_continent_map_ui() -> void:
	print("Generating res://scenes/ui/continent_map_ui.tscn...")
	var map_ui = ContinentMapUIClass.new()
	map_ui.name = "ContinentMapUI"
	map_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_ui.visible = false

	map_ui._build_ui()

	_set_owners(map_ui, map_ui)

	var packed = PackedScene.new()
	var err = packed.pack(map_ui)
	if err != OK:
		printerr("Failed to pack ContinentMapUI: ", err)
		return

	var save_err = ResourceSaver.save(packed, "res://scenes/ui/continent_map_ui.tscn")
	if save_err != OK:
		printerr("Failed to save continent_map_ui.tscn: ", save_err)
		return
	print("Saved res://scenes/ui/continent_map_ui.tscn successfully.")

