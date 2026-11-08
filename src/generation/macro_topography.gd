class_name MacroTopography
extends MacroTopographyNative

## Pure component responsible for synthesizing continental macro-elevation:
## Coasts, Lowlands, Rolling Hills, Highlands, Mountainous Regions, and Offshore Cliff Islands.
## Accelerated natively by MacroTopographyNative via godot-cpp GDExtension.

func _init(seed_val: int = 1337, p_config: ContinentGeneratorConfig = null, p_mask: ContinentMask = null) -> void:
	var cfg = p_config if p_config != null else ContinentGeneratorConfig.new()
	initialize(seed_val, cfg, p_mask)
