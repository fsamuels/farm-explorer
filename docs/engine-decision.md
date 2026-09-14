# Engine Decision

Status: **decided — Godot 4** (2026-09-14). See rationale below the candidate
comparison, and the project skeleton at [`project/`](../project).

## Candidates

### Godot
- Free, open source (MIT), no royalties ever
- Faster iteration loop, lighter weight
- Strong 2D, improving but less battle-tested 3D/terrain tooling at scale
- Known titles: mostly indie/stylized (Brotato, Cassette Beasts, Dome Keeper); no major 3D open-world terrain title yet

### Unity
- Free tier available, licensing/royalty terms should be re-checked at time of decision (they change)
- More mature 3D terrain and sim-genre track record — Cities: Skylines (terrain + building placement + systems) is a directly relevant reference
- Larger tutorial/community base for terrain-heavy projects
- Known titles: Hollow Knight, Cuphead, Among Us, Ori series, Subnautica, Cities: Skylines

### Unreal Engine
- Best out-of-the-box photorealism / lighting
- Steepest learning curve, most overkill for this project's genre (sim/exploration, not FPS-grade combat/graphics needs)
- Not currently a frontrunner for this project

## Decision factors specific to this project

- Priority is 3D terrain/environment fidelity and fast iteration — favors Unity or Godot over Unreal
- No current need for complex gameplay systems — reduces weight of engine scripting ergonomics as a factor
- Long-term openness to detail/realism polish — slight edge to Unity given terrain/sim track record
- No cost sensitivity stated yet, but Godot's zero-licensing-ever is a clean tiebreaker if other factors are close

## Decision

**Godot**, chosen over Unity and Unreal.

- Unreal has the strongest out-of-the-box photorealism ceiling (Lumen, Nanite,
  native Quixel Megascans), but its overhead — heaviest local install, GUI-only
  Blueprint workflow, steepest learning curve — is the wrong tradeoff given real
  risk of losing momentum on this project before it produces anything visible.
- Not pursuing full photorealism (see README non-goals), which removes Unreal's
  main advantage and narrows the Godot/Unity gap on visual ceiling.
- Godot's project files (`.tscn` scenes, `.gd` scripts) are plain text, unlike
  Unity's fragile-to-hand-edit YAML or Unreal's binary/visual Blueprints. That
  makes Godot the only one of the three where a Claude Code cloud session can
  meaningfully contribute — writing scenes, scripts, and logic as text — between
  local sessions, which matters given the motivation-risk above.
- Zero licensing cost is irrelevant here (no monetization plan) but was a clean
  tiebreaker if other factors were close; they weren't — iteration speed and
  cloud-session compatibility settled it.
- Terrain/3D tooling is less battle-tested at scale than Unity's, but this
  project's terrain needs (Phase 1) are modest relative to a AAA open world.

## Next step

Terrain import experiments in Godot with real drone/orthomosaic data (Phase 0/1
of the implementation plan) once that data is captured.
