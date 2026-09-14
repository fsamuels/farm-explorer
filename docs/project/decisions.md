# Decisions

Append-only decision log. Each row: what was decided, why, how reversible it is, and
who decided. See [`fsamuels/sdlc-standards`](https://github.com/fsamuels/sdlc-standards)
for the format this table follows.

| ID | Date | Decision | Rationale | Reversibility | Decided by |
| --- | --- | --- | --- | --- | --- |
| D-1 | 2026-09-14 | Adopt `fsamuels/sdlc-standards` full layer (standards + skills) | Keep branch naming, docs organization, and PR process consistent with other projects on the same account from day one, rather than drifting and reconciling later | Easy — two `.claude/settings.json` keys plus a few vendored files | fsamuels |
| D-2 | 2026-09-14 | Choose Godot 4 as the engine | Fast iteration and low motivation-risk outweigh Unreal's higher photorealism ceiling, which this project isn't targeting anyway (see README non-goals); Godot's plain-text project files are also the only one of the three a Claude Code cloud session can meaningfully edit | Moderate — asset/logic work invested in Godot won't carry over automatically, though 3D assets (glTF/FBX, PBR textures) port to another engine if needed later | fsamuels |
| D-3 | 2026-09-14 | Start Phase 2 layout blockout before drone capture, using a provisional square boundary sized to the confirmed 24.06-acre parcel total and a placeholder building box, rather than waiting on real GIS/orthomosaic data | Makes visible progress possible while capture is pending; county GIS/parcel viewers are interactive-only and not fetchable headlessly, so exact boundary shape and building footprints aren't available yet | Easy — boundary mesh and building position are explicitly placeholder and get replaced wholesale once real data lands | fsamuels |
