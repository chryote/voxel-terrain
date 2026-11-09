class_name FallbackPillProvider
extends RefCounted

## Factory helper that constructs or configures the fallback weathered capsule mesh.

const CAPSULE_SHADER = preload("res://shaders/character/weathered_capsule.gdshader")
const CAPSULE_RADIUS: float = 0.4
const CAPSULE_HEIGHT: float = 1.8
const CAPSULE_CENTER_Y: float = 0.9

static func create_fallback_mesh() -> CapsuleMesh:
	var mesh = CapsuleMesh.new()
	mesh.radius = CAPSULE_RADIUS
	mesh.height = CAPSULE_HEIGHT
	return mesh

static func create_fallback_material() -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	mat.shader = CAPSULE_SHADER
	return mat

static func create_fallback_instance() -> MeshInstance3D:
	var instance = MeshInstance3D.new()
	instance.name = "FallbackCapsule"
	instance.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, CAPSULE_CENTER_Y, 0.0))
	instance.mesh = create_fallback_mesh()
	instance.material_override = create_fallback_material()
	return instance

