#include "generation/caves/chasm_column_result.h"
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void ChasmColumnResultNative::_bind_methods() {
    ClassDB::bind_method(D_METHOD("reset"), &ChasmColumnResultNative::reset);

    ClassDB::bind_method(D_METHOD("get_is_chasm"), &ChasmColumnResultNative::get_is_chasm);
    ClassDB::bind_method(D_METHOD("set_is_chasm", "v"), &ChasmColumnResultNative::set_is_chasm);
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "is_chasm"), "set_is_chasm", "get_is_chasm");

    ClassDB::bind_method(D_METHOD("get_floor_y"), &ChasmColumnResultNative::get_floor_y);
    ClassDB::bind_method(D_METHOD("set_floor_y", "v"), &ChasmColumnResultNative::set_floor_y);
    ADD_PROPERTY(PropertyInfo(Variant::INT, "floor_y"), "set_floor_y", "get_floor_y");

    ClassDB::bind_method(D_METHOD("get_ceil_y"), &ChasmColumnResultNative::get_ceil_y);
    ClassDB::bind_method(D_METHOD("set_ceil_y", "v"), &ChasmColumnResultNative::set_ceil_y);
    ADD_PROPERTY(PropertyInfo(Variant::INT, "ceil_y"), "set_ceil_y", "get_ceil_y");

    ClassDB::bind_method(D_METHOD("get_is_pillar"), &ChasmColumnResultNative::get_is_pillar);
    ClassDB::bind_method(D_METHOD("set_is_pillar", "v"), &ChasmColumnResultNative::set_is_pillar);
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "is_pillar"), "set_is_pillar", "get_is_pillar");

    ClassDB::bind_method(D_METHOD("get_is_wall"), &ChasmColumnResultNative::get_is_wall);
    ClassDB::bind_method(D_METHOD("set_is_wall", "v"), &ChasmColumnResultNative::set_is_wall);
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "is_wall"), "set_is_wall", "get_is_wall");

    ClassDB::bind_method(D_METHOD("get_is_arena"), &ChasmColumnResultNative::get_is_arena);
    ClassDB::bind_method(D_METHOD("set_is_arena", "v"), &ChasmColumnResultNative::set_is_arena);
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "is_arena"), "set_is_arena", "get_is_arena");

    ClassDB::bind_method(D_METHOD("get_is_arena_ledge"), &ChasmColumnResultNative::get_is_arena_ledge);
    ClassDB::bind_method(D_METHOD("set_is_arena_ledge", "v"), &ChasmColumnResultNative::set_is_arena_ledge);
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "is_arena_ledge"), "set_is_arena_ledge", "get_is_arena_ledge");

    ClassDB::bind_method(D_METHOD("get_is_basalt_column"), &ChasmColumnResultNative::get_is_basalt_column);
    ClassDB::bind_method(D_METHOD("set_is_basalt_column", "v"), &ChasmColumnResultNative::set_is_basalt_column);
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "is_basalt_column"), "set_is_basalt_column", "get_is_basalt_column");

    ClassDB::bind_method(D_METHOD("get_raw_rift"), &ChasmColumnResultNative::get_raw_rift);
    ClassDB::bind_method(D_METHOD("set_raw_rift", "v"), &ChasmColumnResultNative::set_raw_rift);
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "raw_rift"), "set_raw_rift", "get_raw_rift");
}

