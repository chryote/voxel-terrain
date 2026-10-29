class_name FoliageChunkData
extends RefCounted

## Pure data container for baked MultiMesh instance transform buffers.
## Completely thread-safe and safe to generate on background worker threads.

var instance_count: int = 0
var transform_buffer: PackedFloat32Array = PackedFloat32Array()

func _init(p_count: int = 0, p_buffer: PackedFloat32Array = PackedFloat32Array()) -> void:
	instance_count = p_count
	transform_buffer = p_buffer

func is_empty() -> bool:
	return instance_count <= 0 or transform_buffer.is_empty()

func clear() -> void:
	instance_count = 0
	transform_buffer.clear()

## Appends a single Transform3D as 12 raw floats matching Godot's MultiMesh TRANSFORM_3D format.
func add_instance(t: Transform3D) -> void:
	var basis: Basis = t.basis
	var origin: Vector3 = t.origin

	# Row 0: basis.x.x, basis.y.x, basis.z.x, origin.x
	transform_buffer.append(basis.x.x)
	transform_buffer.append(basis.y.x)
	transform_buffer.append(basis.z.x)
	transform_buffer.append(origin.x)

	# Row 1: basis.x.y, basis.y.y, basis.z.y, origin.y
	transform_buffer.append(basis.x.y)
	transform_buffer.append(basis.y.y)
	transform_buffer.append(basis.z.y)
	transform_buffer.append(origin.y)

	# Row 2: basis.x.z, basis.y.z, basis.z.z, origin.z
	transform_buffer.append(basis.x.z)
	transform_buffer.append(basis.y.z)
	transform_buffer.append(basis.z.z)
	transform_buffer.append(origin.z)

	instance_count += 1

## Reconstructs the Transform3D of an instance at index for test validation.
func get_instance_transform(idx: int) -> Transform3D:
	if idx < 0 or idx >= instance_count:
		return Transform3D.IDENTITY
	var offset: int = idx * 12
	if offset + 12 > transform_buffer.size():
		return Transform3D.IDENTITY

	var basis = Basis(
		Vector3(transform_buffer[offset + 0], transform_buffer[offset + 4], transform_buffer[offset + 8]),
		Vector3(transform_buffer[offset + 1], transform_buffer[offset + 5], transform_buffer[offset + 9]),
		Vector3(transform_buffer[offset + 2], transform_buffer[offset + 6], transform_buffer[offset + 10])
	)
	var origin = Vector3(
		transform_buffer[offset + 3],
		transform_buffer[offset + 7],
		transform_buffer[offset + 11]
	)
	return Transform3D(basis, origin)

