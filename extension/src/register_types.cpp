#include "register_types.h"
#include "core/terrain_native_core.h"
#include "core/voxel_chunk_data.h"
#include "streaming/off_thread_collision_baker.h"
#include "meshing/surface_shell_mesher.h"
#include "meshing/chasm_shell_mesher.h"
#include "meshing/voxel_mesher.h"
#include "generation/caves/chasm_column_result.h"
#include "generation/caves/underground_chasm_sampler.h"
#include "generation/caves/subterranean_tunnel_sampler.h"
#include "generation/macro_topography.h"
#include "generation/fluvial_carver.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

void initialize_terrain_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }

    GDREGISTER_CLASS(TerrainNativeCore);
    GDREGISTER_CLASS(OffThreadCollisionBakerNative);
    GDREGISTER_CLASS(VoxelChunkDataNative);
    GDREGISTER_CLASS(SurfaceShellMesherNative);
    GDREGISTER_CLASS(ChasmShellMesherNative);
    GDREGISTER_CLASS(VoxelMesherNative);
    GDREGISTER_CLASS(ChasmColumnResultNative);
    GDREGISTER_CLASS(UndergroundChasmSamplerNative);
    GDREGISTER_CLASS(SubterraneanTunnelSamplerNative);
    GDREGISTER_CLASS(MacroTopographyNative);
    GDREGISTER_CLASS(FluvialCarverNative);
}

void uninitialize_terrain_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
}

extern "C" {
GDExtensionBool GDE_EXPORT terrain_extension_init(
    GDExtensionInterfaceGetProcAddress p_get_proc_address,
    GDExtensionClassLibraryPtr p_library,
    GDExtensionInitialization *r_initialization
) {
    godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

    init_obj.register_initializer(initialize_terrain_module);
    init_obj.register_terminator(uninitialize_terrain_module);
    init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

    return init_obj.init();
}
}
