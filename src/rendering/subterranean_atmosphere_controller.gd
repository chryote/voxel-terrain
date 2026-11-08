class_name SubterraneanAtmosphereController
extends Node3D

## Exclusive subterranean atmosphere controller managing dynamic transitions
## between surface desolate post-apocalyptic environment and underground Crimson Rot / Creature Stomach vibe.
## Dynamically configures WorldEnvironment (fog, ambient light, volumetric fog, sky), DirectionalLight3D,
## GraphicNovelPostProcess, and AshFallEmitter (embers disabled underground).

@export var world_environment: WorldEnvironment
@export var directional_light: DirectionalLight3D
@export var post_process: Node3D
@export var ash_emitter: GPUParticles3D
@export var voxel_world: Node3D
@export var rot_fog_volume: FogVolume

# Active transition state
var is_underground: bool = false
var transition_progress: float = 0.0 # 0.0 = surface, 1.0 = underground
var transition_speed: float = 3.5 # Fast smooth transition (~0.3s)
var _is_initialized: bool = false

# Cached surface baseline values (captured from scene on ready)
var _surface_ambient_color: Color = Color(0.24, 0.29, 0.25, 1.0)
var _surface_ambient_energy: float = 0.50
var _surface_fog_color: Color = Color(0.22, 0.28, 0.24, 1.0)
var _surface_fog_density: float = 0.012
var _surface_fog_aerial: float = 0.80
var _surface_fog_height: float = 24.0
var _surface_fog_height_density: float = 0.15
var _surface_fog_depth_begin: float = 10.0
var _surface_fog_depth_end: float = 100.0
var _surface_vol_fog_albedo: Color = Color(0.38, 0.44, 0.39, 1.0)
var _surface_vol_fog_emission: Color = Color(0.08, 0.10, 0.08, 1.0)
var _surface_vol_fog_emission_energy: float = 0.40
var _surface_vol_fog_density: float = 0.028
var _surface_light_color: Color = Color(0.78, 0.82, 0.76, 1.0)
var _surface_light_energy: float = 0.85
var _surface_vignette_color: Color = Color(0.02, 0.02, 0.03, 1.0)
var _surface_vignette_intensity: float = 0.45
var _surface_outline_color: Color = Color(0.05, 0.05, 0.07, 1.0)
var _surface_outline_thickness: float = 1.2
var _surface_sky_top: Color = Color(0.10, 0.14, 0.11, 1.0)
var _surface_sky_high: Color = Color(0.18, 0.25, 0.19, 1.0)
var _surface_sky_mid: Color = Color(0.27, 0.38, 0.28, 1.0)
var _surface_sky_low: Color = Color(0.23, 0.32, 0.24, 1.0)
var _surface_sky_horizon: Color = Color(0.20, 0.26, 0.22, 1.0)
var _surface_ground_horizon: Color = Color(0.12, 0.16, 0.13, 1.0)
var _surface_ground_bottom: Color = Color(0.06, 0.08, 0.06, 1.0)
var _surface_adjustment_saturation: float = 0.85
var _surface_adjustment_contrast: float = 1.08

# Underground Crimson Rot / Lake of Rot / High-Contrast Graphic Horror target values:
const ROT_AMBIENT_COLOR: Color = Color(0.55, 0.04, 0.07, 1.0)
const ROT_AMBIENT_ENERGY: float = 1
const ROT_FOG_COLOR: Color = Color(0.48, 0.04, 0.07, 1.0)
const ROT_FOG_DENSITY: float = 0.0006
const ROT_FOG_AERIAL: float = 0.35
const ROT_FOG_HEIGHT_DENSITY: float = 0.0
const ROT_FOG_DEPTH_BEGIN: float = 35.0
const ROT_FOG_DEPTH_END: float = 150.0
const ROT_VOL_FOG_ALBEDO: Color = Color(0.85, 0.08, 0.14, 1.0)
const ROT_VOL_FOG_EMISSION: Color = Color(0.04, 0.003, 0.006, 1.0)
const ROT_VOL_FOG_EMISSION_ENERGY: float = 0.50
# Global volumetric fog underground is 0.0 so distant cavern structures remain clear
const ROT_VOL_FOG_DENSITY: float = 0.0

