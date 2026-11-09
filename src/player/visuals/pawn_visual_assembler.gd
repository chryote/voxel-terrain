class_name PawnVisualAssembler
extends Node3D

## Visual assembly node for RimWorld-style modular pawns.
## When appearance_data is null, default, or has no custom mesh, it seamlessly falls
## back to the weathered capsule (pill) body.

signal assembled

@export var appearance_data: PawnAppearanceData:
	set(value):
		if appearance_data != value:
			if appearance_data != null and appearance_data.appearance_changed.is_connected(_on_appearance_changed):
				appearance_data.appearance_changed.disconnect(_on_appearance_changed)
			appearance_data = value
			if appearance_data != null:
				appearance_data.appearance_changed.connect(_on_appearance_changed)
			rebuild()

var visuals_root: Node3D
var fallback_mesh: MeshInstance3D
var torso_mount: MeshInstance3D
var head_mount: Node3D
var head_mesh: MeshInstance3D
var hair_mount: MeshInstance3D
var headgear_mount: MeshInstance3D
var apparel_mounts: Node3D
var on_skin_mount: MeshInstance3D
var middle_mount: MeshInstance3D
var shell_mount: MeshInstance3D

func _ready() -> void:
	_ensure_structure()
	rebuild()

func _ensure_structure() -> void:
	if visuals_root != null:
		return

	# Check if child nodes already exist in scene
	visuals_root = get_node_or_null("VisualsRoot") as Node3D
	if visuals_root == null:
		visuals_root = Node3D.new()
		visuals_root.name = "VisualsRoot"
		add_child(visuals_root)

	fallback_mesh = visuals_root.get_node_or_null("FallbackMeshInstance") as MeshInstance3D
	if fallback_mesh == null:
		fallback_mesh = FallbackPillProvider.create_fallback_instance()
		fallback_mesh.name = "FallbackMeshInstance"
		visuals_root.add_child(fallback_mesh)

	torso_mount = visuals_root.get_node_or_null("TorsoMount") as MeshInstance3D
	if torso_mount == null:
		torso_mount = MeshInstance3D.new()
		torso_mount.name = "TorsoMount"
		torso_mount.visible = false
		visuals_root.add_child(torso_mount)

	head_mount = visuals_root.get_node_or_null("HeadMount") as Node3D
	if head_mount == null:
		head_mount = Node3D.new()
		head_mount.name = "HeadMount"
		visuals_root.add_child(head_mount)

	head_mesh = head_mount.get_node_or_null("HeadMeshInstance") as MeshInstance3D
	if head_mesh == null:
		head_mesh = MeshInstance3D.new()
		head_mesh.name = "HeadMeshInstance"
		head_mesh.visible = false
		head_mount.add_child(head_mesh)

	hair_mount = head_mount.get_node_or_null("HairMount") as MeshInstance3D
	if hair_mount == null:
		hair_mount = MeshInstance3D.new()
		hair_mount.name = "HairMount"
		hair_mount.visible = false
		head_mount.add_child(hair_mount)

	headgear_mount = head_mount.get_node_or_null("HeadgearMount") as MeshInstance3D
	if headgear_mount == null:
		headgear_mount = MeshInstance3D.new()
		headgear_mount.name = "HeadgearMount"
		headgear_mount.visible = false
		head_mount.add_child(headgear_mount)

	apparel_mounts = visuals_root.get_node_or_null("ApparelMounts") as Node3D
	if apparel_mounts == null:
		apparel_mounts = Node3D.new()
		apparel_mounts.name = "ApparelMounts"
		visuals_root.add_child(apparel_mounts)

	on_skin_mount = apparel_mounts.get_node_or_null("OnSkinMount") as MeshInstance3D
	if on_skin_mount == null:
		on_skin_mount = MeshInstance3D.new()
		on_skin_mount.name = "OnSkinMount"
		on_skin_mount.visible = false
		apparel_mounts.add_child(on_skin_mount)

	middle_mount = apparel_mounts.get_node_or_null("MiddleMount") as MeshInstance3D
	if middle_mount == null:
		middle_mount = MeshInstance3D.new()
		middle_mount.name = "MiddleMount"
		middle_mount.visible = false
		apparel_mounts.add_child(middle_mount)

	shell_mount = apparel_mounts.get_node_or_null("ShellMount") as MeshInstance3D
	if shell_mount == null:
		shell_mount = MeshInstance3D.new()
		shell_mount.name = "ShellMount"
		shell_mount.visible = false
		apparel_mounts.add_child(shell_mount)

func rebuild() -> void:
	_ensure_structure()

	if _is_fallback_needed():
		_apply_fallback_state()
		assembled.emit()
		return

	_apply_modular_state()
	assembled.emit()

func _is_fallback_needed() -> bool:
	if appearance_data == null:
		return true
	if appearance_data.body_type == null:
		return true
	if appearance_data.body_type.is_fallback:
		return true
	if appearance_data.body_type.torso_mesh == null:
		return true
	return false

func _apply_fallback_state() -> void:
	fallback_mesh.visible = true
	torso_mount.visible = false
	head_mesh.visible = false
	hair_mount.visible = false
	headgear_mount.visible = false
	on_skin_mount.visible = false
	middle_mount.visible = false
	shell_mount.visible = false

func _apply_modular_state() -> void:
	fallback_mesh.visible = false

	var body = appearance_data.body_type
	torso_mount.mesh = body.torso_mesh
	torso_mount.scale = body.scale_modifier
	torso_mount.visible = true

	head_mount.position = body.neck_mount_offset

	# Head
	if appearance_data.head_type != null and appearance_data.head_type.head_mesh != null:
		head_mesh.mesh = appearance_data.head_type.head_mesh
		head_mesh.visible = true
		hair_mount.position = appearance_data.head_type.hair_mount_offset
		headgear_mount.position = appearance_data.head_type.hair_mount_offset
	else:
		head_mesh.visible = false

	# Clear previous apparel mounts
	on_skin_mount.mesh = null
	on_skin_mount.visible = false
	middle_mount.mesh = null
	middle_mount.visible = false
	shell_mount.mesh = null
	shell_mount.visible = false
	headgear_mount.mesh = null
	headgear_mount.visible = false

	# Apply apparel layers
	var hidden_parts: Dictionary = {}
	for apparel in appearance_data.equipped_apparel:
		if apparel == null:
			continue

		for hidden in apparel.hides_body_parts:
			hidden_parts[hidden] = true

		var mesh = apparel.get_mesh_for_body(body.id)
		if mesh == null:
			continue

		match apparel.layer:
			ApparelDef.Layer.ON_SKIN:
				on_skin_mount.mesh = mesh
				on_skin_mount.visible = true
			ApparelDef.Layer.MIDDLE:
				middle_mount.mesh = mesh
				middle_mount.visible = true
			ApparelDef.Layer.SHELL:
				shell_mount.mesh = mesh
				shell_mount.visible = true
			ApparelDef.Layer.HEADGEAR:
				headgear_mount.mesh = mesh
				headgear_mount.visible = true

	# Check culling
	if hidden_parts.has("Torso"):
		torso_mount.visible = false
	if hidden_parts.has("Head"):
		head_mesh.visible = false

func _on_appearance_changed() -> void:
	rebuild()
