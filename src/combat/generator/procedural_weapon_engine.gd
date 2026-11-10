class_name ProceduralWeaponEngine
extends RefCounted

## Dedicated Procedural Engine to generate modular weapons.
## Generates discrete voxel structures that are ~1 block height in total scale,
## elongated along the primary axis (imitating a weapon or tool),
## paired with crisp 2D pixel icons for UI and HUD.
## Combat execution & attack patterns remain strictly governed by TechniqueCards.

const MeleeWeaponDef = preload("res://src/combat/core/melee_weapon_def.gd")
const WeaponIconFactory = preload("res://src/combat/ui/weapon_icon_factory.gd")

enum VoxelType {
	EMPTY = 0,
	HANDLE = 1,     # Grip and pommel wrapping
	JUNCTION = 2,   # Collar, reinforcement, and socket brackets
	BODY = 3,       # Primary structural frame alloy
	EDGE = 4,       # Striking perimeter / polished edge voxels
	ENERGY = 5,     # Glowing mana/tech conduits and crystals
	ACCENT = 6      # Trim, gold, brass, or magnetic coils
}

enum WeaponProfile {
	BALANCED = 0,
	SLENDER = 1,
	HEAVY = 2,
	SEGMENTED = 3,
	FLANGED = 4
}

const DEFAULT_VOXEL_SIZE: float = 0.045 # 24 voxels * 0.045m = 1.08m (~1 world block height)
const TARGET_WEAPON_HEIGHT_VOXELS: int = 24
const DEFAULT_GRID_WIDTH: int = 7
const DEFAULT_GRID_DEPTH: int = 3
const JUNCTION_Y: int = 5

const NAME_PREFIXES: Array[String] = [
	"Tempered", "Resonant", "Voxel", "Kinetic", "Prismatic",
	"Aether", "Phase", "Runic", "Stellite", "Obsidian",
	"Cobalt", "Basalt", "Alloy", "Apex", "Fractal",
	"Modular", "Harmonic", "Vector", "Quantized", "Primal"
]

const PALETTES: Array[Dictionary] = [
	{
		"name": "Aether Steel",
		"handle": Color(0.16, 0.17, 0.20),
		"junction": Color(0.42, 0.45, 0.50),
		"body": Color(0.75, 0.80, 0.88),
		"edge": Color(0.92, 0.95, 1.0),
		"energy": Color(0.20, 0.85, 1.0),
		"accent": Color(0.90, 0.75, 0.30)
	},
	{
		"name": "Molten Basalt",
		"handle": Color(0.12, 0.10, 0.10),
		"junction": Color(0.24, 0.22, 0.22),
		"body": Color(0.32, 0.28, 0.30),
		"edge": Color(0.72, 0.25, 0.20),
		"energy": Color(1.0, 0.48, 0.12),
		"accent": Color(0.78, 0.50, 0.24)
	},
	{
		"name": "Verdant Jade",
		"handle": Color(0.10, 0.15, 0.12),
		"junction": Color(0.35, 0.38, 0.30),
		"body": Color(0.28, 0.55, 0.38),
		"edge": Color(0.62, 0.85, 0.70),
		"energy": Color(0.25, 1.0, 0.55),
		"accent": Color(0.95, 0.82, 0.30)
	},
	{
		"name": "Void Amethyst",
		"handle": Color(0.12, 0.08, 0.16),
		"junction": Color(0.28, 0.24, 0.34),
		"body": Color(0.46, 0.38, 0.54),
		"edge": Color(0.76, 0.56, 0.88),
		"energy": Color(0.95, 0.30, 0.95),
		"accent": Color(0.85, 0.85, 0.92)
	},
	{
		"name": "Frost Cobalt",
		"handle": Color(0.08, 0.10, 0.16),
		"junction": Color(0.25, 0.35, 0.52),
		"body": Color(0.46, 0.62, 0.80),
		"edge": Color(0.86, 0.94, 1.0),
		"energy": Color(0.40, 0.90, 1.0),
		"accent": Color(0.95, 0.98, 1.0)
	},
	{
		"name": "Brass Mechanum",
		"handle": Color(0.22, 0.16, 0.12),
		"junction": Color(0.28, 0.28, 0.28),
		"body": Color(0.66, 0.54, 0.30),
		"edge": Color(0.88, 0.76, 0.40),
		"energy": Color(1.0, 0.82, 0.22),
		"accent": Color(0.82, 0.46, 0.28)
	}
]

