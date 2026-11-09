#include "generation/caves/underground_chasm_sampler.h"
#include "generation/caves/chasm_column_result.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#include <algorithm>

using namespace godot;

UndergroundChasmSamplerNative::UndergroundChasmSamplerNative() {
}

void UndergroundChasmSamplerNative::initialize(int32_t p_seed_val, Ref<RefCounted> p_config) {
    current_seed = p_seed_val;
    config = p_config;
    sync_config();
    _init_noises(p_seed_val);
}

void UndergroundChasmSamplerNative::set_config(Ref<RefCounted> p_config) {
    config = p_config;
    sync_config();
}

void UndergroundChasmSamplerNative::sync_config() {
    if (config.is_null()) {
        return;
    }
    Variant v;
    v = config->get("chasm_rift_threshold");
    if (v.get_type() != Variant::NIL) chasm_rift_threshold = v;

    v = config->get("chasm_wall_warp_amplitude");
    if (v.get_type() != Variant::NIL) chasm_wall_warp_amplitude = v;

    v = config->get("chasm_rift_frequency");
    if (v.get_type() != Variant::NIL) chasm_rift_frequency = v;

    v = config->get("chasm_wall_warp_frequency");
    if (v.get_type() != Variant::NIL) chasm_wall_warp_frequency = v;

    v = config->get("chasm_min_y");
    if (v.get_type() != Variant::NIL) chasm_min_y = v;

    v = config->get("chasm_max_y");
    if (v.get_type() != Variant::NIL) chasm_max_y = v;

    v = config->get("chasm_floor_variation");
    if (v.get_type() != Variant::NIL) chasm_floor_variation = v;

    v = config->get("chasm_ceil_variation");
    if (v.get_type() != Variant::NIL) chasm_ceil_variation = v;

    v = config->get("min_chasm_height");
    if (v.get_type() != Variant::NIL) min_chasm_height = v;

    v = config->get("chasm_water_level");
    if (v.get_type() != Variant::NIL) chasm_water_level = v;

    v = config->get("cave_water_enabled");
    if (v.get_type() != Variant::NIL) cave_water_enabled = v;

    v = config->get("pillar_frequency");
    if (v.get_type() != Variant::NIL) pillar_frequency = v;

    v = config->get("pillar_threshold");
    if (v.get_type() != Variant::NIL) pillar_threshold = v;

    v = config->get("arena_enabled");
    if (v.get_type() != Variant::NIL) arena_enabled = v;

    v = config->get("arena_rift_threshold");
    if (v.get_type() != Variant::NIL) arena_rift_threshold = v;

    v = config->get("arena_floor_y");
    if (v.get_type() != Variant::NIL) arena_floor_y = v;

    v = config->get("arena_ceiling_y");
    if (v.get_type() != Variant::NIL) arena_ceiling_y = v;

    v = config->get("arena_ledge_step_height");
    if (v.get_type() != Variant::NIL) arena_ledge_step_height = v;

    v = config->get("crust_depth");
    if (v.get_type() != Variant::NIL) crust_depth = v;
}

