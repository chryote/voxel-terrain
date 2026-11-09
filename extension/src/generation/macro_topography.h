#ifndef MACRO_TOPOGRAPHY_NATIVE_H
#define MACRO_TOPOGRAPHY_NATIVE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/fast_noise_lite.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include "FastNoiseLite.h"

namespace godot {

class MacroTopographyNative : public RefCounted {
    GDCLASS(MacroTopographyNative, RefCounted);

public:
    Ref<RefCounted> config;
    Variant mask;
    Ref<godot::FastNoiseLite> mountain_noise_gd;

    // Direct C++ FastNoiseLite instances
    auburn::FastNoiseLite cont_noise;
    auburn::FastNoiseLite erosion_noise;
    auburn::FastNoiseLite lowland_noise;
    auburn::FastNoiseLite hills_noise;
    auburn::FastNoiseLite highland_noise;
    auburn::FastNoiseLite mountain_noise;

    // Synced configuration fields
    double continent_noise_frequency = 0.00065;
    double erosion_frequency = 0.0012;
    double lowland_frequency = 0.003;
    double lowland_base_elevation = 25.0;
    double lowland_amplitude = 8.0;
    double rolling_hills_frequency = 0.0035;
    double rolling_hills_amplitude = 24.0;
    double highland_frequency = 0.0012;
    double highland_threshold = 0.55;
    double highland_boost = 60.0;
    double mountain_frequency = 0.004;
    double mountain_threshold = 0.45;
    double mountain_power = 1.6;
    double mountain_amplitude = 85.0;
    int32_t mountain_octaves = 4;
    double mountain_fractal_gain = 0.32;
    double mountain_lacunarity = 2.0;
    double inland_elevation_bias = 8.0;
    int32_t seabed_level = 6;
    int32_t sea_level = 24;
    double island_cliff_height = 16.0;
    int32_t island_terrace_step_height = 1;
    double island_terrace_span = 0.55;

    int32_t current_seed = 1337;

protected:
    static void _bind_methods();

public:
    MacroTopographyNative();
    ~MacroTopographyNative() override = default;

    void initialize(int32_t seed_val = 1337, Ref<RefCounted> p_config = nullptr, Variant p_mask = Variant());
    void _init_noises(int32_t seed_val);
    void sync_config();

    Ref<RefCounted> get_config() const { return config; }
    void set_config(Ref<RefCounted> p_config);

    Variant get_mask() const { return mask; }
    void set_mask(Variant p_mask) { mask = p_mask; }

    Ref<godot::FastNoiseLite> get_mountain_noise() const { return mountain_noise_gd; }

    Vector3 sample_offshore_island(double wx, double wz, Ref<RefCounted> bounds);
    Dictionary sample_macro(double wx, double wz, Ref<RefCounted> bounds);
    Vector2 sample_macro_v2(double wx, double wz, Ref<RefCounted> bounds);
    Vector2 sample_macro_interpolated(double wx, double wz, Ref<RefCounted> bounds, int32_t stride = 4);
};

} // namespace godot

#endif // MACRO_TOPOGRAPHY_NATIVE_H
