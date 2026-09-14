# Farm Sim — Explorable Digital Model of Reign Cloud Ranch

A first-person explorable 3D model of a real horse boarding farm in Touchet, WA,
built from drone survey data. Long-term goal: add buildings, animals, chores/tasks,
and light gameplay — in that order.

## Status

Engine chosen: Godot 4 (see [docs/engine-decision.md](docs/engine-decision.md)).
Project skeleton is in [`project/`](project) — a walkable first-person controller
on a placeholder ground plane, ready for real terrain (Phase 1). See
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
| [docs/project/decisions.md](docs/project/decisions.md) | Append-only decision log | Every decision |

## Process

This project follows the shared SDLC standard from
[`fsamuels/sdlc-standards`](https://github.com/fsamuels/sdlc-standards) — see
[CONTRIBUTING.md](CONTRIBUTING.md).
