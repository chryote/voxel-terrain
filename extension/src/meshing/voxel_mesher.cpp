#include "voxel_mesher.h"
#include "mesh_factory.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <algorithm>

using namespace godot;

void VoxelMesherNative::_bind_methods() {
    ClassDB::bind_method(D_METHOD("build_mesh", "data", "registry"), &VoxelMesherNative::build_mesh);

    ClassDB::bind_method(D_METHOD("get_sea_level"), &VoxelMesherNative::get_sea_level);
    ClassDB::bind_method(D_METHOD("set_sea_level", "sea_level"), &VoxelMesherNative::set_sea_level);
    ADD_PROPERTY(PropertyInfo(Variant::INT, "sea_level"), "set_sea_level", "get_sea_level");

    ClassDB::bind_method(D_METHOD("get_crust_depth"), &VoxelMesherNative::get_crust_depth);
    ClassDB::bind_method(D_METHOD("set_crust_depth", "crust_depth"), &VoxelMesherNative::set_crust_depth);
    ADD_PROPERTY(PropertyInfo(Variant::INT, "crust_depth"), "set_crust_depth", "get_crust_depth");

    ClassDB::bind_method(D_METHOD("get_cave_water_enabled"), &VoxelMesherNative::get_cave_water_enabled);
    ClassDB::bind_method(D_METHOD("set_cave_water_enabled", "cave_water_enabled"), &VoxelMesherNative::set_cave_water_enabled);
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "cave_water_enabled"), "set_cave_water_enabled", "get_cave_water_enabled");

    ClassDB::bind_method(D_METHOD("get_shell_mesher"), &VoxelMesherNative::get_shell_mesher);
    ClassDB::bind_method(D_METHOD("set_shell_mesher", "shell_mesher"), &VoxelMesherNative::set_shell_mesher);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "shell_mesher", PROPERTY_HINT_RESOURCE_TYPE, "SurfaceShellMesherNative"), "set_shell_mesher", "get_shell_mesher");

    ClassDB::bind_method(D_METHOD("get_chasm_mesher"), &VoxelMesherNative::get_chasm_mesher);
    ClassDB::bind_method(D_METHOD("set_chasm_mesher", "chasm_mesher"), &VoxelMesherNative::set_chasm_mesher);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "chasm_mesher", PROPERTY_HINT_RESOURCE_TYPE, "ChasmShellMesherNative"), "set_chasm_mesher", "get_chasm_mesher");
}

VoxelMesherNative::VoxelMesherNative() {
    // Lazily instantiate shell_mesher and chasm_mesher on demand
}

VoxelMesherNative::~VoxelMesherNative() {}

