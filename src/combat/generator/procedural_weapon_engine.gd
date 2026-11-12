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
	FLANGED = 4,
	VOLUMETRIC_EROSION = 5,
	PARAMETRIC_HELIX = 6,
	BRANCHING_FRACTAL = 7,
	NOISE_SHATTERED = 8,
	KALEIDOSCOPIC = 9,
	FUNGAL_BRACKET = 10,
	OSTEOLOGICAL_CAGE = 11,
	INSECTOID_HIVE = 12,
	ABYSSAL_MARINE = 13,
	CARNIVOROUS_BOTANICAL = 14
}

enum TopologyType {
	VOLUMETRIC_EROSION = 0,
	PARAMETRIC_HELIX = 1,
	BRANCHING_FRACTAL = 2,
	NOISE_SHATTERED = 3,
	KALEIDOSCOPIC = 4,
	FUNGAL_BRACKET = 5,
	OSTEOLOGICAL_CAGE = 6,
	INSECTOID_HIVE = 7,
	ABYSSAL_MARINE = 8,
	CARNIVOROUS_BOTANICAL = 9
}

## Weapon Crafting & Frame Capacity Tiers (procedural_todo_20_slots.md)
enum FrameTier {
	STANDARD = 0,    ## 4 - 8 slots: The Direct Weapon
	RESONANT = 1,    ## 8 - 12 slots: The Combo Engine
	APEX = 2,        ## 13 - 16 slots: Deep Cascade Architecture
	CYCLOTRON = 3    ## 18 - 20 slots: The Modular Physical Supercomputer (Cyclotron OS)
}

const DEFAULT_VOXEL_SIZE: float = 0.05 # 40 voxels * 0.05m = 2.00m (~2 world blocks height, Monster Hunter scale)
const TARGET_WEAPON_HEIGHT_VOXELS: int = 40
const DEFAULT_GRID_WIDTH: int = 11
const DEFAULT_GRID_DEPTH: int = 5
const JUNCTION_Y: int = 7

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
	},
	{
		"name": "Mycelial Spore",
		"handle": Color(0.18, 0.13, 0.08),
		"junction": Color(0.28, 0.22, 0.14),
		"body": Color(0.72, 0.64, 0.50),
		"edge": Color(0.48, 0.58, 0.32),
		"energy": Color(0.40, 0.95, 0.25),
		"accent": Color(0.85, 0.78, 0.25)
	},
	{
		"name": "Ossuary Bleached",
		"handle": Color(0.24, 0.22, 0.20),
		"junction": Color(0.38, 0.35, 0.32),
		"body": Color(0.88, 0.86, 0.80),
		"edge": Color(0.96, 0.95, 0.90),
		"energy": Color(0.30, 0.85, 1.0),
		"accent": Color(0.75, 0.18, 0.22)
	},
	{
		"name": "Vespoid Amber",
		"handle": Color(0.12, 0.10, 0.08),
		"junction": Color(0.22, 0.18, 0.12),
		"body": Color(0.68, 0.52, 0.32),
		"edge": Color(0.90, 0.70, 0.20),
		"energy": Color(1.0, 0.65, 0.08),
		"accent": Color(0.95, 0.85, 0.15)
	},
	{
		"name": "Abyssal Biolume",
		"handle": Color(0.08, 0.12, 0.16),
		"junction": Color(0.15, 0.25, 0.32),
		"body": Color(0.55, 0.70, 0.78),
		"edge": Color(0.78, 0.92, 0.98),
		"energy": Color(0.10, 0.92, 0.88),
		"accent": Color(0.92, 0.28, 0.75)
	},
	{
		"name": "Predatory Flora",
		"handle": Color(0.16, 0.12, 0.08),
		"junction": Color(0.25, 0.32, 0.18),
		"body": Color(0.35, 0.58, 0.28),
		"edge": Color(0.92, 0.88, 0.75),
		"energy": Color(0.65, 1.0, 0.15),
		"accent": Color(0.85, 0.20, 0.28)
	}
]

## Computes physical frame mass (in kilograms) directly from 3D voxel structure and voxel material roles.
## Heavier compositions (porous cellular hive, heavy frame alloy) generate high mass;
## Slender caduceus/helix staffs generate lower mass for rapid agility.
static func compute_voxel_mass(grid_3d: Array, w: int, h: int, d: int) -> float:
	var total_mass: float = 0.0
	for x in range(w):
		for y in range(h):
			for z in range(d):
				var v = grid_3d[x][y][z]
				match v:
					VoxelType.HANDLE: total_mass += 0.8
					VoxelType.JUNCTION: total_mass += 1.6
					VoxelType.BODY: total_mass += 1.3
					VoxelType.EDGE: total_mass += 1.1
					VoxelType.ENERGY: total_mass += 0.4
					VoxelType.ACCENT: total_mass += 1.5
	# Scale so typical weapons range from ~8.0 kg (slender) to ~35.0 kg (colossal heavy)
	return maxf(total_mass * 0.045, 5.0)

## Primary generation method: produces a fully functional MeleeWeaponDef with 3D voxel mesh and 2D icon.
static func generate_weapon(seed_val: int = -1, params: Dictionary = {}) -> MeleeWeaponDef:
	if seed_val < 0:
		seed_val = int(Time.get_ticks_usec()) & 0x7FFFFFFF

	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val

	var profile_val = params.get("profile", rng.randi_range(0, 4))
	var profile: WeaponProfile = profile_val as WeaponProfile
	var topology: TopologyType = resolve_topology(profile_val, params) as TopologyType

	var palette: Dictionary = params.get("palette", _pick_palette(rng))
	var voxel_data: Dictionary = generate_voxel_matrix(rng, profile, palette, params)

	var icon_size: Vector2i = params.get("icon_size", Vector2i(28, 28))
	var icon_tex: ImageTexture = generate_weapon_icon(voxel_data, icon_size)

	var weapon_name: String = params.get("name", _generate_name(rng, profile, seed_val, topology))
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
	var calculated_mass: float = compute_voxel_mass(voxel_data["grid_3d"], voxel_data["width"], voxel_data["height"], voxel_data["depth"])
	weapon_def.mass = params.get("mass", calculated_mass)
	voxel_data["mass"] = weapon_def.mass

	weapon_def.procedural_data = voxel_data
	weapon_def.set_meta("voxel_data", voxel_data)
	weapon_def.set_meta("seed", seed_val)
	weapon_def.set_meta("profile", profile)
	weapon_def.set_meta("topology", topology)

	if params.has("slotted_techniques"):
		weapon_def.slotted_techniques = params["slotted_techniques"].duplicate()

	WeaponIconFactory.register_weapon_icon(weapon_def.weapon_id, icon_tex)
	return weapon_def

