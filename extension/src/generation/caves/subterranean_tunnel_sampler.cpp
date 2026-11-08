#include "generation/caves/subterranean_tunnel_sampler.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#include <algorithm>

using namespace godot;

SubterraneanTunnelSamplerNative::SubterraneanTunnelSamplerNative() {
}

void SubterraneanTunnelSamplerNative::initialize(int32_t p_seed_val, Ref<RefCounted> p_config, Ref<RefCounted> p_chasm_sampler) {
    current_seed = p_seed_val;
    config = p_config;
    set_chasm_sampler(p_chasm_sampler);
    sync_config();
    _init_noises(p_seed_val);
}

void SubterraneanTunnelSamplerNative::set_config(Ref<RefCounted> p_config) {
    config = p_config;
    sync_config();
}

void SubterraneanTunnelSamplerNative::set_chasm_sampler(Ref<RefCounted> p_chasm_sampler) {
    chasm_sampler = p_chasm_sampler;
    if (chasm_sampler.is_valid()) {
        native_chasm = Object::cast_to<UndergroundChasmSamplerNative>(chasm_sampler.ptr());
    } else {
        native_chasm = nullptr;
    }
}

void SubterraneanTunnelSamplerNative::set_worm_registry(Ref<RefCounted> p_registry) {
    worm_registry = p_registry;
}

void SubterraneanTunnelSamplerNative::sync_config() {
    if (config.is_null()) {
        return;
    }
    Variant v;
    v = config->get("tunnel_frequency");
    if (v.get_type() != Variant::NIL) tunnel_frequency = v;

    v = config->get("tunnel_radius_base");
    if (v.get_type() != Variant::NIL) tunnel_radius_base = v;

    v = config->get("tunnel_radius_variation");
    if (v.get_type() != Variant::NIL) tunnel_radius_variation = v;

    v = config->get("tunnel_vertical_squish");
    if (v.get_type() != Variant::NIL) tunnel_vertical_squish = v;

    v = config->get("min_clearance");
    if (v.get_type() != Variant::NIL) min_clearance = v;

    v = config->get("use_trilinear_tunnel_grid");
    if (v.get_type() != Variant::NIL) use_trilinear_tunnel_grid = v;

    v = config->get("use_directed_worm_corridors");
    if (v.get_type() != Variant::NIL) use_directed_worm_corridors = v;

    v = config->get("continuity_frequency");
    if (v.get_type() != Variant::NIL) continuity_frequency = v;

    v = config->get("dead_end_threshold");
    if (v.get_type() != Variant::NIL) dead_end_threshold = v;

    v = config->get("pinch_rate");
    if (v.get_type() != Variant::NIL) pinch_rate = v;

    v = config->get("arena_enabled");
    if (v.get_type() != Variant::NIL) arena_enabled = v;

    v = config->get("arena_rift_threshold");
    if (v.get_type() != Variant::NIL) arena_rift_threshold = v;

    v = config->get("limit_cave_mouths");
    if (v.get_type() != Variant::NIL) limit_cave_mouths = v;

    v = config->get("max_tunnel_mouths");
    if (v.get_type() != Variant::NIL) max_tunnel_mouths = v;
}

