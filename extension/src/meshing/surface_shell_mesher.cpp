#include "surface_shell_mesher.h"
#include "mesh_factory.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <vector>

using namespace godot;

void SurfaceShellMesherNative::_bind_methods() {
    ClassDB::bind_method(D_METHOD("build_mesh", "data", "registry"), &SurfaceShellMesherNative::build_mesh);

    ClassDB::bind_method(D_METHOD("get_sea_level"), &SurfaceShellMesherNative::get_sea_level);
    ClassDB::bind_method(D_METHOD("set_sea_level", "sea_level"), &SurfaceShellMesherNative::set_sea_level);
    ADD_PROPERTY(PropertyInfo(Variant::INT, "sea_level"), "set_sea_level", "get_sea_level");

    ClassDB::bind_method(D_METHOD("get_water_mesher"), &SurfaceShellMesherNative::get_water_mesher);
    ClassDB::bind_method(D_METHOD("set_water_mesher", "water_mesher"), &SurfaceShellMesherNative::set_water_mesher);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "water_mesher", PROPERTY_HINT_RESOURCE_TYPE, "RefCounted"), "set_water_mesher", "get_water_mesher");
}

SurfaceShellMesherNative::SurfaceShellMesherNative() {
    // Lazily load water_mesher at runtime to prevent loading during early engine scan
}

SurfaceShellMesherNative::~SurfaceShellMesherNative() {}

