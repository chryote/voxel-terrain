#ifndef SURFACE_SHELL_MESHER_NATIVE_H
#define SURFACE_SHELL_MESHER_NATIVE_H

#include <godot_cpp/classes/ref_counted.hpp>

namespace godot {

class SurfaceShellMesherNative : public RefCounted {
    GDCLASS(SurfaceShellMesherNative, RefCounted);

public:
    int sea_level = 24;
    Ref<RefCounted> water_mesher;

protected:
    static void _bind_methods();

public:
    SurfaceShellMesherNative();
    ~SurfaceShellMesherNative();

    Ref<RefCounted> build_mesh(const Variant &p_data, const Variant &p_registry);

    int get_sea_level() const { return sea_level; }
    void set_sea_level(int p_val) { sea_level = p_val; }

    Ref<RefCounted> get_water_mesher() const { return water_mesher; }
    void set_water_mesher(const Ref<RefCounted> &p_val) { water_mesher = p_val; }
};

} // namespace godot

#endif // SURFACE_SHELL_MESHER_NATIVE_H
