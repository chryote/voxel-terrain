class_name ChasmShellMesher
extends Mesher

## Ultra-fast 2.5D Direct Heightfield Mesher for deep subterranean chasms and battle arenas.
## Accelerated natively via godot-cpp GDExtension.

var cave_water_enabled: bool:
	get:
		return _native.get_cave_water_enabled()
	set(val):
		_native.set_cave_water_enabled(val)

var _native: ChasmShellMesherNative = ChasmShellMesherNative.new()

func build_mesh(data: RefCounted, registry: MaterialRegistry) -> MeshData:
	return _native.build_mesh(data, registry)
