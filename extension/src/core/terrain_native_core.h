#ifndef TERRAIN_NATIVE_CORE_H
#define TERRAIN_NATIVE_CORE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

class TerrainNativeCore : public RefCounted {
    GDCLASS(TerrainNativeCore, RefCounted);

protected:
    static void _bind_methods();

public:
    TerrainNativeCore();
    ~TerrainNativeCore();

    bool is_native_active() const;
    String get_version() const;
    float sample_test_noise(float x, float y, int seed = 1337) const;
};

} // namespace godot

#endif // TERRAIN_NATIVE_CORE_H