Ref<RefCounted> VoxelMesherNative::build_mesh(const Variant &p_data, const Variant &p_registry) {
    if (shell_mesher.is_null()) {
        shell_mesher.instantiate();
    }
    if (chasm_mesher.is_null()) {
        chasm_mesher.instantiate();
    }
    if (p_data.get_type() != Variant::OBJECT) {
        return MeshFactory::create_mesh_data();
    }
    Object *data_obj = p_data;
    if (!data_obj) {
        return MeshFactory::create_mesh_data();
    }

    // Direct chasm bypass: if passed 2.5D chasm column data, delegate to chasm shell mesher
    Variant floor_heights_var = data_obj->get("floor_heights");
    if (floor_heights_var.get_type() == Variant::PACKED_INT32_ARRAY) {
        if (chasm_mesher.is_valid()) {
            bool c_ok = data_obj->get("cave_water_enabled");
            chasm_mesher->set_cave_water_enabled(cave_water_enabled && c_ok);
            return chasm_mesher->build_mesh(p_data, p_registry);
        }
    }

    // Polymorphic fallback: if passed 2.5D surface shell data, delegate to surface shell mesher
    Variant vox_var = data_obj->get("voxels");
    Variant heights_var = data_obj->get("heights");
    if (heights_var.get_type() == Variant::PACKED_INT32_ARRAY && vox_var.get_type() != Variant::PACKED_BYTE_ARRAY) {
        if (shell_mesher.is_valid()) {
            return shell_mesher->build_mesh(p_data, p_registry);
        }
    }

    VoxelChunkDataNative *v_data = Object::cast_to<VoxelChunkDataNative>(data_obj);
    if (!v_data) {
        UtilityFunctions::push_error("VoxelMesherNative: Unsupported data type");
        return MeshFactory::create_mesh_data();
    }

    Ref<RefCounted> bundle = MeshFactory::create_dual_mesh_bundle();

    PackedVector3Array s_verts;
    PackedVector3Array s_norms;
    PackedColorArray s_cols;
    PackedInt32Array s_inds;

    PackedVector3Array c_verts;
    PackedVector3Array c_norms;
    PackedColorArray c_cols;
    PackedInt32Array c_inds;

    int n = v_data->get_chunk_size();
    int max_h = v_data->get_max_height();

    bool has_heights = v_data->has_surface_data();

    // Ensure section status bitmasks are computed
    if (!v_data->get_has_section_status()) {
        v_data->compute_section_status();
    }

    int sec_count = v_data->get_section_count();
    std::vector<int> mixed_sections;
    std::vector<int> non_empty_sections;
    std::vector<int> active_h_layers;

    for (int sec = 0; sec < sec_count; ++sec) {
        int status = v_data->get_section_status(sec);
        int sec_start_y = sec * VoxelChunkDataNative::SECTION_HEIGHT;
        int sec_end_y = std::min((sec + 1) * VoxelChunkDataNative::SECTION_HEIGHT, max_h);

        if (status == VoxelChunkDataNative::SECTION_EMPTY) {
            continue;
        }

        non_empty_sections.push_back(sec);

        if (status == VoxelChunkDataNative::SECTION_SOLID) {
            bool above_solid = (sec + 1 < sec_count) && (v_data->get_section_status(sec + 1) == VoxelChunkDataNative::SECTION_SOLID);
            bool below_solid = (sec - 1 >= 0) && (v_data->get_section_status(sec - 1) == VoxelChunkDataNative::SECTION_SOLID);
            if (!below_solid) {
                active_h_layers.push_back(sec_start_y);
            }
            if (!above_solid && (sec_end_y - 1) != sec_start_y) {
                active_h_layers.push_back(sec_end_y - 1);
            }
        } else {
            mixed_sections.push_back(sec);
            for (int ly = sec_start_y; ly < sec_end_y; ++ly) {
                active_h_layers.push_back(ly);
            }
        }
    }

    Object *registry = p_registry.get_type() == Variant::OBJECT ? (Object *)p_registry : nullptr;

    // Fast Color Cache
    Color top_colors[256];
    Color side_colors[256];
    bool cached_top[256] = { false };
    bool cached_side[256] = { false };

    // -------------------------------------------------------------------------
    // 1. Top (+Y) and Bottom (-Y) faces: horizontal slices (X, Z)
    // -------------------------------------------------------------------------
    std::vector<uint8_t> s_top_mask(n * n, 0);
    std::vector<uint8_t> s_bot_mask(n * n, 0);
    std::vector<uint8_t> c_top_mask(n * n, 0);
    std::vector<uint8_t> c_bot_mask(n * n, 0);

    for (int ly : active_h_layers) {
        std::fill(s_top_mask.begin(), s_top_mask.end(), 0);
        std::fill(s_bot_mask.begin(), s_bot_mask.end(), 0);
        std::fill(c_top_mask.begin(), c_top_mask.end(), 0);
        std::fill(c_bot_mask.begin(), c_bot_mask.end(), 0);

        bool has_s_top = false;
        bool has_s_bot = false;
        bool has_c_top = false;
        bool has_c_bot = false;

        for (int lz = 0; lz < n; ++lz) {
            for (int lx = 0; lx < n; ++lx) {
                int mat = v_data->get_voxel(lx, ly, lz);
                if (mat == 0) {
                    continue;
                }
                int idx = lx + lz * n;

                bool is_surf = true;
                if (has_heights) {
                    int boundary_y = v_data->get_surface_height(lx, lz) - crust_depth;
                    is_surf = (ly >= boundary_y);
                }

                int above_mat = (ly + 1 < max_h) ? v_data->get_voxel(lx, ly + 1, lz) : 0;
                int below_mat = (ly - 1 >= 0) ? v_data->get_voxel(lx, ly - 1, lz) : 0;

                if (is_surf) {
                    if (above_mat == 0) {
                        s_top_mask[idx] = (uint8_t)mat;
                        has_s_top = true;
                    }
                    if (below_mat == 0) {
                        s_bot_mask[idx] = (uint8_t)mat;
                        has_s_bot = true;
                    }
                } else {
                    if (above_mat == 0) {
                        c_top_mask[idx] = (uint8_t)mat;
                        has_c_top = true;
                    }
                    if (below_mat == 0) {
                        c_bot_mask[idx] = (uint8_t)mat;
                        has_c_bot = true;
                    }
                }
            }
        }

        if (has_s_top) {
            _greedy_merge_slice(s_top_mask, n, n, ly, 0, 2, 1, true, registry, s_verts, s_norms, s_cols, s_inds, true, top_colors, side_colors, cached_top, cached_side);
        }
        if (has_s_bot) {
            _greedy_merge_slice(s_bot_mask, n, n, ly, 0, 2, 1, false, registry, s_verts, s_norms, s_cols, s_inds, false, top_colors, side_colors, cached_top, cached_side);
        }
        if (has_c_top) {
            _greedy_merge_slice(c_top_mask, n, n, ly, 0, 2, 1, true, registry, c_verts, c_norms, c_cols, c_inds, true, top_colors, side_colors, cached_top, cached_side);
        }
        if (has_c_bot) {
            _greedy_merge_slice(c_bot_mask, n, n, ly, 0, 2, 1, false, registry, c_verts, c_norms, c_cols, c_inds, false, top_colors, side_colors, cached_top, cached_side);
        }
    }

    // -------------------------------------------------------------------------
    // 2. West (-X) and East (+X) faces: vertical slices along X (Z, Y)
    // -------------------------------------------------------------------------
    std::vector<uint8_t> s_west_mask(n * max_h, 0);
    std::vector<uint8_t> s_east_mask(n * max_h, 0);
    std::vector<uint8_t> c_west_mask(n * max_h, 0);
    std::vector<uint8_t> c_east_mask(n * max_h, 0);

    for (int lx = 0; lx < n; ++lx) {
        std::fill(s_west_mask.begin(), s_west_mask.end(), 0);
        std::fill(s_east_mask.begin(), s_east_mask.end(), 0);
        std::fill(c_west_mask.begin(), c_west_mask.end(), 0);
        std::fill(c_east_mask.begin(), c_east_mask.end(), 0);

        bool has_s_west = false;
        bool has_s_east = false;
        bool has_c_west = false;
        bool has_c_east = false;

        const std::vector<int> &x_sections = (lx == 0 || lx == n - 1) ? non_empty_sections : mixed_sections;
        for (int sec : x_sections) {
            int sec_start_y = sec * VoxelChunkDataNative::SECTION_HEIGHT;
            int sec_end_y = std::min((sec + 1) * VoxelChunkDataNative::SECTION_HEIGHT, max_h);

            for (int ly = sec_start_y; ly < sec_end_y; ++ly) {
                for (int lz = 0; lz < n; ++lz) {
                    int mat = v_data->get_voxel(lx, ly, lz);
                    if (mat == 0) {
                        continue;
                    }
                    int idx = lz + ly * n;

                    bool w_air = (v_data->get_voxel(lx - 1, ly, lz) == 0);
                    bool e_air = (v_data->get_voxel(lx + 1, ly, lz) == 0);

                    bool is_surf_w = true;
                    bool is_surf_e = true;
                    if (has_heights) {
                        int boundary_y = v_data->get_surface_height(lx, lz) - crust_depth;
                        int w_adj_h = v_data->get_surface_height(lx - 1, lz);
                        int e_adj_h = v_data->get_surface_height(lx + 1, lz);
                        is_surf_w = (ly >= boundary_y) || (ly >= w_adj_h);
                        is_surf_e = (ly >= boundary_y) || (ly >= e_adj_h);
                    }

                    if (w_air) {
                        if (is_surf_w) {
                            s_west_mask[idx] = (uint8_t)mat;
                            has_s_west = true;
                        } else {
                            c_west_mask[idx] = (uint8_t)mat;
                            has_c_west = true;
                        }
                    }
                    if (e_air) {
                        if (is_surf_e) {
                            s_east_mask[idx] = (uint8_t)mat;
                            has_s_east = true;
                        } else {
                            c_east_mask[idx] = (uint8_t)mat;
                            has_c_east = true;
                        }
                    }
                }
            }
        }

        if (has_s_west) {
            _greedy_merge_slice(s_west_mask, n, max_h, lx, 2, 1, 0, false, registry, s_verts, s_norms, s_cols, s_inds, false, top_colors, side_colors, cached_top, cached_side);
        }
        if (has_s_east) {
            _greedy_merge_slice(s_east_mask, n, max_h, lx, 2, 1, 0, true, registry, s_verts, s_norms, s_cols, s_inds, false, top_colors, side_colors, cached_top, cached_side);
        }
        if (has_c_west) {
            _greedy_merge_slice(c_west_mask, n, max_h, lx, 2, 1, 0, false, registry, c_verts, c_norms, c_cols, c_inds, false, top_colors, side_colors, cached_top, cached_side);
        }
        if (has_c_east) {
            _greedy_merge_slice(c_east_mask, n, max_h, lx, 2, 1, 0, true, registry, c_verts, c_norms, c_cols, c_inds, false, top_colors, side_colors, cached_top, cached_side);
        }
    }

    // -------------------------------------------------------------------------
    // 3. South (-Z) and North (+Z) faces: vertical slices along Z (X, Y)
    // -------------------------------------------------------------------------
    std::vector<uint8_t> s_south_mask(n * max_h, 0);
    std::vector<uint8_t> s_north_mask(n * max_h, 0);
    std::vector<uint8_t> c_south_mask(n * max_h, 0);
    std::vector<uint8_t> c_north_mask(n * max_h, 0);

    for (int lz = 0; lz < n; ++lz) {
        std::fill(s_south_mask.begin(), s_south_mask.end(), 0);
        std::fill(s_north_mask.begin(), s_north_mask.end(), 0);
        std::fill(c_south_mask.begin(), c_south_mask.end(), 0);
        std::fill(c_north_mask.begin(), c_north_mask.end(), 0);

        bool has_s_south = false;
        bool has_s_north = false;
        bool has_c_south = false;
        bool has_c_north = false;

        const std::vector<int> &z_sections = (lz == 0 || lz == n - 1) ? non_empty_sections : mixed_sections;
        for (int sec : z_sections) {
            int sec_start_y = sec * VoxelChunkDataNative::SECTION_HEIGHT;
            int sec_end_y = std::min((sec + 1) * VoxelChunkDataNative::SECTION_HEIGHT, max_h);

            for (int ly = sec_start_y; ly < sec_end_y; ++ly) {
                for (int lx = 0; lx < n; ++lx) {
                    int mat = v_data->get_voxel(lx, ly, lz);
                    if (mat == 0) {
                        continue;
                    }
                    int idx = lx + ly * n;

                    bool s_air = (v_data->get_voxel(lx, ly, lz - 1) == 0);
                    bool n_air = (v_data->get_voxel(lx, ly, lz + 1) == 0);

                    bool is_surf_s = true;
                    bool is_surf_n = true;
                    if (has_heights) {
                        int boundary_y = v_data->get_surface_height(lx, lz) - crust_depth;
                        int s_adj_h = v_data->get_surface_height(lx, lz - 1);
                        int n_adj_h = v_data->get_surface_height(lx, lz + 1);
                        is_surf_s = (ly >= boundary_y) || (ly >= s_adj_h);
                        is_surf_n = (ly >= boundary_y) || (ly >= n_adj_h);
                    }

                    if (s_air) {
                        if (is_surf_s) {
                            s_south_mask[idx] = (uint8_t)mat;
                            has_s_south = true;
                        } else {
                            c_south_mask[idx] = (uint8_t)mat;
                            has_c_south = true;
                        }
                    }
                    if (n_air) {
                        if (is_surf_n) {
                            s_north_mask[idx] = (uint8_t)mat;
                            has_s_north = true;
                        } else {
                            c_north_mask[idx] = (uint8_t)mat;
                            has_c_north = true;
                        }
                    }
                }
            }
        }

        if (has_s_south) {
            _greedy_merge_slice(s_south_mask, n, max_h, lz, 0, 1, 2, false, registry, s_verts, s_norms, s_cols, s_inds, false, top_colors, side_colors, cached_top, cached_side);
        }
        if (has_s_north) {
            _greedy_merge_slice(s_north_mask, n, max_h, lz, 0, 1, 2, true, registry, s_verts, s_norms, s_cols, s_inds, false, top_colors, side_colors, cached_top, cached_side);
        }
        if (has_c_south) {
            _greedy_merge_slice(c_south_mask, n, max_h, lz, 0, 1, 2, false, registry, c_verts, c_norms, c_cols, c_inds, false, top_colors, side_colors, cached_top, cached_side);
        }
        if (has_c_north) {
            _greedy_merge_slice(c_north_mask, n, max_h, lz, 0, 1, 2, true, registry, c_verts, c_norms, c_cols, c_inds, false, top_colors, side_colors, cached_top, cached_side);
        }
    }

    // Assign surface geometry to bundle primary buffers
    bundle->set("vertices", s_verts);
    bundle->set("normals", s_norms);
    bundle->set("colors", s_cols);
    bundle->set("indices", s_inds);
    bundle->set("has_cave_mouth", v_data->get_has_cave_mouth());

    // Assign subterranean geometry to bundle cave mesh data
    if (!c_verts.is_empty()) {
        Ref<RefCounted> cave_mesh = MeshFactory::create_mesh_data();
        cave_mesh->set("vertices", c_verts);
        cave_mesh->set("normals", c_norms);
        cave_mesh->set("colors", c_cols);
        cave_mesh->set("indices", c_inds);
        bundle->set("cave_mesh_data", cave_mesh);
    } else {
        bundle->set("cave_mesh_data", Variant());
    }

    // -------------------------------------------------------------------------
    // 4. Subterranean & surface water meshing
    // -------------------------------------------------------------------------
    _build_dual_water_mesh(v_data, bundle, has_heights);

    return bundle;
}