void SubterraneanTunnelSamplerNative::_init_noises(int32_t seed_val) {
    tunnel_noise_a.SetSeed(seed_val + 909);
    tunnel_noise_a.SetNoiseType(auburn::FastNoiseLite::NoiseType_OpenSimplex2S);
    tunnel_noise_a.SetFrequency((float)tunnel_frequency);
    tunnel_noise_a.SetFractalType(auburn::FastNoiseLite::FractalType_FBm);
    tunnel_noise_a.SetFractalOctaves(5);
    tunnel_noise_a.SetFractalLacunarity(2.0f);
    tunnel_noise_a.SetFractalGain(0.5f);

    tunnel_noise_b.SetSeed(seed_val + 910);
    tunnel_noise_b.SetNoiseType(auburn::FastNoiseLite::NoiseType_OpenSimplex2S);
    tunnel_noise_b.SetFrequency((float)tunnel_frequency);
    tunnel_noise_b.SetFractalType(auburn::FastNoiseLite::FractalType_FBm);
    tunnel_noise_b.SetFractalOctaves(5);
    tunnel_noise_b.SetFractalLacunarity(2.0f);
    tunnel_noise_b.SetFractalGain(0.5f);

    continuity_noise.SetSeed(seed_val + 911);
    continuity_noise.SetNoiseType(auburn::FastNoiseLite::NoiseType_OpenSimplex2S);
    continuity_noise.SetFrequency((float)continuity_frequency);
    continuity_noise.SetFractalType(auburn::FastNoiseLite::FractalType_FBm);
    continuity_noise.SetFractalOctaves(5);
    continuity_noise.SetFractalLacunarity(2.0f);
    continuity_noise.SetFractalGain(0.5f);

    perturb_noise.SetSeed(seed_val + 912);
    perturb_noise.SetNoiseType(auburn::FastNoiseLite::NoiseType_OpenSimplex2S);
    perturb_noise.SetFrequency((float)(tunnel_frequency * 2.5));
    perturb_noise.SetFractalType(auburn::FastNoiseLite::FractalType_FBm);
    perturb_noise.SetFractalOctaves(5);
    perturb_noise.SetFractalLacunarity(2.0f);
    perturb_noise.SetFractalGain(0.5f);
}

double SubterraneanTunnelSamplerNative::get_arena_suppression(double wx, double wz) {
    if (chasm_sampler.is_null() || !arena_enabled) {
        return 1.0;
    }

    double fade_start = arena_rift_threshold - 0.04;
    double warp_margin = 0.0;
    double unwarped_rift = 0.0;

    if (native_chasm) {
        warp_margin = native_chasm->get_wall_warp_margin();
        unwarped_rift = native_chasm->sample_unwarped_rift(wx, wz);
    } else {
        warp_margin = chasm_sampler->call("get_wall_warp_margin");
        unwarped_rift = chasm_sampler->call("sample_unwarped_rift", wx, wz);
    }

    if (unwarped_rift < (fade_start - warp_margin)) {
        return 1.0;
    }

    Vector2 warped_pos;
    double raw_rift = 0.0;
    if (native_chasm) {
        warped_pos = native_chasm->get_warped_coordinates(wx, wz);
        raw_rift = native_chasm->sample_rift_mask(warped_pos.x, warped_pos.y);
    } else {
        warped_pos = chasm_sampler->call("get_warped_coordinates", wx, wz);
        raw_rift = chasm_sampler->call("sample_rift_mask", warped_pos.x, warped_pos.y);
    }

    if (raw_rift <= fade_start) {
        return 1.0;
    }
    if (raw_rift >= arena_rift_threshold) {
        return 0.0;
    }

    double blend = (raw_rift - fade_start) / 0.04;
    return 1.0 - (blend * blend * (3.0 - 2.0 * blend));
}

bool SubterraneanTunnelSamplerNative::_are_tunnels_disabled() {
    return config.is_valid() && limit_cave_mouths && max_tunnel_mouths == 0;
}

