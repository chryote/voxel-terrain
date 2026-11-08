#ifndef CONTINENT_MAP_BAKER_NATIVE_H
#define CONTINENT_MAP_BAKER_NATIVE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

namespace godot {

class ContinentMapBakerNative : public RefCounted {
    GDCLASS(ContinentMapBakerNative, RefCounted)

protected:
    static void _bind_methods();

public:
    ContinentMapBakerNative();
    ~ContinentMapBakerNative();

    Ref<Image> bake_surface_map_native(
        Variant generator,
        Ref<RefCounted> bounds,
        int32_t resolution,
        Ref<RefCounted> palette
    );

    Ref<Image> bake_underground_map_native(
        Variant generator,
        Ref<RefCounted> bounds,
        int32_t resolution,
        Ref<RefCounted> palette,
        int32_t min_island_pixels
    );

    Ref<Image> bake_map_native(
        Variant generator,
        Ref<RefCounted> bounds,
        int32_t resolution,
        Ref<RefCounted> palette,
        int32_t level
    );

    int32_t cull_small_underground_islands_raw(
        uint8_t* p_flags,
        int32_t* p_floor_heights,
        int32_t p_resolution,
        int32_t p_min_island_pixels
    );
};

} // namespace godot

#endif // CONTINENT_MAP_BAKER_NATIVE_H