## Primary generation method: produces a fully functional MeleeWeaponDef with 3D voxel mesh and 2D icon.
static func generate_weapon(seed_val: int = -1, params: Dictionary = {}) -> MeleeWeaponDef:
	if seed_val < 0:
		seed_val = int(Time.get_ticks_usec()) & 0x7FFFFFFF

	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val

	var profile_val = params.get("profile", rng.randi_range(0, 4))
	var profile: WeaponProfile = profile_val as WeaponProfile

	var palette: Dictionary = params.get("palette", _pick_palette(rng))
	var voxel_data: Dictionary = generate_voxel_matrix(rng, profile, palette)

	var icon_size: Vector2i = params.get("icon_size", Vector2i(28, 28))
	var icon_tex: ImageTexture = generate_weapon_icon(voxel_data, icon_size)

	var weapon_name: String = params.get("name", _generate_name(rng, profile, seed_val))
	var weapon_desc: String = params.get("description", _generate_description(profile, palette, voxel_data, seed_val))
	var stats: Dictionary = _generate_deck_stats(rng, profile, params)

	var weapon_def = MeleeWeaponDef.new()
	weapon_def.weapon_id = params.get("weapon_id", "proc_weapon_%d" % seed_val)
	weapon_def.display_name = weapon_name
	weapon_def.description = weapon_desc
	weapon_def.mesh_builder = load("res://src/combat/generator/procedural_weapon_engine.gd")
	weapon_def.icon = icon_tex
	weapon_def.slot_capacity = stats["slot_capacity"]
	weapon_def.is_shuffle = stats["is_shuffle"]
	weapon_def.deck_recharge_time = stats["deck_recharge_time"]
	weapon_def.base_damage_multiplier = stats["base_damage_multiplier"]
	weapon_def.stamina_cost_multiplier = stats["stamina_cost_multiplier"]
	weapon_def.float_offset_right = stats["float_offset_right"]
	weapon_def.float_offset_height = stats["float_offset_height"]
	weapon_def.float_offset_forward = stats["float_offset_forward"]
	weapon_def.float_tilt_degrees = stats["float_tilt_degrees"]
	weapon_def.procedural_data = voxel_data
	weapon_def.set_meta("voxel_data", voxel_data)
	weapon_def.set_meta("seed", seed_val)
	weapon_def.set_meta("profile", profile)

	if params.has("slotted_techniques"):
		weapon_def.slotted_techniques = params["slotted_techniques"].duplicate()

	WeaponIconFactory.register_weapon_icon(weapon_def.weapon_id, icon_tex)
	return weapon_def