Dictionary SubterraneanTunnelSamplerNative::sample_tunnel(double wx, double wy, double wz) {
    sync_config();
    Dictionary dict;
    double arena_supp = get_arena_suppression(wx, wz);

    if (_are_tunnels_disabled()) {
        dict["is_tunnel"] = false;
        dict["density"] = 0.0;
        dict["effective_radius"] = 0.0;
        dict["is_dead_end"] = false;
        dict["centerline_dist"] = INFINITY;
        return dict;
    }

    if ((config.is_null() || use_directed_worm_corridors) && worm_registry.is_valid()) {
        int64_t reg_count = worm_registry->call("get_registered_chunk_count");
        if (reg_count > 0) {
            Vector3 p((float)wx, (float)wy, (float)wz);
            Variant c = worm_registry->call("world_to_chunk", p);
            Array segs = worm_registry->call("get_segments_for_chunk", c);
            if (segs.is_empty()) {
                dict["is_tunnel"] = false;
                dict["density"] = 0.0;
                dict["effective_radius"] = 0.0;
                dict["is_dead_end"] = false;
                dict["centerline_dist"] = INFINITY;
                return dict;
            }

            double min_dist = 1e30;
            double eff_radius = tunnel_radius_base;
            for (int i = 0; i < segs.size(); ++i) {
                Ref<RefCounted> seg = segs[i];
                if (seg.is_valid()) {
                    double d = seg->call("distance_to_point", p);
                    if (d < min_dist) {
                        min_dist = d;
                        eff_radius = seg->call("get_interpolated_radius", p);
                    }
                }
            }

            if (arena_supp < 1.0) {
                eff_radius *= arena_supp;
            }

            if (eff_radius <= 0.0) {
                dict["is_tunnel"] = false;
                dict["density"] = 0.0;
                dict["effective_radius"] = 0.0;
                dict["is_dead_end"] = true;
                dict["centerline_dist"] = min_dist;
                return dict;
            }

            float perturb = perturb_noise.GetNoise((float)wx, (float)wy, (float)wz) * (float)tunnel_radius_variation;
            double final_radius = eff_radius + perturb;
            bool is_inside = min_dist < final_radius;
            double carve_density = 0.0;
            if (is_inside) {
                double factor = 1.0 - (min_dist / final_radius);
                carve_density = factor * factor * (3.0 - 2.0 * factor);
            }

            dict["is_tunnel"] = is_inside;
            dict["density"] = carve_density;
            dict["effective_radius"] = eff_radius;
            dict["is_dead_end"] = false;
            dict["centerline_dist"] = min_dist;
            return dict;
        }
    }

    double squished_y = wy * tunnel_vertical_squish;
    float na = tunnel_noise_a.GetNoise((float)wx, (float)squished_y, (float)wz);
    float nb = tunnel_noise_b.GetNoise((float)wx, (float)squished_y, (float)wz);
    double centerline_dist = std::sqrt(na * na + nb * nb);

    float cont = continuity_noise.GetNoise((float)wx, (float)(wy * 0.8), (float)wz);
    float perturb = perturb_noise.GetNoise((float)wx, (float)wy, (float)wz) * (float)tunnel_radius_variation;

    double eff_radius = tunnel_radius_base + perturb;
    bool is_pinched = false;

    bool is_dead_end = cont <= (float)dead_end_threshold;
    if (is_dead_end) {
        double pinch = (dead_end_threshold - cont) * pinch_rate;
        eff_radius -= pinch;
        is_pinched = true;
    }

    arena_supp = get_arena_suppression(wx, wz);
    if (arena_supp < 1.0) {
        eff_radius *= arena_supp;
        is_pinched = true;
        if (arena_supp <= 0.0) {
            is_dead_end = true;
        }
    }

    if (eff_radius <= 0.0) {
        dict["is_tunnel"] = false;
        dict["density"] = 0.0;
        dict["effective_radius"] = 0.0;
        dict["is_dead_end"] = true;
        dict["centerline_dist"] = centerline_dist;
        return dict;
    }

    if (!is_pinched) {
        eff_radius = std::max(min_clearance, eff_radius);
    }

    double tunnel_threshold = eff_radius * 0.05;
    bool is_inside = centerline_dist < tunnel_threshold;

    double carve_density = 0.0;
    if (is_inside) {
        double factor = 1.0 - (centerline_dist / tunnel_threshold);
        carve_density = factor * factor * (3.0 - 2.0 * factor);
    }

    dict["is_tunnel"] = is_inside;
    dict["density"] = carve_density;
    dict["effective_radius"] = eff_radius;
    dict["is_dead_end"] = is_dead_end;
    dict["centerline_dist"] = centerline_dist;
    return dict;
}