# Option A: Local player-centered rot fog volume exclusively on underground level
const ROT_LOCAL_FOG_DENSITY: float = 0.18
const ROT_LOCAL_FOG_ALBEDO: Color = Color(0.85, 0.08, 0.14, 1.0)
const ROT_LOCAL_FOG_EMISSION: Color = Color(0.05, 0.003, 0.006, 1.0)
const ROT_LOCAL_FOG_EDGE_FADE: float = 0.40
const ROT_LIGHT_COLOR: Color = Color(1.0, 0.35, 0.40, 1.0)
const ROT_LIGHT_ENERGY: float = 0.85
const ROT_VIGNETTE_COLOR: Color = Color(0.25, 0.00, 0.03, 1.0)
const ROT_VIGNETTE_INTENSITY: float = 0.62
const ROT_OUTLINE_COLOR: Color = Color(1.0, 0.06, 0.15, 1.0)
const ROT_OUTLINE_THICKNESS: float = 1.6
const ROT_SKY_TOP: Color = Color(0.12, 0.01, 0.02, 1.0)
const ROT_SKY_HIGH: Color = Color(0.28, 0.02, 0.05, 1.0)
const ROT_SKY_MID: Color = Color(0.55, 0.05, 0.10, 1.0)
const ROT_SKY_LOW: Color = Color(0.42, 0.04, 0.08, 1.0)
const ROT_SKY_HORIZON: Color = Color(0.32, 0.03, 0.06, 1.0)
const ROT_GROUND_HORIZON: Color = Color(0.18, 0.01, 0.03, 1.0)
const ROT_GROUND_BOTTOM: Color = Color(0.08, 0.00, 0.01, 1.0)
const ROT_ADJUSTMENT_SATURATION: float = 1.38
const ROT_ADJUSTMENT_CONTRAST: float = 1.32

func _ready() -> void:
	_capture_surface_baseline()
	_ensure_rot_fog_volume()
	if voxel_world != null:
		if not voxel_world.spawn_mode_changed.is_connected(_on_spawn_mode_changed):
			voxel_world.spawn_mode_changed.connect(_on_spawn_mode_changed)
		if not voxel_world.subterranean_transition_changed.is_connected(_on_subterranean_transition_changed):
			voxel_world.subterranean_transition_changed.connect(_on_subterranean_transition_changed)
		var start_ug = voxel_world.spawn_on_underground_arena and voxel_world.caves_enabled
		set_underground_mode(start_ug, true)

func _ensure_rot_fog_volume() -> void:
	if rot_fog_volume != null and is_instance_valid(rot_fog_volume):
		return
	if voxel_world != null and voxel_world.get("focus_target") != null:
		var ft = voxel_world.focus_target
		if ft != null:
			rot_fog_volume = ft.get_node_or_null("RotFogVolume") as FogVolume
	if rot_fog_volume == null:
		var p = get_node_or_null("../Player")
		if p != null:
			rot_fog_volume = p.get_node_or_null("RotFogVolume") as FogVolume

func _process(delta: float) -> void:
	var target_t = 1.0 if is_underground else 0.0
	if not is_equal_approx(transition_progress, target_t):
		transition_progress = move_toward(transition_progress, target_t, delta * transition_speed)
		_apply_atmosphere(transition_progress)

func set_underground_mode(p_underground: bool, immediate: bool = false) -> void:
	is_underground = p_underground
	if immediate:
		transition_progress = 1.0 if is_underground else 0.0
		_apply_atmosphere(transition_progress)
	_update_ember_particles(is_underground)

func _update_ember_particles(underground_active: bool) -> void:
	if ash_emitter != null and is_instance_valid(ash_emitter):
		ash_emitter.set_emitter_enabled(not underground_active)

func _on_spawn_mode_changed(p_underground: bool, _pos: Vector3) -> void:
	set_underground_mode(p_underground, true)

func _on_subterranean_transition_changed(p_underground: bool) -> void:
	set_underground_mode(p_underground, false)