## Generates the discrete 3D voxel structure and 2D projection matrix.
static func generate_voxel_matrix(rng: RandomNumberGenerator, profile: WeaponProfile, palette: Dictionary) -> Dictionary:
	var h = TARGET_WEAPON_HEIGHT_VOXELS
	var w = DEFAULT_GRID_WIDTH
	var d = DEFAULT_GRID_DEPTH
	var cx = w / 2
	var cz = d / 2

	var grid_3d: Array = []
	for x in range(w):
		var y_arr: Array = []
		for y in range(h):
			var z_arr: Array = []
			z_arr.resize(d)
			z_arr.fill(VoxelType.EMPTY)
			y_arr.append(z_arr)
		grid_3d.append(y_arr)

	var grid_2d: Array = []
	for y in range(h):
		var x_arr: Array = []
		x_arr.resize(w)
		x_arr.fill(VoxelType.EMPTY)
		grid_2d.append(x_arr)

	var set_voxel = func(x: int, y: int, z: int, v_type: int) -> void:
		if x >= 0 and x < w and y >= 0 and y < h and z >= 0 and z < d:
			grid_3d[x][y][z] = v_type
			if z == cz or grid_2d[y][x] == VoxelType.EMPTY or v_type == VoxelType.ENERGY:
				grid_2d[y][x] = v_type

	var set_symmetric = func(dx: int, y: int, z: int, v_type: int) -> void:
		set_voxel.call(cx + dx, y, z, v_type)
		if dx != 0:
			set_voxel.call(cx - dx, y, z, v_type)

	# --- 1. Base and Pommel (y = 0) ---
	set_symmetric.call(0, 0, cz, VoxelType.ACCENT)
	if profile == WeaponProfile.HEAVY or profile == WeaponProfile.FLANGED:
		set_symmetric.call(1, 0, cz, VoxelType.JUNCTION)

	# --- 2. Handle / Grip (y = 1 to 4) ---
	for gy in range(1, JUNCTION_Y):
		set_symmetric.call(0, gy, cz, VoxelType.HANDLE)
		if gy % 2 == 0:
			set_symmetric.call(0, gy, cz, VoxelType.ACCENT)

	# --- 3. Collar / Junction (y = 5) ---
	var guard_w = 2
	if profile == WeaponProfile.SLENDER:
		guard_w = 1
	elif profile == WeaponProfile.HEAVY:
		guard_w = 3

	for gx in range(guard_w + 1):
		set_symmetric.call(gx, JUNCTION_Y, cz, VoxelType.JUNCTION)
		if cz > 0:
			set_symmetric.call(gx, JUNCTION_Y, cz - 1, VoxelType.JUNCTION)
			set_symmetric.call(gx, JUNCTION_Y, cz + 1, VoxelType.JUNCTION)

	# --- 4. Shaft / Body (y = 6 to 18) ---
	match profile:
		WeaponProfile.SLENDER:
			for sy in range(6, 19):
				set_symmetric.call(0, sy, cz, VoxelType.BODY)
				if sy <= 10:
					set_symmetric.call(1, sy, cz, VoxelType.EDGE)
				elif sy % 3 == 0:
					set_symmetric.call(0, sy, cz, VoxelType.ENERGY)

		WeaponProfile.HEAVY:
			for sy in range(6, 19):
				set_symmetric.call(0, sy, cz, VoxelType.BODY)
				set_symmetric.call(1, sy, cz, VoxelType.BODY)
				set_symmetric.call(2, sy, cz, VoxelType.EDGE)
				# 3D reinforcement depth
				if cz > 0:
					set_symmetric.call(0, sy, cz - 1, VoxelType.BODY)
					set_symmetric.call(0, sy, cz + 1, VoxelType.BODY)
				if sy % 4 == 0:
					set_symmetric.call(0, sy, cz, VoxelType.ENERGY)

		WeaponProfile.SEGMENTED:
			# 3 distinct voxel modules separated by floating energy conduits
			for sy in range(6, 19):
				if sy == 9 or sy == 14:
					# Pure energy gap
					set_symmetric.call(0, sy, cz, VoxelType.ENERGY)
				else:
					set_symmetric.call(0, sy, cz, VoxelType.BODY)
					set_symmetric.call(1, sy, cz, VoxelType.EDGE)

		WeaponProfile.FLANGED:
			for sy in range(6, 19):
				set_symmetric.call(0, sy, cz, VoxelType.BODY)
				set_symmetric.call(1, sy, cz, VoxelType.EDGE)
				if sy == 8 or sy == 11 or sy == 14 or sy == 17:
					set_symmetric.call(2, sy, cz, VoxelType.ACCENT)

		_: # BALANCED
			for sy in range(6, 19):
				set_symmetric.call(0, sy, cz, VoxelType.BODY)
				set_symmetric.call(1, sy, cz, VoxelType.EDGE)
				if sy >= 8 and sy <= 15 and sy % 2 == 1:
					set_symmetric.call(0, sy, cz, VoxelType.ENERGY)

	# --- 5. Head / Emitter / Tip (y = 19 to 23) ---
	match profile:
		WeaponProfile.SLENDER:
			for hy in range(19, 23):
				set_symmetric.call(0, hy, cz, VoxelType.BODY)
			set_symmetric.call(0, 23, cz, VoxelType.ENERGY) # Needle emitter point

		WeaponProfile.HEAVY:
			# Broad hammer/block strike head
			for hy in range(19, 23):
				for hx in range(3):
					set_symmetric.call(hx, hy, cz, VoxelType.BODY)
					if cz > 0:
						set_symmetric.call(hx, hy, cz - 1, VoxelType.BODY)
						set_symmetric.call(hx, hy, cz + 1, VoxelType.BODY)
				set_symmetric.call(0, hy, cz, VoxelType.ENERGY)
			for hx in range(2):
				set_symmetric.call(hx, 23, cz, VoxelType.EDGE)

		WeaponProfile.SEGMENTED:
			# Forked dual emitter head
			set_symmetric.call(0, 19, cz, VoxelType.ENERGY)
			set_symmetric.call(1, 19, cz, VoxelType.JUNCTION)
			set_symmetric.call(1, 20, cz, VoxelType.EDGE)
			set_symmetric.call(1, 21, cz, VoxelType.EDGE)
			set_symmetric.call(1, 22, cz, VoxelType.ACCENT)
			set_symmetric.call(0, 21, cz, VoxelType.ENERGY) # Suspended energy core

		WeaponProfile.FLANGED:
			set_symmetric.call(0, 19, cz, VoxelType.BODY)
			set_symmetric.call(1, 19, cz, VoxelType.EDGE)
			set_symmetric.call(0, 20, cz, VoxelType.BODY)
			set_symmetric.call(1, 20, cz, VoxelType.EDGE)
			set_symmetric.call(0, 21, cz, VoxelType.EDGE)
			set_symmetric.call(0, 22, cz, VoxelType.EDGE)
			set_symmetric.call(0, 23, cz, VoxelType.ACCENT)

		_: # BALANCED
			set_symmetric.call(0, 19, cz, VoxelType.ENERGY)
			set_symmetric.call(1, 19, cz, VoxelType.EDGE)
			set_symmetric.call(0, 20, cz, VoxelType.ENERGY)
			set_symmetric.call(1, 20, cz, VoxelType.EDGE)
			set_symmetric.call(0, 21, cz, VoxelType.EDGE)
			set_symmetric.call(1, 21, cz, VoxelType.EDGE)
			set_symmetric.call(0, 22, cz, VoxelType.EDGE)
			set_symmetric.call(0, 23, cz, VoxelType.ACCENT)

	return {
		"grid_3d": grid_3d,
		"grid_2d": grid_2d,
		"width": w,
		"height": h,
		"depth": d,
		"center_x": cx,
		"center_z": cz,
		"junction_y": JUNCTION_Y,
		"profile": profile,
		"palette": palette
	}

