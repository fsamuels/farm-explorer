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
│   │   ├── parcel-*.geojson      # real parcel boundary polygons pulled from county/state GIS
│   │   └── water-features-*.json # the traced irrigation ditch and pond (the source for the carved ground) — see D-140
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
│   ├── water_overlay.py          # draws the traced ditch/pond over the imagery with numbered vertices, for review (D-140)
│   ├── build_water_data.py       # regenerates project/scripts/water_data.gd from docs/gis/water-features-*.json (D-140)
│   ├── build_star_data.py        # regenerates project/scripts/star_data.gd from the Yale Bright Star Catalogue JSON (D-104)
│   ├── build_world_data.py       # regenerates project/scripts/world_data.gd and road_data.gd and textures/world/naip_world.jpg from USGS 3DEP, Census TIGERweb roads and NAIP; cuts the road beds and snaps roads to the photo, drops those with no road under them, and marks each point asphalt or gravel (D-148, D-150, D-154)
│   ├── build_horizon_data.py     # regenerates project/scripts/horizon_data.gd from USGS 3DEP elevations and the US Wind Turbine Database (D-133)
│   ├── build_release_notes.gd    # regenerates project/scripts/release_data.gd from CHANGELOG.md and a count of the game (D-130)
│   ├── build_player_model.py     # Blender (bpy) script that builds project/models/player.glb
│   │                              from Quaternius's CC0 base-character + animation packs (D-89)
│   ├── build_ranger_ev_model.py  # builds project/models/ranger_ev.glb from the Sketchfab download: recolours it yellow/black, drops the textures, splits the wheels and cargo box out (numpy only, D-182)
│   ├── make_corrugated_texture.py # generates the tileable blue corrugated-metal albedo + normal textures for the Shop walls (D-98)
│   ├── make_music.py             # renders project/audio/farm_theme.wav, the game's looping techno theme (D-178)
│   ├── make_music_groove.py      # the earlier relaxed electric-piano groove, to farm_theme_groove.wav (unused, D-176)
│   ├── make_barn_textures.py     # generates the tileable tan siding (albedo + normal) and post-wood textures for the Front Barn (D-125)
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
    │   ├── tree.tscn              # wraps models/tree.glb; unused since the treeline wall went in D-148, kept for the trees to come
    │   ├── transport_pad.tscn    # an invisible map teleport point (script only), instanced 5x under `TransportPads` in main.tscn — see D-131, D-139
    │   ├── cub_cadet_utv.tscn    # the drivable Cub Cadet 550 UTV (tuning only; the body is models/ranger_ev.glb, which has the bed), instanced once in the Front Barn — see D-127
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
    │   ├── tr6.tscn               # drivable car: models/tr6.glb under a CharacterBody3D with vehicle.gd and a box collider, instanced once — see D-106
    │   └── bmw_2002_tii.tscn      # drivable car, same setup as tr6.tscn, instanced once — see D-106
    ├── shaders/
    │   ├── distant_terrain.gdshader # low-poly distant land: summer/winter colours, own distance haze — see D-133
    │   ├── wind_turbine.gdshader  # distant wind turbines: spinning rotors, red warning lights at night — see D-133
    │   ├── horizon.gdshaderinc    # shared by both: squeezes far geometry inside the far plane, distance haze — see D-133
    │   ├── water.gdshader         # pond sheet and ditch ribbon: depth tint, foam edge, ripples; the ribbon rises with the flow texture — see D-141
    │   ├── world_ground.gdshader  # the ground beyond the farm: the world NAIP photo plus fine noise — see D-148
    │   ├── road.gdshader          # asphalt, edge lines, centre line and gravel verge for the roads — see D-148
    │   ├── terrain.gdshader       # the carved ground: NAIP base + both drone orthomosaics projected from world position — see D-140
    │   ├── night_sky.gdshader     # sky shader: flat sky colour + stars, Milky Way, constellation lines, northern lights — see D-104, D-105
    │   └── weather_surface.gdshader # overlay for the ground and roofs: wet darkening, puddles, settled snow — see D-105
    ├── scripts/
    │   ├── controls_overlay.gd    # read-only controls help panel in the player HUD, F1 toggles — see D-90/D-91
    │   ├── player.gd             # walking controller (hold Shift to walk, D-90), F or the mouse wheel switches 1st/3rd person (D-91), drives the body's animations (D-89) + look-at-and-press-E interaction ray and prompt (D-76)
    │   ├── horse.gd               # horse-specific wander AI (drives its own AnimationPlayer)
    │   ├── wander.gd              # generic no-animation wander AI, reused by hen/rooster/flock/coyote/ducks/geese/quail
    │   ├── fence_segment.gd       # @tool script: builds posts+wire strands from an exported length — see D-11
    │   ├── fence_path.gd          # @tool script: builds posts+wire strands from a Path3D/Curve3D's points instead of a length, closing the loop back to the first point (optional `solid` collision, D-76) — see D-67/D-69
    │   ├── gate.gd                # @tool script: builds the gate and swings its AnimatableBody3D hinge on interact() — see D-76
    │   ├── barn_facade.gd         # Front Barn outside: siding, skirt, posts, trim and roofs from the photo's cross-section — see D-125
    │   ├── barn_profile.gd        # the Front Barn's heights (wings, eave, ridge, clearance), shared by facade and interior — see D-125
    │   ├── barn_interior.gd       # Front Barn fittings: corner posts, three stalls with gates, tack room, two cubbies, hay stack — see D-116, D-121
    │   ├── building_shell.gd      # data-driven walk-in shell (hollow room, doors, windows, glass sliders, optional open walls, siding skin) for the House, its South Wing, Sally's House and the open Front Barn — see D-115, D-121, D-170
    │   ├── shop_shell.gd          # builds the walk-in Shop (hollow corrugated walls, windows, floor, ceiling, lights, pad) over the placeholder box's footprint and places its three doors — see D-98
    │   ├── shop_door.gd           # interactive door: swinging, sliding or roll-up leaf with collision, E to open — see D-98
    │   ├── vehicle.gd             # drivable car: E to get in/out, W/S/A/D/Space to drive, collides with the world — see D-106
    │   ├── transport_pad.gd       # transport point: invisible; the map lists it and `receive()` lands you beside it — see D-139
    │   ├── activity_icon.gd       # the drawn icons and stars on the Things to Do card — see D-168
    │   ├── things_to_do.gd        # the Things to Do card (H key): five things to try, teleport buttons, saved ticks — see D-167
    │   ├── whats_new.gd           # the What's New dialog (C key): the changelog and game-size stats, from release_data.gd — see D-130
    │   ├── release_notes.gd       # parses CHANGELOG.md, counts the game's size; pure, covered by tests/ — see D-130
    │   ├── release_data.gd        # GENERATED from CHANGELOG.md by tools/build_release_notes.gd; do not edit — see D-130
    │   ├── utv.gd                 # the Cub Cadet 550 UTV: vehicle.gd plus the model's tipping dump bed — see D-127, D-182
    │   ├── vehicle_math.gd        # pure driving maths (speed, mph, turn rate, exit spots), covered by tests/ — see D-106
    │   ├── wheel_builder.gd       # splits a car model's wheel meshes into four wheels that spin and steer, covered by tests/ — see D-107
    │   ├── engine_sound.gd        # synthesized engine note: gears, revs, harmonics; covered by tests/ — see D-107
    │   ├── wall_layout.gd         # pure helper that cuts a wall into boxes around openings, covered by tests/ — see D-98
    │   ├── corrugated.gd          # the shared blue corrugated-metal material (triplanar, mipmapped) — see D-98
    │   ├── siding.gd              # the farmhouse's pale blue lap siding, made in code (world triplanar) — see D-170
    │   ├── music_player.gd        # the looping soundtrack, P to toggle — see D-184
    │   ├── house_interior.gd      # the House's ground floor from the owner's photos: kitchen, pantry to the garage, dining, living room, a closed south-east block — see D-195
    │   ├── house_porch.gd         # the House's front porch: slab, steps, posts and roof; the concrete apron by the garage doors — see D-199
    │   ├── house_backyard.gd      # the House's back yard: deck and steps, concrete pad, AC unit, willows and mulch, siding on garage and gables — see D-170, D-171
    │   ├── willow.gd              # a tree-form willow grown in code from a seed (forking limbs, hanging leaf strands) — see D-171
    │   ├── birch.gd               # a tall poplar-type tree grown in code from a seed (furrowed grey-brown trunk, bare below, narrow crown, heart-shaped leaves); first built as a birch — see D-192, D-196
    │   ├── back_yard_birches.gd   # the seven back-yard birches at their world spots, a view south-west left open — see D-192
    │   ├── back_yard_shed.gd      # the little grey shed with a red door in the back yard's north-west corner, built from primitives — see D-193
    │   ├── russian_olive.gd       # an older Russian olive grown in code from a seed (crooked stems, wide crown, silvery leaves) — see D-194
    │   ├── russian_olives.gd      # the ~28 Russian olives along the farm's north side, thin west to thick east — see D-194
    │   ├── backyard_mockups.gd    # 35 back-yard ideas behind the House (30 realistic, 5 for fun), none roofed over the tub, O to step through them, a card and a hint — see D-184, D-190, D-197, D-198
    │   ├── mockup_kit.gd          # the mockups' building blocks: hot tubs on decks, fire tables, pavilions, counters, the Traeger, saunas, seating — see D-184, D-190
    │   ├── hot_tub_soak.gd        # get into a back-yard hot tub: underwear, a seat facing west, L lights, J jets, K sky scenes, steam — see D-190, D-191
    │   ├── world_terrain.gd       # the driveable world: builds and drops 320 m chunks (ground mesh, collider, road ribbons) around the camera — see D-148
    │   ├── world_math.gd          # pure world-ground maths (grid heights on the mesh's own triangles, farm blend, chunk meshes), covered by tests/ — see D-148
    │   ├── road_math.gd           # pure road maths (resample, ribbon geometry, nearest road), covered by tests/ — see D-148
    │   ├── world_data.gd          # GENERATED by tools/build_world_data.py: 20 m elevation grid, road beds cut in — see D-148
    │   ├── road_data.gd           # GENERATED by tools/build_world_data.py: named road centrelines from TIGERweb, with asphalt or gravel per point — see D-148, D-150
    │   ├── minimap.gd             # map controller: minimap, full-screen map (M, pauses the game), zoom/pan, waypoint, trail, layer toggles — see D-93
    │   ├── map_canvas.gd          # draws one map view (imagery, footprints + names, fences, horses, trail, waypoint, player) from scene groups — see D-93
    │   ├── map_math.gd            # pure map helpers (projection, zoom, bearings, footprints, trail), covered by tests/ — see D-93
    │   ├── drive_hud.gd           # quiet driving readout: big soft-blue speed, rpm, dim "E  get out" — see D-113
    │   ├── sky_menu.gd            # sky & weather menu (G or the minimap icon): pick time of day, weather, constellation names, season, and the Water row (weir, ditch, pond level, water speed); pauses the game — see D-110, D-133, D-142
    │   ├── constellation_names.gd # names and sky anchors for the constellation labels — see D-110
    │   ├── time_of_day.gd         # Day / Sunset / Dusk / Night / Dawn / Sunrise lighting presets, cycled with T; overcast hook for weather — see D-94, D-95
    │   ├── distant_terrain.gd     # builds the land out to 80 km (Blue Mountains, wind-farm ridges) and ~1,100 real turbines; season — see D-133
    │   ├── horizon_math.gd        # pure distant-terrain maths (exaggeration, curvature, squeezing, haze), covered by tests/ — see D-133
    │   ├── horizon_data.gd        # GENERATED by tools/build_horizon_data.py: elevation grid + turbine list — see D-133
    │   ├── sky_math.gd            # pure night-sky maths (sidereal time, celestial → world rotation, star colour/size), covered by tests/ — see D-104
    │   ├── water_system.gd        # the ditch and pond water: steps the flow, the pond level and rain; builds the weir and pipe mouths and the pond's overflow channel; E opens the weir — see D-141, D-180
    │   ├── water_math.gd          # pure water maths (ditch and overflow routes, flow row, pond volume/level table, spilling), covered by tests/ — see D-141, D-180
    │   ├── toast.gd               # toasts: short fading notices at the top of the screen, posted with `call_group("toast", "show_toast", text, colour)` — see D-142
    │   ├── terrain.gd             # builds the carved ground: one mesh + trimesh collider, ditch and pond cut in, imagery projected on — see D-140
    │   ├── terrain_math.gd        # pure carve maths (ditch trapezoid, pond bowl, height at a point), covered by tests/ — see D-140
    │   ├── water_data.gd          # GENERATED by tools/build_water_data.py: ditch segments, pipe runs, pond spine — see D-140
    │   ├── star_map.gd            # bakes the star and constellation-line maps the sky shader reads — see D-104
    │   ├── star_data.gd           # GENERATED by tools/build_star_data.py: ~1,600 bright stars + constellation lines — see D-104
    │   └── weather.gd             # Clear / Rain / Snow: camera-following particles, roof/tree occlusion, overcast sky, cycled with R — see D-95
    ├── tests/                    # headless test scripts (extends SceneTree), excluded from export — see CONTRIBUTING.md
    │   ├── test_map_math.gd       # unit tests for map_math.gd
    │   ├── test_map_scene.gd      # loads main.tscn, checks the map's collected data and M pause toggle
    │   ├── test_wall_layout.gd    # unit tests for wall_layout.gd
    │   ├── test_shop.gd           # loads main.tscn, checks the Shop's walls block and its three doors open and close
    │   ├── test_time_of_day.gd    # preset helpers + TimeOfDay driving main.tscn's sun/environment on T
    │   ├── test_horizon.gd        # distant terrain: real geography in the data, the maths, DistantTerrain in main.tscn, Season button
    │   ├── test_buildings.gd      # Sally's House and Front Barn shells: built, doors placed, the player walks in through doorways and not walls
    │   ├── test_things_to_do.gd   # the Things to Do card: list, saved ticks, teleports, what counts as done
    │   ├── test_house_front.gd    # the porch, the front windows and the garage's two roll-up doors; the player walks in the front door — see D-199
    │   ├── test_house_interior.gd # the House's rooms are built, the pantry door meets the garage, the player walks slider to front door and pantry to garage — see D-195
    │   ├── test_backyard_mockups.gd # every back-yard idea meets the brief, stays in the yard, and the doors and sliders still let you out
    │   ├── test_hot_tub.gd        # getting into a hot tub: underwear, seat facing west, lights, jets, steam, and out onto the deck
    │   ├── test_sky_menu.gd       # start position / third person, constellation name labels, sky menu picks and pause
    │   ├── test_toast.gd          # toast queue, fade, de-duplication, works while paused — see D-142
    │   ├── test_decisions.gd      # decisions.md: row IDs unique, in order, none skipped (catches parallel branches claiming the same D-number) — see D-146
    │   ├── test_world.gd          # world data, ground heights vs mesh, chunks, roads, road beds, open boundary, a drive up a hill road — see D-148
    │   ├── test_water.gd          # route, pond basin table, flow row, pond step; the Water node: weir E, fill, drain, rain — see D-141
    │   ├── test_terrain.gd        # carve maths, slopes, data sync with the trace JSON, Terrain in main.tscn, posts and animals on the ground — see D-140
    │   ├── test_weather.gd        # weather/overcast helpers + Weather switching rain/snow on R in main.tscn
    │   ├── test_night_sky.gd      # sky maths, star data + baked maps, and the sky shader driven by TimeOfDay
    │   ├── test_parked_cars.gd    # the three parked cars stay on the ground at startup (the UTV used to fall through the barn floor), see D-147
    │   ├── test_transport.gd      # super-sprint speed choice, and the transport points: invisible, inside the property, `receive()` lands you facing away
    │   └── test_vehicle.gd        # driving maths, then both cars driven in main.tscn: board, throttle, steer, brake, reverse, wall, exit
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
    │   ├── ranger_ev.glb           # Sketchfab Standard (geyges) Polaris Ranger EV body, recoloured Cub Cadet yellow/black
    │   │                            # by tools/build_ranger_ev_model.py (4.7 MB, 116k tris; no textures) — see D-182, credits.md
    │   └── tr6.glb                 # CC-BY static mesh (Configcars, Sketchfab), simplified from a 32MB/879k-tri
    │                                # download to 7.7MB — see D-25, credits.md
    └── textures/
        ├── world/                 # naip_world.jpg: one NAIP photo of the whole 11.2 km world square (D-148)
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
