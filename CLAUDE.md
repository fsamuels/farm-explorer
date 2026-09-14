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
