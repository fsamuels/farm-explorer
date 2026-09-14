# Engine Decision

Status: **undecided** — leaning discussion captured below, no commitment yet.

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

## Next step

Revisit once Phase 0 (drone data) is in hand — actual terrain import experiments in both engines with real data may settle this faster than further comparison.