## Resolves the exotic generative topology based on profile or explicit parameters.
static func resolve_topology(profile_val: int, params: Dictionary = {}) -> int:
	if params.has("topology"):
		var t = params["topology"]
		if t is int:
			return clampi(t, 0, 9)
		elif t is String:
			match t.to_lower():
				"erosion", "volumetric_erosion", "cellular_automata", "erosion_hive":
					return TopologyType.VOLUMETRIC_EROSION
				"helix", "parametric_helix", "orbital", "caduceus":
					return TopologyType.PARAMETRIC_HELIX
				"fractal", "branching_fractal", "lsystem", "crystalline":
					return TopologyType.BRANCHING_FRACTAL
				"shattered", "noise_shattered", "fractured", "segmented":
					return TopologyType.NOISE_SHATTERED
				"kaleidoscopic", "sacred_geometry", "mandala", "geometric":
					return TopologyType.KALEIDOSCOPIC
				"fungal", "fungal_bracket", "mycelial", "mycelial_rot", "rot", "bracket", "fungus":
					return TopologyType.FUNGAL_BRACKET
				"osteological", "osteological_cage", "skeletal", "cage", "ribcage", "vertebra", "bone":
					return TopologyType.OSTEOLOGICAL_CAGE
				"insectoid", "insectoid_hive", "hive", "honeycomb", "wasp", "hexagonal", "nectar":
					return TopologyType.INSECTOID_HIVE
				"abyssal", "abyssal_marine", "marine", "coral", "jellyfish", "bioluminescence", "ocean":
					return TopologyType.ABYSSAL_MARINE
				"carnivorous", "carnivorous_botanical", "botanical", "pitcher", "pitcher_plant", "overgrowth", "flora":
					return TopologyType.CARNIVOROUS_BOTANICAL

	match profile_val:
		WeaponProfile.SLENDER, WeaponProfile.PARAMETRIC_HELIX:
			return TopologyType.PARAMETRIC_HELIX
		WeaponProfile.HEAVY, WeaponProfile.VOLUMETRIC_EROSION:
			return TopologyType.VOLUMETRIC_EROSION
		WeaponProfile.SEGMENTED, WeaponProfile.NOISE_SHATTERED:
			return TopologyType.NOISE_SHATTERED
		WeaponProfile.FLANGED, WeaponProfile.BRANCHING_FRACTAL:
			return TopologyType.BRANCHING_FRACTAL
		WeaponProfile.FUNGAL_BRACKET:
			return TopologyType.FUNGAL_BRACKET
		WeaponProfile.OSTEOLOGICAL_CAGE:
			return TopologyType.OSTEOLOGICAL_CAGE
		WeaponProfile.INSECTOID_HIVE:
			return TopologyType.INSECTOID_HIVE
		WeaponProfile.ABYSSAL_MARINE:
			return TopologyType.ABYSSAL_MARINE
		WeaponProfile.CARNIVOROUS_BOTANICAL:
			return TopologyType.CARNIVOROUS_BOTANICAL
		_: # BALANCED, KALEIDOSCOPIC
			return TopologyType.KALEIDOSCOPIC

## Generates the discrete 3D voxel structure and 2D projection matrix.
## Abandons traditional layer-by-layer blade silhouettes: locks the structural handle
## and spine while applying advanced generative algorithms to outer bounds.
static func generate_voxel_matrix(rng: RandomNumberGenerator, profile: WeaponProfile, palette: Dictionary, params: Dictionary = {}) -> Dictionary:
	var h = TARGET_WEAPON_HEIGHT_VOXELS
	var w = params.get("grid_width", DEFAULT_GRID_WIDTH)
	var d = params.get("grid_depth", DEFAULT_GRID_DEPTH)
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

	var set_symmetric = func(dx: int, y: int, z: int, v_type: int) -> void:
		set_voxel.call(cx + dx, y, z, v_type)
		if dx != 0:
			set_voxel.call(cx - dx, y, z, v_type)

	# --- 1. Base and Pommel (y = 0) ---
	set_symmetric.call(0, 0, cz, VoxelType.ACCENT)
	set_symmetric.call(1, 0, cz, VoxelType.JUNCTION)
	if cz > 0:
		set_symmetric.call(0, 0, cz - 1, VoxelType.JUNCTION)
		set_symmetric.call(0, 0, cz + 1, VoxelType.JUNCTION)
	if profile == WeaponProfile.HEAVY or profile == WeaponProfile.VOLUMETRIC_EROSION or profile == WeaponProfile.FLANGED:
		set_symmetric.call(2, 0, cz, VoxelType.JUNCTION)

	# --- 2. Handle / Grip (y = 1 to JUNCTION_Y - 1) ---
	for gy in range(1, JUNCTION_Y):
		set_symmetric.call(0, gy, cz, VoxelType.HANDLE)
		if gy % 2 == 0:
			set_symmetric.call(0, gy, cz, VoxelType.ACCENT)
		if cz > 0:
			set_symmetric.call(0, gy, cz - 1, VoxelType.HANDLE)
			set_symmetric.call(0, gy, cz + 1, VoxelType.HANDLE)

	# --- 3. Collar / Junction (y = JUNCTION_Y) ---
	var guard_w = 3
	if profile == WeaponProfile.SLENDER or profile == WeaponProfile.PARAMETRIC_HELIX:
		guard_w = 2
	elif profile == WeaponProfile.HEAVY or profile == WeaponProfile.VOLUMETRIC_EROSION:
		guard_w = 5

	for gx in range(guard_w + 1):
		set_symmetric.call(gx, JUNCTION_Y, cz, VoxelType.JUNCTION)
		if cz > 0:
			set_symmetric.call(gx, JUNCTION_Y, cz - 1, VoxelType.JUNCTION)
			set_symmetric.call(gx, JUNCTION_Y, cz + 1, VoxelType.JUNCTION)
		if cz > 1:
			set_symmetric.call(gx, JUNCTION_Y, cz - 2, VoxelType.JUNCTION)
			set_symmetric.call(gx, JUNCTION_Y, cz + 2, VoxelType.JUNCTION)

	# --- 4. Lock Central Spine Core (y = JUNCTION_Y + 1 to h - 1) ---
	# The central axis (cx, y, cz) serves as an unbroken structural backbone.
	for sy in range(JUNCTION_Y + 1, h):
		if sy % 4 == 0:
			set_voxel.call(cx, sy, cz, VoxelType.ENERGY)
		else:
			set_voxel.call(cx, sy, cz, VoxelType.BODY)
		if cz > 0 and (sy % 2 == 0):
			set_voxel.call(cx, sy, cz - 1, VoxelType.BODY)
			set_voxel.call(cx, sy, cz + 1, VoxelType.BODY)

	# --- 5. Apply Exotic Generative Topologies Exclusively to Outer Bounds ---
	var topology: TopologyType = resolve_topology(profile, params) as TopologyType
	match topology:
		TopologyType.VOLUMETRIC_EROSION:
			_apply_volumetric_erosion(grid_3d, rng, w, h, d, cx, cz, params)
		TopologyType.PARAMETRIC_HELIX:
			_apply_parametric_helix(grid_3d, rng, w, h, d, cx, cz, params)
		TopologyType.BRANCHING_FRACTAL:
			_apply_branching_fractal(grid_3d, rng, w, h, d, cx, cz, params)
		TopologyType.NOISE_SHATTERED:
			_apply_noise_shattered(grid_3d, rng, w, h, d, cx, cz, params)
		TopologyType.FUNGAL_BRACKET:
			_apply_fungal_bracket(grid_3d, rng, w, h, d, cx, cz, params)
		TopologyType.OSTEOLOGICAL_CAGE:
			_apply_osteological_cage(grid_3d, rng, w, h, d, cx, cz, params)
		TopologyType.INSECTOID_HIVE:
			_apply_insectoid_hive(grid_3d, rng, w, h, d, cx, cz, params)
		TopologyType.ABYSSAL_MARINE:
			_apply_abyssal_marine(grid_3d, rng, w, h, d, cx, cz, params)
		TopologyType.CARNIVOROUS_BOTANICAL:
			_apply_carnivorous_botanical(grid_3d, rng, w, h, d, cx, cz, params)
		_: # TopologyType.KALEIDOSCOPIC
			_apply_kaleidoscopic(grid_3d, rng, w, h, d, cx, cz, params)

	# Lock verification: Ensure spine core remains unbroken from handle to emitter
	for sy in range(JUNCTION_Y + 1, h):
		if grid_3d[cx][sy][cz] == VoxelType.EMPTY:
			grid_3d[cx][sy][cz] = VoxelType.ENERGY if (sy % 3 == 0) else VoxelType.BODY

	# Update 2D projection matrix from final 3D voxel structure
	_update_grid_2d(grid_3d, grid_2d, w, h, d, cx, cz)

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
		"topology": topology,
		"palette": palette
	}

