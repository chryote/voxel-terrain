class_name VoxelQuadBuilder
extends RefCounted

## Pure utility for appending oriented 3D quads with normals, colors, and indices to MeshData.

static func append_quad(
	mesh: MeshData,
	p0: Vector3,
	p1: Vector3,
	p2: Vector3,
	p3: Vector3,
	norm: Vector3,
	col: Color
) -> void:
	var base = mesh.vertices.size()
	mesh.vertices.append(p0)
	mesh.vertices.append(p1)
	mesh.vertices.append(p2)
	mesh.vertices.append(p3)

	for _i in range(4):
		mesh.normals.append(norm)
		mesh.colors.append(col)

	mesh.indices.append(base)
	mesh.indices.append(base + 2)
	mesh.indices.append(base + 1)
	mesh.indices.append(base)
	mesh.indices.append(base + 3)
	mesh.indices.append(base + 2)

static func add_top_quad(mesh: MeshData, x: float, y: float, z: float, w: float, d: float, col: Color) -> void:
	append_quad(
		mesh,
		Vector3(x, y, z),
		Vector3(x, y, z + d),
		Vector3(x + w, y, z + d),
		Vector3(x + w, y, z),
		Vector3(0.0, 1.0, 0.0),
		col
	)

static func add_bottom_quad(mesh: MeshData, x: float, y: float, z: float, w: float, d: float, col: Color) -> void:
	append_quad(
		mesh,
		Vector3(x, y, z),
		Vector3(x + w, y, z),
		Vector3(x + w, y, z + d),
		Vector3(x, y, z + d),
		Vector3(0.0, -1.0, 0.0),
		col
	)

static func add_east_quad(mesh: MeshData, x: float, y: float, z: float, h: float, d: float, col: Color) -> void:
	append_quad(
		mesh,
		Vector3(x, y, z),
		Vector3(x, y + h, z),
		Vector3(x, y + h, z + d),
		Vector3(x, y, z + d),
		Vector3(1.0, 0.0, 0.0),
		col
	)

static func add_west_quad(mesh: MeshData, x: float, y: float, z: float, h: float, d: float, col: Color) -> void:
	append_quad(
		mesh,
		Vector3(x, y, z + d),
		Vector3(x, y + h, z + d),
		Vector3(x, y + h, z),
		Vector3(x, y, z),
		Vector3(-1.0, 0.0, 0.0),
		col
	)

static func add_north_quad(mesh: MeshData, x: float, y: float, z: float, w: float, h: float, col: Color) -> void:
	append_quad(
		mesh,
		Vector3(x + w, y, z),
		Vector3(x + w, y + h, z),
		Vector3(x, y + h, z),
		Vector3(x, y, z),
		Vector3(0.0, 0.0, 1.0),
		col
	)

static func add_south_quad(mesh: MeshData, x: float, y: float, z: float, w: float, h: float, col: Color) -> void:
	append_quad(
		mesh,
		Vector3(x, y, z),
		Vector3(x, y + h, z),
		Vector3(x + w, y + h, z),
		Vector3(x + w, y, z),
		Vector3(0.0, 0.0, -1.0),
		col
	)
