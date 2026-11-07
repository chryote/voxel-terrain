class_name AshFallEmitter
extends GPUParticles3D

## Lightweight GPU particle system emitting drifting industrial ash flakes
## and black embers/soot around the player/camera to amplify the hostile, desolate atmosphere.
## Kept economical (< 150 particles, 1 draw call, unshaded) for high performance.

@export var box_extents: Vector3 = Vector3(24.0, 10.0, 24.0)
@export var wind_direction: Vector3 = Vector3(0.7, -0.45, 0.3)
@export var fall_speed: float = 1.0
@export var ember_color: Color = Color(0.0, 0.0, 0.0, 0.85)

func _ready() -> void:
	amount = 120
	lifetime = 4.5
	preprocess = 2.0
	explosiveness = 0.0
	randomness = 0.75
	local_coords = false

	if draw_pass_1 == null:
		var quad = QuadMesh.new()
		quad.size = Vector2(0.16, 0.16)
		draw_pass_1 = quad

	if material_override == null:
		material_override = create_ash_material()

	if process_material == null:
		process_material = create_process_material(box_extents, wind_direction, fall_speed, ember_color)

static func create_ash_material() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.proximity_fade_enabled = true
	mat.proximity_fade_distance = 0.4
	mat.albedo_texture = create_speckle_texture()
	return mat

static func create_speckle_texture() -> GradientTexture2D:
	var grad = Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.95))
	grad.set_offset(0, 0.0)
	grad.add_point(0.35, Color(1, 1, 1, 0.7))
	grad.set_color(2, Color(1, 1, 1, 0.0))
	grad.set_offset(2, 1.0)

	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 32
	tex.height = 32
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex

static func create_process_material(extents: Vector3, wind_dir: Vector3, speed: float, p_ember_color: Color = Color(0.0, 0.0, 0.0, 0.85)) -> ParticleProcessMaterial:
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = extents
	mat.direction = wind_dir.normalized()
	mat.spread = 25.0
	mat.initial_velocity_min = speed * 0.6
	mat.initial_velocity_max = speed * 1.4
	mat.gravity = Vector3(0.0, -0.4, 0.0)
	mat.scale_min = 0.6
	mat.scale_max = 1.8
	mat.angle_min = -180.0
	mat.angle_max = 180.0

	var grad = Gradient.new()
	grad.set_color(0, Color(0.18, 0.17, 0.18, 0.0))
	grad.set_offset(0, 0.0)
	grad.add_point(0.2, Color(0.18, 0.17, 0.18, 0.7))
	grad.add_point(0.5, p_ember_color) # Black ember / soot
	grad.set_color(3, Color(0.12, 0.11, 0.12, 0.0))
	grad.set_offset(3, 1.0)

	var color_ramp = GradientTexture1D.new()
	color_ramp.gradient = grad
	mat.color_ramp = color_ramp
	return mat

