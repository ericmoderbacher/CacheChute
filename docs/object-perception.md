# Object Perception & Catalog

Design record for the subsystem that **looks at physical items as they enter
CacheChute, identifies them, and makes the inventory browsable and searchable**.
This is the "what is it" half of the appliance; the "where is it" half is handled
by the storage mechanism (see [How it fits the appliance](#how-it-fits-the-appliance)).

The long arc is "everything." The **starting point is small maker fasteners** —
nuts, bolts, screws — classified to their exact spec.

## Goal

On intake, automatically classify an item to a **precise spec** (e.g. `M3×8
socket-head, stainless`), record it, and surface it through a web UI you can
**peruse** (browse) and **search**. Automate the classification as far as
possible; a human confirms or corrects, and those corrections make the system
need the human less over time.

## How it fits the appliance

CacheChute is a chute-fed store/retrieve appliance, and that geometry is a gift to
the vision problem:

- **The chute is the imaging station.** Items arrive **singulated** — one isolated
  piece per shot, on a controlled surface, before it joins any pile. That is the
  easy case for segmentation and classification; we never have to find an object
  inside a cluttered bin.
- **"What it is" → perception** (this document).
- **"Where it is" → recorded at placement** by the storage mechanism, *not* by
  vision. The appliance puts the piece somewhere, so it already knows the location
  by construction. Don't build a vision system to track objects in a pile.

## Compute: the macOS way

The perception pipeline runs **the way we build things on macOS** — the
[`modersNets`](https://github.com/ericmoderbacher/modersNets) runtime on native
Apple frameworks (MPSGraph + Metal kernels), no Python in the running path. This
is the approach, not a specific machine or chip.

Per-item work is **async / offline**: intake is one piece at a time, the piece is
stored immediately, and the catalog row fills in a minute or two later. Nobody
waits on inference, so model latency is a non-issue.

## Dependency direction (decision)

- CacheChute **consumes** `modersNets` **one-way**, vendored and **pinned** the
  same way `webenginebase` pulls its forks (submodule → personal fork → known-good
  commit, evaluated rather than auto-merged).
- `modersNets` **stays consumer-agnostic** — it must not know about CacheChute. It
  is a general-purpose perception toolbox; CacheChute is just one caller.
- If "who consumes this repo" ever needs to be discoverable, that reverse lookup
  belongs in a **centralized cross-repo submodule/dependency list**, *not* baked
  back into `modersNets`.

## Pipeline (the producer)

```
singulated photo
  → SAM            segment the piece from the background
  → features       scale-invariant proportions + thread-series analysis
  → classifier     fine-grained (geometry + CLIP/DINO features)
  → proposed spec  {head, drive, thread Ø, length, series, material/finish} + confidence
```

Tools drawn from the `modersNets` zoo: the **SAM family** (segmentation),
**CLIP / DINOv2** (features and, later, text+image query). `depth_anything` is
available if monocular depth helps. **`zero123++` and `nerf` are reserved for the
later phase** (distinct objects, 3D browse, "everything") — and possibly for
generating synthetic training data; they are *not* part of the fastener milestone.

## Sizing without a ruler (decision)

A flat photo has no inherent scale, and ISO metric fasteners are deliberately
**near self-similar across sizes** (pitch ÷ diameter is ~constant), so proportions
alone cannot give absolute millimetres. What they *can* give reliably: **head
type, drive type, length-to-diameter class, and thread series** (coarse vs fine) —
i.e. the shape family.

Absolute size is then resolved by stacking three cheap signals, none of which
needs a fixed metrology rig:

1. **Closed-set snap** — match to the discrete sizes actually stocked, not the
   continuum.
2. **Light calibration anchor** — an occasional rough pixel↔mm reference collapses
   the ambiguity.
3. **Human correct / retry in the UI** — catches the rare miss, and each
   correction becomes a training label.

## Human-in-the-loop / active learning

The web UI lets you **confirm / correct / "try again"** on every proposed spec.
Each confirmation does double duty: it **files the part** *and* becomes a
**training label**. The classifier improves with use, so the manual burden shrinks
over time.

## Catalog seam

A clean producer→reader boundary lets the two halves evolve independently:

- **Producer (macOS side)** writes one catalog **record** per item: media +
  extracted features + proposed/confirmed spec (+ location/timestamp later). Keep
  the record **open/extensible** — decide fields by *the questions you want to ask
  the catalog*, not up front.
- **Reader (web tier)** serves peruse + search; it runs **no inference**, it just
  reads records and ranks. CLIP gives **text + image query for free** later, and 3D
  display rides the **Online3DViewer** already shipped in `webenginebase` once 3D
  capture exists.

## Milestone 1

A **2D fastener classifier from still photos**.

- **In:** hand-staged still photos of singulated nuts/bolts/screws (one per shot).
- **Out:** a proposed structured spec + confidence, surfaced in a confirm/correct
  UI, written to a catalog row.
- **Not in M1:** live-camera intake, mechatronic sorting, 3D / `zero123++`.

## Checkpoint — what's prototyped (2026-06-29)

Built in **`modersNets`** (consumed here; see `modersNets/docs/segmentationBench.md`):

- **SAM2 segmentation, Metal-accelerated** — a resident warm engine (encoder+decoder on GPU,
  capped resolution) behind the `seg_bench` compare tool. SAM is **promptable + class-agnostic**:
  it answers "what's at this point," so it segments thin metal screws fine where closed-vocab
  models (no "screw" class) can't. "Everything mode" is a grid of prompts deduped into instances.
- **Cacheable stages** (`core/stage.h`) — the encode-once / decode-cheap pattern made a reusable
  primitive: changing a threshold re-filters with no model; changing the grid reuses the embedding.
- **Identity via CLIP zero-shot** ("what is it" → a human-readable guess) — proved it works
  (a screw crop reads as "bolt" 62%), but it's **opt-in/slow on CPU**; needs the GPU CLIP path.
- **Apple Vision** foreground segmentation as a comparison backend (system framework, ANE).

Findings that shape the plan:

- **The split holds: SAM = *where* (geometry), an embedder = *what* (identity).** SAM emits
  masks + confidence, never a label; the label comes from CLIP/DINO on the crop.
- **The upgrade off the blind grid is a detector→SAM tandem** (`owlvit`/`grounded_sam` → boxes →
  SAM masks), not a denser grid — find objects by detection, not by luck of point placement.
- **`zero123++` is the wrong tool for fasteners.** On the *clean segmented* screw crop it produced
  coherent 3D-consistent views (segmentation clearly helps) but **collapsed the thin shiny screws
  into a single metallic blob** — thin specular metal is its worst case. So 3D capture is for
  chunky distinct objects later; for fasteners the win is **measurement + classification**, which
  is exactly Milestone 1.

## Open decisions

- **Training-data source** (next decision): shoot-and-label your own fasteners vs.
  **CAD-rendered synthetic** views — the latter is where `zero123++` / rendering
  could finally earn its keep, generating labeled training images at scale.
- **Record granularity:** per individual piece vs. per type + count.
- **Integration mechanism:** how CacheChute pins/consumes `modersNets` (submodule
  pin vs. consuming a built artifact).

## Later (not Milestone 1)

Live singulated camera intake · mechatronic sort + contain + retrieve · 3D capture
(`zero123++` → `nerf`) and 3D browse · broadening beyond fasteners toward
"everything."