void UndergroundChasmSamplerNative::_init_noises(int32_t seed_val) {
    // 1. 2D Rift Corridor Noise (Cellular Voronoi Edge Network)
    rift_noise.SetSeed(seed_val + 1010);
    rift_noise.SetNoiseType(auburn::FastNoiseLite::NoiseType_Cellular);
    rift_noise.SetFrequency((float)chasm_rift_frequency);
    rift_noise.SetCellularDistanceFunction(auburn::FastNoiseLite::CellularDistanceFunction_Euclidean);
    rift_noise.SetCellularReturnType(auburn::FastNoiseLite::CellularReturnType_Distance2Sub);
    rift_noise.SetFractalType(auburn::FastNoiseLite::FractalType_FBm);
    rift_noise.SetFractalOctaves(5);
    rift_noise.SetFractalLacunarity(2.0f);
    rift_noise.SetFractalGain(0.5f);

    // 2. 2D Wall Domain Warp Noise (2-octave Fractal FBM)
    wall_warp_noise.SetSeed(seed_val + 1012);
    wall_warp_noise.SetNoiseType(auburn::FastNoiseLite::NoiseType_OpenSimplex2S);
    wall_warp_noise.SetFrequency((float)chasm_wall_warp_frequency);
    wall_warp_noise.SetFractalType(auburn::FastNoiseLite::FractalType_FBm);
    wall_warp_noise.SetFractalOctaves(2);
    wall_warp_noise.SetFractalLacunarity(2.0f);
    wall_warp_noise.SetFractalGain(0.5f);

    // 3. 2D Floor Heightfield Noise
    floor_noise.SetSeed(seed_val + 1013);
    floor_noise.SetNoiseType(auburn::FastNoiseLite::NoiseType_OpenSimplex2S);
    floor_noise.SetFrequency(0.01f);
    floor_noise.SetFractalType(auburn::FastNoiseLite::FractalType_FBm);
    floor_noise.SetFractalOctaves(5);
    floor_noise.SetFractalLacunarity(2.0f);
    floor_noise.SetFractalGain(0.5f);

    // 4. 2D Ceiling Heightfield Noise
    ceil_noise.SetSeed(seed_val + 1014);
    ceil_noise.SetNoiseType(auburn::FastNoiseLite::NoiseType_OpenSimplex2S);
    ceil_noise.SetFrequency(0.012f);
    ceil_noise.SetFractalType(auburn::FastNoiseLite::FractalType_FBm);
    ceil_noise.SetFractalOctaves(5);
    ceil_noise.SetFractalLacunarity(2.0f);
    ceil_noise.SetFractalGain(0.5f);

    // 5. 2D Natural Support Column Noise
    pillar_noise.SetSeed(seed_val + 1011);
    pillar_noise.SetNoiseType(auburn::FastNoiseLite::NoiseType_OpenSimplex2S);
    pillar_noise.SetFrequency((float)pillar_frequency);
    pillar_noise.SetFractalType(auburn::FastNoiseLite::FractalType_FBm);
    pillar_noise.SetFractalOctaves(5);
    pillar_noise.SetFractalLacunarity(2.0f);
    pillar_noise.SetFractalGain(0.5f);
}

double UndergroundChasmSamplerNative::sample_unwarped_rift(double wx, double wz) {
    float raw = rift_noise.GetNoise((float)wx, (float)wz);
    float dist_val = raw + 1.0f;
    float c = dist_val / 0.42f;
    if (c < 0.0f) c = 0.0f; else if (c > 1.0f) c = 1.0f;
    return 1.0f - c;
}

double UndergroundChasmSamplerNative::get_wall_warp_margin() {
    sync_config();
    double max_reach = chasm_wall_warp_amplitude * 1.4142;
    return max_reach * chasm_rift_frequency * 2.0;
}

bool UndergroundChasmSamplerNative::can_column_contain_chasm(double wx, double wz) {
    double unwarped_rift = sample_unwarped_rift(wx, wz);
    return unwarped_rift >= (chasm_rift_threshold - get_wall_warp_margin());
}

Vector2 UndergroundChasmSamplerNative::get_warped_coordinates(double wx, double wz) {
    sync_config();
    float warp_x = wall_warp_noise.GetNoise((float)wx, (float)wz) * (float)chasm_wall_warp_amplitude;
    float warp_z = wall_warp_noise.GetNoise((float)(wx + 43.1), (float)(wz + 17.4)) * (float)chasm_wall_warp_amplitude;
    return Vector2((float)wx + warp_x, (float)wz + warp_z);
}

void UndergroundChasmSamplerNative::set_continent_mask(Variant p_mask, Ref<RefCounted> p_bounds) {
    continent_mask = p_mask;
    world_bounds = p_bounds;
    reset_inland_cache();
}

void UndergroundChasmSamplerNative::reset_inland_cache() {
    is_deep_inland = false;
    _inland_min_x = 0.0;
    _inland_max_x = -1.0;
    _inland_min_z = 0.0;
    _inland_max_z = -1.0;
}

double UndergroundChasmSamplerNative::_get_effective_inland_raw(double wx, double wz) {
    if (continent_mask.get_type() == Variant::NIL || world_bounds.is_null()) {
        return 1.0;
    }
    double min_x = world_bounds->get("min_world_x");
    double max_x = world_bounds->get("max_world_x");
    double min_z = world_bounds->get("min_world_z");
    double max_z = world_bounds->get("max_world_z");

    double dist_left = wx - min_x;
    double dist_right = max_x - wx;
    double dist_bottom = wz - min_z;
    double dist_top = max_z - wz;
    double border_dist = std::min(std::min(dist_left, dist_right), std::min(dist_bottom, dist_top));
    if (border_dist <= 0.0) {
        return -1.0;
    }

    double land_raw = 0.0;
    if (continent_mask.has_method("get_main_continent_raw")) {
        land_raw = continent_mask.call("get_main_continent_raw", wx, wz, world_bounds);
    } else {
        land_raw = continent_mask.call("get_land_raw", wx, wz, world_bounds);
    }

    if (land_raw <= 0.0) {
        return land_raw;
    }

    double half_w = (max_x - min_x) * 0.5;
    double half_h = (max_z - min_z) * 0.5;
    double max_radius = std::min(half_w, half_h);
    double coast_falloff_distance = continent_mask.get("coast_falloff_distance");
    double border_margin = std::max(std::min(coast_falloff_distance, max_radius * 0.25), 1.0);
    if (border_dist < border_margin) {
        double c = border_dist / border_margin;
        if (c < 0.0) c = 0.0; else if (c > 1.0) c = 1.0;
        double border_land_cap = 0.20 * c;
        land_raw = std::min(land_raw, border_land_cap);
    }

    return land_raw;
}

