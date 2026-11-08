#ifndef CHASM_SHELL_MESHER_NATIVE_H
#define CHASM_SHELL_MESHER_NATIVE_H

#include "surface_shell_mesher.h"
#include <godot_cpp/classes/ref_counted.hpp>

namespace godot {

class ChasmShellMesherNative : public RefCounted {
    GDCLASS(ChasmShellMesherNative, RefCounted);

public:
    static const int FLAG_CHASM = 1;
    static const int FLAG_PILLAR = 2;
    static const int FLAG_WALL = 4;
    static const int FLAG_ARENA = 8;
    static const int FLAG_ARENA_LEDGE = 16;
    static const int FLAG_BASALT_COLUMN = 32;

    static const int ID_CHASM_BASALT = 9;

    bool cave_water_enabled = true;
    Ref<SurfaceShellMesherNative> surface_mesher;

protected:
    static void _bind_methods();

    void _mesh_subterranean_chasm(Object *chasm_data, Object *registry, Ref<RefCounted> &bundle);

    static void _emit_quad_x_pos(PackedVector3Array &verts, PackedVector3Array &norms, PackedColorArray &cols, PackedInt32Array &inds,
                                float x, float y_min, float y_max, float z, float d, const Color &color);
    static void _emit_quad_x_neg(PackedVector3Array &verts, PackedVector3Array &norms, PackedColorArray &cols, PackedInt32Array &inds,
                                float x, float y_min, float y_max, float z, float d, const Color &color);
    static void _emit_quad_z_pos(PackedVector3Array &verts, PackedVector3Array &norms, PackedColorArray &cols, PackedInt32Array &inds,
                                float z, float y_min, float y_max, float x, float w, const Color &color);
    static void _emit_quad_z_neg(PackedVector3Array &verts, PackedVector3Array &norms, PackedColorArray &cols, PackedInt32Array &inds,
                                float z, float y_min, float y_max, float x, float w, const Color &color);

public:
    ChasmShellMesherNative();
    ~ChasmShellMesherNative();

    Ref<RefCounted> build_mesh(const Variant &p_data, const Variant &p_registry);

    bool get_cave_water_enabled() const { return cave_water_enabled; }
    void set_cave_water_enabled(bool p_val) { cave_water_enabled = p_val; }

    Ref<SurfaceShellMesherNative> get_surface_mesher() const { return surface_mesher; }
    void set_surface_mesher(const Ref<SurfaceShellMesherNative> &p_val) { surface_mesher = p_val; }
};

} // namespace godot

#endif // CHASM_SHELL_MESHER_NATIVE_H