## 1. Volumetric Erosion (3D Cellular Automata)
## Generates a massive solid geometric block around the spine, then uses Cellular
## Automata to eat away at it, producing an ancient, porous hive/relic relic.
static func _apply_volumetric_erosion(grid_3d: Array, rng: RandomNumberGenerator, w: int, h: int, d: int, cx: int, cz: int, params: Dictionary) -> void:
	var iterations: int = params.get("ca_iterations", 3)
	var max_half_w: int = maxi(3, cx)

	# Initial solid volume fill around central spine
	for y in range(JUNCTION_Y + 1, h):
		var taper: float = 1.0 - (float(y - (JUNCTION_Y + 1)) / float(maxi(1, h - (JUNCTION_Y + 1)))) * 0.20
		var cur_half_w = maxi(2, int(round(float(max_half_w) * taper)))
		for x in range(cx - cur_half_w, cx + cur_half_w + 1):
			if x < 0 or x >= w:
				continue
			for z in range(d):
				if x == cx and z == cz:
					continue # Spine locked
				var roll = rng.randf()
				if roll < 0.18:
					grid_3d[x][y][z] = VoxelType.EMPTY # Initial cavity seed
				elif roll < 0.42:
					grid_3d[x][y][z] = VoxelType.ENERGY # Glowing energy nodules
				else:
					grid_3d[x][y][z] = VoxelType.BODY

	# 3D Cellular Automata simulation
	for it in range(iterations):
		var copy: Array = []
		for x in range(w):
			var y_arr: Array = []
			for y in range(h):
				var z_arr: Array = []
				for z in range(d):
					z_arr.append(grid_3d[x][y][z])
				y_arr.append(z_arr)
			copy.append(y_arr)

		for y in range(JUNCTION_Y + 1, h):
			for x in range(w):
				for z in range(d):
					if x == cx and z == cz:
						continue # Spine is locked
					var solid_neighbors = 0
					for dx in range(-1, 2):
						for dy in range(-1, 2):
							for dz in range(-1, 2):
								if dx == 0 and dy == 0 and dz == 0:
									continue
								var nx = x + dx
								var ny = y + dy
								var nz = z + dz
								if nx >= 0 and nx < w and ny >= (JUNCTION_Y + 1) and ny < h and nz >= 0 and nz < d:
									if copy[nx][ny][nz] != VoxelType.EMPTY:
										solid_neighbors += 1

					var cur = copy[x][y][z]
					if cur != VoxelType.EMPTY:
						if solid_neighbors < 8 or solid_neighbors > 20:
							grid_3d[x][y][z] = VoxelType.EMPTY
					else:
						if solid_neighbors >= 12 and solid_neighbors <= 16:
							grid_3d[x][y][z] = VoxelType.BODY

	# Perimeter boundary pass: turn exposed outer surface into EDGE
	var edge_placed = false
	for y in range(JUNCTION_Y + 1, h):
		for x in range(w):
			for z in range(d):
				if x == cx and z == cz:
					continue
				if grid_3d[x][y][z] == VoxelType.BODY:
					var has_empty_adj = false
					var dirs = [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,1,0), Vector3i(0,-1,0), Vector3i(0,0,1), Vector3i(0,0,-1)]
					for dir in dirs:
						var nx = x + dir.x
						var ny = y + dir.y
						var nz = z + dir.z
						if nx < 0 or nx >= w or ny < 0 or ny >= h or nz < 0 or nz >= d or grid_3d[nx][ny][nz] == VoxelType.EMPTY:
							has_empty_adj = true
							break
					if has_empty_adj and rng.randf() < 0.70:
						grid_3d[x][y][z] = VoxelType.EDGE
						edge_placed = true

	if not edge_placed:
		grid_3d[mini(cx + 1, w - 1)][JUNCTION_Y + 2][cz] = VoxelType.EDGE
		grid_3d[maxi(cx - 1, 0)][JUNCTION_Y + 2][cz] = VoxelType.EDGE

	grid_3d[cx][h - 1][cz] = VoxelType.ENERGY

## 2. Parametric Helices & Orbitals
## Loops through Y = JUNCTION_Y+1..h-1 using sin and cos to wind ENERGY and EDGE voxels
## in a 3D double-helix around the protected central spine.
static func _apply_parametric_helix(grid_3d: Array, rng: RandomNumberGenerator, w: int, h: int, d: int, cx: int, cz: int, params: Dictionary) -> void:
	var freq: float = params.get("helix_frequency", 0.38)
	var phase: float = params.get("helix_phase", rng.randf() * TAU)
	var max_rx: float = params.get("helix_rx", float(maxi(1, cx)) * 0.88)
	var max_rz: float = params.get("helix_rz", float(maxi(1, cz)) * 0.88 if d > 1 else 0.0)

	for y in range(JUNCTION_Y + 1, h):
		var t: float = float(y - (JUNCTION_Y + 1)) / float(maxi(1, h - (JUNCTION_Y + 1)))
		var r_mult: float = 0.75 + 0.35 * sin(t * PI)
		if y >= h - 4:
			r_mult = 1.10 # Tuning fork flare

		# Strand 1: ENERGY orbital conduit
		var a1 = float(y) * freq + phase
		var ox1 = int(round(sin(a1) * max_rx * r_mult))
		var oz1 = int(round(cos(a1) * max_rz * r_mult))
		var x1 = clampi(cx + ox1, 0, w - 1)
		var z1 = clampi(cz + oz1, 0, d - 1)
		if x1 != cx or z1 != cz:
			grid_3d[x1][y][z1] = VoxelType.ENERGY
			if d > 1 and cz > 0:
				if z1 - 1 >= 0 and rng.randf() < 0.40:
					grid_3d[x1][y][z1 - 1] = VoxelType.ENERGY
				if z1 + 1 < d and rng.randf() < 0.40:
					grid_3d[x1][y][z1 + 1] = VoxelType.ENERGY

		# Strand 2: EDGE striking perimeter (180 deg offset)
		var a2 = a1 + PI
		var ox2 = int(round(sin(a2) * max_rx * r_mult))
		var oz2 = int(round(cos(a2) * max_rz * r_mult))
		var x2 = clampi(cx + ox2, 0, w - 1)
		var z2 = clampi(cz + oz2, 0, d - 1)
		if x2 != cx or z2 != cz:
			grid_3d[x2][y][z2] = VoxelType.EDGE
			if d > 1 and cz > 0:
				if z2 - 1 >= 0 and rng.randf() < 0.40:
					grid_3d[x2][y][z2 - 1] = VoxelType.EDGE
				if z2 + 1 < d and rng.randf() < 0.40:
					grid_3d[x2][y][z2 + 1] = VoxelType.EDGE

		# Caduceus stabilizer rungs / horizontal bridges
		if y % 4 == 0:
			var step_dir1 = signi(cx - x1)
			if step_dir1 != 0:
				var bx = x1 + step_dir1
				while bx != cx and bx >= 0 and bx < w:
					grid_3d[bx][y][z1] = VoxelType.ACCENT
					bx += step_dir1
			var step_dir2 = signi(cx - x2)
			if step_dir2 != 0:
				var bx2 = x2 + step_dir2
				while bx2 != cx and bx2 >= 0 and bx2 < w:
					grid_3d[bx2][y][z2] = VoxelType.ACCENT
					bx2 += step_dir2

	# Forked tuning fork tips
	var tip_y = h - 1
	for ox in range(1, 3):
		if cx + ox < w:
			grid_3d[cx + ox][tip_y][cz] = VoxelType.EDGE
			grid_3d[cx + ox][tip_y - 1][cz] = VoxelType.EDGE
		if cx - ox >= 0:
			grid_3d[cx - ox][tip_y][cz] = VoxelType.EDGE
			grid_3d[cx - ox][tip_y - 1][cz] = VoxelType.EDGE
	grid_3d[cx][tip_y][cz] = VoxelType.ENERGY

