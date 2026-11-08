#include "map/continent_map_baker.h"
#include "generation/macro_topography.h"
#include "generation/fluvial_carver.h"
#include "generation/caves/underground_chasm_sampler.h"
#include "generation/caves/chasm_column_result.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#include <algorithm>
#include <vector>

using namespace godot;

namespace {

struct PaletteHelper {
    Color color_deep_ocean = Color("#12181f");
    Color color_shallow_ocean = Color("#1d262e");
    Color color_water_body = Color("#3d2c1e");
    Color color_beach_sand = Color("#665b49");
    Color color_alpine_snow = Color("#87827a");
    Color color_mountain_stone = Color("#454442");
    Color color_slope_dirt = Color("#302e2c");
    Color color_plains_grass = Color("#363836");
    Color color_gravel_bed = Color("#33302c");

    Color color_underground_rock = Color("#1c0609");
    Color color_chasm_floor = Color("#380f16");
    Color color_arena_floor = Color("#a82338");
    Color color_arena_ledge = Color("#591320");
    Color color_pillar = Color("#1e060a");
    Color color_basalt_column = Color("#29080e");
    Color color_subterranean_water = Color("#94192d");

    Vector3 light_direction = Vector3(-0.6f, 1.2f, -0.6f).normalized();
    float relief_strength = 0.45f;
    float ambient_base = 0.68f;
    float elevation_boost_factor = 0.12f;

    void load(Ref<RefCounted> palette) {
        if (palette.is_null()) return;
        Variant v;
        v = palette->get("color_deep_ocean"); if (v.get_type() == Variant::COLOR) color_deep_ocean = v;
        v = palette->get("color_shallow_ocean"); if (v.get_type() == Variant::COLOR) color_shallow_ocean = v;
        v = palette->get("color_water_body"); if (v.get_type() == Variant::COLOR) color_water_body = v;
        v = palette->get("color_beach_sand"); if (v.get_type() == Variant::COLOR) color_beach_sand = v;
        v = palette->get("color_alpine_snow"); if (v.get_type() == Variant::COLOR) color_alpine_snow = v;
        v = palette->get("color_mountain_stone"); if (v.get_type() == Variant::COLOR) color_mountain_stone = v;
        v = palette->get("color_slope_dirt"); if (v.get_type() == Variant::COLOR) color_slope_dirt = v;
        v = palette->get("color_plains_grass"); if (v.get_type() == Variant::COLOR) color_plains_grass = v;
        v = palette->get("color_gravel_bed"); if (v.get_type() == Variant::COLOR) color_gravel_bed = v;

        v = palette->get("color_underground_rock"); if (v.get_type() == Variant::COLOR) color_underground_rock = v;
        v = palette->get("color_chasm_floor"); if (v.get_type() == Variant::COLOR) color_chasm_floor = v;
        v = palette->get("color_arena_floor"); if (v.get_type() == Variant::COLOR) color_arena_floor = v;
        v = palette->get("color_arena_ledge"); if (v.get_type() == Variant::COLOR) color_arena_ledge = v;
        v = palette->get("color_pillar"); if (v.get_type() == Variant::COLOR) color_pillar = v;
        v = palette->get("color_basalt_column"); if (v.get_type() == Variant::COLOR) color_basalt_column = v;
        v = palette->get("color_subterranean_water"); if (v.get_type() == Variant::COLOR) color_subterranean_water = v;

        v = palette->get("light_direction"); if (v.get_type() == Variant::VECTOR3) light_direction = ((Vector3)v).normalized();
        v = palette->get("relief_strength"); if (v.get_type() != Variant::NIL) relief_strength = (float)v;
        v = palette->get("ambient_base"); if (v.get_type() != Variant::NIL) ambient_base = (float)v;
        v = palette->get("elevation_boost_factor"); if (v.get_type() != Variant::NIL) elevation_boost_factor = (float)v;
    }

    Color get_water_color(int h, int sea_level) const {
        if (h < sea_level) {
            float depth = std::clamp((float)(sea_level - h) / 20.0f, 0.0f, 1.0f);
            return color_shallow_ocean.lerp(color_deep_ocean, depth);
        }
        return color_water_body;
    }

