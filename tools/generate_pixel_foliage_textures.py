"""
Generates high quality stylized pixel art textures for grass tufts and bushes.
Creates 64x64 pixel art sprites and upscales them 8x (nearest neighbor) to 512x512
with crisp, authentic 1-bit alpha contours and cohesive graphic novel / toon palettes.
"""
from PIL import Image
import numpy as np

def create_pixel_grass_tuft(size=64) -> Image.Image:
    # 64x64 RGBA canvas
    arr = np.zeros((size, size, 4), dtype=np.uint8)

    # 7-step pixel art grass palette (warm, stylized, vibrant toon greens)
    C_OUTLINE = (28, 40, 20, 255)
    C_ROOT    = (42, 58, 26, 255)
    C_SHADOW  = (60, 86, 34, 255)
    C_MID_D   = (88, 126, 44, 255)
    C_MID_L   = (124, 174, 56, 255)
    C_LIGHT   = (168, 218, 74, 255)
    C_TIP     = (218, 252, 110, 255)

    def set_pixel(x, y, color):
        if 0 <= x < size and 0 <= y < size:
            arr[y, x] = color

    def draw_blade(spine, widths, color_rule):
        """
        spine: list of (x, y) coordinates from root to tip
        widths: float width at each point along spine
        color_rule: function(i, n_steps, side_offset) -> color
        """
        n = len(spine)
        for i, (sx, sy) in enumerate(spine):
            w = widths[i]
            x_min = int(round(sx - w))
            x_max = int(round(sx + w))
            for px in range(x_min, x_max + 1):
                offset = px - sx
                norm_offset = offset / max(w, 0.5)
                c = color_rule(i, n, norm_offset)
                if c[3] > 0:
                    set_pixel(px, sy, c)

    # 1. Back/Shadow Blades (Layer 1 - provides depth & backdrop)
    # Blade 1A: Back-left curved blade
    spine_1a = []
    for y in range(63, 14, -1):
        t = (63 - y) / (63 - 14)
        x = 30 - 15 * (t ** 1.3) + 2 * np.sin(t * np.pi)
        spine_1a.append((x, y))
    widths_1a = [max(1.0, 2.5 * (1.0 - (i / len(spine_1a)) ** 1.4)) for i in range(len(spine_1a))]
    draw_blade(spine_1a, widths_1a, lambda i, n, off: (
        C_TIP if i >= n - 2 else
        (C_MID_D if off > 0 else C_SHADOW)
    ))

    # Blade 1B: Back-right curved blade
    spine_1b = []
    for y in range(63, 12, -1):
        t = (63 - y) / (63 - 12)
        x = 33 + 16 * (t ** 1.3) - 2 * np.sin(t * np.pi)
        spine_1b.append((x, y))
    widths_1b = [max(1.0, 2.5 * (1.0 - (i / len(spine_1b)) ** 1.4)) for i in range(len(spine_1b))]
    draw_blade(spine_1b, widths_1b, lambda i, n, off: (
        C_TIP if i >= n - 2 else
        (C_MID_L if off < 0 else C_MID_D)
    ))

    # 2. Main Central Tower Blade (Layer 2 - tall hero blade)
    spine_center = []
    for y in range(63, 4, -1):
        t = (63 - y) / (63 - 4)
        # S-curve: lean slightly left then tip right
        x = 32 - 3.5 * np.sin(t * np.pi * 0.9) + 2.0 * (t ** 2.2)
        spine_center.append((x, y))
    widths_center = [max(0.6, 3.2 * (1.0 - (i / len(spine_center)) ** 1.2)) for i in range(len(spine_center))]
    draw_blade(spine_center, widths_center, lambda i, n, off: (
        C_TIP if i >= n - 3 else
        (C_LIGHT if off > 0.2 else (C_MID_L if off > -0.4 else C_MID_D))
    ))

    # 3. Flanking Mid Blades (Layer 3 - medium height)
    # Blade 3A: Left-mid blade curving outward
    spine_3a = []
    for y in range(63, 19, -1):
        t = (63 - y) / (63 - 19)
        x = 28 - 18 * (t ** 1.1) + 1.5 * np.sin(t * np.pi)
        spine_3a.append((x, y))
    widths_3a = [max(0.6, 2.8 * (1.0 - (i / len(spine_3a)) ** 1.3)) for i in range(len(spine_3a))]
    draw_blade(spine_3a, widths_3a, lambda i, n, off: (
        C_TIP if i >= n - 2 else
        (C_LIGHT if off > 0.1 else (C_MID_L if off > -0.5 else C_MID_D))
    ))

    # Blade 3B: Right-mid blade curving outward
    spine_3b = []
    for y in range(63, 16, -1):
        t = (63 - y) / (63 - 16)
        x = 35 + 20 * (t ** 1.1) - 1.5 * np.sin(t * np.pi)
        spine_3b.append((x, y))
    widths_3b = [max(0.6, 2.8 * (1.0 - (i / len(spine_3b)) ** 1.3)) for i in range(len(spine_3b))]
    draw_blade(spine_3b, widths_3b, lambda i, n, off: (
        C_TIP if i >= n - 2 else
        (C_LIGHT if off < 0.2 else (C_MID_L if off < 0.6 else C_MID_D))
    ))

    # 4. Wide Drooping Outer Blades (Layer 4 - dramatic silhouette width)
    # Blade 4A: Far left wide drooping blade
    spine_4a = []
    for y in range(63, 26, -1):
        t = (63 - y) / (63 - 26)
        x = 26 - 22 * (t ** 0.85)
        spine_4a.append((x, y))
    # Hook tip downward
    spine_4a.extend([(3, 27), (2, 28), (2, 29)])
    widths_4a = [max(0.6, 2.5 * (1.0 - (i / len(spine_4a)) ** 1.3)) for i in range(len(spine_4a))]
    draw_blade(spine_4a, widths_4a, lambda i, n, off: (
        C_TIP if i >= n - 2 else
        (C_LIGHT if off > 0.0 else (C_MID_L if off > -0.6 else C_MID_D))
    ))

    # Blade 4B: Far right wide drooping blade
    spine_4b = []
    for y in range(63, 24, -1):
        t = (63 - y) / (63 - 24)
        x = 38 + 23 * (t ** 0.85)
        spine_4b.append((x, y))
    # Hook tip downward
    spine_4b.extend([(61, 25), (62, 26), (62, 27)])
    widths_4b = [max(0.6, 2.5 * (1.0 - (i / len(spine_4b)) ** 1.3)) for i in range(len(spine_4b))]
    draw_blade(spine_4b, widths_4b, lambda i, n, off: (
        C_TIP if i >= n - 2 else
        (C_LIGHT if off < 0.1 else (C_MID_L if off < 0.7 else C_MID_D))
    ))

    # 5. Foreground Sprouting Shoots (Layer 5 - short lively sprouts at the base)
    # Shoot 5A: Front-left short blade
    spine_5a = []
    for y in range(63, 38, -1):
        t = (63 - y) / (63 - 38)
        x = 29 - 9 * (t ** 1.1)
        spine_5a.append((x, y))
    widths_5a = [max(0.6, 2.0 * (1.0 - (i / len(spine_5a)) ** 1.2)) for i in range(len(spine_5a))]
    draw_blade(spine_5a, widths_5a, lambda i, n, off: (
        C_TIP if i >= n - 2 else
        (C_LIGHT if off > 0.0 else C_MID_L)
    ))

    # Shoot 5B: Front-right short blade
    spine_5b = []
    for y in range(63, 36, -1):
        t = (63 - y) / (63 - 36)
        x = 35 + 10 * (t ** 1.1)
        spine_5b.append((x, y))
    widths_5b = [max(0.6, 2.0 * (1.0 - (i / len(spine_5b)) ** 1.2)) for i in range(len(spine_5b))]
    draw_blade(spine_5b, widths_5b, lambda i, n, off: (
        C_TIP if i >= n - 2 else
        (C_LIGHT if off < 0.2 else C_MID_L)
    ))

    # 6. Deep Root Anchor (ground connection)
    for y in range(56, 64):
        y_t = (y - 56) / 7.0
        w_root = int(round(5.0 + y_t * 6.0))
        for x in range(32 - w_root, 33 + w_root):
            if arr[y, x, 3] > 0:
                if y >= 61:
                    arr[y, x] = C_ROOT
                elif y >= 58:
                    arr[y, x] = C_SHADOW if (x % 2 == 0) else C_MID_D

    # 7. Add Pixel Art Blade Crest Highlights (hand-tuned sparkle pixels)
    highlights = [
        (32, 5), (32, 6), (33, 7),
        (15, 14), (16, 15),
        (49, 17), (48, 18),
        (3, 27), (4, 26),
        (61, 25), (60, 24),
        (20, 38), (45, 36)
    ]
    for hx, hy in highlights:
        set_pixel(hx, hy, C_TIP)

    # Convert to image and scale up 8x with NEAREST for perfect crisp pixel blocks
    img_64 = Image.fromarray(arr, mode='RGBA')
    img_512 = img_64.resize((512, 512), resample=Image.NEAREST)
    return img_512


