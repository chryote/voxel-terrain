class_name FluvialCarver
extends FluvialCarverNative

## Pure component responsible for fluvial drainage networks:
## Wide rivers, small winding streams, lake basins, and inland ponds.
## Accelerated natively by FluvialCarverNative via godot-cpp GDExtension.

func _init(seed_val: int = 1337, p_config: ContinentGeneratorConfig = null) -> void:
	var cfg = p_config if p_config != null else ContinentGeneratorConfig.new()
	initialize(seed_val, cfg)
