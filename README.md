# Farm Sim — Explorable Digital Model of Reign Cloud Ranch

A first-person explorable 3D model of a real horse boarding farm in Touchet, WA,
built from drone survey data. Long-term goal: add buildings, animals, chores/tasks,
and light gameplay — in that order.

## Status

Engine chosen: Godot 4 (see [docs/engine-decision.md](docs/engine-decision.md)).
Project skeleton is in [`project/`](project) — a walkable first-person controller
(F or the mouse wheel switches to a third-person view of the player character, D-89/D-91;
M opens a full-screen map with labeled buildings, a waypoint, your trail and an X / Z coordinate grid, D-93/D-97, and a double-click on a building teleports you to just outside its front door, D-118;
T cycles the time of day through day, sunset, dusk, night, dawn and sunrise, D-94–D-96,
and a clock (running from the start, Y pauses it) that advances it on its own, with a small top-right time estimate, D-99/D-103, under a sky with a sun and moon disc, real stars, a Milky Way, constellation lines and names (N), the planets and shooting stars, a full moon that rises and sets (or never, your choice), D-104/D-110/D-120/D-123, and a sky menu (G, or the icon under the minimap) that picks the time of day, weather, moon and shooting stars directly, D-110;
C opens a What's New window with the changelog and the game's size, D-130;
R cycles the weather through clear, drizzle, rain, downpour, thunderstorm, light and heavy fog, smoke haze and heavy smoke, snow, heavy snow, a rainbow and the northern lights, with wet ground, puddles and settling snow, D-95/D-99/D-101/D-102/D-105;
the Shop is walk-in — blue corrugated walls, windows, and an entry door, roll-up garage door and sliding barn door you open with E, D-98 — and so are Sally's House, the Back Barn (D-123) and the Front Barn, Sally's House one big room for now (D-115) and the Front Barn an open pole barn with posts, stalls, a tack room and cubbies (D-121), shaped and textured from a photo of its north end, which is also where the map teleport puts you (D-125);
the Triumph TR6, BMW 2002 tii and the Front Barn's yellow Cub Cadet 550 UTV can be driven — E to get in or out, W/S gas and brake, A/D steer, Space handbrake, D-106, and B tips the UTV's dump bed, D-127),
holding Ctrl is a super sprint and the map (M) also teleports you to named transport points in the back pastures, D-131 and D-139, and likewise to the three driveable vehicles, which the map also shows, D-144,
and the irrigation ditch can be burned — 1 takes out a propane torch, hold the left mouse button to burn, with a wind-driven fire, tall dry grass and the "Burn the Ditch" quest, D-156,
the real parcel boundary and (approximate) building footprints, and a ground
plane textured with public NAIP aerial imagery as a stand-in for the real
drone-derived orthomosaic (Phase 1). See
[docs/implementation-plan.md](docs/implementation-plan.md).

## Goals (priority order)

1. Recognizable, accurately-scaled terrain and property layout
2. Placeholder buildings and fences at correct positions
3. First-person walking exploration
4. Detail pass: textures, vegetation, lighting, hero buildings
5. Animals (static, then simple movement)
6. Chores/task systems (gameplay — lowest priority)

## Non-goals (for now)

- Full photorealism
- Any gameplay/scoring systems
- Multiplayer

## Repo layout

See [docs/repo-structure.md](docs/repo-structure.md).

## Docs

| Document | Contents | Changes |
| --- | --- | --- |
| [docs/implementation-plan.md](docs/implementation-plan.md) | Phased build plan, engine-agnostic | As phases complete or reorder |
| [docs/drone-capture-plan.md](docs/drone-capture-plan.md) | Drone flight + processing plan for Phase 0 | Rarely, once capture happens |
| [docs/engine-decision.md](docs/engine-decision.md) | Godot vs Unity vs Unreal tradeoffs | Once, when the engine is chosen |
| [docs/parcel-data.md](docs/parcel-data.md) | Confirmed parcel facts (ID, acreage, boundary source) and how the boundary GeoJSON was obtained | As real GIS/survey data lands |
| [docs/repo-structure.md](docs/repo-structure.md) | Repo layout reference | Rarely, when layout changes |
| [docs/credits.md](docs/credits.md) | Attribution for third-party assets that require it (CC-BY etc.) | Whenever a non-CC0 asset is added |
| [docs/distribution.md](docs/distribution.md) | How to export a Web build and publish it to itch.io | As export/publishing steps change |
| [CHANGELOG.md](CHANGELOG.md) | Customer-facing "what's new" highlights, newest first; shown in the game's What's New window (C) | Every player-visible change, with a one-line summary (see CLAUDE.md) |
| [docs/easter-eggs.md](docs/easter-eggs.md) | Hidden things in the game, found and planned | When an easter egg is found or added |
| [docs/project/decisions.md](docs/project/decisions.md) | Append-only decision log | Every decision |

## Process

This project follows the shared SDLC standard from
[`fsamuels/sdlc-standards`](https://github.com/fsamuels/sdlc-standards) — see
[CONTRIBUTING.md](CONTRIBUTING.md).
