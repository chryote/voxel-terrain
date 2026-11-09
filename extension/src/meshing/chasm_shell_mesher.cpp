#include "chasm_shell_mesher.h"
#include "mesh_factory.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <vector>

using namespace godot;

void ChasmShellMesherNative::_bind_methods() {
    ClassDB::bind_method(D_METHOD("build_mesh", "data", "registry"), &ChasmShellMesherNative::build_mesh);

    ClassDB::bind_method(D_METHOD("get_cave_water_enabled"), &ChasmShellMesherNative::get_cave_water_enabled);
    ClassDB::bind_method(D_METHOD("set_cave_water_enabled", "cave_water_enabled"), &ChasmShellMesherNative::set_cave_water_enabled);
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "cave_water_enabled"), "set_cave_water_enabled", "get_cave_water_enabled");

    ClassDB::bind_method(D_METHOD("get_surface_mesher"), &ChasmShellMesherNative::get_surface_mesher);
    ClassDB::bind_method(D_METHOD("set_surface_mesher", "surface_mesher"), &ChasmShellMesherNative::set_surface_mesher);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "surface_mesher", PROPERTY_HINT_RESOURCE_TYPE, "SurfaceShellMesherNative"), "set_surface_mesher", "get_surface_mesher");
}

ChasmShellMesherNative::ChasmShellMesherNative() {
    // Lazily instantiate surface_mesher on demand
}

ChasmShellMesherNative::~ChasmShellMesherNative() {}

Ref<RefCounted> ChasmShellMesherNative::build_mesh(const Variant &p_data, const Variant &p_registry) {
    if (surface_mesher.is_null()) {
        surface_mesher.instantiate();
    }
    if (p_data.get_type() != Variant::OBJECT) {
        return MeshFactory::create_mesh_data();
    }
    Object *data_obj = p_data;
    if (!data_obj) {
        return MeshFactory::create_mesh_data();
    }

    // Polymorphic fallback: if passed 2.5D surface shell data, delegate to surface shell mesher
    // SurfaceChunkData has heights but does not have floor_heights
    Variant floor_heights_var = data_obj->get("floor_heights");
    if (floor_heights_var.get_type() != Variant::PACKED_INT32_ARRAY) {
        if (surface_mesher.is_valid()) {
            return surface_mesher->build_mesh(p_data, p_registry);
        }
        return MeshFactory::create_mesh_data();
    }

    Ref<RefCounted> bundle = MeshFactory::create_dual_mesh_bundle();

    // 1. Surface Shell Meshing if present
    Variant surf_data_var = data_obj->get("surface_data");
    if (surf_data_var.get_type() == Variant::OBJECT && (Object *)surf_data_var != nullptr) {
        if (surface_mesher.is_valid()) {
            Ref<RefCounted> s_mesh = surface_mesher->build_mesh(surf_data_var, p_registry);
            if (s_mesh.is_valid()) {
                bundle->set("vertices", s_mesh->get("vertices"));
                bundle->set("normals", s_mesh->get("normals"));
                bundle->set("colors", s_mesh->get("colors"));
                bundle->set("indices", s_mesh->get("indices"));
                bundle->set("water_mesh_data", s_mesh->get("water_mesh_data"));
                bundle->set("has_cave_mouth", s_mesh->get("has_cave_mouth"));
            }
        }
    }

    // If chunk has no subterranean chasm geometry, return surface bundle immediately
    bool has_chasm = data_obj->get("has_chasm");
    if (!has_chasm) {
        return bundle;
    }

    // 2. Direct 2D Subterranean Cave Meshing
    Object *reg_obj = p_registry.get_type() == Variant::OBJECT ? (Object *)p_registry : nullptr;
    _mesh_subterranean_chasm(data_obj, reg_obj, bundle);

    return bundle;
}