func _capture_surface_baseline() -> void:
	if _is_initialized:
		return
	if world_environment != null and world_environment.environment != null:
		var env = world_environment.environment
		_surface_ambient_color = env.ambient_light_color
		_surface_ambient_energy = env.ambient_light_energy
		_surface_fog_color = env.fog_light_color
		_surface_fog_density = env.fog_density
		_surface_fog_aerial = env.fog_aerial_perspective
		_surface_fog_height = env.fog_height
		_surface_fog_height_density = env.fog_height_density
		_surface_fog_depth_begin = env.fog_depth_begin
		_surface_fog_depth_end = env.fog_depth_end
		_surface_vol_fog_albedo = env.volumetric_fog_albedo
		_surface_vol_fog_emission = env.volumetric_fog_emission
		_surface_vol_fog_emission_energy = env.volumetric_fog_emission_energy
		_surface_vol_fog_density = env.volumetric_fog_density
		_surface_adjustment_saturation = env.adjustment_saturation
		_surface_adjustment_contrast = env.adjustment_contrast
		if env.sky != null and env.sky.sky_material is ShaderMaterial:
			var sm = env.sky.sky_material as ShaderMaterial
			_surface_sky_top = sm.get_shader_parameter("sky_top_color") if sm.get_shader_parameter("sky_top_color") != null else _surface_sky_top
			_surface_sky_high = sm.get_shader_parameter("sky_high_color") if sm.get_shader_parameter("sky_high_color") != null else _surface_sky_high
			_surface_sky_mid = sm.get_shader_parameter("sky_mid_color") if sm.get_shader_parameter("sky_mid_color") != null else _surface_sky_mid
			_surface_sky_low = sm.get_shader_parameter("sky_low_color") if sm.get_shader_parameter("sky_low_color") != null else _surface_sky_low
			_surface_sky_horizon = sm.get_shader_parameter("sky_horizon_color") if sm.get_shader_parameter("sky_horizon_color") != null else _surface_sky_horizon
			_surface_ground_horizon = sm.get_shader_parameter("ground_horizon_color") if sm.get_shader_parameter("ground_horizon_color") != null else _surface_ground_horizon
			_surface_ground_bottom = sm.get_shader_parameter("ground_bottom_color") if sm.get_shader_parameter("ground_bottom_color") != null else _surface_ground_bottom

	if directional_light != null and is_instance_valid(directional_light):
		_surface_light_color = directional_light.light_color
		_surface_light_energy = directional_light.light_energy

	if post_process != null and is_instance_valid(post_process):
		if post_process.post_material == null and post_process.has_method("_setup_fullscreen_quad"):
			post_process._setup_fullscreen_quad()
			post_process.apply_config()
		if post_process.post_material != null:
			var pm = post_process.post_material
			_surface_vignette_color = pm.get_shader_parameter("vignette_color") if pm.get_shader_parameter("vignette_color") != null else _surface_vignette_color
			_surface_vignette_intensity = float(pm.get_shader_parameter("vignette_intensity")) if pm.get_shader_parameter("vignette_intensity") != null else _surface_vignette_intensity
			_surface_outline_color = pm.get_shader_parameter("outline_color") if pm.get_shader_parameter("outline_color") != null else _surface_outline_color
			_surface_outline_thickness = float(pm.get_shader_parameter("outline_thickness")) if pm.get_shader_parameter("outline_thickness") != null else _surface_outline_thickness

	_is_initialized = true