## Builds the 3D voxel ArrayMesh with face culling between adjacent voxels.
static func build_weapon_mesh(voxel_data: Dictionary, voxel_size: float = DEFAULT_VOXEL_SIZE) -> ArrayMesh:
	var grid_3d: Array = voxel_data["grid_3d"]
	var w: int = voxel_data["width"]
	var h: int = voxel_data["height"]
	var d: int = voxel_data["depth"]
	var cx: int = voxel_data["center_x"]
	var cz: int = voxel_data["center_z"]
	var jy: int = voxel_data["junction_y"]
	var palette: Dictionary = voxel_data["palette"]

	var st_opaque = SurfaceTool.new()
	st_opaque.begin(Mesh.PRIMITIVE_TRIANGLES)

	var st_energy = SurfaceTool.new()
	st_energy.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half = voxel_size * 0.5
	var opaque_quad_count = 0
	var energy_quad_count = 0

	var color_map = {
		VoxelType.HANDLE: palette["handle"],
		VoxelType.JUNCTION: palette["junction"],
		VoxelType.BODY: palette["body"],
		VoxelType.EDGE: palette["edge"],
		VoxelType.ACCENT: palette["accent"],
		VoxelType.ENERGY: palette["energy"]
	}

	for x in range(w):
		for y in range(h):
			for z in range(d):
				var v_type = grid_3d[x][y][z]
				if v_type == VoxelType.EMPTY:
					continue

				var is_energy = (v_type == VoxelType.ENERGY)
				var st = st_energy if is_energy else st_opaque
				var col: Color = color_map.get(v_type, Color.WHITE)

				var center = Vector3(
					float(x - cx) * voxel_size,
					float(y - jy) * voxel_size,
					float(z - cz) * voxel_size
				)

				# Check all 6 faces: cull if adjacent voxel is solid
				# +Z (Front)
				if z + 1 >= d or grid_3d[x][y][z + 1] == VoxelType.EMPTY:
					_emit_quad(st, col, Vector3(0, 0, 1),
						center + Vector3(-half, -half, half),
						center + Vector3( half, -half, half),
						center + Vector3( half,  half, half),
						center + Vector3(-half,  half, half)
					)
					if is_energy:
						energy_quad_count += 1
					else:
						opaque_quad_count += 1

				# -Z (Back)
				if z - 1 < 0 or grid_3d[x][y][z - 1] == VoxelType.EMPTY:
					_emit_quad(st, col, Vector3(0, 0, -1),
						center + Vector3( half, -half, -half),
						center + Vector3(-half, -half, -half),
						center + Vector3(-half,  half, -half),
						center + Vector3( half,  half, -half)
					)
					if is_energy:
						energy_quad_count += 1
					else:
						opaque_quad_count += 1

				# +X (Right)
				if x + 1 >= w or grid_3d[x + 1][y][z] == VoxelType.EMPTY:
					_emit_quad(st, col, Vector3(1, 0, 0),
						center + Vector3(half, -half,  half),
						center + Vector3(half, -half, -half),
						center + Vector3(half,  half, -half),
						center + Vector3(half,  half,  half)
					)
					if is_energy:
						energy_quad_count += 1
					else:
						opaque_quad_count += 1

				# -X (Left)
				if x - 1 < 0 or grid_3d[x - 1][y][z] == VoxelType.EMPTY:
					_emit_quad(st, col, Vector3(-1, 0, 0),
						center + Vector3(-half, -half, -half),
						center + Vector3(-half, -half,  half),
						center + Vector3(-half,  half,  half),
						center + Vector3(-half,  half, -half)
					)
					if is_energy:
						energy_quad_count += 1
					else:
						opaque_quad_count += 1

				# +Y (Top)
				if y + 1 >= h or grid_3d[x][y + 1][z] == VoxelType.EMPTY:
					_emit_quad(st, col, Vector3(0, 1, 0),
						center + Vector3(-half, half,  half),
						center + Vector3( half, half,  half),
						center + Vector3( half, half, -half),
						center + Vector3(-half, half, -half)
					)
					if is_energy:
						energy_quad_count += 1
					else:
						opaque_quad_count += 1

				# -Y (Bottom)
				if y - 1 < 0 or grid_3d[x][y - 1][z] == VoxelType.EMPTY:
					_emit_quad(st, col, Vector3(0, -1, 0),
						center + Vector3(-half, -half, -half),
						center + Vector3( half, -half, -half),
						center + Vector3( half, -half,  half),
						center + Vector3(-half, -half,  half)
					)
					if is_energy:
						energy_quad_count += 1
					else:
						opaque_quad_count += 1

	var mesh = ArrayMesh.new()

	if opaque_quad_count > 0:
		var mat_opaque = StandardMaterial3D.new()
		mat_opaque.vertex_color_use_as_albedo = true
		mat_opaque.metallic = 0.78
		mat_opaque.roughness = 0.32
		mat_opaque.cull_mode = BaseMaterial3D.CULL_BACK
		st_opaque.set_material(mat_opaque)
		st_opaque.commit(mesh)

	if energy_quad_count > 0:
		var mat_energy = StandardMaterial3D.new()
		mat_energy.vertex_color_use_as_albedo = true
		mat_energy.emission_enabled = true
		mat_energy.emission = palette["energy"]
		mat_energy.emission_energy_multiplier = 3.5
		mat_energy.cull_mode = BaseMaterial3D.CULL_BACK
		st_energy.set_material(mat_energy)
		st_energy.commit(mesh)

	return mesh