## 3. L-System Branching (Fractal & Crystalline Growth)
## Grows crystalline clusters, coral formations, or fractal lightning bolts outward
## from anchor points along the protected spine using recursive branching paths.
static func _apply_branching_fractal(grid_3d: Array, rng: RandomNumberGenerator, w: int, h: int, d: int, cx: int, cz: int, params: Dictionary) -> void:
	var anchors = [
		JUNCTION_Y + 1,
		JUNCTION_Y + 6,
		JUNCTION_Y + 13,
		JUNCTION_Y + 20,
		JUNCTION_Y + 26,
		h - 3
	]
	var max_depth = params.get("fractal_depth", 6)

	for anchor_y in anchors:
		if anchor_y >= h:
			continue
		grid_3d[cx][anchor_y][cz] = VoxelType.ACCENT
		var dir_left = Vector3i(-1, 1 if rng.randf() < 0.65 else 0, 1 if (d > 1 and rng.randf() < 0.5) else (-1 if d > 1 else 0))
		var dir_right = Vector3i(1, 1 if rng.randf() < 0.65 else 0, -dir_left.z)
		_branch_recurse(grid_3d, rng, Vector3i(cx + dir_left.x, anchor_y + dir_left.y, cz + dir_left.z), dir_left, 1, max_depth, w, h, d, cx, cz)
		_branch_recurse(grid_3d, rng, Vector3i(cx + dir_right.x, anchor_y + dir_right.y, cz + dir_right.z), dir_right, 1, max_depth, w, h, d, cx, cz)

	var edge_found = false
	for y in range(JUNCTION_Y + 1, h):
		for x in range(w):
			for z in range(d):
				if grid_3d[x][y][z] == VoxelType.EDGE:
					edge_found = true
					break
	if not edge_found:
		grid_3d[mini(cx + 1, w - 1)][h - 2][cz] = VoxelType.EDGE
		grid_3d[maxi(cx - 1, 0)][h - 2][cz] = VoxelType.EDGE

	grid_3d[cx][h - 1][cz] = VoxelType.ENERGY

static func _branch_recurse(grid_3d: Array, rng: RandomNumberGenerator, pos: Vector3i, dir: Vector3i, depth: int, max_depth: int, w: int, h: int, d: int, cx: int, cz: int) -> void:
	if pos.x < 0 or pos.x >= w or pos.y <= JUNCTION_Y or pos.y >= h or pos.z < 0 or pos.z >= d:
		return
	if pos.x == cx and pos.z == cz:
		return

	if depth >= max_depth:
		grid_3d[pos.x][pos.y][pos.z] = VoxelType.EDGE if (rng.randf() < 0.65) else VoxelType.ENERGY
		return
	else:
		var v_type = VoxelType.BODY
		if depth % 2 == 1 and rng.randf() < 0.35:
			v_type = VoxelType.ENERGY
		elif rng.randf() < 0.35:
			v_type = VoxelType.EDGE
		grid_3d[pos.x][pos.y][pos.z] = v_type

	var dy1 = 1 if rng.randf() < 0.70 else 0
	var d1 = Vector3i(dir.x, dy1, dir.z)
	_branch_recurse(grid_3d, rng, pos + d1, d1, depth + 1, max_depth, w, h, d, cx, cz)

	if rng.randf() < 0.55:
		var dx2 = -dir.x if (rng.randf() < 0.35) else dir.x
		var dz2 = -dir.z if (d > 1 and rng.randf() < 0.5) else 0
		var d2 = Vector3i(dx2, 1, dz2)
		_branch_recurse(grid_3d, rng, pos + d2, d2, depth + 1, max_depth, w, h, d, cx, cz)

## 4. Noise-Sliced Fracturing (The "Shattered" Matrix)
## Slices a solid heavy silhouette into chaotic floating shards via 3D Simplex noise.
## Sliced faces are lined with glowing ENERGY, while shards are held together by telekinetic conduits.
static func _apply_noise_shattered(grid_3d: Array, rng: RandomNumberGenerator, w: int, h: int, d: int, cx: int, cz: int, params: Dictionary) -> void:
	var max_half_w = maxi(3, cx)
	for y in range(JUNCTION_Y + 1, h):
		var t = float(y - (JUNCTION_Y + 1)) / float(maxi(1, h - (JUNCTION_Y + 1)))
		var cur_half_w = maxi(2, int(round(float(max_half_w) * (1.0 - t * 0.20))))
		for dx in range(-cur_half_w, cur_half_w + 1):
			var x = cx + dx
			if x < 0 or x >= w:
				continue
			for z in range(d):
				if dx == 0 and z == cz:
					continue # Spine locked
				if absi(dx) == cur_half_w or z == 0 or z == d - 1:
					grid_3d[x][y][z] = VoxelType.EDGE if (absi(dx) == cur_half_w) else VoxelType.BODY
				else:
					grid_3d[x][y][z] = VoxelType.BODY

	var noise = FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = params.get("noise_freq", 0.16)
	var slice_band: float = params.get("slice_band", 0.11)

	var sliced_voxels: Array = []
	for y in range(JUNCTION_Y + 1, h):
		for x in range(w):
			for z in range(d):
				if grid_3d[x][y][z] == VoxelType.EMPTY:
					continue
				var n = noise.get_noise_3d(float(x) * 2.0, float(y) * 0.8, float(z) * 2.5)
				if absf(n) <= slice_band:
					if x == cx and z == cz:
						grid_3d[x][y][z] = VoxelType.ENERGY
					else:
						grid_3d[x][y][z] = VoxelType.EMPTY
						sliced_voxels.append(Vector3i(x, y, z))

	# Inner exposed fracture faces lined with ENERGY
	for sv in sliced_voxels:
		var neighbors = [
			Vector3i(sv.x + 1, sv.y, sv.z), Vector3i(sv.x - 1, sv.y, sv.z),
			Vector3i(sv.x, sv.y + 1, sv.z), Vector3i(sv.x, sv.y - 1, sv.z),
			Vector3i(sv.x, sv.y, sv.z + 1), Vector3i(sv.x, sv.y, sv.z - 1)
		]
		for nb in neighbors:
			if nb.x >= 0 and nb.x < w and nb.y > JUNCTION_Y and nb.y < h and nb.z >= 0 and nb.z < d:
				if grid_3d[nb.x][nb.y][nb.z] == VoxelType.BODY and rng.randf() < 0.75:
					grid_3d[nb.x][nb.y][nb.z] = VoxelType.ENERGY

	var has_edge = false
	var has_body = false
	for y in range(JUNCTION_Y + 1, h):
		for x in range(w):
			for z in range(d):
				if grid_3d[x][y][z] == VoxelType.EDGE:
					has_edge = true
				elif grid_3d[x][y][z] == VoxelType.BODY:
					has_body = true

	if not has_edge:
		grid_3d[mini(cx + 1, w - 1)][JUNCTION_Y + 2][cz] = VoxelType.EDGE
	if not has_body:
		grid_3d[cx][JUNCTION_Y + 2][cz] = VoxelType.BODY

## 5. Multi-Axis Mirroring (Kaleidoscopic / Sacred Geometry)
## Generates a geometric mandala or snowflake star in one quadrant and mirrors it
## across X, Y (around a midpoint), and Z axes simultaneously.
static func _apply_kaleidoscopic(grid_3d: Array, rng: RandomNumberGenerator, w: int, h: int, d: int, cx: int, cz: int, params: Dictionary) -> void:
	var blade_span = h - 1 - (JUNCTION_Y + 1)
	var mid_y: int = params.get("kaleido_mid_y", (JUNCTION_Y + 1) + blade_span / 2)
	var max_dx: int = maxi(2, cx)
	var max_dy: int = mini(mid_y - (JUNCTION_Y + 1), (h - 1) - mid_y)
	var max_radius: int = params.get("kaleido_max_radius", maxi(5, max_dx + 1))

	for dx in range(max_dx + 1):
		for dy in range(max_dy + 1):
			var v_type = VoxelType.EMPTY
			var r_manhattan = dx + int(float(dy) * 0.35)

			if dx == 0 and dy == 0:
				v_type = VoxelType.ENERGY
			elif dx == 0:
				v_type = VoxelType.ENERGY if (dy % 3 == 0) else VoxelType.BODY
			elif dy == 0:
				v_type = VoxelType.EDGE if (dx == max_dx) else VoxelType.BODY
			elif r_manhattan == max_radius or (dx == max_dx and dy <= 3):
				v_type = VoxelType.EDGE
			elif r_manhattan == max_radius - 1 or r_manhattan == max_radius - 3:
				v_type = VoxelType.ENERGY
			elif dx == dy and dx <= 3:
				v_type = VoxelType.ACCENT
			elif r_manhattan < max_radius:
				v_type = VoxelType.BODY

			if v_type == VoxelType.EMPTY:
				continue

			var x_offsets = [dx, -dx] if dx != 0 else [0]
			var y_offsets = [dy, -dy] if dy != 0 else [0]

			for ox in x_offsets:
				for oy in y_offsets:
					var px = cx + ox
					var py = mid_y + oy
					if px >= 0 and px < w and py > JUNCTION_Y and py < h:
						grid_3d[px][py][cz] = v_type
						if d > 1:
							for dz in range(1, cz + 1):
								var z_val = v_type if (v_type != VoxelType.EDGE or dz == 1) else VoxelType.BODY
								if cz - dz >= 0:
									grid_3d[px][py][cz - dz] = z_val
								if cz + dz < d:
									grid_3d[px][py][cz + dz] = z_val

	# Top crown tip
	grid_3d[cx][h - 1][cz] = VoxelType.ENERGY
	if cx + 1 < w:
		grid_3d[cx + 1][h - 1][cz] = VoxelType.EDGE
	if cx - 1 >= 0:
		grid_3d[cx - 1][h - 1][cz] = VoxelType.EDGE

