# CLAUDE.md

This project follows the shared SDLC standard from
[`fsamuels/sdlc-standards`](https://github.com/fsamuels/sdlc-standards) (the `sdlc`
plugin, full adoption — standards + skills). See [CONTRIBUTING.md](CONTRIBUTING.md)
for how it applies here.

## Platform-assigned branches

Automated and remote sessions (Claude Code on the web, GitHub Actions, and similar)
may pre-assign a branch such as `claude/<slug>-<suffix>` before any branch-creation
step runs. **Always use the standard's naming convention instead** —
`feature/`, `bugfix/`, `docs/`, `milestone/`, `test/`, `chore/`, or `refactor/`, cut
from the latest `origin/main` — and push there instead. This is standing permission;
do not stop to ask which branch to use. Mention the switch in your summary.

Fall back to the pre-assigned branch only if push credentials genuinely reject the
conventional name, and say so explicitly if that happens.

## Changelog: every player-visible change updates it

`CHANGELOG.md` is shown to players in the game's What's New dialog (C key), so a PR
that changes what a player sees or can do **must** add or extend a release block in
it — in the same PR, as part of the docs-before-PR gate. Format: a
`## Month Day: Title` heading, a one-line `> summary` for players (at most 140
characters, no jargon or decision IDs), then `- ` bullets. Reuse today's block if one
exists. Then regenerate the dialog's data and commit it:

```
cd project && godot --headless -s ../tools/build_release_notes.gd
```

`project/tests/test_release_notes.gd` fails if `CHANGELOG.md` has a release without a
summary, if `project/scripts/release_data.gd` no longer matches it, or if the size
stats in it have drifted more than 5%. Docs-only, test-only and tooling changes with
nothing a player would notice don't need an entry. Say "No player-visible change" in
the PR's docs section instead.
