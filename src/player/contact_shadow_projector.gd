class_name ContactShadowProjector
extends Decal

## Projects a crisp, grimy contact shadow footprint directly beneath the capsule
## onto the terrain, completely eliminating any "floating" appearance even under flat lighting.

@export var shadow_radius: float = 0.55
@export var shadow_opacity: float = 0.85
@export var shadow_depth: float = 1.4

func _ready() -> void:
	size = Vector3(shadow_radius * 2.0, shadow_depth, shadow_radius * 2.0)
	cull_mask = 1 # Ground/terrain collision layer
	modulate = Color(0.02, 0.02, 0.02, shadow_opacity)
	texture_albedo = _create_radial_shadow_texture()

static func _create_radial_shadow_texture() -> GradientTexture2D:
	var grad = Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1.0))
	grad.set_offset(0, 0.0)
	grad.add_point(0.40, Color(1, 1, 1, 0.85))
	grad.set_color(2, Color(1, 1, 1, 0.0))
	grad.set_offset(2, 1.0)

	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex

