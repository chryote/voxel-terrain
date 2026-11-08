class_name VoxelMesher
extends Mesher

## High-performance 3D greedy voxel mesher with dual-layer surface and subterranean separation.
## Accelerated natively via godot-cpp GDExtension.

var sea_level: int:
	get:
		return _native.get_sea_level()
	set(val):
		_native.set_sea_level(val)

var crust_depth: int:
	get:
		return _native.get_crust_depth()
	set(val):
		_native.set_crust_depth(val)

var cave_water_enabled: bool:
	get:
		return _native.get_cave_water_enabled()
	set(val):
		_native.set_cave_water_enabled(val)

var _native: VoxelMesherNative = VoxelMesherNative.new()

func build_mesh(data: RefCounted, registry: MaterialRegistry) -> MeshData:
	return _native.build_mesh(data, registry)