bool SubterraneanTunnelSamplerNative::can_tunnel_intersect_chunk(Ref<RefCounted> coord, Vector3 min_p, Vector3 max_p) {
    if (_are_tunnels_disabled()) {
        return false;
    }

    if ((config.is_null() || use_directed_worm_corridors) && worm_registry.is_valid()) {
        int64_t reg_count = worm_registry->call("get_registered_chunk_count");
        if (reg_count > 0) {
            if (coord.is_null()) {
                return false;
            }
            bool has_c = worm_registry->call("has_chunk", coord);
            if (!has_c) {
                return false;
            }
            if (min_p != Vector3() || max_p != Vector3()) {
                double sec_h = worm_registry->get("section_height");
                int32_t s_min = std::max((int32_t)0, (int32_t)std::floor(min_p.y / sec_h));
                int32_t s_max = std::max((int32_t)0, (int32_t)std::floor(max_p.y / sec_h));
                for (int32_t s = s_min; s <= s_max; ++s) {
                    bool active = worm_registry->call("is_section_active", coord, s);
                    if (active) {
                        return true;
                    }
                }
                return false;
            }
            return true;
        }
    }

    if (min_p == Vector3() && max_p == Vector3()) {
        return true;
    }
    return can_tunnel_intersect_cell(min_p, max_p);
}

