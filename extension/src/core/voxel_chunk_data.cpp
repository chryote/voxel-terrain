#include "voxel_chunk_data.h"
#include <godot_cpp/core/class_db.hpp>
#include <algorithm>

using namespace godot;

void VoxelChunkDataNative::_bind_methods() {
    BIND_CONSTANT(SECTION_HEIGHT);
    BIND_CONSTANT(SECTION_MIXED);
    BIND_CONSTANT(SECTION_EMPTY);
    BIND_CONSTANT(SECTION_SOLID);

    ClassDB::bind_method(D_METHOD("initialize", "chunk_size", "max_height"), &VoxelChunkDataNative::initialize, DEFVAL(32), DEFVAL(160));

    ClassDB::bind_method(D_METHOD("has_surface_data"), &VoxelChunkDataNative::has_surface_data);
    ClassDB::bind_method(D_METHOD("get_surface_height", "lx", "lz"), &VoxelChunkDataNative::get_surface_height);
    ClassDB::bind_method(D_METHOD("set_surface_height", "lx", "lz", "h"), &VoxelChunkDataNative::set_surface_height);

    ClassDB::bind_method(D_METHOD("is_in_bounds", "lx", "ly", "lz"), &VoxelChunkDataNative::is_in_bounds);
    ClassDB::bind_method(D_METHOD("is_in_apron", "lx", "ly", "lz"), &VoxelChunkDataNative::is_in_apron);

    ClassDB::bind_method(D_METHOD("get_voxel", "lx", "ly", "lz"), &VoxelChunkDataNative::get_voxel);
    ClassDB::bind_method(D_METHOD("set_voxel", "lx", "ly", "lz", "mat"), &VoxelChunkDataNative::set_voxel);

    ClassDB::bind_method(D_METHOD("has_water", "lx", "ly", "lz"), &VoxelChunkDataNative::has_water);
    ClassDB::bind_method(D_METHOD("set_water", "lx", "ly", "lz", "val"), &VoxelChunkDataNative::set_water);

    ClassDB::bind_method(D_METHOD("fill_material", "mat"), &VoxelChunkDataNative::fill_material);
    ClassDB::bind_method(D_METHOD("fill_water", "val"), &VoxelChunkDataNative::fill_water);

    ClassDB::bind_method(D_METHOD("get_section_count"), &VoxelChunkDataNative::get_section_count);
    ClassDB::bind_method(D_METHOD("get_section_status", "s"), &VoxelChunkDataNative::get_section_status);
    ClassDB::bind_method(D_METHOD("set_section_status", "s", "status"), &VoxelChunkDataNative::set_section_status);

    ClassDB::bind_method(D_METHOD("is_section_empty", "s"), &VoxelChunkDataNative::is_section_empty);
    ClassDB::bind_method(D_METHOD("is_section_solid", "s"), &VoxelChunkDataNative::is_section_solid);

    ClassDB::bind_method(D_METHOD("compute_section_status"), &VoxelChunkDataNative::compute_section_status);
    ClassDB::bind_method(D_METHOD("clear"), &VoxelChunkDataNative::clear);

    // Properties
    ClassDB::bind_method(D_METHOD("get_chunk_size"), &VoxelChunkDataNative::get_chunk_size);
    ClassDB::bind_method(D_METHOD("set_chunk_size", "chunk_size"), &VoxelChunkDataNative::set_chunk_size);
    ADD_PROPERTY(PropertyInfo(Variant::INT, "chunk_size"), "set_chunk_size", "get_chunk_size");

    ClassDB::bind_method(D_METHOD("get_apron_size"), &VoxelChunkDataNative::get_apron_size);
    ClassDB::bind_method(D_METHOD("set_apron_size", "apron_size"), &VoxelChunkDataNative::set_apron_size);
    ADD_PROPERTY(PropertyInfo(Variant::INT, "apron_size"), "set_apron_size", "get_apron_size");

    ClassDB::bind_method(D_METHOD("get_max_height"), &VoxelChunkDataNative::get_max_height);
    ClassDB::bind_method(D_METHOD("set_max_height", "max_height"), &VoxelChunkDataNative::set_max_height);
    ADD_PROPERTY(PropertyInfo(Variant::INT, "max_height"), "set_max_height", "get_max_height");

    ClassDB::bind_method(D_METHOD("get_slice_size"), &VoxelChunkDataNative::get_slice_size);
    ClassDB::bind_method(D_METHOD("set_slice_size", "slice_size"), &VoxelChunkDataNative::set_slice_size);
    ADD_PROPERTY(PropertyInfo(Variant::INT, "slice_size"), "set_slice_size", "get_slice_size");

    ClassDB::bind_method(D_METHOD("get_total_voxels"), &VoxelChunkDataNative::get_total_voxels);
    ClassDB::bind_method(D_METHOD("set_total_voxels", "total_voxels"), &VoxelChunkDataNative::set_total_voxels);
    ADD_PROPERTY(PropertyInfo(Variant::INT, "total_voxels"), "set_total_voxels", "get_total_voxels");

    ClassDB::bind_method(D_METHOD("get_voxels"), &VoxelChunkDataNative::get_voxels);
    ClassDB::bind_method(D_METHOD("set_voxels", "voxels"), &VoxelChunkDataNative::set_voxels);
    ADD_PROPERTY(PropertyInfo(Variant::PACKED_BYTE_ARRAY, "voxels"), "set_voxels", "get_voxels");

    ClassDB::bind_method(D_METHOD("get_water_voxels"), &VoxelChunkDataNative::get_water_voxels);
    ClassDB::bind_method(D_METHOD("set_water_voxels", "water_voxels"), &VoxelChunkDataNative::set_water_voxels);
    ADD_PROPERTY(PropertyInfo(Variant::PACKED_BYTE_ARRAY, "water_voxels"), "set_water_voxels", "get_water_voxels");

    ClassDB::bind_method(D_METHOD("get_surface_heights"), &VoxelChunkDataNative::get_surface_heights);
    ClassDB::bind_method(D_METHOD("set_surface_heights", "surface_heights"), &VoxelChunkDataNative::set_surface_heights);
    ADD_PROPERTY(PropertyInfo(Variant::PACKED_INT32_ARRAY, "surface_heights"), "set_surface_heights", "get_surface_heights");

    ClassDB::bind_method(D_METHOD("get_has_surface_heights"), &VoxelChunkDataNative::get_has_surface_heights);
    ClassDB::bind_method(D_METHOD("set_has_surface_heights", "val"), &VoxelChunkDataNative::set_has_surface_heights);
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "has_surface_heights"), "set_has_surface_heights", "get_has_surface_heights");

    ClassDB::bind_method(D_METHOD("get_has_cave_mouth"), &VoxelChunkDataNative::get_has_cave_mouth);
    ClassDB::bind_method(D_METHOD("set_has_cave_mouth", "val"), &VoxelChunkDataNative::set_has_cave_mouth);
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "has_cave_mouth"), "set_has_cave_mouth", "get_has_cave_mouth");

    ClassDB::bind_method(D_METHOD("get_surface_data"), &VoxelChunkDataNative::get_surface_data);
    ClassDB::bind_method(D_METHOD("set_surface_data", "val"), &VoxelChunkDataNative::set_surface_data);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "surface_data", PROPERTY_HINT_RESOURCE_TYPE, "RefCounted"), "set_surface_data", "get_surface_data");

    ClassDB::bind_method(D_METHOD("get_section_status_array"), &VoxelChunkDataNative::get_section_status_array);
    ClassDB::bind_method(D_METHOD("set_section_status_array", "status_array"), &VoxelChunkDataNative::set_section_status_array);
    ADD_PROPERTY(PropertyInfo(Variant::PACKED_BYTE_ARRAY, "section_status"), "set_section_status_array", "get_section_status_array");

    ClassDB::bind_method(D_METHOD("get_has_section_status"), &VoxelChunkDataNative::get_has_section_status);
    ClassDB::bind_method(D_METHOD("set_has_section_status", "val"), &VoxelChunkDataNative::set_has_section_status);
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "has_section_status"), "set_has_section_status", "get_has_section_status");
}

