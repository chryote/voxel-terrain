#include "generation/macro_topography.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#include <algorithm>

using namespace godot;

MacroTopographyNative::MacroTopographyNative() {
}

void MacroTopographyNative::initialize(int32_t p_seed_val, Ref<RefCounted> p_config, Variant p_mask) {
    current_seed = p_seed_val;
    config = p_config;
    mask = p_mask;
    sync_config();
    _init_noises(p_seed_val);
}

void MacroTopographyNative::set_config(Ref<RefCounted> p_config) {
    config = p_config;
    sync_config();
}

void MacroTopographyNative::sync_config() {
    if (config.is_null()) {
        return;
    }
    Variant v;
    v = config->get("continent_noise_frequency");
    if (v.get_type() != Variant::NIL) continent_noise_frequency = v;

    v = config->get("erosion_frequency");
    if (v.get_type() != Variant::NIL) erosion_frequency = v;

    v = config->get("lowland_frequency");
    if (v.get_type() != Variant::NIL) lowland_frequency = v;

    v = config->get("lowland_base_elevation");
    if (v.get_type() != Variant::NIL) lowland_base_elevation = v;

    v = config->get("lowland_amplitude");
    if (v.get_type() != Variant::NIL) lowland_amplitude = v;

    v = config->get("rolling_hills_frequency");
    if (v.get_type() != Variant::NIL) rolling_hills_frequency = v;

    v = config->get("rolling_hills_amplitude");
    if (v.get_type() != Variant::NIL) rolling_hills_amplitude = v;

    v = config->get("highland_frequency");
    if (v.get_type() != Variant::NIL) highland_frequency = v;

    v = config->get("highland_threshold");
    if (v.get_type() != Variant::NIL) highland_threshold = v;

    v = config->get("highland_boost");
    if (v.get_type() != Variant::NIL) highland_boost = v;

    v = config->get("mountain_frequency");
    if (v.get_type() != Variant::NIL) mountain_frequency = v;

    v = config->get("mountain_threshold");
    if (v.get_type() != Variant::NIL) mountain_threshold = v;

    v = config->get("mountain_power");
    if (v.get_type() != Variant::NIL) mountain_power = v;

    v = config->get("mountain_amplitude");
    if (v.get_type() != Variant::NIL) mountain_amplitude = v;

    v = config->get("mountain_octaves");
    if (v.get_type() != Variant::NIL) mountain_octaves = v;

    v = config->get("mountain_fractal_gain");
    if (v.get_type() != Variant::NIL) mountain_fractal_gain = v;

    v = config->get("mountain_lacunarity");
    if (v.get_type() != Variant::NIL) mountain_lacunarity = v;

    v = config->get("inland_elevation_bias");
    if (v.get_type() != Variant::NIL) inland_elevation_bias = v;

    v = config->get("seabed_level");
    if (v.get_type() != Variant::NIL) seabed_level = v;

    v = config->get("sea_level");
    if (v.get_type() != Variant::NIL) sea_level = v;

    v = config->get("island_cliff_height");
    if (v.get_type() != Variant::NIL) island_cliff_height = v;

    v = config->get("island_terrace_step_height");
    if (v.get_type() != Variant::NIL) island_terrace_step_height = v;

    v = config->get("island_terrace_span");
    if (v.get_type() != Variant::NIL) island_terrace_span = v;
}