bool SubterraneanTunnelSamplerNative::can_tunnel_intersect_cell(Vector3 min_p, Vector3 max_p) {
    if (max_p.y <= min_p.y || max_p.x <= min_p.x || max_p.z <= min_p.z) {
        return false;
    }

    if (_are_tunnels_disabled()) {
        return false;
    }

    if ((config.is_null() || use_directed_worm_corridors) && worm_registry.is_valid()) {
        int64_t reg_count = worm_registry->call("get_registered_chunk_count");
        if (reg_count > 0) {
            Ref<RefCounted> c_min = worm_registry->call("world_to_chunk", min_p);
            Ref<RefCounted> c_max = worm_registry->call("world_to_chunk", max_p);
            AABB cell_box(min_p, max_p - min_p);
            int32_t min_cx = c_min->get("x");
            int32_t max_cx = c_max->get("x");
            int32_t min_cz = c_min->get("z");
            int32_t max_cz = c_max->get("z");

            for (int32_t cz = min_cz; cz <= max_cz; ++cz) {
                for (int32_t cx = min_cx; cx <= max_cx; ++cx) {
                    Variant args[2] = { cx, cz };
                    const Variant* arg_ptrs[2] = { &args[0], &args[1] };
                    Callable custom_coord_ctor; // We can use chunkcoord or worm_registry call
                    // In GDScript: var coord = ChunkCoord.new(cx, cz)
                    // If worm_registry has_chunk accepts ChunkCoord, or we check if chunk has segments:
                    Array segs = worm_registry->call("get_segments_for_chunk_coords", cx, cz);
                    if (segs.is_empty()) {
                        // fallback to coord object if method doesn't exist
                        Ref<RefCounted> coord;
                        // Call has_chunk with a dynamically created coord or check dictionary
                        Variant c_obj = worm_registry->call("get_chunk_coord", cx, cz);
                        if (c_obj.get_type() != Variant::NIL && bool(worm_registry->call("has_chunk", c_obj))) {
                            segs = worm_registry->call("get_segments_for_chunk", c_obj);
                        }
                    }
                    for (int i = 0; i < segs.size(); ++i) {
                        Ref<RefCounted> seg = segs[i];
                        if (seg.is_valid()) {
                            bool inter = seg->call("intersects_aabb", cell_box);
                            if (inter) {
                                return true;
                            }
                        }
                    }
                }
            }
            return false;
        }
    }

    double span_x = max_p.x - min_p.x;
    double span_y = max_p.y - min_p.y;
    double span_z = max_p.z - min_p.z;

    bool has_arena_influence = false;
    if (chasm_sampler.is_valid() && arena_enabled) {
        double mid_x_c = (min_p.x + max_p.x) * 0.5;
        double mid_z_c = (min_p.z + max_p.z) * 0.5;
        double unwarped = 0.0;
        double warp_margin = 0.0;
        double chasm_freq = 0.003;
        if (native_chasm) {
            unwarped = native_chasm->sample_unwarped_rift(mid_x_c, mid_z_c);
            warp_margin = native_chasm->get_wall_warp_margin();
            chasm_freq = native_chasm->chasm_rift_frequency;
        } else {
            unwarped = chasm_sampler->call("sample_unwarped_rift", mid_x_c, mid_z_c);
            warp_margin = chasm_sampler->call("get_wall_warp_margin");
            chasm_freq = chasm_sampler->get("config").get_type() != Variant::NIL ? double(chasm_sampler->get("config").call("get", "chasm_rift_frequency")) : 0.003;
        }
        double half_diag = std::sqrt(span_x * span_x + span_z * span_z) * 0.5;
        double margin = (half_diag + warp_margin) * chasm_freq * 2.5 + 0.05;
        if (unwarped >= (arena_rift_threshold - 0.04 - margin)) {
            has_arena_influence = true;
            if (get_arena_suppression(mid_x_c, mid_z_c) <= 0.0) {
                if (get_arena_suppression(min_p.x, min_p.z) <= 0.0 &&
                    get_arena_suppression(max_p.x, min_p.z) <= 0.0 &&
                    get_arena_suppression(min_p.x, max_p.z) <= 0.0 &&
                    get_arena_suppression(max_p.x, max_p.z) <= 0.0) {
                    return false;
                }
            }
        }
    }

    double eff_thresh = tunnel_radius_base * 0.05 * 0.85;

    if (!has_arena_influence) {
        if (span_x <= 4.1 && span_y <= 4.1 && span_z <= 4.1) {
            double max_safe_d = eff_thresh + 0.12;
            double mid_x = (min_p.x + max_p.x) * 0.5;
            double mid_y = (min_p.y + max_p.y) * 0.5;
            double mid_z = (min_p.z + max_p.z) * 0.5;
            double sq_y_m = mid_y * tunnel_vertical_squish;
            float na_m = tunnel_noise_a.GetNoise((float)mid_x, (float)sq_y_m, (float)mid_z);
            float nb_m = tunnel_noise_b.GetNoise((float)mid_x, (float)sq_y_m, (float)mid_z);
            double mid_d = std::sqrt(na_m * na_m + nb_m * nb_m);
            if (mid_d <= eff_thresh) {
                return true;
            }

            double min_d = mid_d;
            double xs[2] = { (double)min_p.x, (double)max_p.x };
            double ys[2] = { (double)min_p.y, (double)max_p.y };
            double zs[2] = { (double)min_p.z, (double)max_p.z };
            for (int ix = 0; ix < 2; ++ix) {
                for (int iy = 0; iy < 2; ++iy) {
                    for (int iz = 0; iz < 2; ++iz) {
                        double sq_y = ys[iy] * tunnel_vertical_squish;
                        float na = tunnel_noise_a.GetNoise((float)xs[ix], (float)sq_y, (float)zs[iz]);
                        float nb = tunnel_noise_b.GetNoise((float)xs[ix], (float)sq_y, (float)zs[iz]);
                        double d = std::sqrt(na * na + nb * nb);
                        if (d <= eff_thresh) {
                            return true;
                        }
                        min_d = std::min(min_d, d);
                    }
                }
            }
            return min_d <= max_safe_d;
        }

        double step_x = std::min(8.0, span_x);
        double step_y = std::min(8.0, span_y);
        double step_z = std::min(8.0, span_z);
        double max_safe_d = eff_thresh + 0.25;

        for (double y = min_p.y; y <= max_p.y; y += step_y) {
            double sq_y = y * tunnel_vertical_squish;
            for (double z = min_p.z; z <= max_p.z; z += step_z) {
                for (double x = min_p.x; x <= max_p.x; x += step_x) {
                    float na = tunnel_noise_a.GetNoise((float)x, (float)sq_y, (float)z);
                    float nb = tunnel_noise_b.GetNoise((float)x, (float)sq_y, (float)z);
                    double d = std::sqrt(na * na + nb * nb);
                    if (d <= max_safe_d) {
                        return true;
                    }
                }
            }
        }
        return false;
    }

    // Path B: Arena influence active
    if (span_x <= 4.1 && span_y <= 4.1 && span_z <= 4.1) {
        double mid_x = (min_p.x + max_p.x) * 0.5;
        double mid_y = (min_p.y + max_p.y) * 0.5;
        double mid_z = (min_p.z + max_p.z) * 0.5;
        double mid_supp = get_arena_suppression(mid_x, mid_z);

        if (mid_supp > 0.0) {
            double sq_y_m = mid_y * tunnel_vertical_squish;
            float na_m = tunnel_noise_a.GetNoise((float)mid_x, (float)sq_y_m, (float)mid_z);
            float nb_m = tunnel_noise_b.GetNoise((float)mid_x, (float)sq_y_m, (float)mid_z);
            double mid_d = std::sqrt(na_m * na_m + nb_m * nb_m);
            if (mid_d <= (eff_thresh * mid_supp)) {
                return true;
            }
        }

        double max_supp = mid_supp;
        double min_d_scaled = 999.0;
        double xs[2] = { (double)min_p.x, (double)max_p.x };
        double ys[2] = { (double)min_p.y, (double)max_p.y };
        double zs[2] = { (double)min_p.z, (double)max_p.z };
        for (int ix = 0; ix < 2; ++ix) {
            for (int iy = 0; iy < 2; ++iy) {
                for (int iz = 0; iz < 2; ++iz) {
                    double supp = get_arena_suppression(xs[ix], zs[iz]);
                    max_supp = std::max(max_supp, supp);
                    if (supp <= 0.0) {
                        continue;
                    }
                    double sq_y = ys[iy] * tunnel_vertical_squish;
                    float na = tunnel_noise_a.GetNoise((float)xs[ix], (float)sq_y, (float)zs[iz]);
                    float nb = tunnel_noise_b.GetNoise((float)xs[ix], (float)sq_y, (float)zs[iz]);
                    double d = std::sqrt(na * na + nb * nb);
                    if (d <= (eff_thresh * supp)) {
                        return true;
                    }
                    min_d_scaled = std::min(min_d_scaled, d / std::max(0.01, supp));
                }
            }
        }
        if (max_supp <= 0.0) {
            return false;
        }
        return min_d_scaled <= (eff_thresh + 0.12);
    }

    double step_x = std::min(8.0, span_x);
    double step_y = std::min(8.0, span_y);
    double step_z = std::min(8.0, span_z);

    for (double y = min_p.y; y <= max_p.y; y += step_y) {
        double sq_y = y * tunnel_vertical_squish;
        for (double z = min_p.z; z <= max_p.z; z += step_z) {
            for (double x = min_p.x; x <= max_p.x; x += step_x) {
                double supp = get_arena_suppression(x, z);
                if (supp > 0.0) {
                    double pt_eff_thresh = tunnel_radius_base * supp * 0.05 * 0.85;
                    double pt_max_safe_d = pt_eff_thresh + (0.25 * supp);
                    float na = tunnel_noise_a.GetNoise((float)x, (float)sq_y, (float)z);
                    float nb = tunnel_noise_b.GetNoise((float)x, (float)sq_y, (float)z);
                    double d = std::sqrt(na * na + nb * nb);
                    if (d <= pt_max_safe_d) {
                        return true;
                    }
                }
            }
        }
    }

    return false;
}