bool UndergroundChasmSamplerNative::update_deep_inland_status(double min_x, double min_z, double max_x, double max_z) {
    if (continent_mask.get_type() == Variant::NIL || world_bounds.is_null()) {
        reset_inland_cache();
        return false;
    }

    double c0 = _get_effective_inland_raw(min_x, min_z);
    double c1 = _get_effective_inland_raw(max_x, min_z);
    double c2 = _get_effective_inland_raw(min_x, max_z);
    double c3 = _get_effective_inland_raw(max_x, max_z);

    bool inland = (
        c0 > DEEP_INLAND_LAND_THRESHOLD &&
        c1 > DEEP_INLAND_LAND_THRESHOLD &&
        c2 > DEEP_INLAND_LAND_THRESHOLD &&
        c3 > DEEP_INLAND_LAND_THRESHOLD
    );
    if (inland) {
        double warp_pad = chasm_wall_warp_amplitude + 4.0;
        _inland_min_x = min_x - warp_pad;
        _inland_max_x = max_x + warp_pad;
        _inland_min_z = min_z - warp_pad;
        _inland_max_z = max_z + warp_pad;
        is_deep_inland = true;
    } else {
        reset_inland_cache();
    }
    return is_deep_inland;
}

double UndergroundChasmSamplerNative::sample_rift_mask(double sample_x, double sample_z) {
    float raw = rift_noise.GetNoise((float)sample_x, (float)sample_z);
    float dist_val = raw + 1.0f;
    float c = dist_val / 0.42f;
    if (c < 0.0f) c = 0.0f; else if (c > 1.0f) c = 1.0f;
    float rift = 1.0f - c;
    if (rift <= 0.0f) {
        return 0.0;
    }

    bool in_cached_inland = (
        is_deep_inland &&
        sample_x >= _inland_min_x && sample_x <= _inland_max_x &&
        sample_z >= _inland_min_z && sample_z <= _inland_max_z
    );

    if (!in_cached_inland && continent_mask.get_type() != Variant::NIL && world_bounds.is_valid()) {
        double land_raw = _get_effective_inland_raw(sample_x, sample_z);
        double ocean_fade = (land_raw - 0.08) / 0.04;
        if (ocean_fade < 0.0) ocean_fade = 0.0; else if (ocean_fade > 1.0) ocean_fade = 1.0;
        ocean_fade = ocean_fade * ocean_fade * (3.0 - 2.0 * ocean_fade);
        rift *= (float)ocean_fade;
    }
    return rift;
}

bool UndergroundChasmSamplerNative::is_support_pillar(double sample_x, double sample_z, double raw_rift) {
    if (arena_enabled) {
        double rift = raw_rift >= 0.0 ? raw_rift : sample_rift_mask(sample_x, sample_z);
        if (rift >= (arena_rift_threshold - 0.08)) {
            return false;
        }
    }

    float pil_val = (pillar_noise.GetNoise((float)sample_x, (float)sample_z) + 1.0f) * 0.5f;
    if (pil_val <= pillar_threshold) {
        return false;
    }

    float pil_val2 = (pillar_noise.GetNoise((float)(sample_x * 1.8 + 61.7), (float)(sample_z * 1.8 + 43.1)) + 1.0f) * 0.5f;
    return pil_val2 > (pillar_threshold * 0.92f);
}