void MacroTopographyNative::_init_noises(int32_t seed_val) {
    // 1. Continentalness Noise
    cont_noise.SetSeed(seed_val);
    cont_noise.SetNoiseType(auburn::FastNoiseLite::NoiseType_OpenSimplex2S);
    cont_noise.SetFrequency((float)continent_noise_frequency);
    cont_noise.SetFractalType(auburn::FastNoiseLite::FractalType_FBm);
    cont_noise.SetFractalOctaves(3);
    cont_noise.SetFractalLacunarity(2.0f);
    cont_noise.SetFractalGain(0.5f);

    // 2. Erosion Noise
    erosion_noise.SetSeed(seed_val + 101);
    erosion_noise.SetNoiseType(auburn::FastNoiseLite::NoiseType_OpenSimplex2S);
    erosion_noise.SetFrequency((float)erosion_frequency);
    erosion_noise.SetFractalType(auburn::FastNoiseLite::FractalType_FBm);
    erosion_noise.SetFractalOctaves(3);
    erosion_noise.SetFractalLacunarity(2.0f);
    erosion_noise.SetFractalGain(0.5f);

    // 3. Lowland Noise
    lowland_noise.SetSeed(seed_val + 202);
    lowland_noise.SetNoiseType(auburn::FastNoiseLite::NoiseType_OpenSimplex2S);
    lowland_noise.SetFrequency((float)lowland_frequency);
    lowland_noise.SetFractalType(auburn::FastNoiseLite::FractalType_FBm);
    lowland_noise.SetFractalOctaves(2);
    lowland_noise.SetFractalLacunarity(2.0f);
    lowland_noise.SetFractalGain(0.5f);

    // 4. Rolling Hills Noise
    hills_noise.SetSeed(seed_val + 303);
    hills_noise.SetNoiseType(auburn::FastNoiseLite::NoiseType_OpenSimplex2S);
    hills_noise.SetFrequency((float)rolling_hills_frequency);
    hills_noise.SetFractalType(auburn::FastNoiseLite::FractalType_FBm);
    hills_noise.SetFractalOctaves(3);
    hills_noise.SetFractalLacunarity(2.0f);
    hills_noise.SetFractalGain(0.5f);

    // 5. Highland Plateau Noise
    highland_noise.SetSeed(seed_val + 404);
    highland_noise.SetNoiseType(auburn::FastNoiseLite::NoiseType_OpenSimplex2S);
    highland_noise.SetFrequency((float)highland_frequency);
    highland_noise.SetFractalType(auburn::FastNoiseLite::FractalType_FBm);
    highland_noise.SetFractalOctaves(3);
    highland_noise.SetFractalLacunarity(2.0f);
    highland_noise.SetFractalGain(0.5f);

    // 6. Mountain Noise
    mountain_noise.SetSeed(seed_val + 777);
    mountain_noise.SetNoiseType(auburn::FastNoiseLite::NoiseType_OpenSimplex2S);
    mountain_noise.SetFrequency((float)mountain_frequency);
    mountain_noise.SetFractalType(auburn::FastNoiseLite::FractalType_Ridged);
    mountain_noise.SetFractalOctaves(mountain_octaves);
    mountain_noise.SetFractalGain((float)mountain_fractal_gain);
    mountain_noise.SetFractalLacunarity((float)mountain_lacunarity);

    // Godot engine FastNoiseLite wrapper for reflection / test queries
    mountain_noise_gd.instantiate();
    mountain_noise_gd->set_seed(seed_val + 777);
    mountain_noise_gd->set_noise_type(godot::FastNoiseLite::TYPE_SIMPLEX_SMOOTH);
    mountain_noise_gd->set_frequency((real_t)mountain_frequency);
    mountain_noise_gd->set_fractal_type(godot::FastNoiseLite::FRACTAL_RIDGED);
    mountain_noise_gd->set_fractal_octaves(mountain_octaves);
    mountain_noise_gd->set_fractal_gain((real_t)mountain_fractal_gain);
    mountain_noise_gd->set_fractal_lacunarity((real_t)mountain_lacunarity);
}

