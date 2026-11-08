class_name ChasmColumnResult
extends ChasmColumnResultNative

## Value object representing the vertical span of a subterranean chasm at an (x, z) column.
## Designed to be allocated once and reused across sampling loops to eliminate GC pressure.
## Accelerated natively by ChasmColumnResultNative via godot-cpp GDExtension.
