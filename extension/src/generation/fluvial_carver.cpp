#include "generation/fluvial_carver.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#include <algorithm>

using namespace godot;

FluvialCarverNative::FluvialCarverNative() {
}

void FluvialCarverNative::initialize(int32_t p_seed_val, Ref<RefCounted> p_config) {
    current_seed = p_seed_val;
    config = p_config;
    sync_config();
    _init_noises(p_seed_val);
}

void FluvialCarverNative::set_config(Ref<RefCounted> p_config) {
    config = p_config;
    sync_config();
}

void FluvialCarverNative::sync_config() {
    if (config.is_null()) {
        return;
    }
    Variant v;
    v = config->get("sea_level");
    if (v.get_type() != Variant::NIL) sea_level = v;

    v = config->get("wide_river_frequency");
    if (v.get_type() != Variant::NIL) wide_river_frequency = v;

    v = config->get("wide_river_warp_amplitude");
    if (v.get_type() != Variant::NIL) wide_river_warp_amplitude = v;

    v = config->get("wide_river_width_threshold");
    if (v.get_type() != Variant::NIL) wide_river_width_threshold = v;

    v = config->get("wide_river_depth");
    if (v.get_type() != Variant::NIL) wide_river_depth = v;

    v = config->get("wide_river_water_recede");
    if (v.get_type() != Variant::NIL) wide_river_water_recede = v;

    v = config->get("small_river_frequency");
    if (v.get_type() != Variant::NIL) small_river_frequency = v;

    v = config->get("small_river_warp_amplitude");
    if (v.get_type() != Variant::NIL) small_river_warp_amplitude = v;

    v = config->get("small_river_width_threshold");
    if (v.get_type() != Variant::NIL) small_river_width_threshold = v;

    v = config->get("small_river_depth");
    if (v.get_type() != Variant::NIL) small_river_depth = v;

    v = config->get("small_river_water_recede");
    if (v.get_type() != Variant::NIL) small_river_water_recede = v;

    v = config->get("lake_frequency");
    if (v.get_type() != Variant::NIL) lake_frequency = v;

    v = config->get("lake_threshold");
    if (v.get_type() != Variant::NIL) lake_threshold = v;

    v = config->get("lake_depth");
    if (v.get_type() != Variant::NIL) lake_depth = v;

    v = config->get("lake_water_recede");
    if (v.get_type() != Variant::NIL) lake_water_recede = v;

    v = config->get("pond_frequency");
    if (v.get_type() != Variant::NIL) pond_frequency = v;

    v = config->get("pond_threshold");
    if (v.get_type() != Variant::NIL) pond_threshold = v;

    v = config->get("pond_depth");
    if (v.get_type() != Variant::NIL) pond_depth = v;

    v = config->get("pond_water_recede");
    if (v.get_type() != Variant::NIL) pond_water_recede = v;
}

void FluvialCarverNative::_init_noises(int32_t seed_val) {
    // 1. Wide river network + large domain warp
    wide_noise.SetSeed(seed_val + 505);
    wide_noise.SetNoiseType(auburn::FastNoiseLite::NoiseType_OpenSimplex2S);
    wide_noise.SetFrequency((float)wide_river_frequency);
    wide_noise.SetFractalType(auburn::FastNoiseLite::FractalType_FBm);
    wide_noise.SetFractalOctaves(5);
    wide_noise.SetFractalLacunarity(2.0f);
    wide_noise.SetFractalGain(0.5f);

    wide_warp.SetSeed(seed_val + 506);
    wide_warp.SetNoiseType(auburn::FastNoiseLite::NoiseType_OpenSimplex2S);
    wide_warp.SetFrequency(0.0012f);
    wide_warp.SetFractalType(auburn::FastNoiseLite::FractalType_FBm);
    wide_warp.SetFractalOctaves(5);
    wide_warp.SetFractalLacunarity(2.0f);
    wide_warp.SetFractalGain(0.5f);

    // 2. Small winding river network + high-frequency sinuous warp
    small_noise.SetSeed(seed_val + 606);
    small_noise.SetNoiseType(auburn::FastNoiseLite::NoiseType_OpenSimplex2S);
    small_noise.SetFrequency((float)small_river_frequency);
    small_noise.SetFractalType(auburn::FastNoiseLite::FractalType_FBm);
    small_noise.SetFractalOctaves(5);
    small_noise.SetFractalLacunarity(2.0f);
    small_noise.SetFractalGain(0.5f);

    small_warp.SetSeed(seed_val + 607);
    small_warp.SetNoiseType(auburn::FastNoiseLite::NoiseType_OpenSimplex2S);
    small_warp.SetFrequency(0.004f);
    small_warp.SetFractalType(auburn::FastNoiseLite::FractalType_FBm);
    small_warp.SetFractalOctaves(5);
    small_warp.SetFractalLacunarity(2.0f);
    small_warp.SetFractalGain(0.5f);

    // 3. Lake basin depression noise
    lake_noise.SetSeed(seed_val + 707);
    lake_noise.SetNoiseType(auburn::FastNoiseLite::NoiseType_OpenSimplex2S);
    lake_noise.SetFrequency((float)lake_frequency);
    lake_noise.SetFractalType(auburn::FastNoiseLite::FractalType_FBm);
    lake_noise.SetFractalOctaves(2);
    lake_noise.SetFractalLacunarity(2.0f);
    lake_noise.SetFractalGain(0.5f);

    // 4. Pond basin depression noise
    pond_noise.SetSeed(seed_val + 808);
    pond_noise.SetNoiseType(auburn::FastNoiseLite::NoiseType_OpenSimplex2S);
    pond_noise.SetFrequency((float)pond_frequency);
    pond_noise.SetFractalType(auburn::FastNoiseLite::FractalType_FBm);
    pond_noise.SetFractalOctaves(2);
    pond_noise.SetFractalLacunarity(2.0f);
    pond_noise.SetFractalGain(0.5f);
}