void VoxelMesherNative::_greedy_merge_slice(
    const std::vector<uint8_t> &mask, int dim_u, int dim_v,
    int slice_coord, int u_axis, int v_axis, int normal_axis, bool is_positive,
    Object *registry,
    PackedVector3Array &verts, PackedVector3Array &norms,
    PackedColorArray &cols, PackedInt32Array &inds,
    bool is_top,
    Color top_colors[256], Color side_colors[256],
    bool cached_top[256], bool cached_side[256]
) {
    std::vector<uint8_t> visited(dim_u * dim_v, 0);

    float norm_val = is_positive ? (float)(slice_coord + 1) : (float)slice_coord;
    Vector3 norm(0, 0, 0);
    norm[normal_axis] = is_positive ? 1.0f : -1.0f;

    auto get_top_color = [&](uint8_t id) -> Color {
        if (!cached_top[id]) {
            if (registry) {
                top_colors[id] = registry->call("get_top_color", id);
            } else {
                top_colors[id] = Color(1, 1, 1, (float)id / 255.0f);
            }
            cached_top[id] = true;
        }
        return top_colors[id];
    };

    auto get_side_color = [&](uint8_t id) -> Color {
        if (!cached_side[id]) {
            if (registry) {
                side_colors[id] = registry->call("get_side_color", id);
            } else {
                side_colors[id] = Color(1, 1, 1, (float)id / 255.0f);
            }
            cached_side[id] = true;
        }
        return side_colors[id];
    };

    for (int v = 0; v < dim_v; ++v) {
        for (int u = 0; u < dim_u; ++u) {
            int idx = u + v * dim_u;
            if (visited[idx] == 1 || mask[idx] == 0) {
                continue;
            }

            uint8_t mat = mask[idx];
            int w = 1;
            while ((u + w) < dim_u && visited[(u + w) + v * dim_u] == 0 && mask[(u + w) + v * dim_u] == mat) {
                w++;
            }

            int h = 1;
            bool can_expand = true;
            while ((v + h) < dim_v && can_expand) {
                for (int cu = u; cu < u + w; ++cu) {
                    int row_idx = cu + (v + h) * dim_u;
                    if (visited[row_idx] == 1 || mask[row_idx] != mat) {
                        can_expand = false;
                        break;
                    }
                }
                if (can_expand) {
                    h++;
                }
            }

            for (int rv = v; rv < v + h; ++rv) {
                for (int ru = u; ru < u + w; ++ru) {
                    visited[ru + rv * dim_u] = 1;
                }
            }

            Color color = is_top ? get_top_color(mat) : get_side_color(mat);
            int base_idx = verts.size();
            float fu = (float)u;
            float fv = (float)v;
            float fw = (float)w;
            float fh = (float)h;

            if (normal_axis == 1) {
                if (is_positive) { // +Y (Top)
                    verts.append(Vector3(fu, norm_val, fv));
                    verts.append(Vector3(fu, norm_val, fv + fh));
                    verts.append(Vector3(fu + fw, norm_val, fv + fh));
                    verts.append(Vector3(fu + fw, norm_val, fv));
                } else { // -Y (Bottom)
                    verts.append(Vector3(fu + fw, norm_val, fv));
                    verts.append(Vector3(fu + fw, norm_val, fv + fh));
                    verts.append(Vector3(fu, norm_val, fv + fh));
                    verts.append(Vector3(fu, norm_val, fv));
                }
            } else if (normal_axis == 0) {
                if (is_positive) { // +X (East)
                    verts.append(Vector3(norm_val, fv, fu + fw));
                    verts.append(Vector3(norm_val, fv, fu));
                    verts.append(Vector3(norm_val, fv + fh, fu));
                    verts.append(Vector3(norm_val, fv + fh, fu + fw));
                } else { // -X (West)
                    verts.append(Vector3(norm_val, fv, fu));
                    verts.append(Vector3(norm_val, fv, fu + fw));
                    verts.append(Vector3(norm_val, fv + fh, fu + fw));
                    verts.append(Vector3(norm_val, fv + fh, fu));
                }
            } else { // normal_axis == 2
                if (is_positive) { // +Z (North)
                    verts.append(Vector3(fu, fv, norm_val));
                    verts.append(Vector3(fu + fw, fv, norm_val));
                    verts.append(Vector3(fu + fw, fv + fh, norm_val));
                    verts.append(Vector3(fu, fv + fh, norm_val));
                } else { // -Z (South)
                    verts.append(Vector3(fu + fw, fv, norm_val));
                    verts.append(Vector3(fu, fv, norm_val));
                    verts.append(Vector3(fu, fv + fh, norm_val));
                    verts.append(Vector3(fu + fw, fv + fh, norm_val));
                }
            }

            for (int k = 0; k < 4; ++k) {
                norms.append(norm);
                cols.append(color);
            }

            inds.append(base_idx);
            inds.append(base_idx + 2);
            inds.append(base_idx + 1);
            inds.append(base_idx);
            inds.append(base_idx + 3);
            inds.append(base_idx + 2);
        }
    }
}