Vector2i UndergroundChasmSamplerNative::calculate_floor_and_ceiling(double sample_x, double sample_z, double raw_rift) {
    float floor_offset = floor_noise.GetNoise((float)sample_x, (float)sample_z) * (float)chasm_floor_variation;
    float ceil_offset = ceil_noise.GetNoise((float)sample_x, (float)sample_z) * (float)chasm_ceil_variation;

    float raw_fl_y = (float)chasm_min_y + floor_offset;
    int fl_y = (int)std::round(raw_fl_y);
    int cl_y = (int)std::round((float)chasm_max_y + ceil_offset);

    if (arena_enabled) {
        float target_floor = (float)arena_floor_y;
        if (raw_rift >= arena_rift_threshold) {
            float blend = (float)((raw_rift - arena_rift_threshold) / 0.02);
            if (blend < 0.0f) blend = 0.0f; else if (blend > 1.0f) blend = 1.0f;
            if (blend >= 1.0f) {
                fl_y = (int)target_floor;
                cl_y = std::max(cl_y, arena_ceiling_y);
            } else {
                float ledge_elev = (float)arena_ledge_step_height * std::sin(blend * 3.14159265358979323846f);
                fl_y = (int)std::round((raw_fl_y * (1.0f - blend) + target_floor * blend) + ledge_elev);
                cl_y = std::max(cl_y, (int)((float)cl_y * (1.0f - blend) + (float)arena_ceiling_y * blend));
            }
        } else if (raw_rift >= (arena_rift_threshold - 0.06)) {
            float approach_blend = (float)((raw_rift - (arena_rift_threshold - 0.06)) / 0.06);
            fl_y = (int)std::round(raw_fl_y * (1.0f - approach_blend * 0.75f) + target_floor * (approach_blend * 0.75f));
            if (cave_water_enabled) {
                fl_y = std::max(fl_y, chasm_water_level + 1);
            }
            cl_y = std::max(cl_y, (int)((float)cl_y * (1.0f - approach_blend * 0.75f) + (float)arena_ceiling_y * (approach_blend * 0.75f)));
        }
    }

    fl_y = std::max(fl_y, 3);

    if (!(arena_enabled && raw_rift >= (arena_rift_threshold - 0.06))) {
        cl_y = std::min(cl_y, chasm_max_y);
    }

    int min_clearance = (int)min_chasm_height;
    if (cl_y - fl_y < min_clearance) {
        cl_y = fl_y + min_clearance;
    }

    return Vector2i(fl_y, cl_y);
}

bool UndergroundChasmSamplerNative::is_arena(double wx, double wz) {
    if (!arena_enabled) {
        return false;
    }
    double unwarped_rift = sample_unwarped_rift(wx, wz);
    if (unwarped_rift < (arena_rift_threshold - get_wall_warp_margin())) {
        return false;
    }
    Vector2 warped_pos = get_warped_coordinates(wx, wz);
    return sample_rift_mask(warped_pos.x, warped_pos.y) >= arena_rift_threshold;
}

bool UndergroundChasmSamplerNative::can_arena_intersect_box(double min_x, double min_z, double max_x, double max_z) {
    if (!arena_enabled) {
        return false;
    }

    double mid_x = (min_x + max_x) * 0.5;
    double mid_z = (min_z + max_z) * 0.5;
    double unwarped_mid = sample_unwarped_rift(mid_x, mid_z);
    double half_diag = std::sqrt((max_x - min_x) * (max_x - min_x) + (max_z - min_z) * (max_z - min_z)) * 0.5;
    double max_reach = half_diag + get_wall_warp_margin();
    double margin = std::max(0.12, max_reach * chasm_rift_frequency * 2.5);

    if (unwarped_mid < (arena_rift_threshold - margin)) {
        return false;
    }

    if (is_arena(mid_x, mid_z)) return true;
    if (is_arena(min_x, min_z) || is_arena(max_x, min_z) || is_arena(min_x, max_z) || is_arena(max_x, max_z)) return true;
    if (is_arena(mid_x, min_z) || is_arena(mid_x, max_z) || is_arena(min_x, mid_z) || is_arena(max_x, mid_z)) return true;

    Vector2 warped_pos = get_warped_coordinates(mid_x, mid_z);
    double raw_rift = sample_rift_mask(warped_pos.x, warped_pos.y);
    return raw_rift >= (arena_rift_threshold - 0.02);
}

bool UndergroundChasmSamplerNative::can_arena_intersect_chunk(Ref<RefCounted> coord, Ref<RefCounted> bounds) {
    if (bounds.is_null() || !arena_enabled || coord.is_null()) {
        return false;
    }
    int32_t c_size = bounds->get("chunk_size");
    double voxel_size = bounds->get("voxel_size");
    int32_t cx = coord->get("x");
    int32_t cz = coord->get("z");

    double min_x = (double)(cx * c_size) * voxel_size;
    double min_z = (double)(cz * c_size) * voxel_size;
    double max_x = (double)((cx + 1) * c_size) * voxel_size;
    double max_z = (double)((cz + 1) * c_size) * voxel_size;
    return can_arena_intersect_box(min_x, min_z, max_x, max_z);
}