    Color get_land_color(int h, float slope_grade, int water_h, int sea_level, int sand_offset, int snow_height, int stone_height, bool is_river_or_lake, float moisture = 0.5f) const {
        bool is_coastal_edge = (h <= (sea_level + sand_offset));
        bool is_inland_water_edge = (is_river_or_lake && h <= (water_h + 1));

        if (is_coastal_edge) {
            if (moisture < 0.75f) {
                return color_beach_sand;
            }
        } else if (is_inland_water_edge) {
            if (moisture < 0.40f) {
                return color_beach_sand;
            }
        }

        if (h >= snow_height) {
            return color_alpine_snow;
        }
        if (h >= stone_height) {
            return color_mountain_stone;
        }
        if (slope_grade >= 0.75f) {
            return color_mountain_stone;
        }
        if (slope_grade >= 0.40f) {
            return color_slope_dirt;
        }
        return color_plains_grass;
    }

    Color get_underground_color(bool is_arena, bool is_arena_ledge, bool is_chasm, bool is_pillar, bool is_basalt_column, bool is_water, int _floor_y = 0) const {
        if (is_arena) {
            if (is_basalt_column) return color_basalt_column;
            if (is_arena_ledge) return color_arena_ledge;
            return color_arena_floor;
        }
        if (is_pillar) return color_pillar;
        if (is_water) return color_subterranean_water;
        if (is_chasm) return color_chasm_floor;
        return color_underground_rock;
    }

    float compute_hillshade(float dh_dx, float dh_dz, float steepness_multiplier = 3.0f) const {
        Vector3 normal(-dh_dx * steepness_multiplier, 1.0f, -dh_dz * steepness_multiplier);
        normal.normalize();
        float dot_val = std::clamp((float)normal.dot(light_direction), 0.0f, 1.0f);
        return ambient_base + relief_strength * (dot_val - 0.5f);
    }

    Color apply_relief(const Color& base_color, float shade, int elevation, int sea_level) const {
        float elev_boost = std::clamp((float)(elevation - sea_level) / 180.0f, 0.0f, elevation_boost_factor);
        return Color(
            std::clamp(base_color.r * shade + elev_boost, 0.0f, 1.0f),
            std::clamp(base_color.g * shade + elev_boost, 0.0f, 1.0f),
            std::clamp(base_color.b * shade + elev_boost, 0.0f, 1.0f),
            1.0f
        );
    }

    Color apply_underground_relief(const Color& base_color, float shade, int floor_y, bool is_void = true) const {
        if (!is_void) {
            return base_color;
        }
        float elev_boost = std::clamp((float)floor_y / 60.0f, 0.0f, 0.15f);
        return Color(
            std::clamp(base_color.r * shade + elev_boost, 0.0f, 1.0f),
            std::clamp(base_color.g * shade + elev_boost, 0.0f, 1.0f),
            std::clamp(base_color.b * shade + elev_boost, 0.0f, 1.0f),
            1.0f
        );
    }
};

} // namespace

ContinentMapBakerNative::ContinentMapBakerNative() {
}

ContinentMapBakerNative::~ContinentMapBakerNative() {
}

