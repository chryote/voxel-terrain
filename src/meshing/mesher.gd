class_name Mesher
extends RefCounted

## Abstract base class for voxel chunk meshers.

func build_mesh(_data: RefCounted, _registry: MaterialRegistry) -> MeshData:
	push_error("Mesher.build_mesh() must be overridden")
	return null
