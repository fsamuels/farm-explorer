# Contributing

This project follows the shared process standard in
[`fsamuels/sdlc-standards`](https://github.com/fsamuels/sdlc-standards) (the `sdlc`
plugin, full adoption). It defines branch naming, documentation organization, and
the docs-before-PR gate — see that repo rather than a local restatement.

Wired via `.claude/settings.json` (`extraKnownMarketplaces` + `enabledPlugins`), with
`scripts/ensure-sdlc-plugin.sh` vendored as a `SessionStart` self-heal in case the
plugin doesn't auto-install (see
[`docs/packaging.md`](https://github.com/fsamuels/sdlc-standards/blob/main/docs/packaging.md#known-gap-intermittent-auto-install-failure)
in that repo).

## What's local to this project

- **Docs stay flat under `docs/`** — four small planning files, plus the decision log
  at the standard's fixed path (`docs/project/decisions.md`). No full
  `product/`/`technical`/`project` split yet; revisit past ~5 files per topic area
  per the standard's own threshold.
- **No link checker yet** — docs don't meaningfully cross-reference each other yet.
  Add one (per `documentation.md#link-integrity-is-enforced-not-hoped-for`) once they do.
- **Engine is Godot 4** — see [`docs/engine-decision.md`](docs/engine-decision.md).
  No build/lint/test tooling is wired up yet (no CI, no headless-export check); the
  standard's skills (`/sdlc:new-branch`, `/sdlc:create-pr`) still don't know this
  project's commands, so `create-pr`'s Checks section will keep saying "Skipped —
  no build tooling yet" until that's added.

## Where the process differs from this repo's day-to-day

Nowhere yet — this project has no code, so nothing has had a chance to diverge.
Anything that does diverge gets reconciled per the standard's own guidance
(routed upward if it's a guess, answered locally if it's been run — see
[`README.md#applying-this-to-a-project`](https://github.com/fsamuels/sdlc-standards#applying-this-to-a-project)
in that repo).
