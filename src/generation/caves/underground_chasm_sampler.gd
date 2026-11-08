class_name UndergroundChasmSampler
extends UndergroundChasmSamplerNative

## Pure mathematical sampler for the Dual-2D Heightmap Deep Chasms & Abyssal Caverns system.
## Replaces volumetric 3D Simplex noise with two 2D heightfield noise maps (floor and ceiling)
## bounded laterally by a domain-warped 2D tectonic rift corridor mask with vertical walls.
## Guarantees minimum vertical clearance and indestructible bedrock protection.
## Accelerated natively by UndergroundChasmSamplerNative via godot-cpp GDExtension.

const WALL_MARGIN: float = 0.03
const DEEP_INLAND_LAND_THRESHOLD: float = 0.20

func _init(seed_val: int = 1337, p_config: CaveGeneratorConfig = null) -> void:
	var cfg = p_config if p_config != null else CaveGeneratorConfig.new()
	initialize(seed_val, cfg)