## 6. Fungal Bracket & Mycelial Rot
## Abandons bilateral symmetry for parasitic growth. Treats the spine as a decaying host,
## generating BODY voxels that shelf outward unilaterally along the X-axis like bracket fungi,
## woven with a random-walk algorithm of creeping mycelial ENERGY filaments around the base.
static func _apply_fungal_bracket(grid_3d: Array, rng: RandomNumberGenerator, w: int, h: int, d: int, cx: int, cz: int, params: Dictionary) -> void:
	var blade_span = h - 1 - (JUNCTION_Y + 1)
	var max_shelf_w = maxi(2, cx)

	# Gnarly decaying host trunk around spine
	for y in range(JUNCTION_Y + 1, h):
		var trunk_r = 1.0 + 0.35 * sin(float(y) * 0.45)
		for ox in range(-1, 2):
			for oz in range(-1, 2):
				var px = cx + ox
				var pz = cz + oz
				if px >= 0 and px < w and pz >= 0 and pz < d:
					if ox * ox + oz * oz <= int(trunk_r * trunk_r) or (ox == 0 and oz == 0):
						var v = VoxelType.BODY
						if rng.randf() < 0.15:
							v = VoxelType.ACCENT
						grid_3d[px][y][pz] = v

	# Bracket fungi shelves placed unilaterally at tiered heights
	var shelf_heights = [
		JUNCTION_Y + 4,
		JUNCTION_Y + 10,
		JUNCTION_Y + 17,
		JUNCTION_Y + 24,
		JUNCTION_Y + 30
	]

	# Choose dominant shelf side (unilateral growth along X)
	var primary_dir = 1 if rng.randf() < 0.60 else -1

	for sh_y in shelf_heights:
		if sh_y >= h - 3:
			continue
		var side_dir = primary_dir if (rng.randf() < 0.80) else -primary_dir
		var shelf_w = rng.randi_range(2, max_shelf_w)
		var shelf_thick = rng.randi_range(2, 3)

		for ty in range(sh_y, mini(h - 1, sh_y + shelf_thick)):
			for sx in range(1, shelf_w + 1):
				var px = cx + sx * side_dir
				if px < 0 or px >= w:
					continue
				var max_dz = maxi(1, int(round(float(shelf_w - sx + 1) * 0.75)))
				for dz in range(-max_dz, max_dz + 1):
					var pz = cz + dz
					if pz < 0 or pz >= d:
						continue

					var is_outer_rim = (sx == shelf_w or absi(dz) == max_dz)
					var is_spore_underside = (ty == sh_y and sx >= 2)

					if is_outer_rim:
						grid_3d[px][ty][pz] = VoxelType.EDGE if (ty > sh_y) else VoxelType.ACCENT
					elif is_spore_underside and rng.randf() < 0.40:
						grid_3d[px][ty][pz] = VoxelType.ENERGY
					else:
						grid_3d[px][ty][pz] = VoxelType.BODY

	# Creeping mycelium random-walk tendrils around base
	var filament_count = params.get("mycelium_filaments", 4)
	for f in range(filament_count):
		var cur_pos = Vector3i(
			clampi(cx + rng.randi_range(-1, 1), 0, w - 1),
			JUNCTION_Y + 1,
			clampi(cz + rng.randi_range(-1, 1), 0, d - 1)
		)
		var steps = rng.randi_range(14, 22)
		for s in range(steps):
			grid_3d[cur_pos.x][cur_pos.y][cur_pos.z] = VoxelType.ENERGY
			var next_y = cur_pos.y + (1 if rng.randf() < 0.65 else (0 if rng.randf() < 0.75 else -1))
			next_y = clampi(next_y, JUNCTION_Y + 1, JUNCTION_Y + 12)
			var next_x = clampi(cur_pos.x + rng.randi_range(-1, 1), 0, w - 1)
			var next_z = clampi(cur_pos.z + rng.randi_range(-1, 1), 0, d - 1)
			cur_pos = Vector3i(next_x, next_y, next_z)

	# Heavy asymmetrical club apex
	for y in range(h - 4, h):
		for dx in range(-1, maxi(2, max_shelf_w - 1)):
			var px = cx + dx * primary_dir
			if px >= 0 and px < w:
				for dz in range(-1, 2):
					var pz = cz + dz
					if pz >= 0 and pz < d:
						if y == h - 1 and dx == 0 and dz == 0:
							grid_3d[px][y][pz] = VoxelType.ENERGY
						elif absi(dx) >= 2 or absi(dz) >= 1:
							grid_3d[px][y][pz] = VoxelType.EDGE if (rng.randf() < 0.5) else VoxelType.BODY
						else:
							grid_3d[px][y][pz] = VoxelType.BODY