## Emits a single quad into a SurfaceTool.
static func _emit_quad(st: SurfaceTool, color: Color, normal: Vector3, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3) -> void:
	st.set_color(color)
	st.set_normal(normal)
	st.add_vertex(v0)
	st.add_vertex(v1)
	st.add_vertex(v2)

	st.set_color(color)
	st.set_normal(normal)
	st.add_vertex(v0)
	st.add_vertex(v2)
	st.add_vertex(v3)

## Instantiates the 3D visual node hierarchy for FloatingSwordController.
static func create_weapon_node(weapon_def: MeleeWeaponDef = null) -> Node3D:
	var root = Node3D.new()
	root.name = "WeaponVisualRoot"

	var voxel_data: Dictionary = {}
	if weapon_def != null and weapon_def.has_meta("voxel_data"):
		voxel_data = weapon_def.get_meta("voxel_data")
	elif weapon_def != null and weapon_def.procedural_data != null and not weapon_def.procedural_data.is_empty():
		voxel_data = weapon_def.procedural_data
	else:
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		var pal = _pick_palette(rng)
		voxel_data = generate_voxel_matrix(rng, WeaponProfile.BALANCED, pal)

	var mesh = build_weapon_mesh(voxel_data)
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "WeaponMeshInstance"
	mesh_inst.mesh = mesh
	root.add_child(mesh_inst)

	# Ambient weapon aura particles
	var energy_col = voxel_data.get("palette", {}).get("energy", Color(0.2, 0.85, 1.0))
	var aura_parts = _create_weapon_aura_particles(energy_col)
	aura_parts.name = "WeaponAuraParticles"
	root.add_child(aura_parts)

	return root

