class_name PollutionSmogEmitter
extends GPUParticles3D

## Lightweight, low-overhead GPU particle emitter simulating drifting black-grey industrial
## pollution smog and soot clouds hugging the terrain surface.
## Provides an economical aesthetic layer (< 150 particles, unshaded, 1 draw call)
## that moves with the player across the voxel terrain.

@export var smoke_color: Color = Color(0.12, 0.13, 0.15, 0.40)
@export var wind_direction: Vector3 = Vector3(1.0, 0.12, 0.45)
@export var wind_speed: float = 1.2
@export var box_extents: Vector3 = Vector3(32.0, 4.0, 32.0)

func _ready() -> void:
	amount = 140
	lifetime = 6.0
	preprocess = 3.0
	explosiveness = 0.0
	randomness = 0.6
	local_coords = false

	if draw_pass_1 == null:
		var quad = QuadMesh.new()
		quad.size = Vector2(3.2, 3.2)
		draw_pass_1 = quad

	if material_override == null:
		material_override = create_smog_material(smoke_color)

	if process_material == null:
		process_material = create_process_material(box_extents, wind_direction, wind_speed)

static func create_smoke_puff_texture() -> GradientTexture2D:
	var grad = Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1.0))
	grad.set_offset(0, 0.0)
	grad.add_point(0.40, Color(1, 1, 1, 0.75))
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

static func create_smog_material(color: Color = Color(0.12, 0.13, 0.15, 0.40)) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = color
	mat.albedo_texture = create_smoke_puff_texture()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.proximity_fade_enabled = true
	mat.proximity_fade_distance = 0.8
	return mat

static func create_process_material(extents: Vector3, wind_dir: Vector3, speed: float) -> ParticleProcessMaterial:
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = extents
	mat.direction = wind_dir.normalized()
	mat.spread = 35.0
	mat.initial_velocity_min = speed * 0.5
	mat.initial_velocity_max = speed * 1.5
	mat.gravity = Vector3(0.0, 0.05, 0.0)
	mat.scale_min = 1.2
	mat.scale_max = 3.2
	mat.angle_min = -180.0
	mat.angle_max = 180.0
	mat.angular_velocity_min = -12.0
	mat.angular_velocity_max = 12.0

	var alpha_grad = Gradient.new()
	alpha_grad.set_color(0, Color(1, 1, 1, 0.0))
	alpha_grad.set_offset(0, 0.0)
	alpha_grad.add_point(0.25, Color(1, 1, 1, 1.0))
	alpha_grad.add_point(0.70, Color(1, 1, 1, 0.85))
	alpha_grad.set_color(3, Color(1, 1, 1, 0.0))
	alpha_grad.set_offset(3, 1.0)

	var color_ramp = GradientTexture1D.new()
	color_ramp.gradient = alpha_grad
	mat.color_ramp = color_ramp

	return mat