void VoxelMesherNative::_greedy_merge_water_slice(
    const std::vector<uint8_t> &mask, int n, int ly,
    const Color &water_color, const Vector3 &norm,
    PackedVector3Array &w_verts, PackedVector3Array &w_norms,
    PackedColorArray &w_cols, PackedInt32Array &w_inds
) {
    std::vector<uint8_t> visited(n * n, 0);
    float y_pos = (float)(ly + 1);

    for (int lz = 0; lz < n; ++lz) {
        for (int lx = 0; lx < n; ++lx) {
            int idx = lx + lz * n;
            if (visited[idx] == 1 || mask[idx] == 0) {
                continue;
            }

            int w = 1;
            while ((lx + w) < n && visited[(lx + w) + lz * n] == 0 && mask[(lx + w) + lz * n] == 1) {
                w++;
            }

            int d = 1;
            bool can_expand = true;
            while ((lz + d) < n && can_expand) {
                for (int cx = lx; cx < lx + w; ++cx) {
                    if (visited[cx + (lz + d) * n] == 1 || mask[cx + (lz + d) * n] == 0) {
                        can_expand = false;
                        break;
                    }
                }
                if (can_expand) {
                    d++;
                }
            }

            for (int rz = lz; rz < lz + d; ++rz) {
                for (int rx = lx; rx < lx + w; ++rx) {
                    visited[rx + rz * n] = 1;
                }
            }

            int base_idx = w_verts.size();
            float flx = (float)lx;
            float flz = (float)lz;
            float fw = (float)w;
            float fd = (float)d;

            w_verts.append(Vector3(flx, y_pos, flz));
            w_verts.append(Vector3(flx, y_pos, flz + fd));
            w_verts.append(Vector3(flx + fw, y_pos, flz + fd));
            w_verts.append(Vector3(flx + fw, y_pos, flz));

            for (int k = 0; k < 4; ++k) {
                w_norms.append(norm);
                w_cols.append(water_color);
            }

            w_inds.append(base_idx);
            w_inds.append(base_idx + 2);
            w_inds.append(base_idx + 1);
            w_inds.append(base_idx);
            w_inds.append(base_idx + 3);
            w_inds.append(base_idx + 2);
        }
    }
}