## 7. The Osteological Cage
## Replaces a solid blade with an exposed skeletal cavity. Treats the central spine as a
## vertebral column. Projects curved rib-like arches outward in X and Z, enclosing an untouched,
## floating massive ENERGY core suspended inside the cage.
static func _apply_osteological_cage(grid_3d: Array, rng: RandomNumberGenerator, w: int, h: int, d: int, cx: int, cz: int, params: Dictionary) -> void:
	var blade_span = h - 1 - (JUNCTION_Y + 1)
	var mid_y = (JUNCTION_Y + 1) + blade_span / 2
	var rib_w = maxi(2, mini(4, cx - 1))

	# Clear out the blade area around spine to leave room for the cage cavity
	for y in range(JUNCTION_Y + 1, h):
		for x in range(w):
			for z in range(d):
				if x != cx or z != cz:
					grid_3d[x][y][z] = VoxelType.EMPTY

	# Vertebral column spine (alternating centrum and cartilage)
	for y in range(JUNCTION_Y + 1, h):
		if (y - (JUNCTION_Y + 1)) % 4 == 0:
			grid_3d[cx][y][cz] = VoxelType.ACCENT
		else:
			grid_3d[cx][y][cz] = VoxelType.BODY
		if cz > 0 and (y % 2 == 0):
			grid_3d[cx][y][cz - 1] = VoxelType.EDGE

	# Massive, floating ENERGY core suspended completely untouched in center of cage
	var core_radius_y = 3
	for cy in range(mid_y - core_radius_y, mid_y + core_radius_y + 1):
		if cy > JUNCTION_Y and cy < h:
			grid_3d[cx][cy][cz] = VoxelType.ENERGY
			if cz > 0:
				grid_3d[cx][cy][cz - 1] = VoxelType.ENERGY
			if cz + 1 < d:
				grid_3d[cx][cy][cz + 1] = VoxelType.ENERGY
			if absi(cy - mid_y) <= 1:
				if cx - 1 >= 0:
					grid_3d[cx - 1][cy][cz] = VoxelType.ENERGY
				if cx + 1 < w:
					grid_3d[cx + 1][cy][cz] = VoxelType.ENERGY

	# Rib-like arches projected at set intervals
	var rib_step = params.get("rib_interval", 4)
	for ry in range(JUNCTION_Y + 2, h - 5, rib_step):
		for rx in range(1, rib_w + 1):
			var t = float(rx) / float(rib_w)
			var y_arch = ry + int(round(sin(t * PI) * 1.5))
			var z_arch = cz + int(round(sin(t * PI) * float(maxi(1, cz))))
			z_arch = clampi(z_arch, 0, d - 1)
			y_arch = clampi(y_arch, JUNCTION_Y + 1, h - 2)

			if cx - rx >= 0:
				grid_3d[cx - rx][y_arch][z_arch] = VoxelType.BODY
				if rx == rib_w:
					grid_3d[cx - rx][y_arch][z_arch] = VoxelType.EDGE
			if cx + rx < w:
				grid_3d[cx + rx][y_arch][z_arch] = VoxelType.BODY
				if rx == rib_w:
					grid_3d[cx + rx][y_arch][z_arch] = VoxelType.EDGE

		# Inward costal cartilage tip reaching toward ventral sternum
		var sternum_y = clampi(ry + 1, JUNCTION_Y + 1, h - 2)
		var sternum_z = clampi(cz + 1, 0, d - 1)
		if cx - 1 >= 0 and (sternum_y < mid_y - core_radius_y or sternum_y > mid_y + core_radius_y):
			grid_3d[cx - 1][sternum_y][sternum_z] = VoxelType.ACCENT
		if cx + 1 < w and (sternum_y < mid_y - core_radius_y or sternum_y > mid_y + core_radius_y):
			grid_3d[cx + 1][sternum_y][sternum_z] = VoxelType.ACCENT

	# Cervical spear / skull crest apex
	for y in range(h - 4, h):
		grid_3d[cx][y][cz] = VoxelType.ENERGY if (y == h - 1) else VoxelType.BODY
		if cx - 1 >= 0:
			grid_3d[cx - 1][y][cz] = VoxelType.EDGE
		if cx + 1 < w:
			grid_3d[cx + 1][y][cz] = VoxelType.EDGE

## 8. Insectoid Hive (Hexagonal Porosity)
## Generates a bulky, teardrop-shaped mass of BODY voxels around the upper shaft.
## Applies a 3D modulo operation to carve repeating, honeycomb-like EMPTY cavities,
## filling deepest internal recesses with glowing volatile nectar (ENERGY).
static func _apply_insectoid_hive(grid_3d: Array, rng: RandomNumberGenerator, w: int, h: int, d: int, cx: int, cz: int, params: Dictionary) -> void:
	var blade_span = h - 1 - (JUNCTION_Y + 1)
	var max_r = maxi(3, cx)

	# 1. Generate bulky teardrop mass of BODY voxels
	for y in range(JUNCTION_Y + 1, h - 1):
		var t = float(y - (JUNCTION_Y + 1)) / float(maxi(1, blade_span))
		var shape = sin(t * PI) * (0.8 + 0.5 * sin(t * PI * 0.5))
		var cur_rx = maxi(1, int(round(float(max_r) * shape)))
		var cur_rz = maxi(1, int(round(float(cz) * shape)))

		for dx in range(-cur_rx, cur_rx + 1):
			var px = cx + dx
			if px < 0 or px >= w:
				continue
			for dz in range(-cur_rz, cur_rz + 1):
				var pz = cz + dz
				if pz < 0 or pz >= d:
					continue

				var norm_dist = (float(dx * dx) / float(cur_rx * cur_rx)) + (float(dz * dz) / float(cur_rz * cur_rz))
				if norm_dist <= 1.05:
					if norm_dist >= 0.85:
						grid_3d[px][y][pz] = VoxelType.EDGE
					else:
						grid_3d[px][y][pz] = VoxelType.BODY

	# 2. 3D Modulo Hexagonal Honeycomb Cavity Carving & Deep Nectar Pools
	for y in range(JUNCTION_Y + 3, h - 3):
		for x in range(w):
			for z in range(d):
				if x == cx and z == cz:
					continue # Backbone core
				if grid_3d[x][y][z] == VoxelType.EMPTY:
					continue

				var hex_shift = (x % 2) * 1
				var mod_x = (x + 100) % 3
				var mod_y = (y + hex_shift + 100) % 3

				if mod_x == 0 and mod_y == 0:
					if absi(z - cz) <= 0:
						grid_3d[x][y][z] = VoxelType.ENERGY
					else:
						grid_3d[x][y][z] = VoxelType.EMPTY

	# 3. Razor-sharp stinger apex
	for y in range(h - 3, h):
		grid_3d[cx][y][cz] = VoxelType.ENERGY if (y == h - 1) else VoxelType.EDGE
		if cx - 1 >= 0:
			grid_3d[cx - 1][y][cz] = VoxelType.EDGE
		if cx + 1 < w:
			grid_3d[cx + 1][y][cz] = VoxelType.EDGE

## 9. Abyssal Marine (Coral & Bioluminescence)
## Mixes branching staghorn coral with jellyfish anatomy. Grows outward from junction
## using an upward-biased random walk, capped at the apex with an umbrella-like dome
## of ENERGY voxels and trailing venomous ACCENT tentacles.
static func _apply_abyssal_marine(grid_3d: Array, rng: RandomNumberGenerator, w: int, h: int, d: int, cx: int, cz: int, params: Dictionary) -> void:
	var dome_apex_y = h - 6
	var max_r = maxi(3, cx)

	# 1. Branching staghorn coral from junction
	var branch_count = params.get("coral_branches", 4)
	for b in range(branch_count):
		var cur = Vector3i(cx, JUNCTION_Y + 1, cz)
		var target_x = cx + (1 if b % 2 == 0 else -1) * rng.randi_range(1, maxi(1, cx - 1))
		var target_z = cz + (1 if b >= 2 else -1) * rng.randi_range(0, maxi(0, cz - 1))

		while cur.y < dome_apex_y - 2:
			grid_3d[cur.x][cur.y][cur.z] = VoxelType.BODY
			if rng.randf() < 0.20:
				grid_3d[cur.x][cur.y][cur.z] = VoxelType.ENERGY

			var step_y = rng.randi_range(1, 2)
			var step_x = signi(target_x - cur.x) if (rng.randf() < 0.65) else rng.randi_range(-1, 1)
			var step_z = signi(target_z - cur.z) if (rng.randf() < 0.65) else rng.randi_range(-1, 1)
			cur = Vector3i(
				clampi(cur.x + step_x, 0, w - 1),
				mini(cur.y + step_y, dome_apex_y - 2),
				clampi(cur.z + step_z, 0, d - 1)
			)

	# 2. Jellyfish umbrella bell dome at apex
	var bell_r = max_r
	var tentacle_origins: Array[Vector3i] = []

	for dx in range(-bell_r, bell_r + 1):
		var px = cx + dx
		if px < 0 or px >= w:
			continue
		for dz in range(-cz, cz + 1):
			var pz = cz + dz
			if pz < 0 or pz >= d:
				continue

			var dist = sqrt(float(dx * dx) + float(dz * dz) * 1.8)
			if dist <= float(bell_r):
				var curve = int(round(dist * 0.55))
				var bell_y = dome_apex_y - curve
				if bell_y > JUNCTION_Y and bell_y < h:
					grid_3d[px][bell_y][pz] = VoxelType.ENERGY
					if bell_y + 1 < h:
						grid_3d[px][bell_y + 1][pz] = VoxelType.ENERGY
					if dist >= float(bell_r) - 0.95:
						grid_3d[px][bell_y][pz] = VoxelType.ACCENT
						if rng.randf() < 0.65:
							tentacle_origins.append(Vector3i(px, bell_y - 1, pz))

	# 3. Trailing venomous tentacles dropping downward
	for t_orig in tentacle_origins:
		var t_len = rng.randi_range(5, 9)
		var tx = t_orig.x
		var tz = t_orig.z
		for ty in range(t_orig.y, maxi(JUNCTION_Y + 2, t_orig.y - t_len), -1):
			if tx >= 0 and tx < w and tz >= 0 and tz < d:
				if ty == t_orig.y - t_len + 1:
					grid_3d[tx][ty][tz] = VoxelType.ENERGY
				else:
					grid_3d[tx][ty][tz] = VoxelType.ACCENT
				if rng.randf() < 0.30:
					tx = clampi(tx + rng.randi_range(-1, 1), 0, w - 1)
				if rng.randf() < 0.30:
					tz = clampi(tz + rng.randi_range(-1, 1), 0, d - 1)

	# Top crown
	grid_3d[cx][h - 1][cz] = VoxelType.ENERGY
	if cx - 1 >= 0:
		grid_3d[cx - 1][h - 1][cz] = VoxelType.ACCENT
	if cx + 1 < w:
		grid_3d[cx + 1][h - 1][cz] = VoxelType.ACCENT