func _apply_atmosphere(t: float) -> void:
	if world_environment != null and world_environment.environment != null:
		var env = world_environment.environment
		env.ambient_light_color = _surface_ambient_color.lerp(ROT_AMBIENT_COLOR, t)
		env.ambient_light_energy = lerpf(_surface_ambient_energy, ROT_AMBIENT_ENERGY, t)
		env.fog_light_color = _surface_fog_color.lerp(ROT_FOG_COLOR, t)
		env.fog_density = lerpf(_surface_fog_density, ROT_FOG_DENSITY, t)
		env.fog_aerial_perspective = lerpf(_surface_fog_aerial, ROT_FOG_AERIAL, t)
		env.fog_height_density = lerpf(_surface_fog_height_density, ROT_FOG_HEIGHT_DENSITY, t)
		env.fog_depth_begin = lerpf(_surface_fog_depth_begin, ROT_FOG_DEPTH_BEGIN, t)
		env.fog_depth_end = lerpf(_surface_fog_depth_end, ROT_FOG_DEPTH_END, t)
		env.volumetric_fog_albedo = _surface_vol_fog_albedo.lerp(ROT_VOL_FOG_ALBEDO, t)
		env.volumetric_fog_emission = _surface_vol_fog_emission.lerp(ROT_VOL_FOG_EMISSION, t)
		env.volumetric_fog_emission_energy = lerpf(_surface_vol_fog_emission_energy, ROT_VOL_FOG_EMISSION_ENERGY, t)
		env.volumetric_fog_density = lerpf(_surface_vol_fog_density, ROT_VOL_FOG_DENSITY, t)
		env.adjustment_saturation = lerpf(_surface_adjustment_saturation, ROT_ADJUSTMENT_SATURATION, t)
		env.adjustment_contrast = lerpf(_surface_adjustment_contrast, ROT_ADJUSTMENT_CONTRAST, t)

		if env.sky != null and env.sky.sky_material is ShaderMaterial:
			var sm = env.sky.sky_material as ShaderMaterial
			sm.set_shader_parameter("sky_top_color", _surface_sky_top.lerp(ROT_SKY_TOP, t))
			sm.set_shader_parameter("sky_high_color", _surface_sky_high.lerp(ROT_SKY_HIGH, t))
			sm.set_shader_parameter("sky_mid_color", _surface_sky_mid.lerp(ROT_SKY_MID, t))
			sm.set_shader_parameter("sky_low_color", _surface_sky_low.lerp(ROT_SKY_LOW, t))
			sm.set_shader_parameter("sky_horizon_color", _surface_sky_horizon.lerp(ROT_SKY_HORIZON, t))
			sm.set_shader_parameter("ground_horizon_color", _surface_ground_horizon.lerp(ROT_GROUND_HORIZON, t))
			sm.set_shader_parameter("ground_bottom_color", _surface_ground_bottom.lerp(ROT_GROUND_BOTTOM, t))
			sm.set_shader_parameter("sun_enabled", t < 0.5)

	if directional_light != null and is_instance_valid(directional_light):
		directional_light.light_color = _surface_light_color.lerp(ROT_LIGHT_COLOR, t)
		directional_light.light_energy = lerpf(_surface_light_energy, ROT_LIGHT_ENERGY, t)

	if post_process != null and is_instance_valid(post_process):
		if post_process.post_material == null and post_process.has_method("_setup_fullscreen_quad"):
			post_process._setup_fullscreen_quad()
			post_process.apply_config()
		if post_process.post_material != null:
			var pm = post_process.post_material
			pm.set_shader_parameter("vignette_color", _surface_vignette_color.lerp(ROT_VIGNETTE_COLOR, t))
			pm.set_shader_parameter("vignette_intensity", lerpf(_surface_vignette_intensity, ROT_VIGNETTE_INTENSITY, t))
			pm.set_shader_parameter("outline_color", _surface_outline_color.lerp(ROT_OUTLINE_COLOR, t))
			pm.set_shader_parameter("outline_thickness", lerpf(_surface_outline_thickness, ROT_OUTLINE_THICKNESS, t))

	if rot_fog_volume == null:
		_ensure_rot_fog_volume()

	if rot_fog_volume != null and is_instance_valid(rot_fog_volume):
		rot_fog_volume.visible = (t > 0.001)
		if rot_fog_volume.material is FogMaterial:
			var fm = rot_fog_volume.material as FogMaterial
			fm.density = lerpf(0.0, ROT_LOCAL_FOG_DENSITY, t)
			fm.albedo = ROT_LOCAL_FOG_ALBEDO
			fm.emission = ROT_LOCAL_FOG_EMISSION
			fm.edge_fade = ROT_LOCAL_FOG_EDGE_FADE

