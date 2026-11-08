#ifndef VOXEL_MESHER_NATIVE_H
#define VOXEL_MESHER_NATIVE_H

#include "surface_shell_mesher.h"
#include "chasm_shell_mesher.h"
#include "../core/voxel_chunk_data.h"
#include <godot_cpp/classes/ref_counted.hpp>
#include <vector>

namespace godot {

class VoxelMesherNative : public RefCounted {
    GDCLASS(VoxelMesherNative, RefCounted);

public:
    int sea_level = 24;
    int crust_depth = 3;
    bool cave_water_enabled = true;

    Ref<SurfaceShellMesherNative> shell_mesher;
    Ref<ChasmShellMesherNative> chasm_mesher;

protected:
    static void _bind_methods();

    void _greedy_merge_slice(
        const std::vector<uint8_t> &mask, int dim_u, int dim_v,
        int slice_coord, int u_axis, int v_axis, int normal_axis, bool is_positive,
        Object *registry,
        PackedVector3Array &verts, PackedVector3Array &norms,
        PackedColorArray &cols, PackedInt32Array &inds,
        bool is_top,
        Color top_colors[256], Color side_colors[256],
        bool cached_top[256], bool cached_side[256]
    );

    void _greedy_merge_water_slice(
        const std::vector<uint8_t> &mask, int n, int ly,
        const Color &water_color, const Vector3 &norm,
        PackedVector3Array &w_verts, PackedVector3Array &w_norms,
        PackedColorArray &w_cols, PackedInt32Array &w_inds
    );

    void _build_dual_water_mesh(VoxelChunkDataNative *v_data, Ref<RefCounted> &bundle, bool has_heights);

public:
    VoxelMesherNative();
    ~VoxelMesherNative();

    Ref<RefCounted> build_mesh(const Variant &p_data, const Variant &p_registry);

    int get_sea_level() const { return sea_level; }
    void set_sea_level(int p_val) { sea_level = p_val; }

    int get_crust_depth() const { return crust_depth; }
    void set_crust_depth(int p_val) { crust_depth = p_val; }

    bool get_cave_water_enabled() const { return cave_water_enabled; }
    void set_cave_water_enabled(bool p_val) { cave_water_enabled = p_val; }

    Ref<SurfaceShellMesherNative> get_shell_mesher() const { return shell_mesher; }
    void set_shell_mesher(const Ref<SurfaceShellMesherNative> &p_val) { shell_mesher = p_val; }

    Ref<ChasmShellMesherNative> get_chasm_mesher() const { return chasm_mesher; }
    void set_chasm_mesher(const Ref<ChasmShellMesherNative> &p_val) { chasm_mesher = p_val; }
};

} // namespace godot

#endif // VOXEL_MESHER_NATIVE_H