Vector3 MacroTopographyNative::sample_offshore_island(double wx, double wz, Ref<RefCounted> bounds) {
    if (mask.get_type() == Variant::NIL || !bool(mask.get("islands_enabled")) || !mask.has_method("sample_offshore_island")) {
        return Vector3();
    }

    Vector2 isl_info = mask.call("sample_offshore_island", wx, wz, bounds);
    double isl_norm = isl_info.x;
    if (isl_norm <= 0.001) {
        return Vector3();
    }

    double entry_blend = isl_info.y;
    double seabed = (double)seabed_level;
    double sea = (double)sea_level;
    double cliff_h = std::max(4.0, island_cliff_height);

    double shore_threshold = 0.15;
    if (isl_norm < shore_threshold) {
        double base_t = isl_norm / shore_threshold;
        double smooth_base = base_t * base_t * (3.0 - 2.0 * base_t);
        double sub_h = seabed * (1.0 - smooth_base) + (sea - 1.0) * smooth_base;
        return Vector3((float)sub_h, 1.0f, (float)isl_norm);
    }

    double u = (isl_norm - shore_threshold) / (1.0 - shore_threshold);
    if (u < 0.0) u = 0.0; else if (u > 1.0) u = 1.0;

    double terrace_span = island_terrace_span;
    if (terrace_span < 0.15) terrace_span = 0.15; else if (terrace_span > 0.85) terrace_span = 0.85;

    double stair_span = 0.02 * (1.0 - entry_blend) + terrace_span * entry_blend;
    double stair_progress = u / stair_span;
    if (stair_progress < 0.0) stair_progress = 0.0; else if (stair_progress > 1.0) stair_progress = 1.0;

    double step_h = std::max(1.0, (double)island_terrace_step_height);
    double num_steps = std::max(1.0, std::round(cliff_h / step_h));
    double terrace_raise = stair_progress < 1.0 ? (std::floor(stair_progress * num_steps) / num_steps) * cliff_h : cliff_h;

    double final_h = sea + terrace_raise;
    bool is_inner_plateau = (stair_progress >= 1.0) && (u >= (terrace_span + 0.10));
    double zone_type = is_inner_plateau ? 3.0 : 2.0;
    return Vector3((float)final_h, (float)zone_type, (float)isl_norm);
}

Vector2 MacroTopographyNative::sample_macro_v2(double wx, double wz, Ref<RefCounted> bounds) {
    sync_config();
    if (mask.get_type() == Variant::NIL || bounds.is_null()) {
        return Vector2((float)seabed_level, 0.0f);
    }

    double main_raw = 0.0;
    if (mask.has_method("get_main_continent_raw")) {
        main_raw = mask.call("get_main_continent_raw", wx, wz, bounds);
    } else {
        main_raw = mask.call("get_land_raw", wx, wz, bounds);
    }

    if (main_raw <= 0.0) {
        return Vector2((float)seabed_level, 0.0f);
    }

    double min_x = bounds->get("min_world_x");
    double max_x = bounds->get("max_world_x");
    double min_z = bounds->get("min_world_z");
    double max_z = bounds->get("max_world_z");

    double dist_left = wx - min_x;
    double dist_right = max_x - wx;
    double dist_bottom = wz - min_z;
    double dist_top = max_z - wz;
    double border_dist = std::min(std::min(dist_left, dist_right), std::min(dist_bottom, dist_top));
    if (border_dist <= 0.0) {
        return Vector2((float)seabed_level, 0.0f);
    }

    double coast_falloff_distance = mask.get("coast_falloff_distance");
    double border_fade = border_dist / std::max(1.0, coast_falloff_distance);
    if (border_fade < 0.0) border_fade = 0.0; else if (border_fade > 1.0) border_fade = 1.0;
    border_fade = border_fade * border_fade * (3.0 - 2.0 * border_fade);

    double t_mask = main_raw / 0.16;
    if (t_mask < 0.0) t_mask = 0.0; else if (t_mask > 1.0) t_mask = 1.0;
    double land_factor = t_mask * t_mask * (3.0 - 2.0 * t_mask) * border_fade;
    if (land_factor < 0.0) land_factor = 0.0; else if (land_factor > 1.0) land_factor = 1.0;

    if (land_factor <= 0.001) {
        return Vector2((float)seabed_level, 0.0f);
    }

    double inland_gradient = main_raw;
    if (inland_gradient < 0.0) inland_gradient = 0.0; else if (inland_gradient > 1.0) inland_gradient = 1.0;

    float c_sample = (cont_noise.GetNoise((float)wx, (float)wz) + 1.0f) * 0.5f;
    double continentalness = land_factor * (inland_gradient * 0.6 + (double)c_sample * 0.4);
    double erosion = ((double)erosion_noise.GetNoise((float)wx, (float)wz) + 1.0) * 0.5;

    double low_n = ((double)lowland_noise.GetNoise((float)wx, (float)wz) + 1.0) * 0.5;
    double h_low = lowland_base_elevation + low_n * lowland_amplitude;

    float hill_raw = hills_noise.GetNoise((float)wx, (float)wz);
    double hill_billow = (double)std::abs(hill_raw) * 2.0 - 1.0;
    double h_hills = lowland_base_elevation + (hill_billow * 0.5 + 0.5) * rolling_hills_amplitude;

    double h_highland = 0.0;
    if (continentalness > highland_threshold) {
        double hl_n = ((double)highland_noise.GetNoise((float)wx, (float)wz) + 1.0) * 0.5;
        double plateau_t = (continentalness - highland_threshold) / 0.25;
        if (plateau_t < 0.0) plateau_t = 0.0; else if (plateau_t > 1.0) plateau_t = 1.0;
        double plateau_step = plateau_t * plateau_t * (3.0 - 2.0 * plateau_t);
        h_highland = plateau_step * (highland_boost + hl_n * 12.0);
    }

    double h_mountain = 0.0;
    double m_sample = ((double)mountain_noise.GetNoise((float)wx, (float)wz) + 1.0) * 0.5;
    if (m_sample > mountain_threshold) {
        double m_norm = (m_sample - mountain_threshold) / (1.0 - mountain_threshold);
        double m_ridge = std::pow(m_norm, mountain_power) * mountain_amplitude;
        double c_part = (continentalness - 0.25) / 0.35;
        if (c_part < 0.0) c_part = 0.0; else if (c_part > 1.0) c_part = 1.0;
        double mountain_weight = (1.0 - erosion) * c_part;
        h_mountain = m_ridge * mountain_weight;
    }

    double base_relief = h_hills * (1.0 - erosion) + h_low * erosion;
    double total_land_h = base_relief + h_highland + h_mountain + inland_elevation_bias;

    double coast_t = continentalness / 0.12;
    if (coast_t < 0.0) coast_t = 0.0; else if (coast_t > 1.0) coast_t = 1.0;
    coast_t = coast_t * coast_t * (3.0 - 2.0 * coast_t);
    double final_h = (double)seabed_level * (1.0 - coast_t) + total_land_h * coast_t;

    return Vector2((float)final_h, (float)continentalness);
}