Vector3 FluvialCarverNative::sample_fluvial_v3(double wx, double wz, double base_elevation, double continentalness) {
    if (continentalness < 0.06) {
        float f = (int64_t)std::round(base_elevation) < sea_level ? 4.0f : 0.0f;
        return Vector3(0.0f, (float)sea_level, f);
    }

    double bank_top = std::round(base_elevation);

    double carve_wide = 0.0;
    bool is_wide_river = false;
    double wide_water_level = (double)sea_level;

    double w_wx = wx + (double)wide_warp.GetNoise((float)wx, (float)wz) * wide_river_warp_amplitude;
    double w_wz = wz + (double)wide_warp.GetNoise((float)(wx + 3456.0), (float)(wz + 3456.0)) * wide_river_warp_amplitude;
    double w_dist = (double)std::abs(wide_noise.GetNoise((float)w_wx, (float)w_wz));

    if (w_dist < wide_river_width_threshold) {
        is_wide_river = true;
        double f_wide = 1.0 - (w_dist / wide_river_width_threshold);
        double u_wide = f_wide * f_wide * (3.0 - 2.0 * f_wide);
        carve_wide = u_wide * wide_river_depth;
        wide_water_level = std::max((double)sea_level, bank_top - wide_river_water_recede);
    }

    double carve_small = 0.0;
    bool is_small_river = false;
    double small_water_level = (double)sea_level;

    double s_wx = wx + (double)small_warp.GetNoise((float)wx, (float)wz) * small_river_warp_amplitude;
    double s_wz = wz + (double)small_warp.GetNoise((float)(wx + 7890.0), (float)(wz + 7890.0)) * small_river_warp_amplitude;
    double s_dist = (double)std::abs(small_noise.GetNoise((float)s_wx, (float)s_wz));

    if (s_dist < small_river_width_threshold) {
        is_small_river = true;
        double f_small = 1.0 - (s_dist / small_river_width_threshold);
        double u_small = f_small * f_small * (3.0 - 2.0 * f_small);
        carve_small = u_small * small_river_depth;
        small_water_level = std::max((double)sea_level, bank_top - small_river_water_recede);
    }

    double carve_lake = 0.0;
    bool is_lake = false;
    double lake_water_level = (double)sea_level;

    double l_sample = ((double)lake_noise.GetNoise((float)wx, (float)wz) + 1.0) * 0.5;
    if (l_sample > lake_threshold && continentalness > 0.12) {
        is_lake = true;
        double lake_span = std::max(0.05, (1.0 - lake_threshold) * 0.60);
        double f_lake = (l_sample - lake_threshold) / lake_span;
        if (f_lake < 0.0) f_lake = 0.0; else if (f_lake > 1.0) f_lake = 1.0;
        double u_lake = f_lake * f_lake * (3.0 - 2.0 * f_lake);
        carve_lake = u_lake * lake_depth;
        lake_water_level = std::max((double)sea_level, bank_top - lake_water_recede);
    }

    double carve_pond = 0.0;
    bool is_pond = false;
    double pond_water_level = (double)sea_level;

    double p_sample = ((double)pond_noise.GetNoise((float)wx, (float)wz) + 1.0) * 0.5;
    if (p_sample > pond_threshold && continentalness > 0.10) {
        is_pond = true;
        double pond_span = std::max(0.05, (1.0 - pond_threshold) * 0.60);
        double f_pond = (p_sample - pond_threshold) / pond_span;
        if (f_pond < 0.0) f_pond = 0.0; else if (f_pond > 1.0) f_pond = 1.0;
        double u_pond = f_pond * f_pond * (3.0 - 2.0 * f_pond);
        carve_pond = u_pond * pond_depth;
        pond_water_level = std::max((double)sea_level, bank_top - pond_water_recede);
    }

    double basin_carve = std::max(carve_lake, carve_pond);
    double basin_water_level = carve_lake >= carve_pond ? lake_water_level : pond_water_level;
    bool has_basin = is_lake || is_pond;

    if (carve_wide <= 0.0 && carve_small <= 0.0 && basin_carve <= 0.0) {
        float f = (int64_t)std::round(base_elevation) < sea_level ? 4.0f : 0.0f;
        return Vector3(0.0f, (float)sea_level, f);
    }

    double total_carve = 0.0;
    double water_elevation_f = (double)sea_level;

    if (carve_wide >= carve_small && carve_wide >= basin_carve) {
        total_carve = carve_wide;
        water_elevation_f = wide_water_level;
    } else if (carve_small >= basin_carve) {
        total_carve = carve_small;
        water_elevation_f = small_water_level;
    } else {
        total_carve = basin_carve;
        water_elevation_f = basin_water_level;
    }

    int64_t flags = 0;
    if (is_wide_river || is_small_river) {
        flags |= 1;
    }
    if (has_basin) {
        flags |= 2;
    }
    if ((int64_t)std::round(base_elevation - total_carve) < (int64_t)std::round(water_elevation_f)) {
        flags |= 4;
    }

    return Vector3((float)total_carve, (float)water_elevation_f, (float)flags);
}