def create_pixel_bush(size=64) -> Image.Image:
    # 64x64 RGBA canvas
    arr = np.zeros((size, size, 4), dtype=np.uint8)

    # 7-step pixel art bush palette (rich volumetric foliage tones)
    C_OUTLINE = (26, 36, 18, 255)
    C_AO      = (34, 48, 24, 255) # Ambient occlusion underbelly
    C_SHADOW  = (52, 74, 32, 255) # Cluster underside shadow
    C_MID_D   = (78, 112, 42, 255) # Shadow-facing leaf body
    C_MID_L   = (114, 162, 52, 255) # Sunlit leaf body
    C_LIGHT   = (164, 214, 72, 255) # Sun-catching upper leaf rim
    C_CREST   = (214, 250, 110, 255) # Top peak sun highlight

    def set_pixel(x, y, color):
        if 0 <= x < size and 0 <= y < size:
            arr[y, x] = color

    # Define foliage clusters: (center_x, center_y, radius_x, radius_y, sun_angle_weight)
    clusters = [
        # Deep backdrop clusters
        (24, 44, 16, 14, 0.45),
        (40, 42, 16, 14, 0.55),
        # Flank lower clusters
        (14, 48, 11, 12, 0.40),
        (50, 46, 11, 12, 0.60),
        # Far lateral sprigs
        (8, 51, 8, 8, 0.35),
        (56, 50, 8, 8, 0.65),
        # Ground anchor / bottom skirt clusters (ensures base touches y=63)
        (24, 54, 14, 10, 0.30),
        (40, 54, 14, 10, 0.35),
        (32, 55, 16, 9, 0.30),
        # Mid-height main bulk
        (22, 34, 13, 12, 0.70),
        (42, 32, 13, 12, 0.75),
        # Top crown clusters (sun catching)
        (32, 22, 14, 13, 0.95),
        (24, 20, 10, 10, 0.90),
        (40, 19, 10, 10, 0.95),
        # Center foreground belly
        (32, 40, 12, 11, 0.75),
    ]

    # Pre-fill base cluster silhouettes
    mask = np.zeros((size, size), dtype=bool)
    cluster_id = np.zeros((size, size), dtype=int)
    depth_val = np.zeros((size, size), dtype=float)

    # 4x4 Bayer matrix for authentic pixel art cluster dither transitions
    bayer_4x4 = np.array([
        [ 0,  8,  2, 10],
        [12,  4, 14,  6],
        [ 3, 11,  1,  9],
        [15,  7, 13,  5]
    ], dtype=float) / 16.0

    # Draw each cluster with notched pixel art leaf edges
    for cid, (cx, cy, rx, ry, sun_w) in enumerate(clusters):
        for y in range(max(0, cy - ry - 3), min(size, cy + ry + 4)):
            for x in range(max(0, cx - rx - 3), min(size, cx + rx + 4)):
                # Normalized coordinate within cluster ellipse
                dx = (x - cx) / float(rx)
                dy = (y - cy) / float(ry)
                dist = np.sqrt(dx*dx + dy*dy)

                # Leaf notch jitter to give chunky pixel-leaf silhouette
                angle = np.arctan2(dy, dx)
                leaf_bump = 0.12 * np.cos(angle * 7.0 + cid * 1.7) + 0.08 * np.sin(angle * 13.0)
                effective_dist = dist - leaf_bump

                if effective_dist <= 1.05:
                    mask[y, x] = True
                    # Higher depth value = closer / more dominant
                    d = sun_w * 10.0 + (1.0 - effective_dist) * 2.0
                    if d > depth_val[y, x]:
                        depth_val[y, x] = d
                        cluster_id[y, x] = cid

    # Shading pass based on cluster volume and sun direction (top-right / top)
    for y in range(size):
        for x in range(size):
            if not mask[y, x]:
                continue

            cid = cluster_id[y, x]
            cx, cy, rx, ry, sun_w = clusters[cid]

            # Vector from cluster center
            dx = (x - cx) / float(rx)
            dy = (y - cy) / float(ry)

            # Sun vector: slightly from top-right (-0.3 x, -0.9 y)
            sun_dot = -(dx * 0.25 + dy * 0.95)

            # Height gradient: lower bush has more ambient shadow
            height_factor = 1.0 - (y / float(size))

            # Overall shading score [0..1]
            shade = 0.5 + sun_dot * 0.45 + (sun_w - 0.5) * 0.35 + (height_factor - 0.5) * 0.25
            shade = np.clip(shade, 0.0, 1.0)

            # Bayer dither stipple at color boundaries
            dither = (bayer_4x4[y % 4, x % 4] - 0.5) * 0.12
            d_shade = np.clip(shade + dither, 0.0, 1.0)

            # Ground root / underbelly shadow
            if y >= 58:
                c = C_AO
            elif y >= 52 and d_shade < 0.45:
                c = C_AO if (x + y) % 2 == 0 else C_SHADOW
            elif d_shade > 0.88:
                c = C_CREST
            elif d_shade > 0.72:
                c = C_LIGHT
            elif d_shade > 0.48:
                c = C_MID_L
            elif d_shade > 0.30:
                c = C_MID_D
            elif d_shade > 0.16:
                c = C_SHADOW
            else:
                c = C_AO

            set_pixel(x, y, c)

    # Outline / border pass: dark pixel outline on exterior silhouette
    final_arr = arr.copy()
    for y in range(size):
        for x in range(size):
            if mask[y, x]:
                # Check 4-neighbors
                is_edge = False
                for nx, ny in [(x-1, y), (x+1, y), (x, y-1), (x, y+1)]:
                    if nx < 0 or nx >= size or ny < 0 or ny >= size or not mask[ny, nx]:
                        is_edge = True
                        break
                if is_edge:
                    # Dark outline on shadow / lower sides; light-catching rim on top
                    if y < 22:
                        final_arr[y, x] = C_CREST if ((x + y) % 3 == 0) else C_LIGHT
                    elif y >= 50:
                        final_arr[y, x] = C_OUTLINE
                    else:
                        # Soft shadow outline
                        final_arr[y, x] = C_AO if ((x + y) % 2 == 0) else C_SHADOW

    img_64 = Image.fromarray(final_arr, mode='RGBA')
    img_512 = img_64.resize((512, 512), resample=Image.NEAREST)
    return img_512

if __name__ == "__main__":
    print("Generating pixel art foliage textures...")
    grass = create_pixel_grass_tuft(64)
    grass.save("assets/textures/grass_tuft.png")
    print("Saved assets/textures/grass_tuft.png (512x512 with 64x64 pixel grid)")

    bush = create_pixel_bush(64)
    bush.save("assets/textures/bush.png")
    print("Saved assets/textures/bush.png (512x512 with 64x64 pixel grid)")
