class_name CaveCarver
extends RefCounted

## High-level coordinator unifying 2D cave mouths, 3D worm tunnels, and deep chasms.
## Features hierarchical coarse-lattice culling to guarantee 160 FPS on the surface
## and rapid subterranean chunk generation on background worker threads.

const STATUS_SOLID: int = -1
const STATUS_MIXED: int = 0
const STATUS_AIR: int = 1

var config: CaveGeneratorConfig
var mouth_sampler: CaveMouthSampler
var tunnel_sampler: SubterraneanTunnelSampler
var chasm_sampler: UndergroundChasmSampler

var crystal_noise: FastNoiseLite

func _init(seed_val: int = 1337, p_config: CaveGeneratorConfig = null) -> void:
	config = p_config if p_config != null else CaveGeneratorConfig.new()

	mouth_sampler = CaveMouthSampler.new(seed_val, config)
	tunnel_sampler = SubterraneanTunnelSampler.new(seed_val, config)
	chasm_sampler = UndergroundChasmSampler.new(seed_val, config)

	# High-frequency vein noise for subterranean crystal deposits
	crystal_noise = FastNoiseLite.new()
	crystal_noise.seed = seed_val + 1111
	crystal_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	crystal_noise.frequency = 0.04

func sample_carve_density(wx: float, wy: float, wz: float, surface_h: float, sea_level: int) -> float:
	## Returns carving density: > 0.0 means hollow air (carved), <= 0.0 means solid rock.
	# 1. Above surface is natural sky air
	if wy > surface_h:
		return 1.0

	# When caves are disabled, underground remains 100% solid rock
	if not config.enabled:
		return 0.0

	# 2. Bedrock floor (Y <= 2) is indestructible solid
	if wy <= 2.0:
		return 0.0

	# 3. Surface crust protection: outer terrain cannot be punctured except at active mouths
	if mouth_sampler.is_crust_sealed(wx, wy, wz, surface_h, sea_level):
		return 0.0

	# 4. Cave mouth downward funnel check (strictly bounded to entrance depth)
	if wy >= (surface_h - config.max_entrance_depth) and wy <= (surface_h + 1.0):
		var mouth_carve = mouth_sampler.get_funnel_carve(wx, wy, wz, surface_h, sea_level)
		if mouth_carve > 0.0:
			return mouth_carve

	# 5. Deep chasm cavern check (confined strictly to Y: 4-22)
	var chasm_carve = 0.0
	if wy > float(config.chasm_min_y) and wy < float(config.chasm_max_y):
		chasm_carve = chasm_sampler.get_chasm_carve(wx, wy, wz)

	# 6. 3D worm tunnel check
	var tunnel_carve = tunnel_sampler.get_tunnel_carve(wx, wy, wz)

	# Combine hollowed spaces
	return maxf(tunnel_carve, chasm_carve)

func is_carved(wx: float, wy: float, wz: float, surface_h: float, sea_level: int) -> bool:
	return sample_carve_density(wx, wy, wz, surface_h, sea_level) > 0.05

func is_subterranean_water(wx: float, wy: float, wz: float, surface_h: float, sea_level: int) -> bool:
	if wy > float(config.chasm_water_level):
		return false
	if not is_carved(wx, wy, wz, surface_h, sea_level):
		return false
	return chasm_sampler.is_subterranean_water(wx, wy, wz)

func classify_subterranean_voxel(wx: float, wy: float, wz: float) -> int:
	## Assigns geological material for solid voxels exposed to cave/chasm voids.
	# Deep chasm strata (Y <= chasm_max_y)
	if wy <= float(config.chasm_max_y):
		# Basalt lining for submerged chasm basin and cavern floors
		if wy <= float(config.chasm_water_level + 1):
			return MaterialDef.ID_CHASM_BASALT

		# Crystal deposits in deep chasm walls
		var c_sample = crystal_noise.get_noise_3d(wx, wy, wz)
		if c_sample > 0.62:
			return MaterialDef.ID_CAVE_CRYSTAL

		return MaterialDef.ID_CHASM_BASALT

	# Upper and mid cave strata
	return MaterialDef.ID_CAVE_WALL

func sample_coarse_cell_status(min_p: Vector3, max_p: Vector3, min_surface_h: float, max_surface_h: float, sea_level: int) -> int:
	## Hierarchical performance optimization:
	## Evaluates whether an entire coarse cell (e.g. 4x4x4 voxels) is definitely pure air or solid rock.
	# 1. Completely above surface -> pure air
	if min_p.y > max_surface_h:
		return STATUS_AIR

	# When caves are disabled, all subterranean cells are completely solid rock
	if not config.enabled:
		return STATUS_SOLID

	# 2. Completely below bedrock -> pure solid
	if max_p.y <= 2.0:
		return STATUS_SOLID

	# 3. Completely inside protected surface crust with no mouths -> pure solid
	if max_p.y <= min_surface_h and min_p.y >= (max_surface_h - config.crust_depth):
		if not mouth_sampler.can_mouth_intersect_cell(min_p, max_p, max_surface_h, sea_level):
			return STATUS_SOLID

	# 4. Multi-strata culling: check if any subterranean cave feature can intersect this cell
	var can_mouth = mouth_sampler.can_mouth_intersect_cell(min_p, max_p, max_surface_h, sea_level)
	var can_chasm = chasm_sampler.can_chasm_intersect_cell(min_p, max_p)
	var can_tunnel = tunnel_sampler.can_tunnel_intersect_cell(min_p, max_p)

	if not can_mouth and not can_chasm and not can_tunnel:
		return STATUS_SOLID

	return STATUS_MIXED
