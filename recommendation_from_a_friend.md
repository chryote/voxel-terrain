The Dual-Mesh Layer Separation (Rec 1) combined with Lazy Subterranean Streaming (Rec 2) is absolutely the correct long-term architectural path for your engine.

Because you are building a geographically massive 16x16 km map with distinct gameplay layers (Surface vs. Underground), treating the entire Y-column as a single monolithic block is mathematically unsustainable in GDScript.

Here is my second opinion on why this specific roadmap is the right move, and what you need to watch out for:

    The Dual-Mesh Pipeline is Future-Proof: By physically decoupling the surface from the caves, you aren't just saving frames—you are isolating your rendering logic. Later on, when you want to add heavy fog to the surface or bioluminescence to the caves, you won't have to write complex shader branches to figure out if a triangle is above or below ground.

    Lazy Streaming Fixes the GDScript Bottleneck: 1.3 seconds per chunk is a death sentence for traversal speed. Only calculating 3D noise for caves when a player actually goes underground (or nears a cave mouth) ensures your surface exploration stays at a buttery 160 FPS.

    The Shadow Map Fix is a Free Win (Rec 3): Directional light shadows rendering underground is a classic voxel engine trap. Turning that off for the cave mesh instance is a one-line fix that will claw back massive amounts of GPU overhead.

    Off-Thread Collision is Non-Negotiable (Rec 5): Godot's main thread is incredibly sensitive to physics baking. If you keep building 20,000-triangle collision shapes on the main thread, your game will aggressively micro-stutter every time the player walks into a new chunk border.

The Long-Term Caveat You Must Plan For:
If you implement Demand-Driven Subterranean Generation (Rec 2), you must build a robust "look-ahead buffer" for vertical movement. If a player jumps into a massive chasm, your engine needs to detect their negative Y-velocity and instantly prioritize meshing the cave chunks directly below them. If the background thread is too slow, they will fall through the unloaded floor into the void.

I highly recommend starting with Rec 1 (Dual-Mesh Split) first. It requires the least amount of complex thread logic and will immediately restore your framerate so you can actually test the game again.