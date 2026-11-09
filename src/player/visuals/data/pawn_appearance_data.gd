class_name PawnAppearanceData
extends Resource

## Dynamic appearance state for an individual pawn instance.

signal appearance_changed

var _body_type: BodyTypeDef
var _head_type: HeadTypeDef
var _skin_color: Color = Color(0.95, 0.82, 0.72)
var _hair_color: Color = Color(0.2, 0.15, 0.1)
var _equipped_apparel: Array[ApparelDef] = []
var _apparel_colors: Dictionary = {}

@export var body_type: BodyTypeDef:
	get:
		return _body_type
	set(value):
		if _body_type != value:
			_body_type = value
			appearance_changed.emit()

@export var head_type: HeadTypeDef:
	get:
		return _head_type
	set(value):
		if _head_type != value:
			_head_type = value
			appearance_changed.emit()

@export var skin_color: Color:
	get:
		return _skin_color
	set(value):
		if _skin_color != value:
			_skin_color = value
			appearance_changed.emit()

@export var hair_color: Color:
	get:
		return _hair_color
	set(value):
		if _hair_color != value:
			_hair_color = value
			appearance_changed.emit()

@export var equipped_apparel: Array[ApparelDef]:
	get:
		return _equipped_apparel
	set(value):
		_equipped_apparel = value
		appearance_changed.emit()

@export var apparel_colors: Dictionary: # StringName (apparel.id) -> Color
	get:
		return _apparel_colors
	set(value):
		_apparel_colors = value
		appearance_changed.emit()

func equip(apparel: ApparelDef, color: Color = Color.WHITE) -> void:
	if apparel == null:
		return
	# Remove any existing apparel occupying the same layer
	for existing in _equipped_apparel.duplicate():
		if existing != null and existing.layer == apparel.layer:
			_equipped_apparel.erase(existing)
			_apparel_colors.erase(existing.id)

	_equipped_apparel.append(apparel)
	_apparel_colors[apparel.id] = color
	appearance_changed.emit()

func unequip(apparel_id: StringName) -> void:
	for existing in _equipped_apparel.duplicate():
		if existing != null and existing.id == apparel_id:
			_equipped_apparel.erase(existing)
			_apparel_colors.erase(apparel_id)
			appearance_changed.emit()
			break

func has_apparel(apparel_id: StringName) -> bool:
	for item in _equipped_apparel:
		if item != null and item.id == apparel_id:
			return true
	return false

func get_apparel_color(apparel_id: StringName, fallback: Color = Color.WHITE) -> Color:
	return _apparel_colors.get(apparel_id, fallback)

func reset_to_fallback() -> void:
	_body_type = null
	_head_type = null
	_equipped_apparel.clear()
	_apparel_colors.clear()
	_skin_color = Color(0.95, 0.82, 0.72)
	_hair_color = Color(0.2, 0.15, 0.1)
	appearance_changed.emit()
