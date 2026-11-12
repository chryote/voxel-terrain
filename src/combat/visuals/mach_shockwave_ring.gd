class_name MachShockwaveRing
extends Node3D

## Visual supersonic Mach vapor ring (Prandtl-Glauert singularity).
## Spawns perpendicular to the blade trajectory when kinetic energy exceeds 50k Joules (Tier 2+).
## Expands rapidly outward in a conical shockwave collar and fades out to simulate a sonic boom.

@export var duration: float = 0.16
@export var initial_radius: float = 0.6
@export var target_radius: float = 3.4
@export var cone_depth: float = 0.45

var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D
var _time_elapsed: float = 0.0
var _is_animating: bool = false

func _init() -> void:
	top_level = true

func _ready() -> void:
	_setup_mesh()

func _setup_mesh() -> void:
	if _mesh_instance != null:
		return

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "MachRingMesh"

	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = Color(1.0, 1.0, 1.0, 0.85)
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	_mesh_instance.material_override = _material
	add_child(_mesh_instance)
	_update_ring_mesh(initial_radius, 0.85)

func _update_ring_mesh(radius: float, alpha: float) -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var segments = 28
	var ring_thickness = maxf(0.12 * (1.0 - (_time_elapsed / maxf(duration, 0.001))), 0.02)
	var r_in = maxf(radius - ring_thickness, 0.05)
	var r_out = radius + ring_thickness
	var cone_z = -cone_depth * (_time_elapsed / maxf(duration, 0.001))

	var color_edge = Color(0.9, 0.96, 1.0, alpha * 0.9)
	var color_inner = Color(1.0, 1.0, 1.0, alpha)

	for i in range(segments):
		var theta0 = float(i) * TAU / float(segments)
		var theta1 = float(i + 1) * TAU / float(segments)

		var c0 = cos(theta0)
		var s0 = sin(theta0)
		var c1 = cos(theta1)
		var s1 = sin(theta1)

		# Outer vertices (pushed slightly forward/cone shape)
		var p0_out = Vector3(c0 * r_out, s0 * r_out, cone_z)
		var p1_out = Vector3(c1 * r_out, s1 * r_out, cone_z)

		# Inner vertices
		var p0_in = Vector3(c0 * r_in, s0 * r_in, 0.0)
		var p1_in = Vector3(c1 * r_in, s1 * r_in, 0.0)

		# Quad (2 triangles)
		st.set_color(color_inner)
		st.add_vertex(p0_in)
		st.set_color(color_edge)
		st.add_vertex(p0_out)
		st.set_color(color_edge)
		st.add_vertex(p1_out)

		st.set_color(color_inner)
		st.add_vertex(p0_in)
		st.set_color(color_edge)
		st.add_vertex(p1_out)
		st.set_color(color_inner)
		st.add_vertex(p1_in)

	_mesh_instance.mesh = st.commit()

func play(start_xform: Transform3D, travel_dir: Vector3, anim_duration: float = 0.16) -> void:
	global_transform = start_xform
	# Orient ring so its local Z points along travel_dir (perpendicular to slash plane)
	if travel_dir.length_squared() > 0.001:
		var norm_dir = travel_dir.normalized()
		var up_axis = Vector3.UP if absf(norm_dir.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
		look_at(global_position + norm_dir, up_axis)

	duration = anim_duration
	_time_elapsed = 0.0
	_is_animating = true
	_setup_mesh()

func _process(delta: float) -> void:
	if not _is_animating:
		return

	_time_elapsed += delta
	var progress = clampf(_time_elapsed / maxf(duration, 0.001), 0.0, 1.0)
	var cur_radius = lerpf(initial_radius, target_radius, ease(progress, 0.35))
	var alpha = (1.0 - progress) * 0.85

	if _material != null:
		_material.albedo_color.a = alpha

	_update_ring_mesh(cur_radius, alpha)

	if progress >= 1.0:
		_is_animating = false
		queue_free()

## Static spawner helper to quickly instantiate and play a Mach ring.
static func spawn_mach_ring(
	parent: Node,
	pos: Vector3,
	travel_dir: Vector3,
	anim_duration: float = 0.16,
	init_rad: float = 0.6,
	max_rad: float = 3.4
) -> MachShockwaveRing:
	if parent == null or not parent.is_inside_tree():
		return null

	var ring = (load("res://src/combat/visuals/mach_shockwave_ring.gd") as GDScript).new()
	ring.initial_radius = init_rad
	ring.target_radius = max_rad
	parent.add_child(ring)

	var xform = Transform3D()
	xform.origin = pos
	ring.play(xform, travel_dir, anim_duration)
	return ring