Dictionary MacroTopographyNative::sample_macro(double wx, double wz, Ref<RefCounted> bounds) {
    sync_config();
    Dictionary dict;
    Vector3 isl = sample_offshore_island(wx, wz, bounds);
    if (isl.y > 0.0f) {
        dict["elevation"] = (double)isl.x;
        double lf = isl.z;
        if (lf < 0.0) lf = 0.0; else if (lf > 1.0) lf = 1.0;
        dict["land_factor"] = lf;
        dict["continentalness"] = 0.0;
        dict["erosion"] = 1.0;
        dict["is_highland"] = false;
        dict["is_mountain"] = false;
        dict["is_offshore_island"] = true;
        dict["island_zone_type"] = (int64_t)isl.y;
        return dict;
    }

    if (mask.get_type() == Variant::NIL || bounds.is_null()) {
        dict["elevation"] = (double)seabed_level;
        dict["land_factor"] = 0.0;
        dict["continentalness"] = 0.0;
        dict["erosion"] = 1.0;
        dict["is_highland"] = false;
        dict["is_mountain"] = false;
        dict["is_offshore_island"] = false;
        dict["island_zone_type"] = (int64_t)0;
        return dict;
    }

    double main_raw = 0.0;
    if (mask.has_method("get_main_continent_raw")) {
        main_raw = mask.call("get_main_continent_raw", wx, wz, bounds);
    } else {
        main_raw = mask.call("get_land_raw", wx, wz, bounds);
    }

    if (main_raw <= 0.0) {
        dict["elevation"] = (double)seabed_level;
        dict["land_factor"] = 0.0;
        dict["continentalness"] = 0.0;
        dict["erosion"] = 1.0;
        dict["is_highland"] = false;
        dict["is_mountain"] = false;
        dict["is_offshore_island"] = false;
        dict["island_zone_type"] = (int64_t)0;
        return dict;
    }

    double min_x = bounds->get("min_world_x");
    double max_x = bounds->get("max_world_x");
    double min_z = bounds->get("min_world_z");
    double max_z = bounds->get("max_world_z");

    double dist_left = wx - min_x;
    double dist_right = max_x - wx;
    double dist_bottom = wz - min_z;
    double dist_top = max_z - wz;
    double border_dist = std::min(std::min(dist_left, dist_right), std::min(dist_bottom, dist_top));

    double coast_falloff_distance = mask.get("coast_falloff_distance");
    double border_fade = border_dist / std::max(1.0, coast_falloff_distance);
    if (border_fade < 0.0) border_fade = 0.0; else if (border_fade > 1.0) border_fade = 1.0;
    border_fade = border_fade * border_fade * (3.0 - 2.0 * border_fade);

    double t_mask = main_raw / 0.16;
    if (t_mask < 0.0) t_mask = 0.0; else if (t_mask > 1.0) t_mask = 1.0;
    double land_factor = t_mask * t_mask * (3.0 - 2.0 * t_mask) * border_fade;
    if (land_factor < 0.0) land_factor = 0.0; else if (land_factor > 1.0) land_factor = 1.0;

    if (land_factor <= 0.001) {
        dict["elevation"] = (double)seabed_level;
        dict["land_factor"] = 0.0;
        dict["continentalness"] = 0.0;
        dict["erosion"] = 1.0;
        dict["is_highland"] = false;
        dict["is_mountain"] = false;
        dict["is_offshore_island"] = false;
        dict["island_zone_type"] = (int64_t)0;
        return dict;
    }

    double inland_gradient = main_raw;
    if (inland_gradient < 0.0) inland_gradient = 0.0; else if (inland_gradient > 1.0) inland_gradient = 1.0;

    float c_sample = (cont_noise.GetNoise((float)wx, (float)wz) + 1.0f) * 0.5f;
    double continentalness = land_factor * (inland_gradient * 0.6 + (double)c_sample * 0.4);
    double erosion = ((double)erosion_noise.GetNoise((float)wx, (float)wz) + 1.0) * 0.5;

    double low_n = ((double)lowland_noise.GetNoise((float)wx, (float)wz) + 1.0) * 0.5;
    double h_low = lowland_base_elevation + low_n * lowland_amplitude;

    float hill_raw = hills_noise.GetNoise((float)wx, (float)wz);
    double hill_billow = (double)std::abs(hill_raw) * 2.0 - 1.0;
    double h_hills = lowland_base_elevation + (hill_billow * 0.5 + 0.5) * rolling_hills_amplitude;

    bool is_highland = false;
    double h_highland = 0.0;
    if (continentalness > highland_threshold) {
        double hl_n = ((double)highland_noise.GetNoise((float)wx, (float)wz) + 1.0) * 0.5;
        double plateau_t = (continentalness - highland_threshold) / 0.25;
        if (plateau_t < 0.0) plateau_t = 0.0; else if (plateau_t > 1.0) plateau_t = 1.0;
        double plateau_step = plateau_t * plateau_t * (3.0 - 2.0 * plateau_t);
        h_highland = plateau_step * (highland_boost + hl_n * 12.0);
        if (plateau_step > 0.5) {
            is_highland = true;
        }
    }

    bool is_mountain = false;
    double h_mountain = 0.0;
    double m_sample = ((double)mountain_noise.GetNoise((float)wx, (float)wz) + 1.0) * 0.5;
    if (m_sample > mountain_threshold) {
        double m_norm = (m_sample - mountain_threshold) / (1.0 - mountain_threshold);
        double m_ridge = std::pow(m_norm, mountain_power) * mountain_amplitude;
        double c_part = (continentalness - 0.25) / 0.35;
        if (c_part < 0.0) c_part = 0.0; else if (c_part > 1.0) c_part = 1.0;
        double mountain_weight = (1.0 - erosion) * c_part;
        h_mountain = m_ridge * mountain_weight;
        if (h_mountain > 15.0) {
            is_mountain = true;
        }
    }

    double base_relief = h_hills * (1.0 - erosion) + h_low * erosion;
    double total_land_h = base_relief + h_highland + h_mountain + inland_elevation_bias;

    double coast_t = continentalness / 0.12;
    if (coast_t < 0.0) coast_t = 0.0; else if (coast_t > 1.0) coast_t = 1.0;
    coast_t = coast_t * coast_t * (3.0 - 2.0 * coast_t);
    double final_h = (double)seabed_level * (1.0 - coast_t) + total_land_h * coast_t;

    dict["elevation"] = final_h;
    dict["land_factor"] = land_factor;
    dict["continentalness"] = continentalness;
    dict["erosion"] = erosion;
    dict["is_highland"] = is_highland;
    dict["is_mountain"] = is_mountain;
    dict["is_offshore_island"] = false;
    dict["island_zone_type"] = (int64_t)0;
    return dict;
}