void ChasmShellMesherNative::_mesh_subterranean_chasm(Object *chasm_data, Object *registry, Ref<RefCounted> &bundle) {
    int n = chasm_data->get("chunk_size");
    int apron_w = chasm_data->get("apron_size");
    PackedInt32Array fl_heights = chasm_data->get("floor_heights");
    PackedInt32Array cl_heights = chasm_data->get("ceil_heights");
    PackedByteArray flags = chasm_data->get("chasm_flags");
    PackedByteArray mats = chasm_data->get("materials");
    int water_lvl = chasm_data->get("chasm_water_level");
    bool chasm_water_ok = chasm_data->get("cave_water_enabled");

    if (fl_heights.is_empty() || cl_heights.is_empty() || flags.is_empty() || mats.is_empty()) {
        return;
    }

    const int32_t *fl_ptr = fl_heights.ptr();
    const int32_t *cl_ptr = cl_heights.ptr();
    const uint8_t *flag_ptr = flags.ptr();
    const uint8_t *mat_ptr = mats.ptr();

    PackedVector3Array c_verts;
    PackedVector3Array c_norms;
    PackedColorArray c_cols;
    PackedInt32Array c_inds;

    PackedVector3Array sub_water_verts;
    PackedVector3Array sub_water_norms;
    PackedColorArray sub_water_cols;
    PackedInt32Array sub_water_inds;

    // Fast Color Cache
    Color top_colors[256];
    Color side_colors[256];
    bool cached_top[256] = { false };
    bool cached_side[256] = { false };

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

    // -------------------------------------------------------------------------
    // Pass A: Floor (+Y faces, upward facing) with 2D greedy merging
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
            uint8_t flag = flag_ptr[col_idx];
            if ((flag & FLAG_CHASM) == 0 || (flag & FLAG_PILLAR) != 0) {
                continue;
            }

            int32_t fl_y = fl_ptr[col_idx];
            uint8_t mat = mat_ptr[col_idx];

            // Find width w along X
            int w = 1;
            while ((lx + w) < n) {
                int next_idx = (lx + w) + lz * n;
                if (visited[next_idx] == 1) {
                    break;
                }
                int next_col = (lx + w + 1) + row_start;
                uint8_t next_flag = flag_ptr[next_col];
                if ((next_flag & FLAG_CHASM) == 0 || (next_flag & FLAG_PILLAR) != 0) {
                    break;
                }
                if (fl_ptr[next_col] != fl_y || mat_ptr[next_col] != mat) {
                    break;
                }
                w++;
            }

            // Find depth d along Z
            int d = 1;
            bool can_expand = true;
            while ((lz + d) < n && can_expand) {
                int exp_row = (lz + d + 1) * apron_w;
                for (int check_x = lx; check_x < lx + w; ++check_x) {
                    int r_idx = check_x + (lz + d) * n;
                    if (visited[r_idx] == 1) {
                        can_expand = false;
                        break;
                    }
                    int exp_col = (check_x + 1) + exp_row;
                    uint8_t exp_flag = flag_ptr[exp_col];
                    if ((exp_flag & FLAG_CHASM) == 0 || (exp_flag & FLAG_PILLAR) != 0) {
                        can_expand = false;
                        break;
                    }
                    if (fl_ptr[exp_col] != fl_y || mat_ptr[exp_col] != mat) {
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

            // Emit merged floor quad (+Y normal)
            float fy = (float)(fl_y + 1);
            float flx = (float)lx;
            float flz = (float)lz;
            float fw = (float)w;
            float fd = (float)d;

            int base_idx = c_verts.size();
            c_verts.append(Vector3(flx, fy, flz));
            c_verts.append(Vector3(flx, fy, flz + fd));
            c_verts.append(Vector3(flx + fw, fy, flz + fd));
            c_verts.append(Vector3(flx + fw, fy, flz));

            Vector3 norm(0, 1, 0);
            c_norms.append(norm);
            c_norms.append(norm);
            c_norms.append(norm);
            c_norms.append(norm);

            Color col = get_top_color(mat);
            c_cols.append(col);
            c_cols.append(col);
            c_cols.append(col);
            c_cols.append(col);

            c_inds.append(base_idx);
            c_inds.append(base_idx + 2);
            c_inds.append(base_idx + 1);
            c_inds.append(base_idx);
            c_inds.append(base_idx + 3);
            c_inds.append(base_idx + 2);
        }
    }

    // -------------------------------------------------------------------------
    // Pass B: Ceiling (-Y faces, downward facing with inverted normals)
    // -------------------------------------------------------------------------
    std::fill(visited.begin(), visited.end(), 0);

    for (int lz = 0; lz < n; ++lz) {
        int row_start = (lz + 1) * apron_w;
        for (int lx = 0; lx < n; ++lx) {
            int idx = lx + lz * n;
            if (visited[idx] == 1) {
                continue;
            }

            int col_idx = (lx + 1) + row_start;
            uint8_t flag = flag_ptr[col_idx];
            if ((flag & FLAG_CHASM) == 0 || (flag & FLAG_PILLAR) != 0) {
                continue;
            }

            int32_t cl_y = cl_ptr[col_idx];
            uint8_t mat = mat_ptr[col_idx];

            // Find width w along X
            int w = 1;
            while ((lx + w) < n) {
                int next_idx = (lx + w) + lz * n;
                if (visited[next_idx] == 1) {
                    break;
                }
                int next_col = (lx + w + 1) + row_start;
                uint8_t next_flag = flag_ptr[next_col];
                if ((next_flag & FLAG_CHASM) == 0 || (next_flag & FLAG_PILLAR) != 0) {
                    break;
                }
                if (cl_ptr[next_col] != cl_y || mat_ptr[next_col] != mat) {
                    break;
                }
                w++;
            }

            // Find depth d along Z
            int d = 1;
            bool can_expand = true;
            while ((lz + d) < n && can_expand) {
                int exp_row = (lz + d + 1) * apron_w;
                for (int check_x = lx; check_x < lx + w; ++check_x) {
                    int r_idx = check_x + (lz + d) * n;
                    if (visited[r_idx] == 1) {
                        can_expand = false;
                        break;
                    }
                    int exp_col = (check_x + 1) + exp_row;
                    uint8_t exp_flag = flag_ptr[exp_col];
                    if ((exp_flag & FLAG_CHASM) == 0 || (exp_flag & FLAG_PILLAR) != 0) {
                        can_expand = false;
                        break;
                    }
                    if (cl_ptr[exp_col] != cl_y || mat_ptr[exp_col] != mat) {
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

            // Emit merged ceiling quad (-Y normal, inverted winding)
            float cy = (float)cl_y;
            float flx = (float)lx;
            float flz = (float)lz;
            float fw = (float)w;
            float fd = (float)d;

            int base_idx = c_verts.size();
            c_verts.append(Vector3(flx, cy, flz));
            c_verts.append(Vector3(flx + fw, cy, flz));
            c_verts.append(Vector3(flx + fw, cy, flz + fd));
            c_verts.append(Vector3(flx, cy, flz + fd));

            Vector3 norm(0, -1, 0);
            c_norms.append(norm);
            c_norms.append(norm);
            c_norms.append(norm);
            c_norms.append(norm);

            Color col = get_side_color(mat);
            c_cols.append(col);
            c_cols.append(col);
            c_cols.append(col);
            c_cols.append(col);

            c_inds.append(base_idx);
            c_inds.append(base_idx + 2);
            c_inds.append(base_idx + 1);
            c_inds.append(base_idx);
            c_inds.append(base_idx + 3);
            c_inds.append(base_idx + 2);
        }
    }

    // -------------------------------------------------------------------------
    // Pass C: Vertical Curtain Walls along X-boundaries (normal +X and -X)
    // -------------------------------------------------------------------------
    for (int lx = 0; lx <= n; ++lx) {
        int lz = 0;
        while (lz < n) {
            int left_col = lx + (lz + 1) * apron_w;
            int right_col = (lx + 1) + (lz + 1) * apron_w;

            uint8_t left_flag = flag_ptr[left_col];
            uint8_t right_flag = flag_ptr[right_col];

            bool left_void = (left_flag & FLAG_CHASM) != 0 && (left_flag & FLAG_PILLAR) == 0;
            bool right_void = (right_flag & FLAG_CHASM) != 0 && (right_flag & FLAG_PILLAR) == 0;

            // Face facing -X: left is void, right is solid
            if (left_void && !right_void) {
                int32_t y_min = fl_ptr[left_col] + 1;
                int32_t y_max = cl_ptr[left_col];
                uint8_t mat = mat_ptr[right_col];
                if (mat == 0) {
                    mat = ID_CHASM_BASALT;
                }

                int d = 1;
                while ((lz + d) < n) {
                    int nl_col = lx + (lz + d + 1) * apron_w;
                    int nr_col = (lx + 1) + (lz + d + 1) * apron_w;
                    uint8_t nl_flag = flag_ptr[nl_col];
                    uint8_t nr_flag = flag_ptr[nr_col];
                    bool nl_void = (nl_flag & FLAG_CHASM) != 0 && (nl_flag & FLAG_PILLAR) == 0;
                    bool nr_void = (nr_flag & FLAG_CHASM) != 0 && (nr_flag & FLAG_PILLAR) == 0;
                    if (!nl_void || nr_void) {
                        break;
                    }
                    uint8_t nr_mat = mat_ptr[nr_col];
                    if (nr_mat == 0) {
                        nr_mat = ID_CHASM_BASALT;
                    }
                    if ((fl_ptr[nl_col] + 1) != y_min || cl_ptr[nl_col] != y_max || nr_mat != mat) {
                        break;
                    }
                    d++;
                }

                if (y_max > y_min) {
                    _emit_quad_x_neg(c_verts, c_norms, c_cols, c_inds, (float)lx, (float)y_min, (float)y_max, (float)lz, (float)d, get_side_color(mat));
                }
                lz += d;
                continue;
            }

            // Face facing +X: left is solid, right is void
            if (!left_void && right_void) {
                int32_t y_min = fl_ptr[right_col] + 1;
                int32_t y_max = cl_ptr[right_col];
                uint8_t mat = mat_ptr[left_col];
                if (mat == 0) {
                    mat = ID_CHASM_BASALT;
                }

                int d = 1;
                while ((lz + d) < n) {
                    int nl_col = lx + (lz + d + 1) * apron_w;
                    int nr_col = (lx + 1) + (lz + d + 1) * apron_w;
                    uint8_t nl_flag = flag_ptr[nl_col];
                    uint8_t nr_flag = flag_ptr[nr_col];
                    bool nl_void = (nl_flag & FLAG_CHASM) != 0 && (nl_flag & FLAG_PILLAR) == 0;
                    bool nr_void = (nr_flag & FLAG_CHASM) != 0 && (nr_flag & FLAG_PILLAR) == 0;
                    if (nl_void || !nr_void) {
                        break;
                    }
                    uint8_t nl_mat = mat_ptr[nl_col];
                    if (nl_mat == 0) {
                        nl_mat = ID_CHASM_BASALT;
                    }
                    if ((fl_ptr[nr_col] + 1) != y_min || cl_ptr[nr_col] != y_max || nl_mat != mat) {
                        break;
                    }
                    d++;
                }

                if (y_max > y_min) {
                    _emit_quad_x_pos(c_verts, c_norms, c_cols, c_inds, (float)lx, (float)y_min, (float)y_max, (float)lz, (float)d, get_side_color(mat));
                }
                lz += d;
                continue;
            }

            // Floor step face between two void columns
            if (left_void && right_void) {
                int32_t left_fl = fl_ptr[left_col];
                int32_t right_fl = fl_ptr[right_col];
                if (left_fl > right_fl) {
                    _emit_quad_x_pos(c_verts, c_norms, c_cols, c_inds, (float)lx, (float)(right_fl + 1), (float)(left_fl + 1), (float)lz, 1.0f, get_side_color(mat_ptr[left_col]));
                } else if (right_fl > left_fl) {
                    _emit_quad_x_neg(c_verts, c_norms, c_cols, c_inds, (float)lx, (float)(left_fl + 1), (float)(right_fl + 1), (float)lz, 1.0f, get_side_color(mat_ptr[right_col]));
                }

                int32_t left_cl = cl_ptr[left_col];
                int32_t right_cl = cl_ptr[right_col];
                if (left_cl < right_cl) {
                    _emit_quad_x_pos(c_verts, c_norms, c_cols, c_inds, (float)lx, (float)left_cl, (float)right_cl, (float)lz, 1.0f, get_side_color(mat_ptr[left_col]));
                } else if (right_cl < left_cl) {
                    _emit_quad_x_neg(c_verts, c_norms, c_cols, c_inds, (float)lx, (float)right_cl, (float)left_cl, (float)lz, 1.0f, get_side_color(mat_ptr[right_col]));
                }
            }

            lz++;
        }
    }

    // -------------------------------------------------------------------------
    // Pass D: Vertical Curtain Walls along Z-boundaries (normal +Z and -Z)
    // -------------------------------------------------------------------------
    for (int lz = 0; lz <= n; ++lz) {
        int lx = 0;
        while (lx < n) {
            int back_col = (lx + 1) + lz * apron_w;
            int front_col = (lx + 1) + (lz + 1) * apron_w;

            uint8_t back_flag = flag_ptr[back_col];
            uint8_t front_flag = flag_ptr[front_col];

            bool back_void = (back_flag & FLAG_CHASM) != 0 && (back_flag & FLAG_PILLAR) == 0;
            bool front_void = (front_flag & FLAG_CHASM) != 0 && (front_flag & FLAG_PILLAR) == 0;

            // Face facing -Z: back is void, front is solid
            if (back_void && !front_void) {
                int32_t y_min = fl_ptr[back_col] + 1;
                int32_t y_max = cl_ptr[back_col];
                uint8_t mat = mat_ptr[front_col];
                if (mat == 0) {
                    mat = ID_CHASM_BASALT;
                }

                int w = 1;
                while ((lx + w) < n) {
                    int nb_col = (lx + w + 1) + lz * apron_w;
                    int nf_col = (lx + w + 1) + (lz + 1) * apron_w;
                    uint8_t nb_flag = flag_ptr[nb_col];
                    uint8_t nf_flag = flag_ptr[nf_col];
                    bool nb_void = (nb_flag & FLAG_CHASM) != 0 && (nb_flag & FLAG_PILLAR) == 0;
                    bool nf_void = (nf_flag & FLAG_CHASM) != 0 && (nf_flag & FLAG_PILLAR) == 0;
                    if (!nb_void || nf_void) {
                        break;
                    }
                    uint8_t nf_mat = mat_ptr[nf_col];
                    if (nf_mat == 0) {
                        nf_mat = ID_CHASM_BASALT;
                    }
                    if ((fl_ptr[nb_col] + 1) != y_min || cl_ptr[nb_col] != y_max || nf_mat != mat) {
                        break;
                    }
                    w++;
                }

                if (y_max > y_min) {
                    _emit_quad_z_neg(c_verts, c_norms, c_cols, c_inds, (float)lz, (float)y_min, (float)y_max, (float)lx, (float)w, get_side_color(mat));
                }
                lx += w;
                continue;
            }

            // Face facing +Z: back is solid, front is void
            if (!back_void && front_void) {
                int32_t y_min = fl_ptr[front_col] + 1;
                int32_t y_max = cl_ptr[front_col];
                uint8_t mat = mat_ptr[back_col];
                if (mat == 0) {
                    mat = ID_CHASM_BASALT;
                }

                int w = 1;
                while ((lx + w) < n) {
                    int nb_col = (lx + w + 1) + lz * apron_w;
                    int nf_col = (lx + w + 1) + (lz + 1) * apron_w;
                    uint8_t nb_flag = flag_ptr[nb_col];
                    uint8_t nf_flag = flag_ptr[nf_col];
                    bool nb_void = (nb_flag & FLAG_CHASM) != 0 && (nb_flag & FLAG_PILLAR) == 0;
                    bool nf_void = (nf_flag & FLAG_CHASM) != 0 && (nf_flag & FLAG_PILLAR) == 0;
                    if (nb_void || !nf_void) {
                        break;
                    }
                    uint8_t nb_mat = mat_ptr[nb_col];
                    if (nb_mat == 0) {
                        nb_mat = ID_CHASM_BASALT;
                    }
                    if ((fl_ptr[nf_col] + 1) != y_min || cl_ptr[nf_col] != y_max || nb_mat != mat) {
                        break;
                    }
                    w++;
                }

                if (y_max > y_min) {
                    _emit_quad_z_pos(c_verts, c_norms, c_cols, c_inds, (float)lz, (float)y_min, (float)y_max, (float)lx, (float)w, get_side_color(mat));
                }
                lx += w;
                continue;
            }

            // Floor step face between two void columns
            if (back_void && front_void) {
                int32_t back_fl = fl_ptr[back_col];
                int32_t front_fl = fl_ptr[front_col];
                if (back_fl > front_fl) {
                    _emit_quad_z_pos(c_verts, c_norms, c_cols, c_inds, (float)lz, (float)(front_fl + 1), (float)(back_fl + 1), (float)lx, 1.0f, get_side_color(mat_ptr[back_col]));
                } else if (front_fl > back_fl) {
                    _emit_quad_z_neg(c_verts, c_norms, c_cols, c_inds, (float)lz, (float)(back_fl + 1), (float)(front_fl + 1), (float)lx, 1.0f, get_side_color(mat_ptr[front_col]));
                }

                int32_t back_cl = cl_ptr[back_col];
                int32_t front_cl = cl_ptr[front_col];
                if (back_cl < front_cl) {
                    _emit_quad_z_pos(c_verts, c_norms, c_cols, c_inds, (float)lz, (float)back_cl, (float)front_cl, (float)lx, 1.0f, get_side_color(mat_ptr[back_col]));
                } else if (front_cl < back_cl) {
                    _emit_quad_z_neg(c_verts, c_norms, c_cols, c_inds, (float)lz, (float)front_cl, (float)back_cl, (float)lx, 1.0f, get_side_color(mat_ptr[front_col]));
                }
            }

            lx++;
        }
    }

    // -------------------------------------------------------------------------
    // Store subterranean cave mesh into bundle
    // -------------------------------------------------------------------------
    Variant cave_mesh_var = bundle->get("cave_mesh_data");
    Ref<RefCounted> cave_mesh;
    if (cave_mesh_var.get_type() == Variant::OBJECT && (Object *)cave_mesh_var != nullptr) {
        cave_mesh = cave_mesh_var;
    } else {
        cave_mesh = MeshFactory::create_mesh_data();
        bundle->set("cave_mesh_data", cave_mesh);
    }
    cave_mesh->set("vertices", c_verts);
    cave_mesh->set("normals", c_norms);
    cave_mesh->set("colors", c_cols);
    cave_mesh->set("indices", c_inds);

    // -------------------------------------------------------------------------
    // Pass E: Subterranean Water Table (+Y faces at water_lvl + 1)
    // -------------------------------------------------------------------------
    if (!cave_water_enabled || !chasm_water_ok) {
        return;
    }

    std::fill(visited.begin(), visited.end(), 0);

    for (int lz = 0; lz < n; ++lz) {
        int row_start = (lz + 1) * apron_w;
        for (int lx = 0; lx < n; ++lx) {
            int idx = lx + lz * n;
            if (visited[idx] == 1) {
                continue;
            }

            int col_idx = (lx + 1) + row_start;
            uint8_t flag = flag_ptr[col_idx];
            if ((flag & FLAG_CHASM) == 0 || (flag & FLAG_PILLAR) != 0 || (flag & FLAG_ARENA) != 0) {
                continue;
            }

            int32_t fl_y = fl_ptr[col_idx];
            if (fl_y >= water_lvl) {
                continue;
            }

            // Greedily expand water rectangle
            int w = 1;
            while ((lx + w) < n) {
                int next_idx = (lx + w) + lz * n;
                if (visited[next_idx] == 1) {
                    break;
                }
                int next_col = (lx + w + 1) + row_start;
                uint8_t next_flag = flag_ptr[next_col];
                if ((next_flag & FLAG_CHASM) == 0 || (next_flag & FLAG_PILLAR) != 0 || (next_flag & FLAG_ARENA) != 0) {
                    break;
                }
                if (fl_ptr[next_col] >= water_lvl) {
                    break;
                }
                w++;
            }

            int d = 1;
            bool can_expand = true;
            while ((lz + d) < n && can_expand) {
                int exp_row = (lz + d + 1) * apron_w;
                for (int check_x = lx; check_x < lx + w; ++check_x) {
                    int r_idx = check_x + (lz + d) * n;
                    if (visited[r_idx] == 1) {
                        can_expand = false;
                        break;
                    }
                    int exp_col = (check_x + 1) + exp_row;
                    uint8_t exp_flag = flag_ptr[exp_col];
                    if ((exp_flag & FLAG_CHASM) == 0 || (exp_flag & FLAG_PILLAR) != 0 || (exp_flag & FLAG_ARENA) != 0) {
                        can_expand = false;
                        break;
                    }
                    if (fl_ptr[exp_col] >= water_lvl) {
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

            float wy = (float)(water_lvl + 1);
            float flx = (float)lx;
            float flz = (float)lz;
            float fw = (float)w;
            float fd = (float)d;

            int base_idx = sub_water_verts.size();
            sub_water_verts.append(Vector3(flx, wy, flz));
            sub_water_verts.append(Vector3(flx, wy, flz + fd));
            sub_water_verts.append(Vector3(flx + fw, wy, flz + fd));
            sub_water_verts.append(Vector3(flx + fw, wy, flz));

            Vector3 norm(0, 1, 0);
            sub_water_norms.append(norm);
            sub_water_norms.append(norm);
            sub_water_norms.append(norm);
            sub_water_norms.append(norm);

            Color water_col(0.15f, 0.45f, 0.85f, 0.7f);
            sub_water_cols.append(water_col);
            sub_water_cols.append(water_col);
            sub_water_cols.append(water_col);
            sub_water_cols.append(water_col);

            sub_water_inds.append(base_idx);
            sub_water_inds.append(base_idx + 2);
            sub_water_inds.append(base_idx + 1);
            sub_water_inds.append(base_idx);
            sub_water_inds.append(base_idx + 3);
            sub_water_inds.append(base_idx + 2);
        }
    }

    if (!sub_water_verts.is_empty()) {
        Variant c_water_var = cave_mesh->get("water_mesh_data");
        Ref<RefCounted> c_water;
        if (c_water_var.get_type() == Variant::OBJECT && (Object *)c_water_var != nullptr) {
            c_water = c_water_var;
        } else {
            c_water = MeshFactory::create_mesh_data();
            cave_mesh->set("water_mesh_data", c_water);
        }
        PackedVector3Array wv = c_water->get("vertices");
        PackedVector3Array wn = c_water->get("normals");
        PackedColorArray wc = c_water->get("colors");
        PackedInt32Array wi = c_water->get("indices");
        int base_w_idx = wv.size();

        wv.append_array(sub_water_verts);
        wn.append_array(sub_water_norms);
        wc.append_array(sub_water_cols);
        for (int i = 0; i < sub_water_inds.size(); ++i) {
            wi.append(base_w_idx + sub_water_inds[i]);
        }
        c_water->set("vertices", wv);
        c_water->set("normals", wn);
        c_water->set("colors", wc);
        c_water->set("indices", wi);
    }
}

void ChasmShellMesherNative::_emit_quad_x_pos(PackedVector3Array &verts, PackedVector3Array &norms, PackedColorArray &cols, PackedInt32Array &inds,
                                              float x, float y_min, float y_max, float z, float d, const Color &color) {
    int base_idx = verts.size();
    verts.append(Vector3(x, y_min, z + d));
    verts.append(Vector3(x, y_min, z));
    verts.append(Vector3(x, y_max, z));
    verts.append(Vector3(x, y_max, z + d));

    Vector3 norm(1, 0, 0);
    norms.append(norm); norms.append(norm); norms.append(norm); norms.append(norm);
    cols.append(color); cols.append(color); cols.append(color); cols.append(color);

    inds.append(base_idx); inds.append(base_idx + 2); inds.append(base_idx + 1);
    inds.append(base_idx); inds.append(base_idx + 3); inds.append(base_idx + 2);
}

void ChasmShellMesherNative::_emit_quad_x_neg(PackedVector3Array &verts, PackedVector3Array &norms, PackedColorArray &cols, PackedInt32Array &inds,
                                              float x, float y_min, float y_max, float z, float d, const Color &color) {
    int base_idx = verts.size();
    verts.append(Vector3(x, y_min, z));
    verts.append(Vector3(x, y_min, z + d));
    verts.append(Vector3(x, y_max, z + d));
    verts.append(Vector3(x, y_max, z));

    Vector3 norm(-1, 0, 0);
    norms.append(norm); norms.append(norm); norms.append(norm); norms.append(norm);
    cols.append(color); cols.append(color); cols.append(color); cols.append(color);

    inds.append(base_idx); inds.append(base_idx + 2); inds.append(base_idx + 1);
    inds.append(base_idx); inds.append(base_idx + 3); inds.append(base_idx + 2);
}

void ChasmShellMesherNative::_emit_quad_z_pos(PackedVector3Array &verts, PackedVector3Array &norms, PackedColorArray &cols, PackedInt32Array &inds,
                                              float z, float y_min, float y_max, float x, float w, const Color &color) {
    int base_idx = verts.size();
    verts.append(Vector3(x, y_min, z));
    verts.append(Vector3(x + w, y_min, z));
    verts.append(Vector3(x + w, y_max, z));
    verts.append(Vector3(x, y_max, z));

    Vector3 norm(0, 0, 1);
    norms.append(norm); norms.append(norm); norms.append(norm); norms.append(norm);
    cols.append(color); cols.append(color); cols.append(color); cols.append(color);

    inds.append(base_idx); inds.append(base_idx + 2); inds.append(base_idx + 1);
    inds.append(base_idx); inds.append(base_idx + 3); inds.append(base_idx + 2);
}

void ChasmShellMesherNative::_emit_quad_z_neg(PackedVector3Array &verts, PackedVector3Array &norms, PackedColorArray &cols, PackedInt32Array &inds,
                                              float z, float y_min, float y_max, float x, float w, const Color &color) {
    int base_idx = verts.size();
    verts.append(Vector3(x + w, y_min, z));
    verts.append(Vector3(x, y_min, z));
    verts.append(Vector3(x, y_max, z));
    verts.append(Vector3(x + w, y_max, z));

    Vector3 norm(0, 0, -1);
    norms.append(norm); norms.append(norm); norms.append(norm); norms.append(norm);
    cols.append(color); cols.append(color); cols.append(color); cols.append(color);

    inds.append(base_idx); inds.append(base_idx + 2); inds.append(base_idx + 1);
    inds.append(base_idx); inds.append(base_idx + 3); inds.append(base_idx + 2);
}
