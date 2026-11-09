class_name SubterraneanTunnelSampler
extends SubterraneanTunnelSamplerNative

## Pure component responsible for 3D worm-tunnel geometry, bifurcations,
## player navigation clearance, and continuity modulation for dead ends.
## Uses dual 3D simplex noise fields to carve continuous winding corridors,
## with a 3D continuity noise that pinches off branches into natural dead ends.
## Accelerated natively by SubterraneanTunnelSamplerNative via godot-cpp GDExtension.

func _init(seed_val: int = 1337, p_config: CaveGeneratorConfig = null, p_chasm_sampler: UndergroundChasmSampler = null) -> void:
	var cfg = p_config if p_config != null else CaveGeneratorConfig.new()
	initialize(seed_val, cfg, p_chasm_sampler)
