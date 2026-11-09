#ifndef OFF_THREAD_COLLISION_BAKER_NATIVE_H
#define OFF_THREAD_COLLISION_BAKER_NATIVE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/concave_polygon_shape3d.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

namespace godot {

class OffThreadCollisionBakerNative : public RefCounted {
    GDCLASS(OffThreadCollisionBakerNative, RefCounted);

protected:
    static void _bind_methods();

public:
    OffThreadCollisionBakerNative();
    ~OffThreadCollisionBakerNative();

    Ref<ConcavePolygonShape3D> bake_shape(const Variant &p_mesh_data);
    Dictionary bake_shapes_for_bundle(const Variant &p_mesh_data, bool p_bake_cave = true);
};

} // namespace godot

#endif // OFF_THREAD_COLLISION_BAKER_NATIVE_H
