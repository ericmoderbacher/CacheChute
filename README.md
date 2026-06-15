# The Cache Chute

An open-source appliance for automatically storing and retrieving physical objects.

## What's here

- `Hardware/` — the physical build: `BoM.md` (bill of materials), `CAD/` (an `.stl`
  interface model), and `VendorDocuments/` (reference photos of the aluminum
  extrusion profiles).
- `docs/` — design writeups (Apple Pages).
- `webenginebase/` — git submodule: a reusable web toolbox (documentation,
  decisions, and vendored libraries) shared across Eric's sites. Most of the
  buildable substance lives here, not at the top level.

There is no application to build or test at the top level; the hardware and design
material is the content. See [`CLAUDE.md`](CLAUDE.md) for the full layout, the
"real vs. planned" breakdown, and the conventions that span the submodule boundary.

## Setup

The repo uses a submodule and Git LFS. After cloning:

```sh
git submodule update --init --recursive   # populate webenginebase + its vendored libs
git lfs pull                              # fetch .stl/.jpg/.jpeg/.png/.pages binaries
```

LFS-tracked types are listed in [`.gitattributes`](.gitattributes). Don't commit
large binaries of these types without LFS.