double SubterraneanTunnelSamplerNative::get_tunnel_carve(double wx, double wy, double wz) {
    double arena_supp = get_arena_suppression(wx, wz);
    if (arena_supp <= 0.0) {
        return 0.0;
    }

    if (_are_tunnels_disabled()) {
        return 0.0;
    }

    if ((config.is_null() || use_directed_worm_corridors) && worm_registry.is_valid()) {
        int64_t reg_count = worm_registry->call("get_registered_chunk_count");
        if (reg_count > 0) {
            Vector3 p((float)wx, (float)wy, (float)wz);
            Variant c = worm_registry->call("world_to_chunk", p);
            Array segs = worm_registry->call("get_segments_for_chunk", c);
            if (segs.is_empty()) {
                return 0.0;
            }

            double min_dist = 1e30;
            double eff_radius = tunnel_radius_base;
            for (int i = 0; i < segs.size(); ++i) {
                Ref<RefCounted> seg = segs[i];
                if (seg.is_valid()) {
                    double d = seg->call("distance_to_point", p);
                    if (d < min_dist) {
                        min_dist = d;
                        eff_radius = seg->call("get_interpolated_radius", p);
                    }
                }
            }

            if (arena_supp < 1.0) {
                eff_radius *= arena_supp;
            }

            if (eff_radius <= 0.0) {
                return 0.0;
            }

            float perturb = perturb_noise.GetNoise((float)wx, (float)wy, (float)wz) * (float)tunnel_radius_variation;
            double final_radius = eff_radius + perturb;

            if (min_dist < final_radius) {
                double factor = 1.0 - (min_dist / final_radius);
                return factor * factor * (3.0 - 2.0 * factor);
            }
            return 0.0;
        }
    }

    double squished_y = wy * tunnel_vertical_squish;
    float na = tunnel_noise_a.GetNoise((float)wx, (float)squished_y, (float)wz);
    float nb = tunnel_noise_b.GetNoise((float)wx, (float)squished_y, (float)wz);
    double centerline_dist = std::sqrt(na * na + nb * nb);

    double eff_radius = tunnel_radius_base;
    bool is_pinched = false;

    if (arena_supp < 1.0) {
        eff_radius *= arena_supp;
        is_pinched = true;
    }

    float cont = continuity_noise.GetNoise((float)wx, (float)(wy * 0.8), (float)wz);
    if (cont <= (float)dead_end_threshold) {
        eff_radius -= (dead_end_threshold - cont) * pinch_rate;
        is_pinched = true;
    }

    if (eff_radius <= 0.0) {
        return 0.0;
    }

    if (!is_pinched) {
        eff_radius = std::max(min_clearance, eff_radius);
    }

    double tunnel_threshold = eff_radius * 0.05;
    if (centerline_dist < tunnel_threshold) {
        double factor = 1.0 - (centerline_dist / tunnel_threshold);
        return factor * factor * (3.0 - 2.0 * factor);
    }

    return 0.0;
}