VoxelChunkDataNative::VoxelChunkDataNative() {
    initialize(32, 160);
}

VoxelChunkDataNative::VoxelChunkDataNative(int p_chunk_size, int p_max_height) {
    initialize(p_chunk_size, p_max_height);
}

VoxelChunkDataNative::~VoxelChunkDataNative() {}

void VoxelChunkDataNative::initialize(int p_chunk_size, int p_max_height) {
    chunk_size = p_chunk_size;
    apron_size = chunk_size + 2;
    max_height = p_max_height;
    slice_size = apron_size * apron_size;
    total_voxels = slice_size * max_height;

    voxels.resize(total_voxels);
    voxels.fill(0);
    water_voxels.resize(total_voxels);
    water_voxels.fill(0);

    section_count = (max_height + SECTION_HEIGHT - 1) / SECTION_HEIGHT;
    section_status.resize(section_count);
    section_status.fill(SECTION_EMPTY);
    has_section_status = true;
    has_surface_heights = false;
    has_cave_mouth = false;
    surface_heights.clear();
    surface_data.unref();
}

int VoxelChunkDataNative::_to_column_index(int lx, int lz) const {
    return (lx + 1) + (lz + 1) * apron_size;
}

bool VoxelChunkDataNative::has_surface_data() const {
    return has_surface_heights && !surface_heights.is_empty();
}

int VoxelChunkDataNative::get_surface_height(int lx, int lz) const {
    if (!has_surface_data()) {
        return max_height;
    }
    if (lx < -1 || lx > chunk_size || lz < -1 || lz > chunk_size) {
        return max_height;
    }
    return surface_heights[_to_column_index(lx, lz)];
}

void VoxelChunkDataNative::set_surface_height(int lx, int lz, int h) {
    if (surface_heights.is_empty()) {
        surface_heights.resize(slice_size);
        surface_heights.fill(max_height);
    }
    has_surface_heights = true;
    if (lx >= -1 && lx <= chunk_size && lz >= -1 && lz <= chunk_size) {
        surface_heights[_to_column_index(lx, lz)] = h;
    }
}