## Compatibility alias for any systems expecting create_sword_node().
static func create_sword_node() -> Node3D:
	return create_weapon_node(null)

## Generates a 2D pixel-art icon for UI, Quickbar, and HUD.
static func generate_weapon_icon(voxel_data: Dictionary, icon_size: Vector2i = Vector2i(28, 28), diagonal: bool = true) -> ImageTexture:
	var grid_2d: Array = voxel_data["grid_2d"]
	var h: int = voxel_data["height"]
	var w: int = voxel_data["width"]
	var cx: int = voxel_data["center_x"]
	var palette: Dictionary = voxel_data["palette"]

	var iw = icon_size.x
	var ih = icon_size.y
	var img = Image.create(iw, ih, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var color_map = {
		VoxelType.HANDLE: palette["handle"],
		VoxelType.JUNCTION: palette["junction"],
		VoxelType.BODY: palette["body"],
		VoxelType.EDGE: palette["edge"],
		VoxelType.ACCENT: palette["accent"],
		VoxelType.ENERGY: palette["energy"]
	}

	if diagonal:
		var p_start = Vector2(5.0, float(ih - 5))
		var p_end = Vector2(float(iw - 5), 5.0)
		var u_perp = Vector2(0.7071, 0.7071)

		for y in range(h):
			var t = float(y) / float(maxi(1, h - 1))
			var p_axis = p_start.lerp(p_end, t)

			for x in range(w):
				var v_type = grid_2d[y][x]
				if v_type == VoxelType.EMPTY:
					continue

				var dx = float(x - cx)
				var px_pos = p_axis + u_perp * dx
				var px = int(round(px_pos.x))
				var py = int(round(px_pos.y))

				var col: Color = color_map.get(v_type, Color.WHITE)
				# Pixel-art shading based on light angle
				if dx < 0.0:
					col = col.lightened(0.18)
				elif dx > 0.0:
					col = col.darkened(0.22)

				if v_type == VoxelType.ENERGY:
					col = col.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.35)

				_set_pixel_safe(img, px, py, col)
	else:
		# Vertical orientation
		var start_y = ih - 3
		var center_px = iw / 2
		for y in range(h):
			var py = start_y - int(round(float(y) / float(h - 1) * float(ih - 6)))
			for x in range(w):
				var v_type = grid_2d[y][x]
				if v_type == VoxelType.EMPTY:
					continue
				var px = center_px + (x - cx)
				var col: Color = color_map.get(v_type, Color.WHITE)
				if (x - cx) < 0:
					col = col.lightened(0.15)
				elif (x - cx) > 0:
					col = col.darkened(0.20)
				_set_pixel_safe(img, px, py, col)

	return ImageTexture.create_from_image(img)