Vector2 MacroTopographyNative::sample_macro_interpolated(double wx, double wz, Ref<RefCounted> bounds, int32_t stride) {
    if (bounds.is_null()) {
        return Vector2();
    }
    double voxel_size = bounds->get("voxel_size");
    int64_t gx = (int64_t)std::floor(wx / voxel_size - 0.5);
    int64_t gz = (int64_t)std::floor(wz / voxel_size - 0.5);

    int64_t gx0 = (int64_t)(std::floor((double)gx / (double)stride)) * stride;
    int64_t gx1 = gx0 + stride;
    int64_t gz0 = (int64_t)(std::floor((double)gz / (double)stride)) * stride;
    int64_t gz1 = gz0 + stride;
    double tx = (double)(gx - gx0) / (double)stride;
    double tz = (double)(gz - gz0) / (double)stride;

    double wx0 = ((double)gx0 + 0.5) * voxel_size;
    double wx1 = ((double)gx1 + 0.5) * voxel_size;
    double wz0 = ((double)gz0 + 0.5) * voxel_size;
    double wz1 = ((double)gz1 + 0.5) * voxel_size;

    Vector2 c00 = sample_macro_v2(wx0, wz0, bounds);
    Vector2 c10 = sample_macro_v2(wx1, wz0, bounds);
    Vector2 c01 = sample_macro_v2(wx0, wz1, bounds);
    Vector2 c11 = sample_macro_v2(wx1, wz1, bounds);

    Vector2 c0 = c00.lerp(c10, (float)tx);
    Vector2 c1 = c01.lerp(c11, (float)tx);
    return c0.lerp(c1, (float)tz);
}

