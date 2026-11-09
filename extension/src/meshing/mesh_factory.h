#ifndef MESH_FACTORY_H
#define MESH_FACTORY_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/classes/resource_loader.hpp>

namespace godot {

class MeshFactory {
public:
    static Ref<RefCounted> create_mesh_data() {
        ResourceLoader *rl = ResourceLoader::get_singleton();
        if (rl) {
            Ref<Resource> scr = rl->load("res://src/meshing/mesh_data.gd");
            if (scr.is_valid()) {
                return scr->call("new");
            }
        }
        Ref<RefCounted> ref;
        ref.instantiate();
        return ref;
    }

    static Ref<RefCounted> create_dual_mesh_bundle() {
        ResourceLoader *rl = ResourceLoader::get_singleton();
        if (rl) {
            Ref<Resource> scr = rl->load("res://src/meshing/dual_mesh_bundle.gd");
            if (scr.is_valid()) {
                return scr->call("new");
            }
        }
        Ref<RefCounted> ref;
        ref.instantiate();
        return ref;
    }
};

} // namespace godot

#endif // MESH_FACTORY_H