Ref<Image> ContinentMapBakerNative::bake_surface_map_native(
    Variant p_generator,
    Ref<RefCounted> p_bounds,
    int32_t resolution,
    Ref<RefCounted> p_palette
) {
    if (p_bounds.is_null() || p_generator.get_type() == Variant::NIL || resolution <= 0) {
        return Ref<Image>();
    }

    PaletteHelper palette;
    palette.load(p_palette);

    double min_x = p_bounds->get("min_world_x");
    double max_x = p_bounds->get("max_world_x");
    double min_z = p_bounds->get("min_world_z");
    double max_z = p_bounds->get("max_world_z");

    float step_x = (float)((max_x - min_x) / (double)resolution);
    float step_z = (float)((max_z - min_z) / (double)resolution);

    int total_pixels = resolution * resolution;
    std::vector<int32_t> heights(total_pixels, 0);
    std::vector<int32_t> water_heights(total_pixels, 0);
    std::vector<uint8_t> fluvial_flags(total_pixels, 0);

    int sea_level = 24;
    int seabed_level = 6;
    int sand_offset = 2;
    int stone_height = 90;
    int snow_height = 125;

    Variant cont_gen = p_generator;
    bool is_cont_gen = false;
    if (p_generator.get_type() == Variant::OBJECT) {
        Object* gen_obj = p_generator;
        if (gen_obj != nullptr) {
            Variant v_cg = gen_obj->get("continent_gen");
            if (v_cg.get_type() == Variant::OBJECT && v_cg.operator Object*() != nullptr) {
                cont_gen = v_cg;
                is_cont_gen = true;
            } else if (gen_obj->has_method("sample_world")) {
                is_cont_gen = true;
            }
        }
    }

    if (cont_gen.get_type() == Variant::OBJECT && cont_gen.operator Object*() != nullptr) {
        Variant cfg_v = cont_gen.get("config");
        if (cfg_v.get_type() == Variant::OBJECT && cfg_v.operator Object*() != nullptr) {
            Variant v;
            v = cfg_v.get("sea_level"); if (v.get_type() != Variant::NIL) sea_level = v;
            v = cfg_v.get("seabed_level"); if (v.get_type() != Variant::NIL) seabed_level = v;
            v = cfg_v.get("sand_height_offset"); if (v.get_type() != Variant::NIL) sand_offset = v;
            v = cfg_v.get("stone_height"); if (v.get_type() != Variant::NIL) stone_height = v;
            v = cfg_v.get("snow_height"); if (v.get_type() != Variant::NIL) snow_height = v;
        }
    }

    MacroTopographyNative* native_macro = nullptr;
    FluvialCarverNative* native_fluvial = nullptr;
    Variant climate;

    if (is_cont_gen && cont_gen.get_type() == Variant::OBJECT) {
        Variant m_v = cont_gen.get("macro");
        if (m_v.get_type() == Variant::OBJECT) {
            native_macro = Object::cast_to<MacroTopographyNative>(m_v.operator Object*());
        }
        Variant f_v = cont_gen.get("fluvial");
        if (f_v.get_type() == Variant::OBJECT) {
            native_fluvial = Object::cast_to<FluvialCarverNative>(f_v.operator Object*());
        }
        climate = cont_gen.get("climate");
    }

    // -------------------------------------------------------------------------
    // Pass 1: Grid Sampling
    // -------------------------------------------------------------------------
    for (int py = 0; py < resolution; py++) {
        double wz = min_z + ((double)py + 0.5) * (double)step_z;
        int row_idx = py * resolution;

        for (int px = 0; px < resolution; px++) {
            double wx = min_x + ((double)px + 0.5) * (double)step_x;
            int idx = row_idx + px;

            if (native_macro != nullptr && native_fluvial != nullptr) {
                Vector2 m_v2 = native_macro->sample_macro_v2(wx, wz, p_bounds);
                if (m_v2.y <= 0.01f) {
                    Vector3 isl = native_macro->sample_offshore_island(wx, wz, p_bounds);
                    if (isl.y > 0.0f) {
                        heights[idx] = std::clamp((int)std::round(isl.x), seabed_level, 255);
                        water_heights[idx] = sea_level;
                        int zone = (int)isl.y;
                        fluvial_flags[idx] = (zone == 2) ? 8 : ((zone == 3) ? 16 : 0);
                        continue;
                    }
                }

                Vector3 f_v3 = native_fluvial->sample_fluvial_v3(wx, wz, m_v2.x, m_v2.y);
                int h = std::clamp((int)std::round(m_v2.x - f_v3.x), seabed_level, 255);
                int wh = (int)std::round(f_v3.y);
                heights[idx] = h;
                water_heights[idx] = wh;
                fluvial_flags[idx] = (uint8_t)f_v3.z;
            } else if (is_cont_gen) {
                Variant m_obj = cont_gen.get("macro");
                Vector2 m_v2 = m_obj.call("sample_macro_v2", wx, wz, p_bounds);
                if (m_v2.y <= 0.01f) {
                    Vector3 isl = m_obj.call("sample_offshore_island", wx, wz, p_bounds);
                    if (isl.y > 0.0f) {
                        heights[idx] = std::clamp((int)std::round(isl.x), seabed_level, 255);
                        water_heights[idx] = sea_level;
                        int zone = (int)isl.y;
                        fluvial_flags[idx] = (zone == 2) ? 8 : ((zone == 3) ? 16 : 0);
                        continue;
                    }
                }
                Variant f_obj = cont_gen.get("fluvial");
                Vector3 f_v3 = f_obj.call("sample_fluvial_v3", wx, wz, m_v2.x, m_v2.y);
                int h = std::clamp((int)std::round(m_v2.x - f_v3.x), seabed_level, 255);
                int wh = (int)std::round(f_v3.y);
                heights[idx] = h;
                water_heights[idx] = wh;
                fluvial_flags[idx] = (uint8_t)f_v3.z;
            } else {
                Vector2i col = p_bounds->call("world_to_column", Vector3((float)wx, 0.0f, (float)wz));
                int h = p_generator.call("height_at", col, p_bounds);
                int wh = p_generator.call("water_height_at", col, p_bounds);
                heights[idx] = h;
                water_heights[idx] = wh;
                fluvial_flags[idx] = (bool)p_generator.call("is_water_at", col, p_bounds) ? 4 : 0;
            }
        }
    }

    // -------------------------------------------------------------------------
    // Pass 2: Relief Shading, Material Classification, and Pixel Painting
    // -------------------------------------------------------------------------
    PackedByteArray byte_array;
    byte_array.resize(total_pixels * 4);
    uint8_t* raw_img_data = byte_array.ptrw();

    for (int py = 0; py < resolution; py++) {
        int row_idx = py * resolution;
        double wz = min_z + ((double)py + 0.5) * (double)step_z;

        for (int px = 0; px < resolution; px++) {
            double wx = min_x + ((double)px + 0.5) * (double)step_x;
            int idx = row_idx + px;
            int h = heights[idx];
            int wh = water_heights[idx];
            uint8_t flags = fluvial_flags[idx];
            bool is_river = (flags & 1) != 0;
            bool is_lake = (flags & 2) != 0;
            bool is_water = (h < sea_level) || (h < wh);

            int h_l = heights[row_idx + std::max(0, px - 1)];
            int h_r = heights[row_idx + std::min(resolution - 1, px + 1)];
            int h_d = heights[std::max(0, py - 1) * resolution + px];
            int h_u = heights[std::min(resolution - 1, py + 1) * resolution + px];

            float dh_dx = (float)(h_r - h_l) / (step_x * 2.0f);
            float dh_dz = (float)(h_u - h_d) / (step_z * 2.0f);
            float slope_grade = std::max(std::abs(dh_dx), std::abs(dh_dz));

            Color pixel_color;
            if (is_water) {
                pixel_color = palette.get_water_color(h, sea_level);
            } else {
                Color base_color;
                if ((flags & 8) != 0) {
                    base_color = palette.color_mountain_stone;
                } else if ((flags & 16) != 0) {
                    base_color = (slope_grade >= 0.75f) ? palette.color_mountain_stone : palette.color_plains_grass;
                } else {
                    float moist = 0.5f;
                    bool is_coastal_edge = (h <= (sea_level + sand_offset));
                    bool is_inland_water_edge = ((is_river || is_lake) && (h <= (wh + 1)));

                    if (is_cont_gen && (is_coastal_edge || is_inland_water_edge) && climate.get_type() != Variant::NIL) {
                        moist = climate.call("sample_moisture", wx, wz);
                    }

                    base_color = palette.get_land_color(
                        h,
                        slope_grade,
                        wh,
                        sea_level,
                        sand_offset,
                        snow_height,
                        stone_height,
                        is_river || is_lake,
                        moist
                    );
                }
                float shade = palette.compute_hillshade(dh_dx, dh_dz, 3.0f);
                pixel_color = palette.apply_relief(base_color, shade, h, sea_level);
            }

            int p_byte_idx = idx * 4;
            raw_img_data[p_byte_idx + 0] = (uint8_t)std::clamp(pixel_color.r * 255.0f, 0.0f, 255.0f);
            raw_img_data[p_byte_idx + 1] = (uint8_t)std::clamp(pixel_color.g * 255.0f, 0.0f, 255.0f);
            raw_img_data[p_byte_idx + 2] = (uint8_t)std::clamp(pixel_color.b * 255.0f, 0.0f, 255.0f);
            raw_img_data[p_byte_idx + 3] = 255;
        }
    }

    return Image::create_from_data(resolution, resolution, false, Image::FORMAT_RGBA8, byte_array);
}

