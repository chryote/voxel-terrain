class_name GraphicNovelPostProcess
extends Node3D

## Fullscreen 3D post-processing controller for graphic novel / comic book ink outlines.
## Manages a fullscreen NDC quad attached to the active Camera3D reading scene depth and normal buffers.
## Guarantees 2D UI (HUD, minimap, crosshairs) on CanvasLayer remains clean and unoutlined.

const SHADER_PATH = "res://shaders/postprocess/outline_postprocess.gdshader"
const GraphicNovelConfigClass = preload("res://src/rendering/graphic_novel_config.gd")

@export var config: Resource:
	set(val):
		config = val
		if is_node_ready():
			apply_config()

var mesh_instance: MeshInstance3D
var post_material: ShaderMaterial

func _ready() -> void:
	_setup_fullscreen_quad()
	apply_config()

func _process(_delta: float) -> void:
	_ensure_attached_to_camera()

## Automatically attaches and aligns the post-process quad to the active Camera3D so it is never culled.
func _ensure_attached_to_camera() -> void:
	var cam = get_viewport().get_camera_3d()
	if cam != null and mesh_instance != null:
		if mesh_instance.get_parent() != cam:
			if mesh_instance.get_parent() != null:
				mesh_instance.get_parent().remove_child(mesh_instance)
			cam.add_child(mesh_instance)
			mesh_instance.transform = Transform3D.IDENTITY

func _setup_fullscreen_quad() -> void:
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "OutlineFullscreenQuad"
		var quad = QuadMesh.new()
		quad.size = Vector2(2.0, 2.0)
		mesh_instance.mesh = quad
		mesh_instance.extra_cull_margin = 16384.0
		mesh_instance.custom_aabb = AABB(Vector3(-1000, -1000, -1000), Vector3(2000, 2000, 2000))
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh_instance)

	if post_material == null:
		post_material = ShaderMaterial.new()
		var shader = load(SHADER_PATH) as Shader
		if shader != null:
			post_material.shader = shader
		# Render priority 10 ensures execution strictly after all opaque geometry passes
		post_material.render_priority = 10
		mesh_instance.material_override = post_material

func apply_config() -> void:
	if config == null:
		config = GraphicNovelConfigClass.create_default_config()

	if post_material == null:
		return

	post_material.set_shader_parameter("outlines_enabled", bool(config.get("outlines_enabled")))
	post_material.set_shader_parameter("outline_color", config.get("outline_color"))
	post_material.set_shader_parameter("outline_thickness", float(config.get("outline_thickness")))
	post_material.set_shader_parameter("depth_threshold", float(config.get("depth_threshold")))
	post_material.set_shader_parameter("normal_threshold", float(config.get("normal_threshold")))
	post_material.set_shader_parameter("outline_fade_start", float(config.get("outline_fade_start")))
	post_material.set_shader_parameter("max_outline_distance", float(config.get("max_outline_distance")))

func set_outlines_enabled(p_enabled: bool) -> void:
	if config != null:
		config.set("outlines_enabled", p_enabled)
	if post_material != null:
		post_material.set_shader_parameter("outlines_enabled", p_enabled)

func _exit_tree() -> void:
	if mesh_instance != null and is_instance_valid(mesh_instance):
		if mesh_instance.get_parent() != self and mesh_instance.get_parent() != null:
			mesh_instance.get_parent().remove_child(mesh_instance)
		mesh_instance.queue_free()