Ref<RefCounted> UndergroundChasmSamplerNative::sample_column(double wx, double wz, Ref<RefCounted> out, double surface_h) {
    if (out.is_null()) {
        Ref<ChasmColumnResultNative> new_res;
        new_res.instantiate();
        out = new_res;
    }
    ChasmColumnResultNative* res = Object::cast_to<ChasmColumnResultNative>(out.ptr());

    double unwarped_rift = sample_unwarped_rift(wx, wz);
    double early_exit_margin = get_wall_warp_margin() + WALL_MARGIN;
    if (unwarped_rift < (chasm_rift_threshold - early_exit_margin)) {
        if (res) {
            res->raw_rift = unwarped_rift;
            res->is_chasm = false;
            res->is_pillar = false;
            res->is_wall = false;
            res->is_arena = false;
            res->is_arena_ledge = false;
            res->is_basalt_column = false;
            res->floor_y = 0;
            res->ceil_y = 0;
        } else {
            out->set("raw_rift", unwarped_rift);
            out->set("is_chasm", false);
            out->set("is_pillar", false);
            out->set("is_wall", false);
            out->set("is_arena", false);
            out->set("is_arena_ledge", false);
            out->set("is_basalt_column", false);
            out->set("floor_y", 0);
            out->set("ceil_y", 0);
        }
        return out;
    }

    Vector2 warped_pos = get_warped_coordinates(wx, wz);
    double raw_rift = sample_rift_mask(warped_pos.x, warped_pos.y);
    if (surface_h >= 0.0) {
        double min_safe_surf = (double)chasm_min_y + chasm_floor_variation + min_chasm_height + crust_depth + 2.0;
        double surf_fade = (surface_h - min_safe_surf) / 8.0;
        if (surf_fade < 0.0) surf_fade = 0.0; else if (surf_fade > 1.0) surf_fade = 1.0;
        surf_fade = surf_fade * surf_fade * (3.0 - 2.0 * surf_fade);
        raw_rift *= surf_fade;
    }

    if (raw_rift < (chasm_rift_threshold - WALL_MARGIN)) {
        if (res) {
            res->raw_rift = raw_rift;
            res->is_chasm = false;
            res->is_pillar = false;
            res->is_wall = false;
            res->is_arena = false;
            res->is_arena_ledge = false;
            res->is_basalt_column = false;
            res->floor_y = 0;
            res->ceil_y = 0;
        } else {
            out->set("raw_rift", raw_rift);
            out->set("is_chasm", false);
            out->set("is_pillar", false);
            out->set("is_wall", false);
            out->set("is_arena", false);
            out->set("is_arena_ledge", false);
            out->set("is_basalt_column", false);
            out->set("floor_y", 0);
            out->set("ceil_y", 0);
        }
        return out;
    }

    bool is_arena_zone = arena_enabled && raw_rift >= arena_rift_threshold;
    double core_arena_threshold = arena_rift_threshold + 0.02;
    bool is_arena_val = is_arena_zone;
    bool is_arena_ledge_val = is_arena_zone && raw_rift < core_arena_threshold;
    bool is_basalt_column_val = false;

    Vector2i bounds = calculate_floor_and_ceiling(warped_pos.x, warped_pos.y, raw_rift);

    if (surface_h >= 0.0) {
        int max_allowed_ceil = (int)surface_h - (int)crust_depth;
        if (bounds.y > max_allowed_ceil) {
            if (max_allowed_ceil - bounds.x < (int)min_chasm_height) {
                if (res) {
                    res->raw_rift = raw_rift;
                    res->is_chasm = false;
                    res->is_pillar = false;
                    res->is_wall = true;
                    res->is_arena = false;
                    res->is_arena_ledge = false;
                    res->is_basalt_column = false;
                    res->floor_y = bounds.x;
                    res->ceil_y = std::max(bounds.x, max_allowed_ceil);
                } else {
                    out->set("raw_rift", raw_rift);
                    out->set("is_chasm", false);
                    out->set("is_pillar", false);
                    out->set("is_wall", true);
                    out->set("is_arena", false);
                    out->set("is_arena_ledge", false);
                    out->set("is_basalt_column", false);
                    out->set("floor_y", bounds.x);
                    out->set("ceil_y", std::max(bounds.x, max_allowed_ceil));
                }
                return out;
            } else {
                bounds.y = max_allowed_ceil;
            }
        }
    }

    if (raw_rift < chasm_rift_threshold) {
        if (res) {
            res->raw_rift = raw_rift;
            res->is_chasm = false;
            res->is_pillar = false;
            res->is_wall = true;
            res->is_arena = is_arena_val;
            res->is_arena_ledge = is_arena_ledge_val;
            res->is_basalt_column = false;
            res->floor_y = bounds.x;
            res->ceil_y = bounds.y;
        } else {
            out->set("raw_rift", raw_rift);
            out->set("is_chasm", false);
            out->set("is_pillar", false);
            out->set("is_wall", true);
            out->set("is_arena", is_arena_val);
            out->set("is_arena_ledge", is_arena_ledge_val);
            out->set("is_basalt_column", false);
            out->set("floor_y", bounds.x);
            out->set("ceil_y", bounds.y);
        }
        return out;
    }

    bool is_pillar_col = is_support_pillar(warped_pos.x, warped_pos.y, raw_rift);
    if (is_arena_zone) {
        is_pillar_col = false;
        if (raw_rift < core_arena_threshold) {
            float pil_val = (pillar_noise.GetNoise((float)warped_pos.x, (float)warped_pos.y) + 1.0f) * 0.5f;
            if (pil_val > pillar_threshold) {
                is_basalt_column_val = true;
            }
        }
    }

    if (is_pillar_col) {
        if (res) {
            res->raw_rift = raw_rift;
            res->is_chasm = false;
            res->is_pillar = true;
            res->is_wall = false;
            res->is_arena = is_arena_val;
            res->is_arena_ledge = is_arena_ledge_val;
            res->is_basalt_column = false;
            res->floor_y = bounds.x;
            res->ceil_y = bounds.y;
        } else {
            out->set("raw_rift", raw_rift);
            out->set("is_chasm", false);
            out->set("is_pillar", true);
            out->set("is_wall", false);
            out->set("is_arena", is_arena_val);
            out->set("is_arena_ledge", is_arena_ledge_val);
            out->set("is_basalt_column", false);
            out->set("floor_y", bounds.x);
            out->set("ceil_y", bounds.y);
        }
        return out;
    }

    if (res) {
        res->raw_rift = raw_rift;
        res->is_chasm = true;
        res->is_pillar = false;
        res->is_wall = false;
        res->is_arena = is_arena_val;
        res->is_arena_ledge = is_arena_ledge_val;
        res->is_basalt_column = is_basalt_column_val;
        res->floor_y = bounds.x;
        res->ceil_y = bounds.y;
    } else {
        out->set("raw_rift", raw_rift);
        out->set("is_chasm", true);
        out->set("is_pillar", false);
        out->set("is_wall", false);
        out->set("is_arena", is_arena_val);
        out->set("is_arena_ledge", is_arena_ledge_val);
        out->set("is_basalt_column", is_basalt_column_val);
        out->set("floor_y", bounds.x);
        out->set("ceil_y", bounds.y);
    }
    return out;
}

