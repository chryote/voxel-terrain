#ifndef VOXEL_CHUNK_DATA_NATIVE_H
#define VOXEL_CHUNK_DATA_NATIVE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/variant.hpp>

namespace godot {

class VoxelChunkDataNative : public RefCounted {
    GDCLASS(VoxelChunkDataNative, RefCounted);

public:
    enum SectionConstants {
        SECTION_HEIGHT = 16,
        SECTION_MIXED = 0,
        SECTION_EMPTY = 1,
        SECTION_SOLID = 2
    };

private:
    int chunk_size = 32;
    int apron_size = 34;
    int max_height = 160;
    int slice_size = 1156;
    int total_voxels = 184960;

    PackedByteArray voxels;
    PackedByteArray water_voxels;
    PackedInt32Array surface_heights;
    bool has_surface_heights = false;
    bool has_cave_mouth = false;
    Ref<RefCounted> surface_data;

    int section_count = 10;
    PackedByteArray section_status;
    bool has_section_status = false;

protected:
    static void _bind_methods();

public:
    VoxelChunkDataNative();
    VoxelChunkDataNative(int p_chunk_size, int p_max_height);
    ~VoxelChunkDataNative();

    void initialize(int p_chunk_size, int p_max_height);

    int _to_column_index(int lx, int lz) const;
    bool has_surface_data() const;
    int get_surface_height(int lx, int lz) const;
    void set_surface_height(int lx, int lz, int h);

    int _to_index(int lx, int ly, int lz) const;
    bool is_in_bounds(int lx, int ly, int lz) const;
    bool is_in_apron(int lx, int ly, int lz) const;

    int get_voxel(int lx, int ly, int lz) const;
    void set_voxel(int lx, int ly, int lz, int mat);

    bool has_water(int lx, int ly, int lz) const;
    void set_water(int lx, int ly, int lz, bool val);

    void fill_material(int mat);
    void fill_water(bool val);

    int get_section_count() const;
    int get_section_status(int s);
    void set_section_status(int s, int status);

    bool is_section_empty(int s);
    bool is_section_solid(int s);

    void compute_section_status();
    void clear();

    // Property getters/setters
    int get_chunk_size() const { return chunk_size; }
    void set_chunk_size(int p_val) { chunk_size = p_val; }

    int get_apron_size() const { return apron_size; }
    void set_apron_size(int p_val) { apron_size = p_val; }

    int get_max_height() const { return max_height; }
    void set_max_height(int p_val) { max_height = p_val; }

    int get_slice_size() const { return slice_size; }
    void set_slice_size(int p_val) { slice_size = p_val; }

    int get_total_voxels() const { return total_voxels; }
    void set_total_voxels(int p_val) { total_voxels = p_val; }

    PackedByteArray get_voxels() const { return voxels; }
    void set_voxels(const PackedByteArray &p_val) { voxels = p_val; }

    PackedByteArray get_water_voxels() const { return water_voxels; }
    void set_water_voxels(const PackedByteArray &p_val) { water_voxels = p_val; }

    PackedInt32Array get_surface_heights() const { return surface_heights; }
    void set_surface_heights(const PackedInt32Array &p_val) { surface_heights = p_val; }

    bool get_has_surface_heights() const { return has_surface_heights; }
    void set_has_surface_heights(bool p_val) { has_surface_heights = p_val; }

    bool get_has_cave_mouth() const { return has_cave_mouth; }
    void set_has_cave_mouth(bool p_val) { has_cave_mouth = p_val; }

    Ref<RefCounted> get_surface_data() const { return surface_data; }
    void set_surface_data(const Ref<RefCounted> &p_val) { surface_data = p_val; }

    PackedByteArray get_section_status_array() const { return section_status; }
    void set_section_status_array(const PackedByteArray &p_val) { section_status = p_val; }

    bool get_has_section_status() const { return has_section_status; }
    void set_has_section_status(bool p_val) { has_section_status = p_val; }
};

} // namespace godot

#endif // VOXEL_CHUNK_DATA_NATIVE_H
