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
│   ├── distribution.md           # Web export + itch.io publishing steps
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
│   ├── build_player_model.py     # Blender (bpy) script that builds project/models/player.glb
│   │                              from Quaternius's CC0 base-character + animation packs (D-89)
│   ├── ortho_fence_trace.py      # Python (Pillow + numpy) helpers to trace white fence
│   │                              lines off the front-section orthomosaic and convert
│   │                              pixels to scene meters via the ground plane's own
│   │                              transform in main.tscn (D-71)
│   ├── ortho_join_section.py     # joins a newly stitched ODM orthophoto onto the front
│   │                              one: registers it, matches its light to the front
│   │                              section's, feathers the seam (D-83)
│   └── elevation-rectifier.html  # standalone web tool: drag a photo's 4 wall corners
│                                    into a homography-corrected, real-proportioned wall
│                                    texture (D-44). Open directly as a local file (corner
│                                    picking + preview work fully offline; the "save into
│                                    Claude" step instead downloads the PNG, since that
│                                    step needs the claude.ai Artifact runtime's `assets`/
│                                    `db` capabilities, which only exist when the same file
│                                    is opened as a published Artifact, not a local file)
└── project/                      # Godot project (chosen 2026-09-14, see engine-decision.md)
    ├── project.godot             # engine config, input map (WASD + mouse look, M map, …)
    ├── export_presets.cfg        # export target config — currently one "Web" preset, for itch.io (docs/distribution.md)
    ├── icon.svg
    ├── scenes/
    │   ├── main.tscn             # ground plane (NAIP-textured) + a higher-res drone-orthomosaic
    │   │                          # patch over the front section (see D-19) and one over the
    │   │                          # middle section (see D-83) + instances below
    │   ├── player.tscn           # player (Forrest model + 1st/3rd-person cameras), instanced once in main.tscn — see D-89
    │   ├── fence_segment.tscn    # procedurally-generated wire/post fence, instanced 11x (boundary polygon, east side across the road) — see D-11, D-82
    │   ├── fence_path.tscn       # same wire/post look, but built from a Path3D/Curve3D's points instead of a length — instanced 2x for the round pens, hand-editable in the editor by clicking points on the ground — see D-67/D-69
    │   ├── gate.tscn              # swinging pipe-panel gate (hinge at the origin, panel along +X), opened/closed with E via player.gd — see D-76
    │   ├── tree_line_segment.tscn # procedurally-scattered treeline + invisible collision wall, instanced 11x, 20m outside the boundary — see D-11, D-82
    │   ├── tree.tscn              # wraps models/tree.glb, instanced by tree_line_segment.gd
    │   ├── building.tscn         # one unit building box, instanced 7x (footprint placeholders)
    │   ├── horse.tscn            # wraps models/horse.glb with wander-AI script, instanced 2x, roams a shared rectangle (D-27)
    │   ├── hen.tscn               # wraps models/hen.glb with wander.gd, instanced 6x inside flock.tscn
    │   ├── rooster.tscn           # wraps models/rooster.glb with wander.gd, instanced once inside flock.tscn
    │   ├── flock.tscn             # 6 hens + 1 rooster around a shared, slower-wandering center
    │   ├── coyote.tscn            # wraps models/coyote.glb with wander.gd, instanced once
    │   ├── minimap.tscn           # map HUD (process_mode Always): player-following minimap + full-screen map on M, built in minimap.gd — see D-13, D-93
    │   ├── duck_mallard.tscn      # wraps models/mallard_duck.glb with wander.gd, instanced once
    │   ├── duck_poly.tscn         # wraps models/duck_poly.glb with wander.gd, instanced once
    │   ├── duck_madtroll.tscn     # wraps models/duck_madtroll.glb with wander.gd, instanced once
    │   ├── goose.tscn             # wraps models/goose.glb with wander.gd, instanced 10x
    │   ├── quail.tscn             # wraps models/quail.glb with wander.gd, instanced 6x
    │   └── tr6.tscn               # wraps models/tr6.glb (no script — stationary prop), instanced once
    ├── scripts/
    │   ├── controls_overlay.gd    # read-only controls help panel in the player HUD, F1 toggles — see D-90/D-91
    │   ├── player.gd             # walking controller (hold Shift to walk, D-90), F or the mouse wheel switches 1st/3rd person (D-91), drives the body's animations (D-89) + look-at-and-press-E interaction ray and prompt (D-76)
    │   ├── horse.gd               # horse-specific wander AI (drives its own AnimationPlayer)
    │   ├── wander.gd              # generic no-animation wander AI, reused by hen/rooster/flock/coyote/ducks/geese/quail
    │   ├── fence_segment.gd       # @tool script: builds posts+wire strands from an exported length — see D-11
    │   ├── fence_path.gd          # @tool script: builds posts+wire strands from a Path3D/Curve3D's points instead of a length, closing the loop back to the first point (optional `solid` collision, D-76) — see D-67/D-69
    │   ├── gate.gd                # @tool script: builds the gate and swings its AnimatableBody3D hinge on interact() — see D-76
    │   ├── tree_line_segment.gd   # @tool script: scatters trees + one invisible collision wall from an exported length — see D-11
    │   ├── minimap.gd             # map controller: minimap, full-screen map (M, pauses the game), zoom/pan, waypoint, trail, layer toggles — see D-93
    │   ├── map_canvas.gd          # draws one map view (imagery, footprints + names, fences, horses, trail, waypoint, player) from scene groups — see D-93
    │   ├── map_math.gd            # pure map helpers (projection, zoom, bearings, footprints, trail), covered by tests/ — see D-93
    │   ├── time_of_day.gd         # Day / Sunset / Dusk / Night / Dawn lighting presets, cycled with T; overcast hook for weather — see D-94, D-95
    │   └── weather.gd             # Clear / Rain / Snow: camera-following particles, roof/tree occlusion, overcast sky, cycled with R — see D-95
    ├── tests/                    # headless test scripts (extends SceneTree), excluded from export — see CONTRIBUTING.md
    │   ├── test_map_math.gd       # unit tests for map_math.gd
    │   ├── test_map_scene.gd      # loads main.tscn, checks the map's collected data and M pause toggle
    │   ├── test_time_of_day.gd    # preset helpers + TimeOfDay driving main.tscn's sun/environment on T
    │   └── test_weather.gd        # weather/overcast helpers + Weather switching rain/snow on R in main.tscn
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
    │   ├── player.glb              # CC0 rigged/animated player character (Quaternius base, dressed by
    │   │                            # tools/build_player_model.py; textures embedded) — see D-89
    │   └── tr6.glb                 # CC-BY static mesh (Configcars, Sketchfab), simplified from a 32MB/879k-tri
    │                                # download to 7.7MB — see D-25, credits.md
    └── textures/
        ├── ground/                # ground textures actually loaded by the scene (res://) —
        │                          # NAIP imagery (whole property) plus a real drone
        │                          # orthomosaic patch over the front section (see D-19)
        │                          # and the middle section (see D-83); the back of the
        │                          # property is still NAIP-only for now
        ├── roofs/                 # real roof imagery cropped from the front- and middle-
        │                            section orthomosaics, one per roof slope (see D-20, D-85)
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