bool SubterraneanTunnelSamplerNative::is_dead_end_zone(double wx, double wy, double wz) {
    return continuity_noise.GetNoise((float)wx, (float)(wy * 0.8), (float)wz) <= (float)dead_end_threshold;
}

PackedFloat32Array SubterraneanTunnelSamplerNative::sample_trilinear_cell_corners(Vector3 min_p, Vector3 max_p) {
    PackedFloat32Array corners;
    corners.resize(8);
    corners[0] = (float)get_tunnel_carve(min_p.x, min_p.y, min_p.z);
    corners[1] = (float)get_tunnel_carve(max_p.x, min_p.y, min_p.z);
    corners[2] = (float)get_tunnel_carve(min_p.x, max_p.y, min_p.z);
    corners[3] = (float)get_tunnel_carve(max_p.x, max_p.y, min_p.z);
    corners[4] = (float)get_tunnel_carve(min_p.x, min_p.y, max_p.z);
    corners[5] = (float)get_tunnel_carve(max_p.x, min_p.y, max_p.z);
    corners[6] = (float)get_tunnel_carve(min_p.x, max_p.y, max_p.z);
    corners[7] = (float)get_tunnel_carve(max_p.x, max_p.y, max_p.z);
    return corners;
}

double SubterraneanTunnelSamplerNative::evaluate_trilinear(PackedFloat32Array corners, double u, double v, double w) {
    if (corners.size() < 8) {
        return 0.0;
    }
    double c00 = corners[0] * (1.0 - u) + corners[1] * u;
    double c01 = corners[4] * (1.0 - u) + corners[5] * u;
    double c10 = corners[2] * (1.0 - u) + corners[3] * u;
    double c11 = corners[6] * (1.0 - u) + corners[7] * u;

    double c0 = c00 * (1.0 - v) + c10 * v;
    double c1 = c01 * (1.0 - v) + c11 * v;

    return c0 * (1.0 - w) + c1 * w;
}