## 10. Carnivorous Botanical
## Hostile botanical overgrowth. Spine acts as thick central stalk wrapped in a secondary
## mathematical helix of BODY voxels with sharp EDGE thorns. The emitter head flares into
## a hollow bulbous pitcher-plant cavity lined with inward-facing EDGE teeth.
static func _apply_carnivorous_botanical(grid_3d: Array, rng: RandomNumberGenerator, w: int, h: int, d: int, cx: int, cz: int, params: Dictionary) -> void:
	var pitcher_base_y = h - 14

	# 1. Thick central stalk spine
	for y in range(JUNCTION_Y + 1, pitcher_base_y):
		grid_3d[cx][y][cz] = VoxelType.BODY
		if cx - 1 >= 0 and (y % 2 == 0):
			grid_3d[cx - 1][y][cz] = VoxelType.BODY
		if cx + 1 < w and (y % 2 == 1):
			grid_3d[cx + 1][y][cz] = VoxelType.BODY
		if cz > 0:
			grid_3d[cx][y][cz - 1] = VoxelType.BODY
		if cz + 1 < d:
			grid_3d[cx][y][cz + 1] = VoxelType.BODY

	# 2. Strangling thorny vine helix
	var vine_freq = params.get("vine_frequency", 0.62)
	var vine_phase = params.get("vine_phase", rng.randf() * TAU)
	for y in range(JUNCTION_Y + 1, pitcher_base_y):
		var a = float(y) * vine_freq + vine_phase
		var vx = clampi(cx + int(round(sin(a) * float(maxi(1, cx - 1)))), 0, w - 1)
		var vz = clampi(cz + int(round(cos(a) * float(maxi(1, cz)))), 0, d - 1)
		grid_3d[vx][y][vz] = VoxelType.BODY

		if y % 3 == 0:
			var thorn_x = clampi(vx + signi(vx - cx), 0, w - 1)
			var thorn_z = clampi(vz + signi(vz - cz), 0, d - 1)
			if thorn_x != cx or thorn_z != cz:
				grid_3d[thorn_x][y][thorn_z] = VoxelType.EDGE

	# 3. Flared bulbous pitcher-plant cavity & inward-facing teeth
	var max_pitcher_r = maxi(3, cx)
	var rim_y = h - 4

	for y in range(pitcher_base_y, h - 1):
		var t = float(y - pitcher_base_y) / float(maxi(1, rim_y - pitcher_base_y))
		var cur_r = 1.8 + (float(max_pitcher_r) - 1.8) * minf(1.0, t)

		for dx in range(-max_pitcher_r, max_pitcher_r + 1):
			var px = cx + dx
			if px < 0 or px >= w:
				continue
			for dz in range(-cz, cz + 1):
				var pz = cz + dz
				if pz < 0 or pz >= d:
					continue

				var dist = sqrt(float(dx * dx) + float(dz * dz) * 1.6)
				if dist <= cur_r:
					var is_outer_wall = (dist >= cur_r - 1.1)
					if is_outer_wall:
						grid_3d[px][y][pz] = VoxelType.BODY
					elif y <= pitcher_base_y + 2:
						# Digestive acid pool at the bottom of the pitcher
						grid_3d[px][y][pz] = VoxelType.ENERGY
					elif y >= rim_y - 1 and y <= rim_y and dist >= cur_r - 1.8:
						# Inward-facing predatory teeth lining the interior rim
						grid_3d[px][y][pz] = VoxelType.EDGE
					else:
						# Hollow trap cavity
						grid_3d[px][y][pz] = VoxelType.EMPTY

	# Overhanging pitcher hood / operculum at apex
	for dx in range(-2, 3):
		var px = cx + dx
		if px >= 0 and px < w:
			for dz in range(-1, 2):
				var pz = cz + dz
				if pz >= 0 and pz < d:
					grid_3d[px][h - 1][pz] = VoxelType.ACCENT if (dx == 0) else VoxelType.BODY
	grid_3d[cx][h - 1][cz] = VoxelType.ENERGY

## Projects the 3D voxel matrix into a 2D layer for pixel-art icon generation.
static func _update_grid_2d(grid_3d: Array, grid_2d: Array, w: int, h: int, d: int, cx: int, cz: int) -> void:
	for y in range(h):
		for x in range(w):
			var center_val = grid_3d[x][y][cz]
			if center_val != VoxelType.EMPTY:
				grid_2d[y][x] = center_val
			else:
				var found = VoxelType.EMPTY
				for z in range(d):
					var v = grid_3d[x][y][z]
					if v == VoxelType.ENERGY:
						found = VoxelType.ENERGY
						break
					elif v != VoxelType.EMPTY and found == VoxelType.EMPTY:
						found = v
				grid_2d[y][x] = found

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
		mat_opaque.cull_mode = BaseMaterial3D.CULL_DISABLED
		st_opaque.set_material(mat_opaque)
		st_opaque.commit(mesh)

	if energy_quad_count > 0:
		var mat_energy = StandardMaterial3D.new()
		mat_energy.vertex_color_use_as_albedo = true
		mat_energy.emission_enabled = true
		mat_energy.emission = palette["energy"]
		mat_energy.emission_energy_multiplier = 3.5
		mat_energy.cull_mode = BaseMaterial3D.CULL_DISABLED
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
		var p_start = Vector2(4.0, float(ih - 4))
		var p_end = Vector2(float(iw - 4), 4.0)
		var u_perp = Vector2(0.7071, 0.7071)
		var perp_scale: float = minf(1.0, 7.0 / float(maxi(7, w)))

		for y in range(h):
			var t = float(y) / float(maxi(1, h - 1))
			var p_axis = p_start.lerp(p_end, t)

			for x in range(w):
				var v_type = grid_2d[y][x]
				if v_type == VoxelType.EMPTY:
					continue

				var dx = float(x - cx) * perp_scale
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
	parts.amount = 20
	parts.lifetime = 1.3
	parts.preprocess = 0.5
	parts.speed_scale = 0.8
	parts.randomness = 0.4
	parts.local_coords = false

	parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	# Sized for colossal ~2.0m weapon (blade span ~1.6m above junction)
	parts.emission_box_extents = Vector3(0.08, 0.75, 0.06)
	parts.position = Vector3(0.0, 0.75, 0.0)

	parts.direction = Vector3(0.0, 1.0, 0.0)
	parts.spread = 22.0
	parts.gravity = Vector3(0.0, 0.2, 0.0)
	parts.initial_velocity_min = 0.04
	parts.initial_velocity_max = 0.18

	parts.color = color
	parts.scale_amount_min = 0.02
	parts.scale_amount_max = 0.045

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