int VoxelChunkDataNative::_to_index(int lx, int ly, int lz) const {
    return (lx + 1) + (lz + 1) * apron_size + ly * slice_size;
}

bool VoxelChunkDataNative::is_in_bounds(int lx, int ly, int lz) const {
    return lx >= 0 && lx < chunk_size && ly >= 0 && ly < max_height && lz >= 0 && lz < chunk_size;
}

bool VoxelChunkDataNative::is_in_apron(int lx, int ly, int lz) const {
    return lx >= -1 && lx <= chunk_size && ly >= 0 && ly < max_height && lz >= -1 && lz <= chunk_size;
}

int VoxelChunkDataNative::get_voxel(int lx, int ly, int lz) const {
    if (!is_in_apron(lx, ly, lz)) {
        return 0;
    }
    return voxels[_to_index(lx, ly, lz)];
}

void VoxelChunkDataNative::set_voxel(int lx, int ly, int lz, int mat) {
    if (is_in_apron(lx, ly, lz)) {
        voxels[_to_index(lx, ly, lz)] = mat;
        has_section_status = false;
    }
}

bool VoxelChunkDataNative::has_water(int lx, int ly, int lz) const {
    if (!is_in_apron(lx, ly, lz)) {
        return false;
    }
    return water_voxels[_to_index(lx, ly, lz)] == 1;
}

void VoxelChunkDataNative::set_water(int lx, int ly, int lz, bool val) {
    if (is_in_apron(lx, ly, lz)) {
        water_voxels[_to_index(lx, ly, lz)] = val ? 1 : 0;
    }
}

void VoxelChunkDataNative::fill_material(int mat) {
    voxels.fill(mat);
    section_status.fill(mat == 0 ? SECTION_EMPTY : SECTION_SOLID);
    has_section_status = true;
}

void VoxelChunkDataNative::fill_water(bool val) {
    water_voxels.fill(val ? 1 : 0);
}

int VoxelChunkDataNative::get_section_count() const {
    return section_count;
}

int VoxelChunkDataNative::get_section_status(int s) {
    if (!has_section_status) {
        compute_section_status();
    }
    if (s >= 0 && s < section_count) {
        return section_status[s];
    }
    return SECTION_EMPTY;
}

void VoxelChunkDataNative::set_section_status(int s, int status) {
    if (s >= 0 && s < section_count) {
        section_status[s] = status;
    }
}

bool VoxelChunkDataNative::is_section_empty(int s) {
    return get_section_status(s) == SECTION_EMPTY;
}

bool VoxelChunkDataNative::is_section_solid(int s) {
    return get_section_status(s) == SECTION_SOLID;
}

void VoxelChunkDataNative::compute_section_status() {
    if (section_count <= 0) {
        section_count = (max_height + SECTION_HEIGHT - 1) / SECTION_HEIGHT;
    }
    if (section_status.size() != section_count) {
        section_status.resize(section_count);
    }

    const uint8_t *vox_ptr = voxels.ptr();
    uint8_t *status_ptr = section_status.ptrw();

    for (int s = 0; s < section_count; ++s) {
        int start_ly = s * SECTION_HEIGHT;
        int end_ly = std::min((s + 1) * SECTION_HEIGHT, max_height);
        int start_idx = start_ly * slice_size;
        int end_idx = end_ly * slice_size;
        int len = end_idx - start_idx;

        if (len <= 0) {
            status_ptr[s] = SECTION_EMPTY;
            continue;
        }

        const uint8_t *sec_ptr = vox_ptr + start_idx;

        int len64 = len / 8;
        const uint64_t *ptr64 = reinterpret_cast<const uint64_t *>(sec_ptr);

        bool has_zero = false;
        bool has_nonzero = false;

        for (int w = 0; w < len64; ++w) {
            uint64_t val = ptr64[w];
            if (val == 0) {
                has_zero = true;
            } else {
                has_nonzero = true;
                uint64_t has_zero_byte = (val - 0x0101010101010101ULL) & ~val & 0x8080808080808080ULL;
                if (has_zero_byte) {
                    has_zero = true;
                }
            }

            if (has_zero && has_nonzero) {
                break;
            }
        }

        if (!(has_zero && has_nonzero)) {
            for (int i = len64 * 8; i < len; ++i) {
                if (sec_ptr[i] == 0) {
                    has_zero = true;
                } else {
                    has_nonzero = true;
                }
                if (has_zero && has_nonzero) {
                    break;
                }
            }
        }

        if (!has_nonzero) {
            status_ptr[s] = SECTION_EMPTY;
        } else if (!has_zero) {
            status_ptr[s] = SECTION_SOLID;
        } else {
            status_ptr[s] = SECTION_MIXED;
        }
    }

    has_section_status = true;
}

void VoxelChunkDataNative::clear() {
    voxels.fill(0);
    water_voxels.fill(0);
    has_surface_heights = false;
    has_cave_mouth = false;
    surface_heights.clear();
    surface_data.unref();
    section_status.fill(SECTION_EMPTY);
    has_section_status = true;
}
