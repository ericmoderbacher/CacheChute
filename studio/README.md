# studio/ — Object Studio

The application side of CacheChute's [object-perception subsystem](../docs/object-perception.md),
structured as the object analog of [`noid`](https://github.com/ericmoderbacher/modersNets)
(*text → 3D human → render*): studio **owns the pipeline + viewer** and **composes
networks from the `modersNets` zoo**. Dependency is one-way — studio consumes
`modersNets`; `modersNets` never knows about CacheChute.

## Swappable pipeline (the point)

While we're trying many networks, the pipeline is a **loose, config-selected harness**,
not a compiled monolith: each stage dispatches to an interchangeable backend adapter
(`stages/<stage>.<backend>.sh`) and backends talk only through files in the run dir.
Swap a network = change one line; add one = drop in an adapter.

```sh
./pipeline.sh                              # run with pipeline.conf
SEGMENT=u2net ./pipeline.sh                # swap one stage from the env
DETECT=owlvit SEGMENT=mobilesam ./pipeline.sh
MULTIVIEW=none NAME=probe ./pipeline.sh    # stop after segment (fast wiring check)
```

Stages: **detect → segment → multiview → view**. HEIC is decoded natively with `sips`.

## Stage contract (files in `out/<NAME>/`)

| file | written by | meaning |
|---|---|---|
| `source.png` / `source.bmp` | prep | decoded input |
| `box.txt` | DETECT | `x0 y0 x1 y1 [score] [label]` in source px |
| `object.png` | SEGMENT | the isolated object on white, square — multiview input |
| `mask.png` | SEGMENT | binary/alpha mask (inspection) |
| `view_0..5.png` | MULTIVIEW | the 6 synthesized views |
| `index.html` | view | the window |

Any backend that honors this contract slots in with no changes elsewhere.

## Backend status

| stage | backend | state |
|---|---|---|
| detect | `manual` (box / centered) | ✅ runnable |
| detect | `owlvit` (open-vocab "screw"→box) | ⛔ needs `modersNets/build/owlvit_detect` |
| segment | `manual` (frame only — does **not** remove background) | ✅ runnable |
| segment | `u2net` (salient matte, prompt-free) | ⛔ needs `u2net_matte` |
| segment | `mobilesam` (box-prompted mask) | ⛔ needs `mobilesam_segment` |
| multiview | `zero123plus` (1 image → 6 views, Metal) | ✅ runnable |

The ⛔ backends are generic arbitrary-image CLIs to add under `modersNets/tools/`
(see each adapter's header for the exact target + which `models/` ref it builds on).
Until a real segmenter is wired, `manual` only **frames** the object — the background
(e.g. the glove) stays, so multiview output stays rough. That's expected.

## Adding a backend

1. Write `stages/<stage>.<name>.sh` reading/writing the contract files above.
2. If it needs a network, add the arbitrary-image CLI in `modersNets/tools/` and
   call it from the adapter (mirror `zero123plus_gen2 --front`).
3. Select it: `<STAGE>=<name> ./pipeline.sh`, or set it in `pipeline.conf`.

## Requirements

- `modersNets` built (at least `zero123plus_gen2`); its pinned weights/goldens under
  `matchMaker/containers/work`. Formalizing how studio pins `modersNets` (submodule
  vs. built artifact) is a tracked open decision in the design doc.
