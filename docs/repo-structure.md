# Repo Structure

```
farm-sim/
├── README.md
├── docs/
│   ├── implementation-plan.md    # phased plan, engine-agnostic
│   ├── drone-capture-plan.md     # drone flight + processing plan
│   ├── engine-decision.md        # Godot vs Unity vs Unreal tradeoffs
│   ├── parcel-data.md            # confirmed parcel facts (ID, acreage, boundary source)
│   ├── credits.md                # attribution for non-CC0 third-party assets
│   ├── gis/
│   │   └── parcel-*.geojson      # real parcel boundary polygons pulled from county/state GIS
│   └── repo-structure.md         # this file
├── assets/
│   ├── drone-source/             # raw drone photos (likely gitignored — large files)
│   ├── orthomosaic/              # placeholder for the eventual drone-derived orthomosaic
│   ├── reference-photos/         # gitignored (D-49) — ground-level phone photos of individual
│   │                              # buildings, named by building + compass-facing wall (e.g.
│   │                              # sallys_house/house_north.jpg), local-only source material
│   │                              # for the tools/elevation-rectifier.html wall-texturing
│   │                              # workflow (D-44, D-46); only the rectified crop it produces
│   │                              # ever needs to leave the photographer's machine
│   └── models/                   # 3D models (buildings, animals) once created
├── tools/
│   └── elevation-rectifier.html  # standalone web tool: drag a photo's 4 wall corners
│                                    into a homography-corrected, real-proportioned wall
│                                    texture (D-44). Open directly as a local file (corner
│                                    picking + preview work fully offline; the "save into
│                                    Claude" step instead downloads the PNG, since that
│                                    step needs the claude.ai Artifact runtime's `assets`/
│                                    `db` capabilities, which only exist when the same file
│                                    is opened as a published Artifact, not a local file)
└── project/                      # Godot project (chosen 2026-09-14, see engine-decision.md)
    ├── project.godot             # engine config, input map (WASD + mouse look)
    ├── icon.svg
    ├── scenes/
    │   ├── main.tscn             # ground plane (NAIP-textured) + a higher-res drone-orthomosaic
    │   │                          # patch over the front section (see D-19) + instances below
    │   ├── player.tscn           # first-person player, instanced once in main.tscn
    │   ├── fence_segment.tscn    # procedurally-generated wire/post fence, instanced 13x (boundary polygon) — see D-11
    │   ├── tree_line_segment.tscn # procedurally-scattered treeline + invisible collision wall, instanced 13x, 20m outside the boundary — see D-11
    │   ├── tree.tscn              # wraps models/tree.glb, instanced by tree_line_segment.gd
    │   ├── building.tscn         # one unit building box, instanced 7x (footprint placeholders)
    │   ├── horse.tscn            # wraps models/horse.glb with wander-AI script, instanced 2x, roams a shared rectangle (D-27)
    │   ├── hen.tscn               # wraps models/hen.glb with wander.gd, instanced 6x inside flock.tscn
    │   ├── rooster.tscn           # wraps models/rooster.glb with wander.gd, instanced once inside flock.tscn
    │   ├── flock.tscn             # 6 hens + 1 rooster around a shared, slower-wandering center
    │   ├── coyote.tscn            # wraps models/coyote.glb with wander.gd, instanced once
    │   ├── minimap.tscn           # corner HUD: NAIP texture + rotating player marker — see D-13
    │   ├── duck_mallard.tscn      # wraps models/mallard_duck.glb with wander.gd, instanced once
    │   ├── duck_poly.tscn         # wraps models/duck_poly.glb with wander.gd, instanced once
    │   ├── duck_madtroll.tscn     # wraps models/duck_madtroll.glb with wander.gd, instanced once
    │   ├── goose.tscn             # wraps models/goose.glb with wander.gd, instanced 10x
    │   ├── quail.tscn             # wraps models/quail.glb with wander.gd, instanced 6x
    │   └── tr6.tscn               # wraps models/tr6.glb (no script — stationary prop), instanced once
    ├── scripts/
    │   ├── player.gd             # first-person walking controller
    │   ├── horse.gd               # horse-specific wander AI (drives its own AnimationPlayer)
    │   ├── wander.gd              # generic no-animation wander AI, reused by hen/rooster/flock/coyote/ducks/geese/quail
    │   ├── fence_segment.gd       # @tool script: builds posts+wire strands from an exported length — see D-11
    │   ├── tree_line_segment.gd   # @tool script: scatters trees + one invisible collision wall from an exported length — see D-11
    │   └── minimap.gd             # maps player world position onto the NAIP texture — see D-13
    ├── models/
    │   ├── horse.glb              # CC0 rigged/animated horse (Quaternius) — see D-9; scale fixed in D-18
    │   ├── hen.glb                 # CC-BY static mesh (Poly by Google) — see D-10, credits.md
    │   ├── rooster.glb             # CC-BY static mesh (Poly by Google) — see D-10, credits.md
    │   ├── coyote.glb              # CC-BY static mesh (Poly by Google) — see D-10, credits.md
    │   ├── tree.glb                # CC0 static mesh (Quaternius) — see D-11
    │   ├── mallard_duck.glb        # CC-BY static mesh (Poly by Google) — see D-15, credits.md
    │   ├── duck_poly.glb           # CC-BY static mesh (Poly by Google) — see D-15/D-17, credits.md
    │   ├── duck_madtroll.glb       # CC-BY static mesh (madtrollstudio) — see D-15/D-17, credits.md
    │   ├── goose.glb               # CC-BY static mesh (Poly by Google) — see D-16, credits.md
    │   ├── quail.glb               # CC-BY static mesh (Poly by Google) — see D-17, credits.md
    │   └── tr6.glb                 # CC-BY static mesh (Configcars, Sketchfab), simplified from a 32MB/879k-tri
    │                                # download to 7.7MB — see D-25, credits.md
    └── textures/
        ├── ground/                # ground textures actually loaded by the scene (res://) —
        │                          # NAIP imagery (whole property) plus a real drone
        │                          # orthomosaic patch over the front section (see D-19);
        │                          # rest of the property still NAIP-only for now
        ├── roofs/                 # real roof imagery cropped from the front-section
        │                            orthomosaic, one per covered building (see D-20)
        ├── buildings/             # real exterior-wall/siding imagery cropped from ground-level
        │                            reference photos (D-39, D-44) — one file per photographed
        │                            wall face; most buildings are still placeholder-color on
        │                            the sides that have no photo yet
        └── horses/                # small generated tileable polka-dot textures standing in for
                                     appaloosa/pinto coat markings, triplanar-projected since
                                     horse.glb has no UV coordinates (see D-64)
```

## Notes

- Raw drone photos and processed imagery will likely be large binary files —
  consider Git LFS or keeping them out of git entirely (local/cloud storage
  with a pointer/README in assets/) once volume is known.
- `.godot/` (editor cache) and `*.import` files are gitignored — regenerated
  locally when the project is opened in the Godot editor. `tr6.glb.import`
  is the one tracked exception (embeds textures instead of the default
  Extract mode) — see D-29.
- Textures the scene actually loads must live under `project/` — Godot's
  `res://` root is the `project/` directory and can't reach outside it (no
  `res://../assets`). `assets/` stays the place for source/raw material and
  anything not directly loaded by the engine; see D-7 in
  [decisions.md](project/decisions.md). The same constraint is why 3D models
  live under `project/models/` rather than `assets/models/` — see D-9.