void SubterraneanTunnelSamplerNative::_bind_methods() {
    ClassDB::bind_method(D_METHOD("initialize", "seed_val", "config", "chasm_sampler"), &SubterraneanTunnelSamplerNative::initialize, DEFVAL(1337), DEFVAL(Variant()), DEFVAL(Variant()));
    ClassDB::bind_method(D_METHOD("_init_noises", "seed_val"), &SubterraneanTunnelSamplerNative::_init_noises);
    ClassDB::bind_method(D_METHOD("sync_config"), &SubterraneanTunnelSamplerNative::sync_config);

    ClassDB::bind_method(D_METHOD("get_config"), &SubterraneanTunnelSamplerNative::get_config);
    ClassDB::bind_method(D_METHOD("set_config", "config"), &SubterraneanTunnelSamplerNative::set_config);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "config", PROPERTY_HINT_RESOURCE_TYPE, "CaveGeneratorConfig"), "set_config", "get_config");

    ClassDB::bind_method(D_METHOD("get_chasm_sampler"), &SubterraneanTunnelSamplerNative::get_chasm_sampler);
    ClassDB::bind_method(D_METHOD("set_chasm_sampler", "chasm_sampler"), &SubterraneanTunnelSamplerNative::set_chasm_sampler);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "chasm_sampler"), "set_chasm_sampler", "get_chasm_sampler");

    ClassDB::bind_method(D_METHOD("get_worm_registry"), &SubterraneanTunnelSamplerNative::get_worm_registry);
    ClassDB::bind_method(D_METHOD("set_worm_registry", "registry"), &SubterraneanTunnelSamplerNative::set_worm_registry);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "worm_registry"), "set_worm_registry", "get_worm_registry");

    ClassDB::bind_method(D_METHOD("get_corridors_configured"), &SubterraneanTunnelSamplerNative::get_corridors_configured);
    ClassDB::bind_method(D_METHOD("set_corridors_configured", "v"), &SubterraneanTunnelSamplerNative::set_corridors_configured);
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "corridors_configured"), "set_corridors_configured", "get_corridors_configured");

    ClassDB::bind_method(D_METHOD("get_arena_suppression", "wx", "wz"), &SubterraneanTunnelSamplerNative::get_arena_suppression);
    ClassDB::bind_method(D_METHOD("_are_tunnels_disabled"), &SubterraneanTunnelSamplerNative::_are_tunnels_disabled);

    ClassDB::bind_method(D_METHOD("sample_tunnel", "wx", "wy", "wz"), &SubterraneanTunnelSamplerNative::sample_tunnel);
    ClassDB::bind_method(D_METHOD("can_tunnel_intersect_chunk", "coord", "min_p", "max_p"), &SubterraneanTunnelSamplerNative::can_tunnel_intersect_chunk, DEFVAL(Vector3()), DEFVAL(Vector3()));
    ClassDB::bind_method(D_METHOD("can_tunnel_intersect_cell", "min_p", "max_p"), &SubterraneanTunnelSamplerNative::can_tunnel_intersect_cell);
    ClassDB::bind_method(D_METHOD("get_tunnel_carve", "wx", "wy", "wz"), &SubterraneanTunnelSamplerNative::get_tunnel_carve);
    ClassDB::bind_method(D_METHOD("is_dead_end_zone", "wx", "wy", "wz"), &SubterraneanTunnelSamplerNative::is_dead_end_zone);

    ClassDB::bind_method(D_METHOD("sample_trilinear_cell_corners", "min_p", "max_p"), &SubterraneanTunnelSamplerNative::sample_trilinear_cell_corners);
    ClassDB::bind_method(D_METHOD("evaluate_trilinear", "corners", "u", "v", "w"), &SubterraneanTunnelSamplerNative::evaluate_trilinear);
}