Dictionary FluvialCarverNative::sample_fluvial(double wx, double wz, double base_elevation, double continentalness) {
    sync_config();
    Dictionary dict;
    if (continentalness < 0.06) {
        dict["carve_depth"] = 0.0;
        dict["water_elevation"] = (int64_t)sea_level;
        dict["is_water"] = (int64_t)std::round(base_elevation) < sea_level;
        dict["is_river"] = false;
        dict["is_wide_river"] = false;
        dict["is_small_river"] = false;
        dict["is_lake"] = false;
        dict["is_pond"] = false;
        return dict;
    }

    double bank_top = std::round(base_elevation);

    double carve_wide = 0.0;
    bool is_wide_river = false;
    double wide_water_level = (double)sea_level;

    double w_wx = wx + (double)wide_warp.GetNoise((float)wx, (float)wz) * wide_river_warp_amplitude;
    double w_wz = wz + (double)wide_warp.GetNoise((float)(wx + 3456.0), (float)(wz + 3456.0)) * wide_river_warp_amplitude;
    double w_dist = (double)std::abs(wide_noise.GetNoise((float)w_wx, (float)w_wz));

    if (w_dist < wide_river_width_threshold) {
        is_wide_river = true;
        double f_wide = 1.0 - (w_dist / wide_river_width_threshold);
        double u_wide = f_wide * f_wide * (3.0 - 2.0 * f_wide);
        carve_wide = u_wide * wide_river_depth;
        wide_water_level = std::max((double)sea_level, bank_top - wide_river_water_recede);
    }

    double carve_small = 0.0;
    bool is_small_river = false;
    double small_water_level = (double)sea_level;

    double s_wx = wx + (double)small_warp.GetNoise((float)wx, (float)wz) * small_river_warp_amplitude;
    double s_wz = wz + (double)small_warp.GetNoise((float)(wx + 7890.0), (float)(wz + 7890.0)) * small_river_warp_amplitude;
    double s_dist = (double)std::abs(small_noise.GetNoise((float)s_wx, (float)s_wz));

    if (s_dist < small_river_width_threshold) {
        is_small_river = true;
        double f_small = 1.0 - (s_dist / small_river_width_threshold);
        double u_small = f_small * f_small * (3.0 - 2.0 * f_small);
        carve_small = u_small * small_river_depth;
        small_water_level = std::max((double)sea_level, bank_top - small_river_water_recede);
    }

    double carve_lake = 0.0;
    bool is_lake = false;
    double lake_water_level = (double)sea_level;

    double l_sample = ((double)lake_noise.GetNoise((float)wx, (float)wz) + 1.0) * 0.5;
    if (l_sample > lake_threshold && continentalness > 0.12) {
        is_lake = true;
        double lake_span = std::max(0.05, (1.0 - lake_threshold) * 0.60);
        double f_lake = (l_sample - lake_threshold) / lake_span;
        if (f_lake < 0.0) f_lake = 0.0; else if (f_lake > 1.0) f_lake = 1.0;
        double u_lake = f_lake * f_lake * (3.0 - 2.0 * f_lake);
        carve_lake = u_lake * lake_depth;
        lake_water_level = std::max((double)sea_level, bank_top - lake_water_recede);
    }

    double carve_pond = 0.0;
    bool is_pond = false;
    double pond_water_level = (double)sea_level;

    double p_sample = ((double)pond_noise.GetNoise((float)wx, (float)wz) + 1.0) * 0.5;
    if (p_sample > pond_threshold && continentalness > 0.10) {
        is_pond = true;
        double pond_span = std::max(0.05, (1.0 - pond_threshold) * 0.60);
        double f_pond = (p_sample - pond_threshold) / pond_span;
        if (f_pond < 0.0) f_pond = 0.0; else if (f_pond > 1.0) f_pond = 1.0;
        double u_pond = f_pond * f_pond * (3.0 - 2.0 * f_pond);
        carve_pond = u_pond * pond_depth;
        pond_water_level = std::max((double)sea_level, bank_top - pond_water_recede);
    }

    double basin_carve = std::max(carve_lake, carve_pond);
    double basin_water_level = carve_lake >= carve_pond ? lake_water_level : pond_water_level;
    bool has_basin = is_lake || is_pond;

    double total_carve = 0.0;
    double water_elevation_f = (double)sea_level;

    if (carve_wide > 0.0 || carve_small > 0.0 || basin_carve > 0.0) {
        if (carve_wide >= carve_small && carve_wide >= basin_carve) {
            total_carve = carve_wide;
            water_elevation_f = wide_water_level;
        } else if (carve_small >= basin_carve) {
            total_carve = carve_small;
            water_elevation_f = small_water_level;
        } else {
            total_carve = basin_carve;
            water_elevation_f = basin_water_level;
        }
    } else {
        dict["carve_depth"] = 0.0;
        dict["water_elevation"] = (int64_t)sea_level;
        dict["is_water"] = (int64_t)std::round(base_elevation) < sea_level;
        dict["is_river"] = false;
        dict["is_wide_river"] = false;
        dict["is_small_river"] = false;
        dict["is_lake"] = false;
        dict["is_pond"] = false;
        return dict;
    }

    int64_t final_ground_i = (int64_t)std::round(base_elevation - total_carve);
    int64_t water_elevation_i = (int64_t)std::round(water_elevation_f);
    bool is_water = final_ground_i < water_elevation_i;
    bool dominant_small_river = is_small_river && (carve_small >= carve_wide) && (carve_small >= basin_carve);

    dict["carve_depth"] = total_carve;
    dict["water_elevation"] = water_elevation_i;
    dict["is_water"] = is_water;
    dict["is_river"] = is_wide_river || is_small_river;
    dict["is_wide_river"] = is_wide_river;
    dict["is_small_river"] = dominant_small_river;
    dict["is_lake"] = has_basin;
    dict["is_pond"] = is_pond;
    return dict;
}

void FluvialCarverNative::_bind_methods() {
    ClassDB::bind_method(D_METHOD("initialize", "seed_val", "config"), &FluvialCarverNative::initialize, DEFVAL(1337), DEFVAL(Variant()));
    ClassDB::bind_method(D_METHOD("_init_noises", "seed_val"), &FluvialCarverNative::_init_noises);
    ClassDB::bind_method(D_METHOD("sync_config"), &FluvialCarverNative::sync_config);

    ClassDB::bind_method(D_METHOD("get_config"), &FluvialCarverNative::get_config);
    ClassDB::bind_method(D_METHOD("set_config", "config"), &FluvialCarverNative::set_config);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "config", PROPERTY_HINT_RESOURCE_TYPE, "ContinentGeneratorConfig"), "set_config", "get_config");

    ClassDB::bind_method(D_METHOD("sample_fluvial", "wx", "wz", "base_elevation", "continentalness"), &FluvialCarverNative::sample_fluvial);
    ClassDB::bind_method(D_METHOD("sample_fluvial_v3", "wx", "wz", "base_elevation", "continentalness"), &FluvialCarverNative::sample_fluvial_v3);
}