Ref<Image> ContinentMapBakerNative::bake_underground_map_native(
    Variant p_generator,
    Ref<RefCounted> p_bounds,
    int32_t resolution,
    Ref<RefCounted> p_palette,
    int32_t min_island_pixels
) {
    if (p_bounds.is_null() || p_generator.get_type() == Variant::NIL || resolution <= 0) {
        return Ref<Image>();
    }

    PaletteHelper palette;
    palette.load(p_palette);

    double min_x = p_bounds->get("min_world_x");
    double max_x = p_bounds->get("max_world_x");
    double min_z = p_bounds->get("min_world_z");
    double max_z = p_bounds->get("max_world_z");

    float step_x = (float)((max_x - min_x) / (double)resolution);
    float step_z = (float)((max_z - min_z) / (double)resolution);

    int total_pixels = resolution * resolution;
    std::vector<int32_t> floor_heights(total_pixels, 0);
    std::vector<uint8_t> flags(total_pixels, 0);

    Variant cont_gen = p_generator;
    bool is_cont_gen = false;
    if (p_generator.get_type() == Variant::OBJECT) {
        Object* gen_obj = p_generator;
        if (gen_obj != nullptr) {
            Variant v_cg = gen_obj->get("continent_gen");
            if (v_cg.get_type() == Variant::OBJECT && v_cg.operator Object*() != nullptr) {
                cont_gen = v_cg;
                is_cont_gen = true;
            } else if (gen_obj->has_method("sample_world")) {
                is_cont_gen = true;
            }
        }
    }

    Variant cave_carver;
    if (p_generator.get_type() == Variant::OBJECT) {
        cave_carver = p_generator.get("cave_carver");
        if (cave_carver.get_type() == Variant::NIL && is_cont_gen && cont_gen.get_type() == Variant::OBJECT) {
            cave_carver = cont_gen.get("cave_carver");
        }
    }

    UndergroundChasmSamplerNative* native_chasm = nullptr;
    MacroTopographyNative* native_macro = nullptr;
    FluvialCarverNative* native_fluvial = nullptr;

    bool cave_water_enabled = true;
    int chasm_water_level = 4;

    if (cave_carver.get_type() == Variant::OBJECT && cave_carver.operator Object*() != nullptr) {
        Variant chasm_s = cave_carver.get("chasm_sampler");
        if (chasm_s.get_type() == Variant::OBJECT) {
            native_chasm = Object::cast_to<UndergroundChasmSamplerNative>(chasm_s.operator Object*());
        }
        Variant cfg_v = cave_carver.get("config");
        if (cfg_v.get_type() == Variant::OBJECT && cfg_v.operator Object*() != nullptr) {
            Variant v;
            v = cfg_v.get("cave_water_enabled"); if (v.get_type() != Variant::NIL) cave_water_enabled = v;
            v = cfg_v.get("chasm_water_level"); if (v.get_type() != Variant::NIL) chasm_water_level = v;
        }

        if (is_cont_gen && cont_gen.get_type() == Variant::OBJECT) {
            Variant mask_v = cont_gen.get("mask");
            if (mask_v.get_type() != Variant::NIL) {
                cave_carver.call("set_continent_mask", mask_v, p_bounds);
            }
        } else if (p_generator.get_type() == Variant::OBJECT) {
            Variant topo = p_generator.get("topography");
            if (topo.get_type() != Variant::NIL && topo.get("continent_mask").get_type() != Variant::NIL) {
                cave_carver.call("set_continent_mask", topo.get("continent_mask"), p_bounds);
            }
        }
    }

    if (is_cont_gen && cont_gen.get_type() == Variant::OBJECT) {
        Variant m_v = cont_gen.get("macro");
        if (m_v.get_type() == Variant::OBJECT) {
            native_macro = Object::cast_to<MacroTopographyNative>(m_v.operator Object*());
        }
        Variant f_v = cont_gen.get("fluvial");
        if (f_v.get_type() == Variant::OBJECT) {
            native_fluvial = Object::cast_to<FluvialCarverNative>(f_v.operator Object*());
        }
    }

    // -------------------------------------------------------------------------
    // Pass 1: Grid Sampling for Subterranean Columns
    // -------------------------------------------------------------------------
    Ref<ChasmColumnResultNative> chasm_col;
    chasm_col.instantiate();
    double default_surf_h = 40.0;

    for (int py = 0; py < resolution; py++) {
        double wz = min_z + ((double)py + 0.5) * (double)step_z;
        int row_idx = py * resolution;

        for (int px = 0; px < resolution; px++) {
            double wx = min_x + ((double)px + 0.5) * (double)step_x;
            int idx = row_idx + px;

            if (native_chasm != nullptr) {
                double surf_h = default_surf_h;
                if (native_macro != nullptr && native_fluvial != nullptr) {
                    Vector2 m_v2 = native_macro->sample_macro_v2(wx, wz, p_bounds);
                    Vector3 f_v3 = native_fluvial->sample_fluvial_v3(wx, wz, m_v2.x, m_v2.y);
                    surf_h = (double)m_v2.x - (double)f_v3.x;
                } else if (p_generator.has_method("height_at")) {
                    Vector2i col = p_bounds->call("world_to_column", Vector3((float)wx, 0.0f, (float)wz));
                    surf_h = (double)p_generator.call("height_at", col, p_bounds);
                }

                native_chasm->sample_column(wx, wz, chasm_col, surf_h);

                if (chasm_col->is_arena || chasm_col->is_chasm || chasm_col->is_pillar) {
                    uint8_t f = 0;
                    if (chasm_col->is_arena) f |= 1;
                    if (chasm_col->is_arena_ledge) f |= 2;
                    if (chasm_col->is_chasm) f |= 4;
                    if (chasm_col->is_pillar) f |= 8;
                    if (chasm_col->is_basalt_column) f |= 16;
                    bool is_water = chasm_col->is_chasm && cave_water_enabled && (!chasm_col->is_arena) && (chasm_col->floor_y <= chasm_water_level);
                    if (is_water) f |= 32;
                    if (!chasm_col->is_pillar) f |= 64; // is_void

                    flags[idx] = f;
                    floor_heights[idx] = chasm_col->floor_y;
                } else {
                    flags[idx] = 0;
                    floor_heights[idx] = 0;
                }
            } else if (cave_carver.get_type() == Variant::OBJECT && cave_carver.operator Object*() != nullptr) {
                double surf_h = default_surf_h;
                if (is_cont_gen && cont_gen.get_type() == Variant::OBJECT) {
                    Variant m_obj = cont_gen.get("macro");
                    Variant f_obj = cont_gen.get("fluvial");
                    Vector2 m_v2 = m_obj.call("sample_macro_v2", wx, wz, p_bounds);
                    Vector3 f_v3 = f_obj.call("sample_fluvial_v3", wx, wz, m_v2.x, m_v2.y);
                    surf_h = (double)m_v2.x - (double)f_v3.x;
                } else if (p_generator.has_method("height_at")) {
                    Vector2i col = p_bounds->call("world_to_column", Vector3((float)wx, 0.0f, (float)wz));
                    surf_h = (double)p_generator.call("height_at", col, p_bounds);
                }

                Variant res_var = cave_carver.call("sample_chasm_column", wx, wz, chasm_col, surf_h);
                if (res_var.get_type() == Variant::OBJECT && res_var.operator Object*() != nullptr) {
                    bool c_arena = res_var.get("is_arena");
                    bool c_arena_ledge = res_var.get("is_arena_ledge");
                    bool c_chasm = res_var.get("is_chasm");
                    bool c_pillar = res_var.get("is_pillar");
                    bool c_basalt = res_var.get("is_basalt_column");
                    int c_floor_y = res_var.get("floor_y");

                    if (c_arena || c_chasm || c_pillar) {
                        uint8_t f = 0;
                        if (c_arena) f |= 1;
                        if (c_arena_ledge) f |= 2;
                        if (c_chasm) f |= 4;
                        if (c_pillar) f |= 8;
                        if (c_basalt) f |= 16;
                        bool is_water = c_chasm && cave_water_enabled && (!c_arena) && (c_floor_y <= chasm_water_level);
                        if (is_water) f |= 32;
                        if (!c_pillar) f |= 64;

                        flags[idx] = f;
                        floor_heights[idx] = c_floor_y;
                    } else {
                        flags[idx] = 0;
                        floor_heights[idx] = 0;
                    }
                }
            } else {
                flags[idx] = 0;
                floor_heights[idx] = 0;
            }
        }
    }

    // -------------------------------------------------------------------------
    // Pass 1.5: Small-Island Pruning
    // -------------------------------------------------------------------------
    if (min_island_pixels > 0) {
        int effective_min = std::max(2, (int)std::round((double)min_island_pixels * ((double)(resolution * resolution) / (512.0 * 512.0))));
        cull_small_underground_islands_raw(flags.data(), floor_heights.data(), resolution, effective_min);
    }

    // -------------------------------------------------------------------------
    // Pass 2: Relief Shading, Palette Mapping, and Pixel Painting
    // -------------------------------------------------------------------------
    PackedByteArray byte_array;
    byte_array.resize(total_pixels * 4);
    uint8_t* raw_img_data = byte_array.ptrw();

    for (int py = 0; py < resolution; py++) {
        int row_idx = py * resolution;
        for (int px = 0; px < resolution; px++) {
            int idx = row_idx + px;
            uint8_t f = flags[idx];
            bool is_arena = (f & 1) != 0;
            bool is_arena_ledge = (f & 2) != 0;
            bool is_chasm = (f & 4) != 0;
            bool is_pillar = (f & 8) != 0;
            bool is_basalt_column = (f & 16) != 0;
            bool is_water = (f & 32) != 0;
            bool is_void = (f & 64) != 0;
            int floor_y = floor_heights[idx];

            Color base_color = palette.get_underground_color(
                is_arena,
                is_arena_ledge,
                is_chasm,
                is_pillar,
                is_basalt_column,
                is_water,
                floor_y
            );

            Color pixel_color = base_color;
            if (is_void) {
                int h_l = floor_heights[row_idx + std::max(0, px - 1)];
                int h_r = floor_heights[row_idx + std::min(resolution - 1, px + 1)];
                int h_d = floor_heights[std::max(0, py - 1) * resolution + px];
                int h_u = floor_heights[std::min(resolution - 1, py + 1) * resolution + px];

                float dh_dx = (float)(h_r - h_l) / (step_x * 2.0f);
                float dh_dz = (float)(h_u - h_d) / (step_z * 2.0f);
                float shade = palette.compute_hillshade(dh_dx, dh_dz, 2.5f);
                pixel_color = palette.apply_underground_relief(base_color, shade, floor_y, true);
            }

            int p_byte_idx = idx * 4;
            raw_img_data[p_byte_idx + 0] = (uint8_t)std::clamp(pixel_color.r * 255.0f, 0.0f, 255.0f);
            raw_img_data[p_byte_idx + 1] = (uint8_t)std::clamp(pixel_color.g * 255.0f, 0.0f, 255.0f);
            raw_img_data[p_byte_idx + 2] = (uint8_t)std::clamp(pixel_color.b * 255.0f, 0.0f, 255.0f);
            raw_img_data[p_byte_idx + 3] = 255;
        }
    }

    return Image::create_from_data(resolution, resolution, false, Image::FORMAT_RGBA8, byte_array);
}

