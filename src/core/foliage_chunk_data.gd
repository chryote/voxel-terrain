class_name FoliageChunkData
extends RefCounted

## Pure data container for baked MultiMesh instance transform buffers.
## Completely thread-safe and safe to generate on background worker threads.

var instance_count: int = 0
var transform_buffer: PackedFloat32Array = PackedFloat32Array()

var bush_instance_count: int = 0
var bush_transform_buffer: PackedFloat32Array = PackedFloat32Array()

func _init(
	p_count: int = 0, p_buffer: PackedFloat32Array = PackedFloat32Array(),
	p_bush_count: int = 0, p_bush_buffer: PackedFloat32Array = PackedFloat32Array()
) -> void:
	instance_count = p_count
	transform_buffer = p_buffer
	bush_instance_count = p_bush_count
	bush_transform_buffer = p_bush_buffer

func is_empty() -> bool:
	return (instance_count <= 0 or transform_buffer.is_empty()) and (bush_instance_count <= 0 or bush_transform_buffer.is_empty())

func clear() -> void:
	instance_count = 0
	transform_buffer.clear()
	bush_instance_count = 0
	bush_transform_buffer.clear()

## Appends a single grass Transform3D as 12 raw floats matching Godot's MultiMesh TRANSFORM_3D format.
func add_instance(t: Transform3D) -> void:
	_append_transform(transform_buffer, t)
	instance_count += 1

## Appends a single bush Transform3D as 12 raw floats matching Godot's MultiMesh TRANSFORM_3D format.
func add_bush_instance(t: Transform3D) -> void:
	_append_transform(bush_transform_buffer, t)
	bush_instance_count += 1

## Reconstructs the Transform3D of a grass instance at index for test validation.
func get_instance_transform(idx: int) -> Transform3D:
	return _read_transform(transform_buffer, instance_count, idx)

## Reconstructs the Transform3D of a bush instance at index for test validation.
func get_bush_instance_transform(idx: int) -> Transform3D:
	return _read_transform(bush_transform_buffer, bush_instance_count, idx)

## Deterministically shuffles instance blocks (12 floats each) in place using a Fisher-Yates shuffle.
## Ensures any prefix of instances (e.g. 25% or 50% for LOD) is spatially uniform across the chunk.
func shuffle_deterministically(seed_val: int) -> void:
	_shuffle_buffer(transform_buffer, instance_count, seed_val)
	_shuffle_buffer(bush_transform_buffer, bush_instance_count, seed_val ^ 0x5BF3)

static func _append_transform(buf: PackedFloat32Array, t: Transform3D) -> void:
	var b: Basis = t.basis
	var o: Vector3 = t.origin
	buf.append_array([
		b.x.x, b.y.x, b.z.x, o.x,
		b.x.y, b.y.y, b.z.y, o.y,
		b.x.z, b.y.z, b.z.z, o.z
	])

static func _read_transform(buf: PackedFloat32Array, count: int, idx: int) -> Transform3D:
	if idx < 0 or idx >= count:
		return Transform3D.IDENTITY
	var off: int = idx * 12
	if off + 12 > buf.size():
		return Transform3D.IDENTITY
	var basis = Basis(
		Vector3(buf[off + 0], buf[off + 4], buf[off + 8]),
		Vector3(buf[off + 1], buf[off + 5], buf[off + 9]),
		Vector3(buf[off + 2], buf[off + 6], buf[off + 10])
	)
	var origin = Vector3(buf[off + 3], buf[off + 7], buf[off + 11])
	return Transform3D(basis, origin)

static func _shuffle_buffer(buf: PackedFloat32Array, count: int, seed_val: int) -> void:
	if count <= 1:
		return
	var rng: int = seed_val
	for i in range(count - 1, 0, -1):
		rng = ((rng * 1103515245 + 12345) & 0x7FFFFFFF)
		var j: int = rng % (i + 1)
		if i != j:
			var off_i: int = i * 12
			var off_j: int = j * 12
			for k in range(12):
				var tmp: float = buf[off_i + k]
				buf[off_i + k] = buf[off_j + k]
				buf[off_j + k] = tmp
