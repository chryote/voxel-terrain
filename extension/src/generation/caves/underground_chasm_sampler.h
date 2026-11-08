#ifndef UNDERGROUND_CHASM_SAMPLER_NATIVE_H
#define UNDERGROUND_CHASM_SAMPLER_NATIVE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include "FastNoiseLite.h"

namespace godot {

class UndergroundChasmSamplerNative : public RefCounted {
    GDCLASS(UndergroundChasmSamplerNative, RefCounted);

public:
    static constexpr double WALL_MARGIN = 0.03;
    static constexpr double DEEP_INLAND_LAND_THRESHOLD = 0.20;

    Ref<RefCounted> config;
    Variant continent_mask;
    Ref<RefCounted> world_bounds;

    bool is_deep_inland = false;
    double _inland_min_x = 0.0;
    double _inland_max_x = -1.0;
    double _inland_min_z = 0.0;
    double _inland_max_z = -1.0;

    // Direct C++ FastNoiseLite instances
    auburn::FastNoiseLite rift_noise;
    auburn::FastNoiseLite wall_warp_noise;
    auburn::FastNoiseLite floor_noise;
    auburn::FastNoiseLite ceil_noise;
    auburn::FastNoiseLite pillar_noise;

    // Synced configuration fields
    double chasm_rift_threshold = 0.45;
    double chasm_wall_warp_amplitude = 4.0;
    double chasm_rift_frequency = 0.003;
    double chasm_wall_warp_frequency = 0.015;
    int32_t chasm_min_y = 4;
    int32_t chasm_max_y = 24;
    double chasm_floor_variation = 3.0;
    double chasm_ceil_variation = 4.0;
    double min_chasm_height = 5.0;
    int32_t chasm_water_level = 4;
    bool cave_water_enabled = true;
    double pillar_frequency = 0.008;
    double pillar_threshold = 0.60;
    bool arena_enabled = true;
    double arena_rift_threshold = 0.74;
    int32_t arena_floor_y = 6;
    int32_t arena_ceiling_y = 28;
    int32_t arena_ledge_step_height = 2;
    double crust_depth = 3.0;

    int32_t current_seed = 1337;

protected:
    static void _bind_methods();

public:
    UndergroundChasmSamplerNative();
    ~UndergroundChasmSamplerNative() override = default;

    void initialize(int32_t p_seed_val = 1337, Ref<RefCounted> p_config = nullptr);
    void _init_noises(int32_t p_seed_val);
    void sync_config();

    Ref<RefCounted> get_config() const { return config; }
    void set_config(Ref<RefCounted> p_config);

    bool get_is_deep_inland() const { return is_deep_inland; }
    void set_is_deep_inland(bool v) { is_deep_inland = v; }

    double sample_unwarped_rift(double wx, double wz);
    double get_wall_warp_margin();
    bool can_column_contain_chasm(double wx, double wz);
    Vector2 get_warped_coordinates(double wx, double wz);

    void set_continent_mask(Variant p_mask, Ref<RefCounted> p_bounds);
    void reset_inland_cache();
    double _get_effective_inland_raw(double wx, double wz);
    bool update_deep_inland_status(double min_x, double min_z, double max_x, double max_z);

    double sample_rift_mask(double sample_x, double sample_z);
    bool is_support_pillar(double sample_x, double sample_z, double raw_rift = -1.0);
    Vector2i calculate_floor_and_ceiling(double sample_x, double sample_z, double raw_rift = 0.0);

    bool is_arena(double wx, double wz);
    bool can_arena_intersect_box(double min_x, double min_z, double max_x, double max_z);
    bool can_arena_intersect_chunk(Ref<RefCounted> coord, Ref<RefCounted> bounds);

    Ref<RefCounted> sample_column(double wx, double wz, Ref<RefCounted> out = nullptr, double surface_h = -1.0);
    bool can_chasm_intersect_cell(Vector3 min_p, Vector3 max_p);
    double get_chasm_carve(double wx, double wy, double wz);
    bool is_subterranean_water(double wx, double wy, double wz);
    Dictionary sample_chasm(double wx, double wy, double wz);
    double get_depth_envelope(double wy);
};

} // namespace godot

#endif // UNDERGROUND_CHASM_SAMPLER_NATIVE_H
