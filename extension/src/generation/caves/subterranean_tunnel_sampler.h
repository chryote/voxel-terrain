#ifndef SUBTERRANEAN_TUNNEL_SAMPLER_NATIVE_H
#define SUBTERRANEAN_TUNNEL_SAMPLER_NATIVE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include "FastNoiseLite.h"
#include "generation/caves/underground_chasm_sampler.h"

namespace godot {

class SubterraneanTunnelSamplerNative : public RefCounted {
    GDCLASS(SubterraneanTunnelSamplerNative, RefCounted);

public:
    Ref<RefCounted> config;
    Ref<RefCounted> chasm_sampler;
    UndergroundChasmSamplerNative* native_chasm = nullptr;
    Ref<RefCounted> worm_registry;
    bool corridors_configured = false;

    // Direct C++ FastNoiseLite instances
    auburn::FastNoiseLite tunnel_noise_a;
    auburn::FastNoiseLite tunnel_noise_b;
    auburn::FastNoiseLite continuity_noise;
    auburn::FastNoiseLite perturb_noise;

    // Synced configuration fields
    double tunnel_frequency = 0.016;
    double tunnel_radius_base = 3.8;
    double tunnel_radius_variation = 0.8;
    double tunnel_vertical_squish = 1.15;
    double min_clearance = 2.2;
    bool use_trilinear_tunnel_grid = false;
    bool use_directed_worm_corridors = true;
    double continuity_frequency = 0.006;
    double dead_end_threshold = -0.08;
    double pinch_rate = 4.0;
    bool arena_enabled = true;
    double arena_rift_threshold = 0.74;
    bool limit_cave_mouths = true;
    int32_t max_tunnel_mouths = 1;

    int32_t current_seed = 1337;

protected:
    static void _bind_methods();

public:
    SubterraneanTunnelSamplerNative();
    ~SubterraneanTunnelSamplerNative() override = default;

    void initialize(int32_t p_seed_val = 1337, Ref<RefCounted> p_config = nullptr, Ref<RefCounted> p_chasm_sampler = nullptr);
    void _init_noises(int32_t p_seed_val);
    void sync_config();

    Ref<RefCounted> get_config() const { return config; }
    void set_config(Ref<RefCounted> p_config);

    Ref<RefCounted> get_chasm_sampler() const { return chasm_sampler; }
    void set_chasm_sampler(Ref<RefCounted> p_chasm_sampler);

    Ref<RefCounted> get_worm_registry() const { return worm_registry; }
    void set_worm_registry(Ref<RefCounted> p_registry);

    bool get_corridors_configured() const { return corridors_configured; }
    void set_corridors_configured(bool v) { corridors_configured = v; }

    double get_arena_suppression(double wx, double wz);
    bool _are_tunnels_disabled();

    Dictionary sample_tunnel(double wx, double wy, double wz);
    bool can_tunnel_intersect_chunk(Ref<RefCounted> coord, Vector3 min_p = Vector3(), Vector3 max_p = Vector3());
    bool can_tunnel_intersect_cell(Vector3 min_p, Vector3 max_p);
    double get_tunnel_carve(double wx, double wy, double wz);
    bool is_dead_end_zone(double wx, double wy, double wz);

    PackedFloat32Array sample_trilinear_cell_corners(Vector3 min_p, Vector3 max_p);
    double evaluate_trilinear(PackedFloat32Array corners, double u, double v, double w);
};

} // namespace godot

#endif // SUBTERRANEAN_TUNNEL_SAMPLER_NATIVE_H
