#ifndef FLUVIAL_CARVER_NATIVE_H
#define FLUVIAL_CARVER_NATIVE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include "FastNoiseLite.h"

namespace godot {

class FluvialCarverNative : public RefCounted {
    GDCLASS(FluvialCarverNative, RefCounted);

public:
    Ref<RefCounted> config;

    // Direct C++ FastNoiseLite instances
    auburn::FastNoiseLite wide_noise;
    auburn::FastNoiseLite wide_warp;
    auburn::FastNoiseLite small_noise;
    auburn::FastNoiseLite small_warp;
    auburn::FastNoiseLite lake_noise;
    auburn::FastNoiseLite pond_noise;

    // Synced configuration fields
    int32_t sea_level = 24;
    double wide_river_frequency = 0.00075;
    double wide_river_warp_amplitude = 120.0;
    double wide_river_width_threshold = 0.020;
    double wide_river_depth = 12.0;
    double wide_river_water_recede = 3.0;
    double small_river_frequency = 0.0028;
    double small_river_warp_amplitude = 40.0;
    double small_river_width_threshold = 0.022;
    double small_river_depth = 5.5;
    double small_river_water_recede = 2.0;
    double lake_frequency = 0.00075;
    double lake_threshold = 0.9;
    double lake_depth = 10.0;
    double lake_water_recede = 2.5;
    double pond_frequency = 0.0024;
    double pond_threshold = 0.72;
    double pond_depth = 6.0;
    double pond_water_recede = 2.0;

    int32_t current_seed = 1337;

protected:
    static void _bind_methods();

public:
    FluvialCarverNative();
    ~FluvialCarverNative() override = default;

    void initialize(int32_t seed_val = 1337, Ref<RefCounted> p_config = nullptr);
    void _init_noises(int32_t seed_val);
    void sync_config();

    Ref<RefCounted> get_config() const { return config; }
    void set_config(Ref<RefCounted> p_config);

    Dictionary sample_fluvial(double wx, double wz, double base_elevation, double continentalness);
    Vector3 sample_fluvial_v3(double wx, double wz, double base_elevation, double continentalness);
};

} // namespace godot

#endif // FLUVIAL_CARVER_NATIVE_H
