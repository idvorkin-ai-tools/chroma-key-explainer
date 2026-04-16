#!/usr/bin/env -S uv run --script
# /// script
# dependencies = ["numpy", "pillow", "scipy"]
# ///
"""
Chroma-key mask evals. Given a processed RGBA image, compute quality metrics.

Metrics:
- residual_magenta_px: opaque pixels still near chroma color (missed background)
- interior_hole_px: transparent pixels enclosed by opaque (eaten interior)
- edge_fringe_px: partial-alpha pixels (incomplete edges)
- opaque_px: rough subject coverage
- alpha_binarity_pct: % pixels that are fully opaque or fully transparent
"""
import sys
import json
import numpy as np
from PIL import Image
from scipy.ndimage import label


def eval_mask(image_path, chroma_rgb=(255, 0, 255), tolerance=20):
    im = Image.open(image_path).convert("RGBA")
    arr = np.asarray(im)
    rgb = arr[:, :, :3]
    alpha = arr[:, :, 3]
    H, W = alpha.shape

    opaque = alpha > 128
    transparent = alpha < 16

    chroma = np.array(chroma_rgb, dtype=np.int16)
    dist = np.abs(rgb.astype(np.int16) - chroma).sum(axis=2)
    near_magenta = dist <= tolerance
    residual = int((opaque & near_magenta).sum())

    labeled, _ = label(transparent)
    border = set()
    border.update(labeled[0, :].tolist())
    border.update(labeled[-1, :].tolist())
    border.update(labeled[:, 0].tolist())
    border.update(labeled[:, -1].tolist())
    border.discard(0)
    interior_holes = int(transparent.sum() - np.isin(labeled, list(border)).sum())

    mid = (~opaque) & (~transparent)
    edge_fringe = int(mid.sum())
    return {
        "residual_magenta_px": residual,
        "interior_hole_px": interior_holes,
        "edge_fringe_px": edge_fringe,
        "opaque_px": int(opaque.sum()),
        "alpha_binarity_pct": round((opaque.sum() + transparent.sum()) / (H * W) * 100, 2),
        "total_px": H * W,
    }


if __name__ == "__main__":
    print(json.dumps(eval_mask(sys.argv[1]), indent=2))
