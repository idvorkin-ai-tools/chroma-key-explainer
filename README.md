# Chroma-key hill-climbing — explainer

Eval-driven hill-climbing on a real image-processing problem: pulling clean
transparent backgrounds out of AI-generated character art. Six approaches,
two test images (sparse / dense), one winning `magick` one-liner — chosen
by a fitness function, not by eyeballing.

**Live page:** https://idvorkin-ai-tools.github.io/chroma-key-explainer/

## The problem

AI image generators render characters on a solid magenta background. A
naive `magick -fuzz 30% -transparent "#FF00FF"` looks clean on a white
page but silently eats magenta-tinted pixels inside the subject (fur
highlights, skin shading), leaving thousands of interior holes that only
show up when the image is composited onto a different background.

## The trick

Treat each ImageMagick recipe as a "model", the alpha channel it produces
as the output, and three cheap pixel counts as the eval:

- `interior_hole_px` — transparent pixels enclosed by opaque (eaten interior)
- `residual_magenta_px` — opaque pixels still near `#FF00FF` (missed background)
- `edge_fringe_px` — partial-alpha pixels

Score is `residual × 5 + holes`. Iterate, keep what scores best, stop.

## Layout

```
index.html                single-page explainer (embeds test images + results)
test_images/              two magenta-bg test cases (sparse / dense)
scripts/eval.py           uv-inline-dep script: compute metrics on an RGBA image
scripts/harness.sh        apply 6 approaches × 2 images, write results + metrics
results/<image>/          pre-computed outputs per approach:
                            <approach>.webp           keyed RGBA result
                            <approach>-alpha.png      extracted alpha mask
                            <approach>-on-white.webp  composite on white (eyeball view)
results/metrics.json      combined fitness scores across the whole matrix
```

## Prereqs

- `magick` (ImageMagick 7) on PATH
- `uv` on PATH (runs `eval.py` via PEP 723 inline deps — no `pip install`)

## Running

```bash
./scripts/harness.sh    # regenerates results/ end-to-end
```

## Hosting

GitHub Pages, served from `main` branch root. `.nojekyll` keeps Pages from
running Jekyll over plain HTML.