void VoxelMesherNative::_build_dual_water_mesh(VoxelChunkDataNative *v_data, Ref<RefCounted> &bundle, bool has_heights) {
    int n = v_data->get_chunk_size();
    int max_h = v_data->get_max_height();

    PackedVector3Array s_w_verts;
    PackedVector3Array s_w_norms;
    PackedColorArray s_w_cols;
    PackedInt32Array s_w_inds;

    PackedVector3Array c_w_verts;
    PackedVector3Array c_w_norms;
    PackedColorArray c_w_cols;
    PackedInt32Array c_w_inds;

    Color water_color(0.16f, 0.19f, 0.20f, 0.88f);
    Vector3 norm(0.0f, 1.0f, 0.0f);

    std::vector<uint8_t> s_mask(n * n, 0);
    std::vector<uint8_t> c_mask(n * n, 0);

    for (int ly = 0; ly < max_h; ++ly) {
        std::fill(s_mask.begin(), s_mask.end(), 0);
        std::fill(c_mask.begin(), c_mask.end(), 0);
        bool has_s_water = false;
        bool has_c_water = false;

        for (int lz = 0; lz < n; ++lz) {
            for (int lx = 0; lx < n; ++lx) {
                if (v_data->has_water(lx, ly, lz)) {
                    bool above_has_water = (ly + 1 < max_h) && v_data->has_water(lx, ly + 1, lz);
                    if (!above_has_water) {
                        int idx = lx + lz * n;
                        bool is_surf = true;
                        if (has_heights) {
                            int boundary_y = v_data->get_surface_height(lx, lz) - crust_depth;
                            is_surf = (ly >= boundary_y);
                        }

                        if (is_surf) {
                            s_mask[idx] = 1;
                            has_s_water = true;
                        } else if (cave_water_enabled) {
                            c_mask[idx] = 1;
                            has_c_water = true;
                        }
                    }
                }
            }
        }

        if (has_s_water) {
            _greedy_merge_water_slice(s_mask, n, ly, water_color, norm, s_w_verts, s_w_norms, s_w_cols, s_w_inds);
        }
        if (has_c_water) {
            _greedy_merge_water_slice(c_mask, n, ly, water_color, norm, c_w_verts, c_w_norms, c_w_cols, c_w_inds);
        }
    }

    if (!s_w_verts.is_empty()) {
        Ref<RefCounted> s_water = MeshFactory::create_mesh_data();
        s_water->set("vertices", s_w_verts);
        s_water->set("normals", s_w_norms);
        s_water->set("colors", s_w_cols);
        s_water->set("indices", s_w_inds);
        bundle->set("water_mesh_data", s_water);
    } else {
        bundle->set("water_mesh_data", Variant());
    }

    if (cave_water_enabled && !c_w_verts.is_empty()) {
        Ref<RefCounted> c_water = MeshFactory::create_mesh_data();
        c_water->set("vertices", c_w_verts);
        c_water->set("normals", c_w_norms);
        c_water->set("colors", c_w_cols);
        c_water->set("indices", c_w_inds);

        Variant cave_var = bundle->get("cave_mesh_data");
        Ref<RefCounted> cave_mesh;
        if (cave_var.get_type() == Variant::OBJECT && (Object *)cave_var != nullptr) {
            cave_mesh = cave_var;
        } else {
            cave_mesh = MeshFactory::create_mesh_data();
            bundle->set("cave_mesh_data", cave_mesh);
        }
        cave_mesh->set("water_mesh_data", c_water);
    } else {
        Variant cave_var = bundle->get("cave_mesh_data");
        if (cave_var.get_type() == Variant::OBJECT && (Object *)cave_var != nullptr) {
            Object *cave_obj = cave_var;
            cave_obj->set("water_mesh_data", Variant());
        }
    }
}
