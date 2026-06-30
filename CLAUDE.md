# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Two layers with very different content:

- **CacheChute (outer repo)** — a hardware project: an open-source appliance that
  automatically stores and retrieves physical objects. Almost no code; it is
  `Hardware/` (a `BoM.md`, a CAD `.stl`, vendor-photo references) and `docs/`
  (Apple Pages design writeups). Binary assets are stored via **Git LFS**.
- **`webenginebase/` (git submodule)** — where nearly all the substance lives. A
  reusable "web toolbox" of **documentation, decisions, and vendored libraries**
  shared across Eric's sites (ericmoderbacher.com, moderbacherlabs.com,
  moderbacher.com). It is mostly Markdown design docs plus a small amount of real
  code (a Pandoc Lua filter, a JS embed glue, nginx config, Dockerfiles).

There is **no application to build or test at the top level.** Treat most `.md`
files here as authoritative *decision records*, not aspirational notes — but check
the "real vs. planned" list below before assuming something runs.

## Setup

The repo uses nested submodules and LFS. After cloning:

```sh
git submodule update --init --recursive   # populate webenginebase + its vendored libs
git lfs pull                              # fetch .stl/.jpg/.png/.pages binaries
```

LFS-tracked types (see `.gitattributes`): `*.stl *.jpg *.jpeg *.png *.pages`. Don't
commit large binaries of these types without LFS, and don't `cat` them — they're
pointer files unless pulled.

## Build / run / test

Almost everything is documentation. The only thing that actually builds today:

- **Static web tier** (`webenginebase/containers/Dockerfile.staticBackend`) — a real
  two-stage nginx image serving vendored Pico CSS, the Inter font, the
  Online3DViewer bundle, and 3D/video media. Build **from the `webenginebase/` root**
  so submodule paths resolve:

  ```sh
  cd webenginebase
  docker build -f containers/Dockerfile.staticBackend -t webenginebase-static .
  docker run --rm -p 8080:80 webenginebase-static     # http://localhost:8080
  ```

  Override the 3D-viewer pin with `--build-arg O3DV_VERSION=…` (the importer-lib
  pins — `OCCT_VERSION`, `DRACO_VERSION`, `RHINO3DM_VERSION`, `WEBIFC_VERSION` —
  are also build args; the known-good set is documented in `media/3d-viewer.md`).

- **Content authoring** is Djot (`.dj`) → Pandoc + Lua filters → static HTML → nginx.
  `webenginebase/authoring-pipeline.md` is the authoritative decision record (why
  Djot+Pandoc, the GPL-at-build-time license nuance, and a live "Still open" list).
  The `render.sh` / Makefile that drives it lives in the **consuming** site repo
  (e.g. ericmoderbacher.com), **not here** — note it peels YAML frontmatter into a
  `--metadata-file` because Pandoc 3.9's Djot reader lacks `yaml_metadata_block`.
  This repo only supplies the Lua filter (`webenginebase/media/embed-media.lua`)
  and runtime glue. There is no content build step to run inside this repo.

- **One real test, no general runner.** `webenginebase/media/test/embed-media.test.sh`
  is a self-contained golden-output test: it renders `embed-media.fixture.dj` through
  Pandoc + `embed-media.lua` and `grep`-asserts the emitted embed HTML (the pinned
  `data-*` attributes — run it after touching the media-embed syntax). Plain
  executable, exits non-zero on failure:

  ```sh
  webenginebase/media/test/embed-media.test.sh
  ```

  Needs `pandoc` ≥ 3.1.12 on `PATH`, else falls back to the `pandoc/core` Docker
  image; `SKIP`s (exit 0) if neither is present. The broader
  `webenginebase/testing-framework.md` C++ visual/CV-diff sidecar is still only a
  design doc — nothing is built.

## Real vs. planned (don't assume it runs)

- **Real:** `Dockerfile.staticBackend` + `staticBackend.nginx.conf`,
  `media/embed-media.lua`, `media/o3dv-embed.js`, `media/embed-media.css`,
  `media/test/embed-media.test.sh` (the one runnable test), all the Markdown
  decision docs.
- **Stubs / planned:** `Dockerfile.openscad`, `Dockerfile.compilerexplorer` (empty
  stubs); the C++ testing sidecar (`testing-framework.md`); `architecture.md`'s
  CDN→LB→nginx→app→Postgres diagram is a *target sketch* — today's reality is one
  nginx in a devcontainer. `styles.css` at the webenginebase root is a placeholder;
  the real theme is per-site `theme.css` in each consuming repo.

## Conventions that are easy to violate

These are load-bearing rules spread across multiple docs; respect them:

- **Vendoring philosophy** (`webenginebase/README.md`): no CDNs or package registries
  at serve time. Every third-party asset is a git submodule pointing at a *personal
  fork* of upstream, pinned to a known-good commit and evaluated rather than
  auto-merged. Ethos: "vendor it, data outlives the tool." Vendored submodules:
  PicoCSS, inter, nginx, bootstrap (legacy, unused), pandoc, djot.js — each a fork
  under `github.com/ericmoderbacher/*`.

- **Sizing system** (`webenginebase/sizing-system.md`): every CSS length must be a
  ratio of a real browser/hardware input (viewport, DPR, pointer type, motion/color
  preference) or a *named* math constant (φ, √2, π, e, 2^(1/12)). **A bare decimal in
  layout CSS is a code smell.** Architecture is three layers — INPUTS → KNOBS →
  SIZES; page CSS consumes named SIZES only. Reaching for a raw input or constant
  from page CSS is a "layer leak."

- **Brand layer** (`webenginebase/STYLE.md`): Pico CSS + a per-site `theme.css`
  override; Inter for everything (don't pick fonts per component); brand palette
  stored as Display P3 with computed sRGB fallbacks; 0.5px borders, no shadows, no
  gradients, semantic HTML first.

- **Pinned media-embed syntax** (`webenginebase/media/embeds.md`): the Djot
  `:::model` / `:::video` attribute spelling is pinned. Changing it means updating
  **four files together** — `embeds.md`, the README, `media/embed-media.lua`, and
  `media/o3dv-embed.js`. The Lua filter emits `data-*` attributes that the JS glue
  reads by name; they must stay in sync. 3D uses **Online3DViewer** (MIT), not
  three.js, not `<model-viewer>`.

- **Research-doc confidence convention** (`webenginebase/research/*`): `†` = well
  documented (talks, eng blogs, vendor case studies); unmarked = inferred from
  category norms / fingerprinting. Preserve the marks when editing.

- **Commits:** no AI/Claude attribution or `Co-Authored-By` trailers in commit
  messages.

## Working across the submodule boundary

`webenginebase` is its own git repo with its own history and remote. Edits inside it
are committed there first; the outer CacheChute repo only records the submodule's
pinned commit SHA. When you change files under `webenginebase/`, commit in that repo,
then update the pointer in CacheChute.