Ref<Image> ContinentMapBakerNative::bake_map_native(
    Variant p_generator,
    Ref<RefCounted> p_bounds,
    int32_t resolution,
    Ref<RefCounted> p_palette,
    int32_t level
) {
    if (level == 1) { // MapLevel.UNDERGROUND
        return bake_underground_map_native(p_generator, p_bounds, resolution, p_palette, 600);
    }
    return bake_surface_map_native(p_generator, p_bounds, resolution, p_palette);
}

int32_t ContinentMapBakerNative::cull_small_underground_islands_raw(
    uint8_t* p_flags,
    int32_t* p_floor_heights,
    int32_t p_resolution,
    int32_t p_min_island_pixels
) {
    if (p_min_island_pixels <= 0 || p_flags == nullptr || p_floor_heights == nullptr || p_resolution <= 0) {
        return 0;
    }

    int32_t total_pixels = p_resolution * p_resolution;
    std::vector<uint8_t> visited(total_pixels, 0);
    std::vector<int32_t> queue(total_pixels, 0);

    int32_t culled_pixels = 0;

    for (int32_t y = 0; y < p_resolution; y++) {
        int32_t row_offset = y * p_resolution;
        for (int32_t x = 0; x < p_resolution; x++) {
            int32_t start_idx = row_offset + x;
            if (p_flags[start_idx] != 0 && visited[start_idx] == 0) {
                int32_t head = 0;
                int32_t tail = 0;
                queue[tail++] = start_idx;
                visited[start_idx] = 1;

                while (head < tail) {
                    int32_t curr_idx = queue[head++];
                    int32_t cx = curr_idx % p_resolution;
                    int32_t cy = curr_idx / p_resolution;

                    // 4-directional flood fill
                    if (cx > 0) {
                        int32_t n_idx = curr_idx - 1;
                        if (p_flags[n_idx] != 0 && visited[n_idx] == 0) {
                            visited[n_idx] = 1;
                            queue[tail++] = n_idx;
                        }
                    }
                    if (cx < p_resolution - 1) {
                        int32_t n_idx = curr_idx + 1;
                        if (p_flags[n_idx] != 0 && visited[n_idx] == 0) {
                            visited[n_idx] = 1;
                            queue[tail++] = n_idx;
                        }
                    }
                    if (cy > 0) {
                        int32_t n_idx = curr_idx - p_resolution;
                        if (p_flags[n_idx] != 0 && visited[n_idx] == 0) {
                            visited[n_idx] = 1;
                            queue[tail++] = n_idx;
                        }
                    }
                    if (cy < p_resolution - 1) {
                        int32_t n_idx = curr_idx + p_resolution;
                        if (p_flags[n_idx] != 0 && visited[n_idx] == 0) {
                            visited[n_idx] = 1;
                            queue[tail++] = n_idx;
                        }
                    }
                }

                if (tail < p_min_island_pixels) {
                    for (int32_t i = 0; i < tail; i++) {
                        int32_t c_idx = queue[i];
                        p_flags[c_idx] = 0;
                        p_floor_heights[c_idx] = 0;
                    }
                    culled_pixels += tail;
                }
            }
        }
    }

    return culled_pixels;
}

void ContinentMapBakerNative::_bind_methods() {
    ClassDB::bind_method(D_METHOD("bake_surface_map_native", "generator", "bounds", "resolution", "palette"), &ContinentMapBakerNative::bake_surface_map_native);
    ClassDB::bind_method(D_METHOD("bake_underground_map_native", "generator", "bounds", "resolution", "palette", "min_island_pixels"), &ContinentMapBakerNative::bake_underground_map_native);
    ClassDB::bind_method(D_METHOD("bake_map_native", "generator", "bounds", "resolution", "palette", "level"), &ContinentMapBakerNative::bake_map_native);
}