static func _set_pixel_safe(img: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		if color.a < 1.0:
			var prev = img.get_pixel(x, y)
			img.set_pixel(x, y, prev.blend(color))
		else:
			img.set_pixel(x, y, color)

static func _create_weapon_aura_particles(color: Color) -> CPUParticles3D:
	var parts = CPUParticles3D.new()
	parts.amount = 14
	parts.lifetime = 1.1
	parts.preprocess = 0.5
	parts.speed_scale = 0.8
	parts.randomness = 0.4
	parts.local_coords = false

	parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	parts.emission_box_extents = Vector3(0.045, 0.45, 0.035)
	parts.position = Vector3(0.0, 0.50, 0.0)

	parts.direction = Vector3(0.0, 1.0, 0.0)
	parts.spread = 22.0
	parts.gravity = Vector3(0.0, 0.2, 0.0)
	parts.initial_velocity_min = 0.04
	parts.initial_velocity_max = 0.15

	parts.color = color
	parts.scale_amount_min = 0.015
	parts.scale_amount_max = 0.035

	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	parts.material_override = mat

	var quad = QuadMesh.new()
	quad.size = Vector2(0.035, 0.035)
	parts.mesh = quad

	return parts

static func _pick_palette(rng: RandomNumberGenerator) -> Dictionary:
	var idx = rng.randi_range(0, PALETTES.size() - 1)
	return PALETTES[idx]

static func _generate_name(rng: RandomNumberGenerator, profile: WeaponProfile, seed_val: int) -> String:
	var prefix = NAME_PREFIXES[rng.randi_range(0, NAME_PREFIXES.size() - 1)]
	var descriptor = "Weapon"
	match profile:
		WeaponProfile.SLENDER:
			descriptor = "Needle Weapon"
		WeaponProfile.HEAVY:
			descriptor = "Heavy Weapon"
		WeaponProfile.SEGMENTED:
			descriptor = "Modular Weapon"
		WeaponProfile.FLANGED:
			descriptor = "Kinetic Weapon"
		_:
			descriptor = "Weapon Frame"

	return "%s %s #%d" % [prefix, descriptor, seed_val % 1000]

static func _generate_description(profile: WeaponProfile, palette: Dictionary, voxel_data: Dictionary, seed_val: int) -> String:
	var h = voxel_data.get("height", TARGET_WEAPON_HEIGHT_VOXELS)
	var pal_name = palette.get("name", "Voxel")
	return "A %d-voxel forged %s frame resonating with %s energy. Attack patterns are governed by slotted cards." % [h, "weapon", pal_name]

static func _generate_deck_stats(rng: RandomNumberGenerator, profile: WeaponProfile, params: Dictionary) -> Dictionary:
	var slot_capacity = 5
	var is_shuffle = false
	var deck_recharge = 0.50
	var dmg_mult = 1.0
	var stam_mult = 1.0

	match profile:
		WeaponProfile.SLENDER:
			slot_capacity = rng.randi_range(6, 9)
			is_shuffle = false
			deck_recharge = rng.randf_range(0.28, 0.40)
			dmg_mult = rng.randf_range(0.88, 1.00)
			stam_mult = rng.randf_range(0.82, 0.92)

		WeaponProfile.HEAVY:
			slot_capacity = rng.randi_range(4, 6)
			is_shuffle = false
			deck_recharge = rng.randf_range(0.62, 0.78)
			dmg_mult = rng.randf_range(1.25, 1.45)
			stam_mult = rng.randf_range(1.15, 1.30)

		WeaponProfile.SEGMENTED:
			slot_capacity = rng.randi_range(5, 8)
			is_shuffle = rng.randf() < 0.45
			deck_recharge = rng.randf_range(0.42, 0.55)
			dmg_mult = rng.randf_range(1.02, 1.15)
			stam_mult = 1.0

		WeaponProfile.FLANGED:
			slot_capacity = rng.randi_range(5, 7)
			is_shuffle = false
			deck_recharge = rng.randf_range(0.45, 0.58)
			dmg_mult = rng.randf_range(1.10, 1.22)
			stam_mult = rng.randf_range(0.95, 1.05)

		_: # BALANCED
			slot_capacity = rng.randi_range(5, 7)
			is_shuffle = false
			deck_recharge = rng.randf_range(0.45, 0.55)
			dmg_mult = rng.randf_range(1.00, 1.10)
			stam_mult = 1.0

	# Param overrides
	if params.has("slot_capacity"):
		slot_capacity = params["slot_capacity"]
	if params.has("is_shuffle"):
		is_shuffle = params["is_shuffle"]
	if params.has("deck_recharge_time"):
		deck_recharge = params["deck_recharge_time"]
	if params.has("base_damage_multiplier"):
		dmg_mult = params["base_damage_multiplier"]
	if params.has("stamina_cost_multiplier"):
		stam_mult = params["stamina_cost_multiplier"]

	return {
		"slot_capacity": slot_capacity,
		"is_shuffle": is_shuffle,
		"deck_recharge_time": deck_recharge,
		"base_damage_multiplier": dmg_mult,
		"stamina_cost_multiplier": stam_mult,
		"float_offset_right": 0.68,
		"float_offset_height": 0.95,
		"float_offset_forward": -0.12,
		"float_tilt_degrees": Vector3(18.0, -12.0, 10.0)
	}
