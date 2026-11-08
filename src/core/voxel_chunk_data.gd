class_name VoxelChunkData
extends VoxelChunkDataNative

## Stores 3D volumetric voxel material IDs and water states for a chunk,
## including a 1-voxel apron across horizontal boundaries for zero-lock multithreaded meshing.
## Accelerated natively by VoxelChunkDataNative via godot-cpp GDExtension.

func _init(p_chunk_size: int = 32, p_max_height: int = 160) -> void:
	initialize(p_chunk_size, p_max_height)