static func _generate_name(rng: RandomNumberGenerator, profile: WeaponProfile, seed_val: int, topology: int = -1) -> String:
	var prefix = NAME_PREFIXES[rng.randi_range(0, NAME_PREFIXES.size() - 1)]
	var descriptor = "Weapon"
	var topo = topology if topology >= 0 else resolve_topology(profile)
	match topo:
		TopologyType.VOLUMETRIC_EROSION:
			descriptor = "Eroded Weapon"
		TopologyType.PARAMETRIC_HELIX:
			descriptor = "Helical Weapon"
		TopologyType.BRANCHING_FRACTAL:
			descriptor = "Fractal Weapon"
		TopologyType.NOISE_SHATTERED:
			descriptor = "Shattered Weapon"
		TopologyType.KALEIDOSCOPIC:
			descriptor = "Geometric Weapon"
		TopologyType.FUNGAL_BRACKET:
			descriptor = "Mycelial Weapon"
		TopologyType.OSTEOLOGICAL_CAGE:
			descriptor = "Osteo Weapon"
		TopologyType.INSECTOID_HIVE:
			descriptor = "Hive Weapon"
		TopologyType.ABYSSAL_MARINE:
			descriptor = "Abyssal Weapon"
		TopologyType.CARNIVOROUS_BOTANICAL:
			descriptor = "Botanical Weapon"
		_:
			descriptor = "Weapon Frame"

	return "%s %s #%d" % [prefix, descriptor, seed_val % 1000]

static func _generate_description(profile: WeaponProfile, palette: Dictionary, voxel_data: Dictionary, seed_val: int) -> String:
	var h = voxel_data.get("height", TARGET_WEAPON_HEIGHT_VOXELS)
	var pal_name = palette.get("name", "Voxel")
	var topo = voxel_data.get("topology", resolve_topology(profile))
	var topo_desc = "exotic"
	match topo:
		TopologyType.VOLUMETRIC_EROSION:
			topo_desc = "porous eroded"
		TopologyType.PARAMETRIC_HELIX:
			topo_desc = "orbital helical"
		TopologyType.BRANCHING_FRACTAL:
			topo_desc = "branching fractal"
		TopologyType.NOISE_SHATTERED:
			topo_desc = "shattered shard"
		TopologyType.KALEIDOSCOPIC:
			topo_desc = "kaleidoscopic geometric"
		TopologyType.FUNGAL_BRACKET:
			topo_desc = "parasitic fungal bracket"
		TopologyType.OSTEOLOGICAL_CAGE:
			topo_desc = "skeletal osteological cage"
		TopologyType.INSECTOID_HIVE:
			topo_desc = "porous insectoid hive"
		TopologyType.ABYSSAL_MARINE:
			topo_desc = "bioluminescent abyssal marine"
		TopologyType.CARNIVOROUS_BOTANICAL:
			topo_desc = "hostile carnivorous botanical"

	return "A %d-voxel %s weapon forged with %s topology, resonating with %s energy. Attack patterns are governed by slotted cards." % [h, "weapon", topo_desc, pal_name]

static func _generate_deck_stats(rng: RandomNumberGenerator, profile: WeaponProfile, params: Dictionary) -> Dictionary:
	var slot_capacity = 5
	var is_shuffle = false
	var deck_recharge = 0.50
	var dmg_mult = 1.0
	var stam_mult = 1.0

	match profile:
		WeaponProfile.SLENDER, WeaponProfile.PARAMETRIC_HELIX:
			slot_capacity = rng.randi_range(6, 9)
			is_shuffle = false
			deck_recharge = rng.randf_range(0.28, 0.40)
			dmg_mult = rng.randf_range(0.88, 1.00)
			stam_mult = rng.randf_range(0.82, 0.92)

		WeaponProfile.HEAVY, WeaponProfile.VOLUMETRIC_EROSION:
			slot_capacity = rng.randi_range(4, 6)
			is_shuffle = false
			deck_recharge = rng.randf_range(0.62, 0.78)
			dmg_mult = rng.randf_range(1.25, 1.45)
			stam_mult = rng.randf_range(1.15, 1.30)

		WeaponProfile.SEGMENTED, WeaponProfile.NOISE_SHATTERED:
			slot_capacity = rng.randi_range(5, 8)
			is_shuffle = rng.randf() < 0.45
			deck_recharge = rng.randf_range(0.42, 0.55)
			dmg_mult = rng.randf_range(1.02, 1.15)
			stam_mult = 1.0

		WeaponProfile.FLANGED, WeaponProfile.BRANCHING_FRACTAL:
			slot_capacity = rng.randi_range(5, 7)
			is_shuffle = false
			deck_recharge = rng.randf_range(0.45, 0.58)
			dmg_mult = rng.randf_range(1.10, 1.22)
			stam_mult = rng.randf_range(0.95, 1.05)

		WeaponProfile.FUNGAL_BRACKET:
			slot_capacity = rng.randi_range(4, 6)
			is_shuffle = false
			deck_recharge = rng.randf_range(0.55, 0.70)
			dmg_mult = rng.randf_range(1.20, 1.35)
			stam_mult = rng.randf_range(1.10, 1.25)

		WeaponProfile.OSTEOLOGICAL_CAGE:
			slot_capacity = rng.randi_range(6, 8)
			is_shuffle = false
			deck_recharge = rng.randf_range(0.35, 0.48)
			dmg_mult = rng.randf_range(1.05, 1.18)
			stam_mult = rng.randf_range(0.90, 1.02)

		WeaponProfile.INSECTOID_HIVE:
			slot_capacity = rng.randi_range(5, 7)
			is_shuffle = true
			deck_recharge = rng.randf_range(0.40, 0.52)
			dmg_mult = rng.randf_range(1.12, 1.28)
			stam_mult = rng.randf_range(0.98, 1.10)

		WeaponProfile.ABYSSAL_MARINE:
			slot_capacity = rng.randi_range(6, 9)
			is_shuffle = false
			deck_recharge = rng.randf_range(0.32, 0.44)
			dmg_mult = rng.randf_range(0.95, 1.10)
			stam_mult = rng.randf_range(0.85, 0.95)

		WeaponProfile.CARNIVOROUS_BOTANICAL:
			slot_capacity = rng.randi_range(5, 8)
			is_shuffle = false
			deck_recharge = rng.randf_range(0.45, 0.58)
			dmg_mult = rng.randf_range(1.15, 1.30)
			stam_mult = rng.randf_range(1.05, 1.18)

		_: # BALANCED, KALEIDOSCOPIC
			slot_capacity = rng.randi_range(5, 7)
			is_shuffle = false
			deck_recharge = rng.randf_range(0.45, 0.55)
			dmg_mult = rng.randf_range(1.00, 1.10)
			stam_mult = 1.0

	# Frame tier crafting logic (procedural_todo_20_slots.md)
	var tier_val = params.get("crafting_tier", params.get("tier", -1))
	if tier_val is int and tier_val >= 0:
		match tier_val:
			FrameTier.STANDARD:
				slot_capacity = rng.randi_range(4, 7)
			FrameTier.RESONANT:
				slot_capacity = rng.randi_range(8, 12)
				deck_recharge = rng.randf_range(0.35, 0.48)
			FrameTier.APEX:
				slot_capacity = rng.randi_range(13, 16)
				deck_recharge = rng.randf_range(0.28, 0.38)
			FrameTier.CYCLOTRON:
				slot_capacity = rng.randi_range(18, 20)
				deck_recharge = rng.randf_range(0.22, 0.32)

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

## Dedicated crafting function for forging a 20-slot Cyclotron frame.
## Serves as the pinnacle kinetic accelerator supercomputer frame (procedural_todo_20_slots.md).
static func craft_cyclotron_frame(seed_val: int = -1, params: Dictionary = {}) -> MeleeWeaponDef:
	var craft_params = params.duplicate()
	craft_params["crafting_tier"] = FrameTier.CYCLOTRON
	craft_params["slot_capacity"] = 20
	if not craft_params.has("name"):
		var id_num = (seed_val if seed_val >= 0 else int(Time.get_ticks_usec())) % 10000
		craft_params["name"] = "Cyclotron Singularity Frame #%d" % id_num
	return generate_weapon(seed_val, craft_params)