bool UndergroundChasmSamplerNative::can_chasm_intersect_cell(Vector3 min_p, Vector3 max_p) {
    sync_config();
    if (max_p.y <= (double)chasm_min_y) {
        is_deep_inland = false;
        return false;
    }

    update_deep_inland_status(min_p.x, min_p.z, max_p.x, max_p.z);

    double mid_x = (min_p.x + max_p.x) * 0.5;
    double mid_z = (min_p.z + max_p.z) * 0.5;

    double max_rift = std::max(
        sample_rift_mask(mid_x, mid_z),
        std::max(
            std::max(sample_rift_mask(min_p.x, min_p.z), sample_rift_mask(max_p.x, min_p.z)),
            std::max(sample_rift_mask(min_p.x, max_p.z), sample_rift_mask(max_p.x, max_p.z))
        )
    );
    max_rift = std::max(
        max_rift,
        std::max(
            std::max(sample_rift_mask(mid_x, min_p.z), sample_rift_mask(mid_x, max_p.z)),
            std::max(sample_rift_mask(min_p.x, mid_z), sample_rift_mask(max_p.x, mid_z))
        )
    );

    double half_diag = std::sqrt((max_p.x - min_p.x) * (max_p.x - min_p.x) + (max_p.z - min_p.z) * (max_p.z - min_p.z)) * 0.5;
    double max_reach = (half_diag * 0.5) + chasm_wall_warp_amplitude;
    double margin = std::max(0.12, max_reach * chasm_rift_frequency * 2.5);

    if (max_rift < (chasm_rift_threshold - margin)) {
        return false;
    }

    bool can_arena = arena_enabled && (max_rift >= (arena_rift_threshold - margin));
    double effective_max_y = can_arena ? (double)arena_ceiling_y : (double)chasm_max_y;
    if (min_p.y >= effective_max_y) {
        return false;
    }

    return true;
}