void MacroTopographyNative::_bind_methods() {
    ClassDB::bind_method(D_METHOD("initialize", "seed_val", "config", "mask"), &MacroTopographyNative::initialize, DEFVAL(1337), DEFVAL(Variant()), DEFVAL(Variant()));
    ClassDB::bind_method(D_METHOD("_init_noises", "seed_val"), &MacroTopographyNative::_init_noises);
    ClassDB::bind_method(D_METHOD("sync_config"), &MacroTopographyNative::sync_config);

    ClassDB::bind_method(D_METHOD("get_config"), &MacroTopographyNative::get_config);
    ClassDB::bind_method(D_METHOD("set_config", "config"), &MacroTopographyNative::set_config);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "config", PROPERTY_HINT_RESOURCE_TYPE, "ContinentGeneratorConfig"), "set_config", "get_config");

    ClassDB::bind_method(D_METHOD("get_mask"), &MacroTopographyNative::get_mask);
    ClassDB::bind_method(D_METHOD("set_mask", "mask"), &MacroTopographyNative::set_mask);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "mask"), "set_mask", "get_mask");

    ClassDB::bind_method(D_METHOD("get_mountain_noise"), &MacroTopographyNative::get_mountain_noise);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "mountain_noise", PROPERTY_HINT_RESOURCE_TYPE, "FastNoiseLite"), "", "get_mountain_noise");

    ClassDB::bind_method(D_METHOD("sample_offshore_island", "wx", "wz", "bounds"), &MacroTopographyNative::sample_offshore_island);
    ClassDB::bind_method(D_METHOD("sample_macro", "wx", "wz", "bounds"), &MacroTopographyNative::sample_macro);
    ClassDB::bind_method(D_METHOD("sample_macro_v2", "wx", "wz", "bounds"), &MacroTopographyNative::sample_macro_v2);
    ClassDB::bind_method(D_METHOD("sample_macro_interpolated", "wx", "wz", "bounds", "stride"), &MacroTopographyNative::sample_macro_interpolated, DEFVAL(4));
}