Ref<RefCounted> SurfaceShellMesherNative::build_mesh(const Variant &p_data, const Variant &p_registry) {
    if (water_mesher.is_null()) {
        ResourceLoader *rl = ResourceLoader::get_singleton();
        if (rl) {
            Ref<Resource> script = rl->load("res://src/meshing/water_surface_mesher.gd");
            if (script.is_valid()) {
                water_mesher = script->call("new");
            }
        }
    }

    Ref<RefCounted> mesh = MeshFactory::create_mesh_data();

    if (p_data.get_type() != Variant::OBJECT) {
        return mesh;
    }
    Object *data_obj = p_data;
    if (!data_obj) {
        return mesh;
    }

    int n = data_obj->get("chunk_size");
    int apron_w = data_obj->get("apron_size");
    PackedInt32Array heights = data_obj->get("heights");
    PackedByteArray top_mats = data_obj->get("top_material");
    PackedByteArray side_mats = data_obj->get("side_material");
    bool has_cave_mouth = data_obj->get("has_cave_mouth");

    if (heights.is_empty() || top_mats.is_empty() || side_mats.is_empty()) {
        return mesh;
    }

    const int32_t *h_ptr = heights.ptr();
    const uint8_t *top_ptr = top_mats.ptr();
    const uint8_t *side_ptr = side_mats.ptr();

    PackedVector3Array verts;
    PackedVector3Array norms;
    PackedColorArray cols;
    PackedInt32Array inds;

    Object *reg_obj = p_registry.get_type() == Variant::OBJECT ? (Object *)p_registry : nullptr;

    // Fast Color Cache
    Color top_colors[256];
    Color side_colors[256];
    bool cached_top[256] = { false };
    bool cached_side[256] = { false };

    auto get_top_color = [&](uint8_t id) -> Color {
        if (!cached_top[id]) {
            if (reg_obj) {
                top_colors[id] = reg_obj->call("get_top_color", id);
            } else {
                top_colors[id] = Color(1, 1, 1, (float)id / 255.0f);
            }
            cached_top[id] = true;
        }
        return top_colors[id];
    };

    auto get_side_color = [&](uint8_t id) -> Color {
        if (!cached_side[id]) {
            if (reg_obj) {
                side_colors[id] = reg_obj->call("get_side_color", id);
            } else {
                side_colors[id] = Color(1, 1, 1, (float)id / 255.0f);
            }
            cached_side[id] = true;
        }
        return side_colors[id];
    };

    // -------------------------------------------------------------------------
    // 1. Top horizontal faces (2D greedy merging)
    // -------------------------------------------------------------------------
    std::vector<uint8_t> visited(n * n, 0);

    for (int lz = 0; lz < n; ++lz) {
        int row_start = (lz + 1) * apron_w;
        for (int lx = 0; lx < n; ++lx) {
            int idx = lx + lz * n;
            if (visited[idx] == 1) {
                continue;
            }

            int col_idx = (lx + 1) + row_start;
            int32_t h = h_ptr[col_idx];
            uint8_t mat = top_ptr[col_idx];
            if (mat == 0) {
                continue;
            }

            int w = 1;
            while ((lx + w) < n) {
                int next_idx = (lx + w) + lz * n;
                if (visited[next_idx] == 1) {
                    break;
                }
                int next_col = (lx + w + 1) + row_start;
                if (h_ptr[next_col] != h || top_ptr[next_col] != mat) {
                    break;
                }
                w += 1;
            }

            int d = 1;
            bool can_expand = true;
            while ((lz + d) < n && can_expand) {
                int exp_row = (lz + d + 1) * apron_w;
                for (int check_x = lx; check_x < lx + w; ++check_x) {
                    int row_idx = check_x + (lz + d) * n;
                    if (visited[row_idx] == 1) {
                        can_expand = false;
                        break;
                    }
                    int exp_col = (check_x + 1) + exp_row;
                    if (h_ptr[exp_col] != h || top_ptr[exp_col] != mat) {
                        can_expand = false;
                        break;
                    }
                }
                if (can_expand) {
                    d += 1;
                }
            }

            for (int rz = lz; rz < lz + d; ++rz) {
                for (int rx = lx; rx < lx + w; ++rx) {
                    visited[rx + rz * n] = 1;
                }
            }

            Color top_color = get_top_color(mat);
            Vector3 norm(0.0f, 1.0f, 0.0f);

            int base_idx = verts.size();
            float fh = (float)h;
            float flx = (float)lx;
            float flz = (float)lz;
            float fw = (float)w;
            float fd = (float)d;

            verts.append(Vector3(flx, fh, flz));
            verts.append(Vector3(flx, fh, flz + fd));
            verts.append(Vector3(flx + fw, fh, flz + fd));
            verts.append(Vector3(flx + fw, fh, flz));

            norms.append(norm);
            norms.append(norm);
            norms.append(norm);
            norms.append(norm);

            cols.append(top_color);
            cols.append(top_color);
            cols.append(top_color);
            cols.append(top_color);

            inds.append(base_idx);
            inds.append(base_idx + 2);
            inds.append(base_idx + 1);
            inds.append(base_idx);
            inds.append(base_idx + 3);
            inds.append(base_idx + 2);
        }
    }

    // -------------------------------------------------------------------------
    // 2. Side vertical walls (greedy run-length merged cliff faces)
    // -------------------------------------------------------------------------
    Vector3 norm_west(-1.0f, 0.0f, 0.0f);
    Vector3 norm_east(1.0f, 0.0f, 0.0f);

    for (int lx = 0; lx < n; ++lx) {
        float flx = (float)lx;
        int col_base = (lx + 1) + apron_w;

        // West (-X)
        int lz = 0;
        while (lz < n) {
            int col_idx = col_base + lz * apron_w;
            uint8_t side_mat = side_ptr[col_idx];
            if (side_mat == 0) {
                lz += 1;
                continue;
            }
            int32_t h = h_ptr[col_idx];
            int32_t h_w = h_ptr[col_idx - 1];
            if (h_w >= h) {
                lz += 1;
                continue;
            }

            int run_z = 1;
            while ((lz + run_z) < n) {
                int next_idx = col_base + (lz + run_z) * apron_w;
                if (side_ptr[next_idx] != side_mat || h_ptr[next_idx] != h || h_ptr[next_idx - 1] != h_w) {
                    break;
                }
                run_z += 1;
            }

            Color side_col = get_side_color(side_mat);
            float fnh = (float)h_w;
            float fh = (float)h;
            float z_start = (float)lz;
            float z_end = (float)(lz + run_z);
            int base_idx = verts.size();

            verts.append(Vector3(flx, fnh, z_start));
            verts.append(Vector3(flx, fnh, z_end));
            verts.append(Vector3(flx, fh, z_end));
            verts.append(Vector3(flx, fh, z_start));

            for (int k = 0; k < 4; ++k) {
                norms.append(norm_west);
                cols.append(side_col);
            }

            inds.append(base_idx);
            inds.append(base_idx + 2);
            inds.append(base_idx + 1);
            inds.append(base_idx);
            inds.append(base_idx + 3);
            inds.append(base_idx + 2);

            lz += run_z;
        }

        // East (+X)
        lz = 0;
        while (lz < n) {
            int col_idx = col_base + lz * apron_w;
            uint8_t side_mat = side_ptr[col_idx];
            if (side_mat == 0) {
                lz += 1;
                continue;
            }
            int32_t h = h_ptr[col_idx];
            int32_t h_e = h_ptr[col_idx + 1];
            if (h_e >= h) {
                lz += 1;
                continue;
            }

            int run_z = 1;
            while ((lz + run_z) < n) {
                int next_idx = col_base + (lz + run_z) * apron_w;
                if (side_ptr[next_idx] != side_mat || h_ptr[next_idx] != h || h_ptr[next_idx + 1] != h_e) {
                    break;
                }
                run_z += 1;
            }

            Color side_col = get_side_color(side_mat);
            float fnh = (float)h_e;
            float fh = (float)h;
            float z_start = (float)lz;
            float z_end = (float)(lz + run_z);
            int base_idx = verts.size();

            verts.append(Vector3(flx + 1.0f, fnh, z_end));
            verts.append(Vector3(flx + 1.0f, fnh, z_start));
            verts.append(Vector3(flx + 1.0f, fh, z_start));
            verts.append(Vector3(flx + 1.0f, fh, z_end));

            for (int k = 0; k < 4; ++k) {
                norms.append(norm_east);
                cols.append(side_col);
            }

            inds.append(base_idx);
            inds.append(base_idx + 2);
            inds.append(base_idx + 1);
            inds.append(base_idx);
            inds.append(base_idx + 3);
            inds.append(base_idx + 2);

            lz += run_z;
        }
    }

    // South (-Z) and North (+Z)
    Vector3 norm_south(0.0f, 0.0f, -1.0f);
    Vector3 norm_north(0.0f, 0.0f, 1.0f);

    for (int lz = 0; lz < n; ++lz) {
        float flz = (float)lz;
        int row_base = 1 + (lz + 1) * apron_w;

        // South (-Z)
        int lx = 0;
        while (lx < n) {
            int col_idx = row_base + lx;
            uint8_t side_mat = side_ptr[col_idx];
            if (side_mat == 0) {
                lx += 1;
                continue;
            }
            int32_t h = h_ptr[col_idx];
            int32_t h_s = h_ptr[col_idx - apron_w];
            if (h_s >= h) {
                lx += 1;
                continue;
            }

            int run_x = 1;
            while ((lx + run_x) < n) {
                int next_idx = row_base + (lx + run_x);
                if (side_ptr[next_idx] != side_mat || h_ptr[next_idx] != h || h_ptr[next_idx - apron_w] != h_s) {
                    break;
                }
                run_x += 1;
            }

            Color side_col = get_side_color(side_mat);
            float fnh = (float)h_s;
            float fh = (float)h;
            float x_start = (float)lx;
            float x_end = (float)(lx + run_x);
            int base_idx = verts.size();

            verts.append(Vector3(x_end, fnh, flz));
            verts.append(Vector3(x_start, fnh, flz));
            verts.append(Vector3(x_start, fh, flz));
            verts.append(Vector3(x_end, fh, flz));

            for (int k = 0; k < 4; ++k) {
                norms.append(norm_south);
                cols.append(side_col);
            }

            inds.append(base_idx);
            inds.append(base_idx + 2);
            inds.append(base_idx + 1);
            inds.append(base_idx);
            inds.append(base_idx + 3);
            inds.append(base_idx + 2);

            lx += run_x;
        }

        // North (+Z)
        lx = 0;
        while (lx < n) {
            int col_idx = row_base + lx;
            uint8_t side_mat = side_ptr[col_idx];
            if (side_mat == 0) {
                lx += 1;
                continue;
            }
            int32_t h = h_ptr[col_idx];
            int32_t h_n = h_ptr[col_idx + apron_w];
            if (h_n >= h) {
                lx += 1;
                continue;
            }

            int run_x = 1;
            while ((lx + run_x) < n) {
                int next_idx = row_base + (lx + run_x);
                if (side_ptr[next_idx] != side_mat || h_ptr[next_idx] != h || h_ptr[next_idx + apron_w] != h_n) {
                    break;
                }
                run_x += 1;
            }

            Color side_col = get_side_color(side_mat);
            float fnh = (float)h_n;
            float fh = (float)h;
            float x_start = (float)lx;
            float x_end = (float)(lx + run_x);
            int base_idx = verts.size();

            verts.append(Vector3(x_start, fnh, flz + 1.0f));
            verts.append(Vector3(x_end, fnh, flz + 1.0f));
            verts.append(Vector3(x_end, fh, flz + 1.0f));
            verts.append(Vector3(x_start, fh, flz + 1.0f));

            for (int k = 0; k < 4; ++k) {
                norms.append(norm_north);
                cols.append(side_col);
            }

            inds.append(base_idx);
            inds.append(base_idx + 2);
            inds.append(base_idx + 1);
            inds.append(base_idx);
            inds.append(base_idx + 3);
            inds.append(base_idx + 2);

            lx += run_x;
        }
    }

    mesh->set("vertices", verts);
    mesh->set("normals", norms);
    mesh->set("colors", cols);
    mesh->set("indices", inds);
    mesh->set("has_cave_mouth", has_cave_mouth);

    // Water meshing
    if (water_mesher.is_valid()) {
        Variant water_mesh = water_mesher->call("build_water_mesh", p_data, sea_level);
        mesh->set("water_mesh_data", water_mesh);
    }

    return mesh;
}
