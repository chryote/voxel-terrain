class_name SurfaceShellMesher
extends Mesher

## Ultra-fast 2.5D Direct Heightfield Mesher for terrain surface crust.
## Accelerated natively via godot-cpp GDExtension.

var sea_level: int:
	get:
		return _native.get_sea_level()
	set(val):
		_native.set_sea_level(val)

var _native: SurfaceShellMesherNative = SurfaceShellMesherNative.new()

func build_mesh(data: RefCounted, registry: MaterialRegistry) -> MeshData:
	return _native.build_mesh(data, registry)