double UndergroundChasmSamplerNative::get_chasm_carve(double wx, double wy, double wz) {
    sync_config();
    double effective_max_y = arena_enabled ? (double)arena_ceiling_y : (double)chasm_max_y;
    if (wy <= 2.0 || wy >= effective_max_y) {
        return 0.0;
    }

    if (!can_column_contain_chasm(wx, wz)) {
        return 0.0;
    }

    Vector2 warped_pos = get_warped_coordinates(wx, wz);
    double raw_rift = sample_rift_mask(warped_pos.x, warped_pos.y);
    if (raw_rift < chasm_rift_threshold) {
        return 0.0;
    }

    bool is_pillar_col = is_support_pillar(warped_pos.x, warped_pos.y, raw_rift);
    if (arena_enabled && raw_rift >= arena_rift_threshold) {
        is_pillar_col = false;
    }

    if (is_pillar_col) {
        return 0.0;
    }

    Vector2i bounds = calculate_floor_and_ceiling(warped_pos.x, warped_pos.y, raw_rift);
    if (wy > (double)bounds.x && wy < (double)bounds.y) {
        return 1.0;
    }

    return 0.0;
}

bool UndergroundChasmSamplerNative::is_subterranean_water(double wx, double wy, double wz) {
    if (!cave_water_enabled) {
        return false;
    }
    if (wy > (double)chasm_water_level) {
        return false;
    }
    if (is_arena(wx, wz)) {
        return false;
    }
    return get_chasm_carve(wx, wy, wz) > 0.05;
}

Dictionary UndergroundChasmSamplerNative::sample_chasm(double wx, double wy, double wz) {
    sync_config();
    Dictionary dict;
    if (!can_column_contain_chasm(wx, wz)) {
        dict["is_chasm"] = false;
        dict["density"] = 0.0;
        dict["is_water"] = false;
        dict["is_pillar"] = false;
        return dict;
    }

    Vector2 warped_pos = get_warped_coordinates(wx, wz);
    double raw_rift = sample_rift_mask(warped_pos.x, warped_pos.y);

    if (raw_rift < chasm_rift_threshold) {
        dict["is_chasm"] = false;
        dict["density"] = 0.0;
        dict["is_water"] = false;
        dict["is_pillar"] = false;
        return dict;
    }

    bool is_arena_col = arena_enabled && raw_rift >= arena_rift_threshold;
    bool is_pillar_col = is_support_pillar(warped_pos.x, warped_pos.y, raw_rift);
    if (is_arena_col) {
        is_pillar_col = false;
    }

    if (is_pillar_col) {
        dict["is_chasm"] = false;
        dict["density"] = 0.0;
        dict["is_water"] = false;
        dict["is_pillar"] = true;
        return dict;
    }

    Vector2i bounds = calculate_floor_and_ceiling(warped_pos.x, warped_pos.y, raw_rift);
    bool is_void = wy > (double)bounds.x && wy < (double)bounds.y;
    bool is_water = is_void && cave_water_enabled && (!is_arena_col) && wy <= (double)chasm_water_level;

    dict["is_chasm"] = is_void;
    dict["density"] = is_void ? 1.0 : 0.0;
    dict["is_water"] = is_water;
    dict["is_pillar"] = false;
    return dict;
}

double UndergroundChasmSamplerNative::get_depth_envelope(double wy) {
    sync_config();
    double min_y = (double)chasm_min_y;
    double max_y = (double)chasm_max_y;

    if (wy <= min_y || wy >= max_y) {
        return 0.0;
    }

    double fade_dist = 3.0;
    double bottom_fade = (wy - min_y) / fade_dist;
    if (bottom_fade < 0.0) bottom_fade = 0.0; else if (bottom_fade > 1.0) bottom_fade = 1.0;

    double top_fade = (max_y - wy) / fade_dist;
    if (top_fade < 0.0) top_fade = 0.0; else if (top_fade > 1.0) top_fade = 1.0;

    return std::min(bottom_fade, top_fade);
}

