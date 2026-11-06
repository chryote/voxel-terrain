class_name ExtremeDistanceTerrain
extends MeshInstance3D

## Visual instance rendering the entire continent surface at lowest polygon density
## with dynamic circular clipping and dither transition matching active view distance.

const ExtremeDistanceMesherClass = preload("res://src/meshing/extreme_distance_terrain_mesher.gd")
const MaterialProviderClass = preload("res://src/rendering/extreme_distance_material_provider.gd")

var mesher: ExtremeDistanceMesherClass = ExtremeDistanceMesherClass.new()
var macro_material: ShaderMaterial = null
var is_mesh_ready: bool = false

var _task_id: int = -1
var _pending_mesh_data: MeshData = null
var _mutex: Mutex = Mutex.new()

func setup(
	bounds: WorldBounds,
	generator: TerrainGenerator,
	registry: MaterialRegistry = null,
	resolution: int = 128,
	theme: Resource = null,
	run_async: bool = true
) -> void:
	macro_material = MaterialProviderClass.get_material(theme)
	material_override = macro_material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	if run_async:
		_task_id = WorkerThreadPool.add_task(
			Callable(self, "_bg_build_mesh").bind(bounds, generator, registry, resolution)
		)
	else:
		var data = mesher.build_mesh(generator, bounds, registry, resolution)
		_apply_mesh_data(data)

func _bg_build_mesh(
	bounds: WorldBounds,
	generator: TerrainGenerator,
	registry: MaterialRegistry,
	resolution: int
) -> void:
	var data = mesher.build_mesh(generator, bounds, registry, resolution)
	_mutex.lock()
	_pending_mesh_data = data
	_mutex.unlock()

func _process(_delta: float) -> void:
	if _task_id != -1 and WorkerThreadPool.is_task_completed(_task_id):
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1

		var data: MeshData = null
		_mutex.lock()
		data = _pending_mesh_data
		_pending_mesh_data = null
		_mutex.unlock()

		if data != null:
			_apply_mesh_data(data)

func _apply_mesh_data(data: MeshData) -> void:
	if data == null or data.is_empty():
		return
	mesh = data.create_array_mesh()
	is_mesh_ready = true

func update_clip(focus_pos: Vector3, clip_radius: float, clip_feather: float = 16.0) -> void:
	if macro_material == null:
		return
	macro_material.set_shader_parameter("u_clip_center", focus_pos)
	macro_material.set_shader_parameter("u_clip_radius", clip_radius)
	macro_material.set_shader_parameter("u_clip_feather", clip_feather)

func set_macro_visible(p_visible: bool) -> void:
	if visible != p_visible:
		visible = p_visible

func set_atmospheric_haze(color: Color = Color(0.92, 0.54, 0.45, 1.0), intensity: float = 0.55, start_dist: float = 300.0, max_dist: float = 3500.0, enabled: bool = true) -> void:
	if macro_material == null:
		return
	macro_material.set_shader_parameter("atmosphere_enabled", enabled)
	macro_material.set_shader_parameter("haze_color", color)
	macro_material.set_shader_parameter("haze_intensity", intensity)
	macro_material.set_shader_parameter("haze_start_distance", start_dist)
	macro_material.set_shader_parameter("haze_max_distance", max_dist)

func set_monochromatic_palette(
	low: Color = Color(0.68, 0.52, 0.52, 1.0),
	mid: Color = Color(0.82, 0.62, 0.56, 1.0),
	high: Color = Color(0.92, 0.72, 0.60, 1.0),
	blend: float = 0.95,
	start_dist: float = -1.0,
	full_dist: float = 360.0,
	enabled: bool = true
) -> void:
	if macro_material == null:
		return
	macro_material.set_shader_parameter("mono_color_enabled", enabled)
	macro_material.set_shader_parameter("mono_color_blend", blend)
	macro_material.set_shader_parameter("mono_blue_low", low)
	macro_material.set_shader_parameter("mono_blue_mid", mid)
	macro_material.set_shader_parameter("mono_blue_high", high)
	macro_material.set_shader_parameter("mono_distance_start", start_dist)
	macro_material.set_shader_parameter("mono_distance_full", full_dist)

func set_pixel_art_style(enabled: bool = true, size: float = 4.0, terrace: float = 16.0, depth_step: float = 800.0) -> void:
	if macro_material == null:
		return
	macro_material.set_shader_parameter("pixel_art_enabled", enabled)
	macro_material.set_shader_parameter("pixel_size", size)
	macro_material.set_shader_parameter("terrace_step", terrace)
	macro_material.set_shader_parameter("depth_step_distance", depth_step)

func set_pixel_art_palette(
	shadow: Color = Color(0.68, 0.52, 0.52, 1.0),
	base: Color = Color(0.82, 0.62, 0.56, 1.0),
	lit: Color = Color(0.92, 0.72, 0.60, 1.0),
	highlight: Color = Color(0.98, 0.84, 0.72, 1.0)
) -> void:
	if macro_material == null:
		return
	macro_material.set_shader_parameter("palette_shadow", shadow)
	macro_material.set_shader_parameter("palette_base", base)
	macro_material.set_shader_parameter("palette_lit", lit)
	macro_material.set_shader_parameter("palette_highlight", highlight)

func _exit_tree() -> void:
	_reclaim_task()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_reclaim_task()

func _reclaim_task() -> void:
	if _task_id != -1:
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1

