#include "terrain_native_core.h"
#include "../../FastNoiseLite.h"

using namespace godot;

void TerrainNativeCore::_bind_methods() {
    ClassDB::bind_method(D_METHOD("is_native_active"), &TerrainNativeCore::is_native_active);
    ClassDB::bind_method(D_METHOD("get_version"), &TerrainNativeCore::get_version);
    ClassDB::bind_method(D_METHOD("sample_test_noise", "x", "y", "seed"), &TerrainNativeCore::sample_test_noise, DEFVAL(1337));
}

TerrainNativeCore::TerrainNativeCore() {}

TerrainNativeCore::~TerrainNativeCore() {}

bool TerrainNativeCore::is_native_active() const {
    return true;
}

String TerrainNativeCore::get_version() const {
    return "Terrain GDExtension v0.1.0 (godot-cpp 4.4)";
}

float TerrainNativeCore::sample_test_noise(float x, float y, int seed) const {
    ::FastNoiseLite noise;
    noise.SetSeed(seed);
    noise.SetNoiseType(::FastNoiseLite::NoiseType_OpenSimplex2);
    return noise.GetNoise(x, y);
}