void UndergroundChasmSamplerNative::_bind_methods() {
    ClassDB::bind_method(D_METHOD("initialize", "seed_val", "config"), &UndergroundChasmSamplerNative::initialize, DEFVAL(1337), DEFVAL(Variant()));
    ClassDB::bind_method(D_METHOD("_init_noises", "seed_val"), &UndergroundChasmSamplerNative::_init_noises);
    ClassDB::bind_method(D_METHOD("sync_config"), &UndergroundChasmSamplerNative::sync_config);

    ClassDB::bind_method(D_METHOD("get_config"), &UndergroundChasmSamplerNative::get_config);
    ClassDB::bind_method(D_METHOD("set_config", "config"), &UndergroundChasmSamplerNative::set_config);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "config", PROPERTY_HINT_RESOURCE_TYPE, "CaveGeneratorConfig"), "set_config", "get_config");

    ClassDB::bind_method(D_METHOD("get_is_deep_inland"), &UndergroundChasmSamplerNative::get_is_deep_inland);
    ClassDB::bind_method(D_METHOD("set_is_deep_inland", "v"), &UndergroundChasmSamplerNative::set_is_deep_inland);
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "is_deep_inland"), "set_is_deep_inland", "get_is_deep_inland");

    ClassDB::bind_method(D_METHOD("sample_unwarped_rift", "wx", "wz"), &UndergroundChasmSamplerNative::sample_unwarped_rift);
    ClassDB::bind_method(D_METHOD("get_wall_warp_margin"), &UndergroundChasmSamplerNative::get_wall_warp_margin);
    ClassDB::bind_method(D_METHOD("can_column_contain_chasm", "wx", "wz"), &UndergroundChasmSamplerNative::can_column_contain_chasm);
    ClassDB::bind_method(D_METHOD("get_warped_coordinates", "wx", "wz"), &UndergroundChasmSamplerNative::get_warped_coordinates);

    ClassDB::bind_method(D_METHOD("set_continent_mask", "mask", "bounds"), &UndergroundChasmSamplerNative::set_continent_mask);
    ClassDB::bind_method(D_METHOD("reset_inland_cache"), &UndergroundChasmSamplerNative::reset_inland_cache);
    ClassDB::bind_method(D_METHOD("_get_effective_inland_raw", "wx", "wz"), &UndergroundChasmSamplerNative::_get_effective_inland_raw);
    ClassDB::bind_method(D_METHOD("update_deep_inland_status", "min_x", "min_z", "max_x", "max_z"), &UndergroundChasmSamplerNative::update_deep_inland_status);

    ClassDB::bind_method(D_METHOD("sample_rift_mask", "sample_x", "sample_z"), &UndergroundChasmSamplerNative::sample_rift_mask);
    ClassDB::bind_method(D_METHOD("is_support_pillar", "sample_x", "sample_z", "raw_rift"), &UndergroundChasmSamplerNative::is_support_pillar, DEFVAL(-1.0));
    ClassDB::bind_method(D_METHOD("calculate_floor_and_ceiling", "sample_x", "sample_z", "raw_rift"), &UndergroundChasmSamplerNative::calculate_floor_and_ceiling, DEFVAL(0.0));

    ClassDB::bind_method(D_METHOD("is_arena", "wx", "wz"), &UndergroundChasmSamplerNative::is_arena);
    ClassDB::bind_method(D_METHOD("can_arena_intersect_box", "min_x", "min_z", "max_x", "max_z"), &UndergroundChasmSamplerNative::can_arena_intersect_box);
    ClassDB::bind_method(D_METHOD("can_arena_intersect_chunk", "coord", "bounds"), &UndergroundChasmSamplerNative::can_arena_intersect_chunk);

    ClassDB::bind_method(D_METHOD("sample_column", "wx", "wz", "out", "surface_h"), &UndergroundChasmSamplerNative::sample_column, DEFVAL(Variant()), DEFVAL(-1.0));
    ClassDB::bind_method(D_METHOD("can_chasm_intersect_cell", "min_p", "max_p"), &UndergroundChasmSamplerNative::can_chasm_intersect_cell);
    ClassDB::bind_method(D_METHOD("get_chasm_carve", "wx", "wy", "wz"), &UndergroundChasmSamplerNative::get_chasm_carve);
    ClassDB::bind_method(D_METHOD("is_subterranean_water", "wx", "wy", "wz"), &UndergroundChasmSamplerNative::is_subterranean_water);
    ClassDB::bind_method(D_METHOD("sample_chasm", "wx", "wy", "wz"), &UndergroundChasmSamplerNative::sample_chasm);
    ClassDB::bind_method(D_METHOD("get_depth_envelope", "wy"), &UndergroundChasmSamplerNative::get_depth_envelope);
}
