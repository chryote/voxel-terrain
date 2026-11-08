#ifndef CHASM_COLUMN_RESULT_NATIVE_H
#define CHASM_COLUMN_RESULT_NATIVE_H

#include <godot_cpp/classes/ref_counted.hpp>

namespace godot {

class ChasmColumnResultNative : public RefCounted {
    GDCLASS(ChasmColumnResultNative, RefCounted);

protected:
    static void _bind_methods();

public:
    bool is_chasm = false;
    int32_t floor_y = 0;
    int32_t ceil_y = 0;
    bool is_pillar = false;
    bool is_wall = false;
    bool is_arena = false;
    bool is_arena_ledge = false;
    bool is_basalt_column = false;
    double raw_rift = 0.0;

    ChasmColumnResultNative() = default;
    ~ChasmColumnResultNative() override = default;

    void reset() {
        is_chasm = false;
        floor_y = 0;
        ceil_y = 0;
        is_pillar = false;
        is_wall = false;
        is_arena = false;
        is_arena_ledge = false;
        is_basalt_column = false;
        raw_rift = 0.0;
    }

    bool get_is_chasm() const { return is_chasm; }
    void set_is_chasm(bool v) { is_chasm = v; }

    int32_t get_floor_y() const { return floor_y; }
    void set_floor_y(int32_t v) { floor_y = v; }

    int32_t get_ceil_y() const { return ceil_y; }
    void set_ceil_y(int32_t v) { ceil_y = v; }

    bool get_is_pillar() const { return is_pillar; }
    void set_is_pillar(bool v) { is_pillar = v; }

    bool get_is_wall() const { return is_wall; }
    void set_is_wall(bool v) { is_wall = v; }

    bool get_is_arena() const { return is_arena; }
    void set_is_arena(bool v) { is_arena = v; }

    bool get_is_arena_ledge() const { return is_arena_ledge; }
    void set_is_arena_ledge(bool v) { is_arena_ledge = v; }

    bool get_is_basalt_column() const { return is_basalt_column; }
    void set_is_basalt_column(bool v) { is_basalt_column = v; }

    double get_raw_rift() const { return raw_rift; }
    void set_raw_rift(double v) { raw_rift = v; }
};

} // namespace godot

#endif // CHASM_COLUMN_RESULT_NATIVE_H

