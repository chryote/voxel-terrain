#include "off_thread_collision_baker.h"
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void OffThreadCollisionBakerNative::_bind_methods() {
    ClassDB::bind_method(D_METHOD("bake_shape", "mesh_data"), &OffThreadCollisionBakerNative::bake_shape);
    ClassDB::bind_method(D_METHOD("bake_shapes_for_bundle", "mesh_data", "bake_cave"), &OffThreadCollisionBakerNative::bake_shapes_for_bundle, DEFVAL(true));
}

OffThreadCollisionBakerNative::OffThreadCollisionBakerNative() {}

OffThreadCollisionBakerNative::~OffThreadCollisionBakerNative() {}

Ref<ConcavePolygonShape3D> OffThreadCollisionBakerNative::bake_shape(const Variant &p_mesh_data) {
    if (p_mesh_data.get_type() != Variant::OBJECT) {
        return nullptr;
    }
    Object *obj = p_mesh_data;
    if (!obj) {
        return nullptr;
    }

    if (obj->has_method("is_empty")) {
        bool empty = obj->call("is_empty");
        if (empty) {
            return nullptr;
        }
    }

    PackedVector3Array verts = obj->get("vertices");
    PackedInt32Array inds = obj->get("indices");
    int64_t num_indices = inds.size();
    if (num_indices == 0 || verts.is_empty()) {
        return nullptr;
    }

    PackedVector3Array faces;
    faces.resize(num_indices);
    Vector3 *dst = faces.ptrw();
    const Vector3 *src_verts = verts.ptr();
    const int32_t *src_inds = inds.ptr();

    for (int64_t i = 0; i < num_indices; ++i) {
        dst[i] = src_verts[src_inds[i]];
    }

    Ref<ConcavePolygonShape3D> shape;
    shape.instantiate();
    shape->set_faces(faces);
    shape->set_backface_collision_enabled(true);
    return shape;
}

Dictionary OffThreadCollisionBakerNative::bake_shapes_for_bundle(const Variant &p_mesh_data, bool p_bake_cave) {
    Dictionary result;
    result["surface_shape"] = Variant();
    result["cave_shape"] = Variant();

    if (p_mesh_data.get_type() != Variant::OBJECT) {
        return result;
    }
    Object *obj = p_mesh_data;
    if (!obj) {
        return result;
    }

    bool is_empty = false;
    if (obj->has_method("is_empty")) {
        is_empty = obj->call("is_empty");
    }
    if (!is_empty) {
        result["surface_shape"] = bake_shape(p_mesh_data);
    }

    if (p_bake_cave && obj->has_method("has_cave_geometry")) {
        bool has_cave = obj->call("has_cave_geometry");
        if (has_cave) {
            Variant cave_mesh = obj->get("cave_mesh_data");
            result["cave_shape"] = bake_shape(cave_mesh);
        }
    }

    return result;
}
